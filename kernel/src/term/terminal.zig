const core_mod = @import("core.zig");
const utf8 = @import("utf8.zig");

// TerminalCore holds ~24000 cells (~384 KiB). It must live in .bss, not on the
// kernel entry stack (Limine typically provides only tens of KiB there).
var core_state: core_mod.TerminalCore = undefined;
var decoder: utf8.Utf8Decoder = .{};

pub fn init(cols: usize, rows: usize, fg: u32, bg: u32) void {
    core_state.initAt(cols, rows, fg, bg);
    decoder = .{};
}

pub fn write(bytes: []const u8) void {
    for (bytes) |byte| {
        if (decoder.feed(byte)) |codepoint| {
            core_state.writeCodepoint(codepoint);
        }
    }
}

pub fn finishWrite() void {
    if (decoder.flush()) |codepoint| {
        core_state.writeCodepoint(codepoint);
    }
}

pub fn core() *core_mod.TerminalCore {
    return &core_state;
}
