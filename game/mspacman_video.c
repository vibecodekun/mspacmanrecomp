/*
 * mspacman_video.c — full-maze vertical view for Ms. Pac-Man (Tengen, 1991).
 *
 * The game draws each whole maze (plus its HUD rows) into a 32x64-cell plane at
 * maze load ($000FD0) and only ever scrolls vertically: one camera word
 * ($FF000E, 1/32 px) is copied to both VSRAM entries each V-int ($002838).
 * Sprites are kept in screen space and the game re-bases them itself whenever
 * the camera moves. So the complete playfield is always resident in VRAM, and a
 * locked camera is a pure presentation transform:
 *
 *   plane row   = locked_top + output_row
 *   sprite row  = native_line + (game_camera - locked_top)
 *
 * Game logic is untouched: the game still "scrolls" internally; only this
 * presentation ignores it. With the view off (default) nothing here runs and
 * the native VDP output is presented unchanged.
 *
 * Presentation modes (configure):
 *   off                    native 224-line view
 *   fit / full / W:H       one fixed canvas tall enough for the largest maze
 *                          (360 lines); smaller mazes are centered in it
 *   stage / maze           canvas height follows the current maze exactly
 * Non-maze screens (title, menus, intermissions, H40 modes) are shown native,
 * centered vertically.
 */
#include "game_video.h"
#include "genesis_runtime.h"
#include "video/genesis_vdp.h"
#include "video/genesis_dac.h"
#include "video/genesis_machine.h"

#include <stdio.h>
#include <string.h>

/* ---- Game facts (verified against the ROM; see game.toml) ------------------ */
#define RAM_CAMERA        0x000Eu   /* camera Y, 1/32 px                        */
#define RAM_CAMERA_MAX    0x0012u   /* per-maze max camera, set by $000FD0      */
#define RAM_INTERMISSION  0x2A5Cu   /* nonzero: V-int runs the cutscene ($E002) */
#define CAMERA_MIN        0x0100u   /* every maze starts at camera $100 (8 px)  */
#define NATIVE_LINES      224
#define TALLEST_MAZE      360       /* Big mazes: 37 rows -> camera 8..144 px   */

enum { VIEW_OFF, VIEW_FULL, VIEW_MAZE };
static int s_mode = VIEW_OFF;

/* Always-on self-check: on every composed maze frame, the rows that the native
 * 224-line raster showed must reappear unchanged at output rows shifted by the
 * camera offset. Queried over TCP (mspac_view); never printed per frame. */
static struct {
    unsigned frames_maze, frames_native, pixels_checked, pixels_mismatched;
    unsigned mismatch_frames;
    int last_shift, last_top, last_field, last_height;
    /* Most recent mismatching frame: wall frame, native row span, pixel count. */
    unsigned long long bad_frame;
    int bad_first_line, bad_last_line;
    unsigned bad_pixels;
} s_stats;

static unsigned ram16(unsigned a)
{
    a &= 0xFFFFu;
    return ((unsigned)g_ram[a] << 8) | g_ram[(a + 1u) & 0xFFFFu];
}

static unsigned vram16(const GVDP *v, unsigned a)
{
    return ((unsigned)v->vram[a & 0xFFFFu] << 8) | v->vram[(a + 1u) & 0xFFFFu];
}

/* Height of the whole scrolling playfield (camera range + one screen). */
static int playfield_height(void)
{
    unsigned max = ram16(RAM_CAMERA_MAX);
    return (int)((max - CAMERA_MIN) >> 5) + NATIVE_LINES;
}

/* The maze screen: H32, 32x64 plane, full-screen vertical scroll, no window,
 * no shadow/highlight, not a cutscene, and a sane per-maze camera range. */
