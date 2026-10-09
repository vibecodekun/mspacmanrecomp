/*
 * mspacman_spec.c — GameSpec for Ms. Pac-Man (Tengen, 1991), USA/Europe.
 *
 * ROM layout: flat 128 KB at $000000-$01FFFF, identity-mapped, no SRAM.
 *   Reset SSP   = $00000000 (first push wraps to $FFFFFC)
 *   EntryPoint  = $000200
 *   VInt (IRQ6) = $0014AA
 *
 * Interrupt model. Ms. Pac-Man runs all of its gameplay inside the V-int
 * handler. The main program keeps interrupts masked ($2700) everywhere except
 * two idle loops, each `MOVE #$2300,SR; BRA *`:
 *
 *   $0008F6  gameplay idle
 *   $00F76E  attract/demo idle
 *
 * The handler is not a short atomic routine: it can poll the HV counter for
 * many frames (the $0004E8 raster wait) and three paths discard its own
 * exception frame (`MOVE.L (A7)+; MOVE.W (A7)+`) and carry on as main-program
 * code, later re-entering an idle loop. The runner's default delivery runs a
 * V-int atomically on the scheduler fiber and requires it to return, which
 * cannot express either behaviour.
 *
 * So the game fiber takes IRQ6 itself, exactly where the 68000 does:
 *   - The idle-loop hooks record the idle PC/A7 and unwind every generated C
 *     frame back to mspac_call_entry_point via the generator's own
 *     g_rte_pending propagation (the same path RTE/skip-returns use).
 *   - The driver parks the CPU in the idle loop until the runner's V-int
 *     delivery signals IRQ6 (call_vblank only raises a flag; the runner still
 *     owns VDP timing, the enable bit, and the masked-V-int latch), then pushes
 *     a real exception frame, raises the mask to 6 and calls the handler.
 *   - The handler runs on the game fiber, so its bus accesses drain the cycle
 *     budget and interleave with the scanline scheduler: raster polling inside
 *     the handler sees the HV counter advance.
 *   - The RTE hooks perform the RTE and unwind to the driver, so an RTE at any
 *     C nesting depth resumes the interrupted idle loop.
 * Frame-discarding paths need no special casing: they simply continue on the
 * game fiber until they reach an idle hook, which unwinds the abandoned C
 * frames. The host stack therefore never grows across interrupts.
 */
#include "game_spec.h"
#include "genesis_runtime.h"

#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define MSPAC_ENTRY_PC      0x000200u
#define MSPAC_VINT_PC       0x0014AAu
#define MSPAC_IDLE_GAMEPLAY 0x0008F6u
#define MSPAC_IDLE_ATTRACT  0x00F76Eu

/* Deep enough to unwind every generated frame; each JSR wrapper consumes one. */
#define MSPAC_UNWIND_ALL    (INT_MAX / 2)

static int      s_irq6_asserted;   /* raised by the runner's V-int delivery */
static uint32_t s_idle_pc;         /* idle loop the CPU is parked in (0 = none) */
static uint32_t s_idle_sp;
static uint32_t s_wait_pc;         /* idle loop being waited in (s_waiting)     */
static int      s_waiting;         /* parked in the driver's BRA * wait         */
static int      s_parked;          /* hold IRQ6 off for a state file (not state) */

static int is_idle_pc(uint32_t pc)
{
    return pc == MSPAC_IDLE_GAMEPLAY || pc == MSPAC_IDLE_ATTRACT;
}

static void unwind_to_idle(uint32_t pc)
{
    s_idle_pc = pc & 0xFFFFFFu;
    s_idle_sp = g_cpu.A[7];
    g_rte_pending = MSPAC_UNWIND_ALL;
}

static int mspac_instruction_hook(uint32_t pc)
{
    switch (pc) {
    case MSPAC_IDLE_GAMEPLAY:
    case MSPAC_IDLE_ATTRACT:
        g_cpu.PC = pc;
        unwind_to_idle(pc);
        return 1;

    case 0x001CB0u:
    case 0x00EBD6u:
    case 0x00ECCEu: {
        /* RTE: pop SR then PC, as the generated RTE does. */
        g_cpu.SR = m68k_read16(g_cpu.A[7]);
        g_cpu.A[7] += 2;
        g_cpu.PC = m68k_read32(g_cpu.A[7]) & 0xFFFFFFu;
        g_cpu.A[7] += 4;
        if (!is_idle_pc(g_cpu.PC))
            fprintf(stderr, "[MSPAC] RTE at $%06X returns to non-idle PC $%06X\n",
                    (unsigned)pc, (unsigned)g_cpu.PC);
        unwind_to_idle(g_cpu.PC);
        return 1;
    }
    default:
        return 0;
    }
}

/* Runner V-int delivery: only reached while the 68K mask is below 6, i.e. while
 * parked in an idle loop. Record the IRQ; the game fiber takes it. */
static void mspac_raise_irq6(void)
{
    s_irq6_asserted = 1;
}

static void take_irq6(uint32_t return_pc)
{
    uint16_t sr = g_cpu.SR;
    g_cpu.A[7] -= 4;
    m68k_write32(g_cpu.A[7], return_pc);
    g_cpu.A[7] -= 2;
    m68k_write16(g_cpu.A[7], sr);
    g_cpu.SR = (uint16_t)((sr & ~(SR_T | 0x0700u)) | SR_S | 0x0600u);
    recomp_call_addr(MSPAC_VINT_PC);
}

/* The driver: park in the idle loop the handler returned to until IRQ6, then
 * take it. `resume` re-enters the wait a portable state was saved in (see
 * mspac_state_resume): everything it needs is in the statics above, which
 * the rollback "game" section carries. */
