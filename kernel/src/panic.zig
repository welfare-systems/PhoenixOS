const std = @import("std");
const klog = @import("log/klog.zig");
const uart = @import("drivers/uart.zig");
const display = @import("display.zig");
const terminal = @import("term/terminal.zig");
const trap = @import("arch/x86_64/trap.zig");

fn haltForever() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

fn emitLine(text: []const u8) void {
    if (klog.klog.initialized) {
        klog.klog.err(text);
    } else {
        uart.uart.write(text);
        uart.uart.write("\n");
    }
}

fn renderPanicScreen(title: []const u8, lines: []const []const u8) void {
    if (display.rendererPtr()) |renderer| {
        const term = terminal.core();
        renderer.clear(0x000000);
        term.clear();
        term.setCursor(0, 0);
        terminal.write(title);
        terminal.write("\n");
        for (lines) |line| {
            terminal.write(line);
            terminal.write("\n");
        }
        terminal.finishWrite();
        renderer.renderDirty(term);
    }
}

pub fn panic(msg: []const u8) noreturn {
    emitLine(msg);
    const lines = [_][]const u8{msg};
    renderPanicScreen("KERNEL PANIC", lines[0..]);
    haltForever();
}

pub fn panicException(frame: *const trap.InterruptFrame) noreturn {
    var line0: [128]u8 = undefined;
    var line1: [128]u8 = undefined;

    const title = std.fmt.bufPrint(line0[0..], "KERNEL EXCEPTION: {s} (vector={})", .{ trap.exceptionName(frame.vector), frame.vector }) catch unreachable;
    const error_line = std.fmt.bufPrint(line1[0..], "error_code=0x{x} rip=0x{x} cs=0x{x} rflags=0x{x}", .{ frame.error_code, frame.rip, frame.cs, frame.rflags }) catch unreachable;
    var line2: [128]u8 = undefined;
    const footer = std.fmt.bufPrint(line2[0..], "system halted", .{}) catch unreachable;

    emitLine(title);
    emitLine(error_line);
    emitLine(footer);

    const lines = [_][]const u8{ title, error_line, footer };
    renderPanicScreen("KERNEL EXCEPTION", lines[0..]);
    haltForever();
}