static int maze_screen(const GVDP *v)
{
    unsigned max = ram16(RAM_CAMERA_MAX);
    return (v->reg[12] & 0x89) == 0 &&
           v->reg[16] == 0x10 &&
           (v->reg[11] & 0x04) == 0 &&
           v->reg[17] == 0 && v->reg[18] == 0 &&
           ram16(RAM_INTERMISSION) == 0 &&
           max > CAMERA_MIN && max <= 0x2000u && (max & 0xFFu) == 0;
}

static int configure(const char *mode)
{
    if (!mode) return 0;
    if (!strcmp(mode, "off")) s_mode = VIEW_OFF;
    else if (!strcmp(mode, "stage") || !strcmp(mode, "maze")) s_mode = VIEW_MAZE;
    else if (!strcmp(mode, "fit") || !strcmp(mode, "adaptive") ||
             !strcmp(mode, "full") || strchr(mode, ':')) s_mode = VIEW_FULL;
    else return 0;
    return 1;
}

static int enabled(void) { return s_mode != VIEW_OFF; }

/* Width is always native; this renderer only adds rows. */
static int width(int dw, int dh, int nw, int nh)
{
    (void)dw; (void)dh; (void)nw; (void)nh;
    return 0;
}

static void scanline(const struct GVDP *vdp, int line, const uint32_t *native,
                     int native_w, uint32_t *out, int w)
{
    (void)vdp; (void)line;
    memcpy(out, native, (size_t)(native_w < w ? native_w : w) * sizeof(uint32_t));
}

static int height(int native_w, int native_h)
{
    if (!native_w && !native_h) return s_mode == VIEW_OFF ? 0 : TALLEST_MAZE;
    if (s_mode == VIEW_OFF || native_h != NATIVE_LINES) return 0;
    if (s_mode == VIEW_FULL) return TALLEST_MAZE;
    /* VIEW_MAZE: the exact playfield on maze screens, native elsewhere. */
    return maze_screen(&g_machine.vdp) ? playfield_height() : 0;
}

/* ---- Composition ---------------------------------------------------------- */

static int plane_cells(int bits) { return bits == 1 ? 64 : bits == 3 ? 128 : 32; }

/* Palette index (0 = transparent) and priority of a plane pixel. */
static unsigned plane_pixel(const GVDP *v, unsigned base, int x, int y, int *hi)
{
    int wc = plane_cells(v->reg[16] & 3), hc = plane_cells((v->reg[16] >> 4) & 3);
    int px = x & (wc * 8 - 1), py = y & (hc * 8 - 1);
    unsigned attr = vram16(v, base + (unsigned)((py >> 3) * wc + (px >> 3)) * 2u);
    int fx = px & 7, fy = py & 7;
    if (attr & 0x0800) fx ^= 7;
    if (attr & 0x1000) fy ^= 7;
    unsigned byte = v->vram[((attr & 0x7FFu) * 32u + (unsigned)fy * 4u + (unsigned)fx / 2u) & 0xFFFFu];
    unsigned nib = (fx & 1) ? (byte & 15u) : (byte >> 4);
    *hi = (attr & 0x8000) != 0;
    return nib ? (((attr >> 9) & 0x30u) | nib) : 0;
}

typedef struct { int x, y, w, h; unsigned attr; } Sprite;

static int collect_sprites(const GVDP *v, int shift, Sprite *out)
{
    unsigned sat = (v->reg[5] & 0x7Fu) << 9;   /* H32: bit 0 used */
    int n = 0, link = 0;
    for (int guard = 0; guard < 64; ++guard) {
        unsigned e = sat + (unsigned)link * 8u;
        unsigned y = vram16(v, e) & 0x1FFu;
        unsigned sl = vram16(v, e + 2);
        unsigned attr = vram16(v, e + 4);
        unsigned x = vram16(v, e + 6) & 0x1FFu;
        Sprite *s = &out[n++];
        s->w = (int)((sl >> 10) & 3) + 1;
        s->h = (int)((sl >> 8) & 3) + 1;
        s->x = (int)x - 128;
        s->y = (int)y - 128 + shift;
        s->attr = attr;
        link = (int)(sl & 0x7F);
        if (!link || link >= 64) break;
    }
    return n;
}