static void driver_loop(int resume)
{
    for (;;) {
        if (!resume) {
            g_rte_pending = 0;
            g_split_sp_popped = 0;
            if (!s_idle_pc) {
                fprintf(stderr, "[MSPAC] control returned to the driver without "
                                "reaching an idle loop (PC=$%06X); parking\n",
                        (unsigned)(g_cpu.PC & 0xFFFFFFu));
                for (;;) glue_yield_for_interrupt_poll();
            }
            s_wait_pc = s_idle_pc;
            s_idle_pc = 0;
            g_cpu.A[7] = s_idle_sp;
            g_cpu.PC = s_wait_pc;
        }
        resume = 0;

        /* BRA * with IRQs unmasked until the VDP raises IRQ6. A state file
         * being written holds the IRQ off until its tick has ended. */
        s_waiting = 1;
        while (!s_irq6_asserted || s_parked)
            glue_yield_for_interrupt_poll();
        s_waiting = 0;
        s_irq6_asserted = 0;

        take_irq6(s_wait_pc);
    }
}

static void mspac_call_entry_point(void)
{
    recomp_call_addr(MSPAC_ENTRY_PC);
    driver_loop(0);
}

/* ---- Rollback and save states ---------------------------------------------
 * The driver's statics are simulation state: a rewind, a preemptive-frames
 * replay or a state load must restore them with the machine. Fixed layout,
 * no padding garbage (the bytes are also the rollback digest domain). */
typedef struct MspacRbState {
    uint32_t idle_pc, idle_sp, wait_pc;
    uint8_t  irq6_asserted, waiting, pad[2];
} MspacRbState;

static size_t mspac_rb_save(void *dst, size_t cap)
{
    MspacRbState st;
    if (!dst) return sizeof st;
    if (cap < sizeof st) return 0;
    memset(&st, 0, sizeof st);
    st.idle_pc = s_idle_pc;
    st.idle_sp = s_idle_sp;
    st.wait_pc = s_wait_pc;
    st.irq6_asserted = (uint8_t)(s_irq6_asserted != 0);
    st.waiting = (uint8_t)(s_waiting != 0);
    memcpy(dst, &st, sizeof st);
    return sizeof st;
}

static int mspac_rb_load(const void *src, size_t len)
{
    MspacRbState st;
    if (len != sizeof st) return 0;
    memcpy(&st, src, sizeof st);
    if (st.waiting && !is_idle_pc(st.wait_pc)) return 0;
    s_idle_pc = st.idle_pc;
    s_idle_sp = st.idle_sp;
    s_wait_pc = st.wait_pc;
    s_irq6_asserted = st.irq6_asserted;
    s_waiting = st.waiting;
    s_parked = 0;
    return 1;
}

/* A state file can be written whenever the CPU is parked in an idle loop
 * waiting for the V-int, which is where the game spends the end of almost
 * every frame: the fiber is then rebuilt by re-entering that wait. */
static int mspac_state_resumable(void)
{
    return s_waiting && is_idle_pc(s_wait_pc);
}

static void mspac_state_resume(void)
{
    driver_loop(1);
}

/* The V-int handler usually runs on past the end of the frame, so a tick
 * rarely ends in the idle wait by itself. A state file asks to be held there:
 * the next IRQ6 waits until the tick has ended and the state is written, and
 * is then taken at the start of the next one (a load resumes the same way). */
static void mspac_state_park(int on)
{
    s_parked = on != 0;
}

extern const GameVideo mspacman_video;   /* mspacman_video.c: full-maze view */
void mspacman_video_command(int id, const char *json);

static const GameDebugCommand s_mspac_commands[] = {
    { "mspac_view", mspacman_video_command },
};

const GameSpec g_game_spec = {
    .video                  = &mspacman_video,
    .display_name           = "Ms. Pac-Man",
    .short_name             = "MSPAC",

    /* USA/Europe cartridge dump: 128 KB, CRC32 AF041BE6, serial GM T-48036 -00. */
    .expected_rom_crc32     = 0xAF041BE6u,
    .expected_rom_size      = 0x20000u,
    /* No-Intro "Ms. Pac-Man (USA, Europe).md": the launcher marks only this
     * file verified, and the runner refuses any other at boot. */
    .expected_rom_sha256    = "87f3c75fea5c4e105163a3b6d4467527fdc3fcc4b8e385155067719b98b2be7c",

    /* No disassembly: run the Tier-3 miss fallback always-on so a discovery
     * gap executes correctly and feeds floor_coverage.toml for the next regen. */
    .tier3_floor_default    = 1,

    .call_entry_point       = mspac_call_entry_point,
    .call_vblank            = mspac_raise_irq6,
    .call_hblank            = NULL,
    .resume_main_loop_pc    = 0u,
    .save_resume_pc         = NULL,
    .dispatch_main_loop_pc  = 0u,
    .call_periodic          = NULL,

    .on_post_reset          = NULL,
    .on_frame_pre           = NULL,
    .on_frame_post          = NULL,
    .on_hblank              = NULL,

    .handle_arg             = NULL,
    .arg_usage              = NULL,
    .dispatch_override      = NULL,
    .instruction_hook       = mspac_instruction_hook,

    .fill_frame_record      = NULL,
    .frame_record_version   = 0u,

    .commands               = s_mspac_commands,
    .command_count          = (int)(sizeof s_mspac_commands / sizeof s_mspac_commands[0]),

    .rb_state_save          = mspac_rb_save,
    .rb_state_load          = mspac_rb_load,
    .state_resumable        = mspac_state_resumable,
    .state_resume           = mspac_state_resume,
    .state_park             = mspac_state_park,
    /* The title screens and the demo run as main-program code that polls the
     * VDP: no point there to rebuild the game from. */
    .state_wait_failed      = "Save states can be made during play, not on the title or demo screens.",
};
