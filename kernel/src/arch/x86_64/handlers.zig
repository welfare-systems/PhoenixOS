const trap = @import("trap.zig");
const panic_mod = @import("../../panic.zig");

pub fn exception_common(frame: *const trap.InterruptFrame) noreturn {
    panic_mod.panicException(frame);
}