static void compose_maze(const GVDP *v, uint32_t *out, int stride, int w, int out_h)
{
    uint32_t pal[64];
    for (int i = 0; i < 64; ++i) pal[i] = genesis_dac_cram_to_argb(v->cram[i], GENESIS_DAC_NORMAL);
    uint32_t backdrop = pal[v->reg[7] & 63];

    /* Locked camera: the playfield top, centered in taller canvases. */
    int field = playfield_height();
    int top = (int)(CAMERA_MIN >> 5) - (out_h > field ? (out_h - field) / 2 : 0);
    int vs_a = v->vsram[0] & 0x3FF, vs_b = v->vsram[1] & 0x3FF;
    int shift = vs_a - top;          /* native line -> output row for sprites */
    s_stats.last_shift = shift;
    s_stats.last_top = top;
    s_stats.last_field = field;

    unsigned base_a = (v->reg[2] & 0x38u) << 10, base_b = (v->reg[4] & 0x07u) << 13;
    unsigned hs_base = (v->reg[13] & 0x3Fu) << 10;
    int hmode = v->reg[11] & 3;

    static Sprite spr[64];
    int ns = collect_sprites(v, shift, spr);
    uint8_t line_idx[512], line_hi[512];

    for (int r = 0; r < out_h; ++r) {
        uint32_t *row = out + r * stride;
        int native_line = r - shift;
        int hl = hmode == 0 ? 0 : hmode == 2 ? (native_line & ~7) : native_line;
        if (hl < 0) hl = 0; else if (hl > NATIVE_LINES - 1) hl = NATIVE_LINES - 1;
        int hs_a = (int)(int16_t)vram16(v, hs_base + (unsigned)hl * 4u) & 0x3FF;
        int hs_b = (int)(int16_t)vram16(v, hs_base + (unsigned)hl * 4u + 2u) & 0x3FF;
        int ya = r + vs_a - shift, yb = r + vs_b - shift;

        /* Sprite line: first sprite in link order owns a pixel. */
        memset(line_idx, 0, (size_t)w);
        for (int k = 0; k < ns; ++k) {
            const Sprite *s = &spr[k];
            int iy = r - s->y;
            if (iy < 0 || iy >= s->h * 8) continue;
            if (s->attr & 0x1000) iy = s->h * 8 - 1 - iy;
            for (int i = 0; i < s->w * 8; ++i) {
                int x = s->x + i;
                if (x < 0 || x >= w || line_idx[x]) continue;
                int ix = (s->attr & 0x0800) ? s->w * 8 - 1 - i : i;
                unsigned tile = ((s->attr & 0x7FFu) + (unsigned)((ix >> 3) * s->h + (iy >> 3))) & 0x7FFu;
                unsigned byte = v->vram[(tile * 32u + (unsigned)(iy & 7) * 4u + (unsigned)(ix & 7) / 2u) & 0xFFFFu];
                unsigned nib = (ix & 1) ? (byte & 15u) : (byte >> 4);
                if (!nib) continue;
                line_idx[x] = (uint8_t)(((s->attr >> 9) & 0x30u) | nib);
                line_hi[x] = (uint8_t)((s->attr & 0x8000) != 0);
            }
        }

        for (int x = 0; x < w; ++x) {
            int ahi, bhi;
            unsigned a = plane_pixel(v, base_a, x - hs_a, ya, &ahi);
            unsigned b = plane_pixel(v, base_b, x - hs_b, yb, &bhi);
            unsigned s = line_idx[x];
            int shi = s && line_hi[x];
            unsigned p = (s && shi) ? s : (a && ahi) ? a : (b && bhi) ? b
                       : s ? s : a ? a : b;
            row[x] = p ? pal[p] : backdrop;
        }
    }
}

static void letterbox(const uint32_t *native, int nstride, int nw, int nh,
                      uint32_t *out, int stride, int out_h)
{
    int top = (out_h - nh) / 2;
    for (int r = 0; r < out_h; ++r) {
        uint32_t *row = out + r * stride;
        int src = r - top;
        if (src >= 0 && src < nh)
            memcpy(row, native + src * nstride, (size_t)nw * sizeof(uint32_t));
        else
            memset(row, 0, (size_t)nw * sizeof(uint32_t));
    }
}

static void verify_against_native(const uint32_t *native, int nstride, int nw,
                                  const uint32_t *out, int stride, int out_h)
{
    unsigned bad = 0, checked = 0;
    int first = -1, last = -1;
    for (int line = 0; line < NATIVE_LINES; ++line) {
        int r = line + s_stats.last_shift;
        if (r < 0 || r >= out_h) continue;
        const uint32_t *a = native + line * nstride, *b = out + r * stride;
        unsigned row_bad = 0;
        for (int x = 0; x < nw; ++x) { ++checked; row_bad += a[x] != b[x]; }
        if (row_bad) { if (first < 0) first = line; last = line; bad += row_bad; }
    }
    s_stats.pixels_checked += checked;
    s_stats.pixels_mismatched += bad;
    if (bad) {
        ++s_stats.mismatch_frames;
        s_stats.bad_frame = g_frame_count;
        s_stats.bad_first_line = first;
        s_stats.bad_last_line = last;
        s_stats.bad_pixels = bad;
    }
}

static void frame(const struct GVDP *vdp, const uint32_t *native, int nstride,
                  int nw, int nh, uint32_t *out, int stride, int out_h)
{
    const GVDP *v = vdp;
    s_stats.last_height = out_h;
    if (nw == 256 && nh == NATIVE_LINES && (v->reg[1] & 0x40) && maze_screen(v)) {
        compose_maze(v, out, stride, nw, out_h);
        verify_against_native(native, nstride, nw, out, stride, out_h);
        ++s_stats.frames_maze;
    } else {
        letterbox(native, nstride, nw, nh, out, stride, out_h);
        ++s_stats.frames_native;
    }
}

void mspacman_video_command(int id, const char *json)
{
    extern void cmd_send_response(const char *json);
    char reply[512];
    (void)json;
    snprintf(reply, sizeof reply,
             "{\"id\":%d,\"enabled\":%d,\"mode\":%d,\"height\":%d,\"frames_maze\":%u,"
             "\"frames_native\":%u,\"pixels_checked\":%u,\"pixels_mismatched\":%u,"
             "\"mismatch_frames\":%u,\"shift\":%d,\"top\":%d,\"playfield\":%d,"
             "\"camera\":%u,\"camera_max\":%u,\"bad_frame\":%llu,\"bad_lines\":[%d,%d],"
             "\"bad_pixels\":%u}",
             id, enabled(), s_mode, s_stats.last_height, s_stats.frames_maze,
             s_stats.frames_native, s_stats.pixels_checked, s_stats.pixels_mismatched,
             s_stats.mismatch_frames, s_stats.last_shift, s_stats.last_top,
             s_stats.last_field, ram16(RAM_CAMERA), ram16(RAM_CAMERA_MAX),
             s_stats.bad_frame, s_stats.bad_first_line, s_stats.bad_last_line,
             s_stats.bad_pixels);
    cmd_send_response(reply);
}

static const GameVideoMod s_mod = {
    "Full maze view",
    "Shows every maze in full, HUD included, with no forced scrolling. "
    "Game logic is unchanged. Disabled restores the original scrolling view.",
    "Canvas",
    "All mazes: one 360-line canvas, smaller mazes centered. "
    "Per maze: the height follows each maze exactly.",
    2,
    { "fit", "stage" },
    { "All mazes (fixed height)", "Per maze" },
};

const GameVideo mspacman_video = {
    .configure = configure,
    .enabled   = enabled,
    .width     = width,
    .scanline  = scanline,
    .height    = height,
    .frame     = frame,
    .mod       = &s_mod,
};
