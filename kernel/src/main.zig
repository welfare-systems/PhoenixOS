const builtin = @import("builtin");
const std = @import("std");
const limine = @import("limine");
const bitmap = @import("font/bitmap.zig");
const core = @import("term/core.zig");
const renderer_mod = @import("term/renderer.zig");
const terminal_mod = @import("term/terminal.zig");
const keyboard = @import("drivers/input/keyboard.zig");
const shell_mod = @import("shell.zig");

export var start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};
export var end_marker: limine.RequestsEndMarker linksection(".limine_requests_end") = .{};

export var base_revision: limine.BaseRevision linksection(".limine_requests") = .init(3);
export var framebuffer_request: limine.FramebufferRequest linksection(".limine_requests") = .{};
export var memory_map_request: limine.MemoryMapRequest linksection(".limine_requests") = .{};
export var smp_request: limine.MpRequest linksection(".limine_requests") = .{};
export var firmware_type_request: limine.FirmwareTypeRequest linksection(".limine_requests") = .{};

fn hcf() noreturn {
    while (true) {
        switch (builtin.cpu.arch) {
            .x86_64 => asm volatile ("hlt"),
            .aarch64 => asm volatile ("wfi"),
            .riscv64 => asm volatile ("wfi"),
            .loongarch64 => asm volatile ("idle 0"),
            else => unreachable,
        }
    }
}

fn countLines(text: []const u8) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |_| {
        count += 1;
    }

    return count;
}

fn firmwareTypeName(firmware_type: limine.FirmwareType) []const u8 {
    return switch (firmware_type) {
        .x86_bios => "BIOS",
        .uefi32 => "UEFI32",
        .uefi64 => "UEFI64",
        .sbi => "SBI",
        else => "unknown",
    };
}

fn getCpuCount() u64 {
    if (smp_request.response) |response| {
        return response.cpu_count;
    }

    return 1;
}

fn getMemoryStats() struct { total: u64, free: u64 } {
    var total: u64 = 0;
    var free: u64 = 0;

    if (memory_map_request.response) |response| {
        for (response.getEntries()) |entry| {
            total += entry.length;
            if (entry.type == .usable) {
                free += entry.length;
            }
        }
    }

    return .{ .total = total, .free = free };
}

fn bootSplash(renderer: *renderer_mod.FramebufferRenderer) void {
    const art =
        \\                 _                      _       ___  ____  
        \\           _ __ | |__   ___   ___ _ __ (_)_  __/ _ \/ ___| 
        \\          | '_ \| '_ \ / _ \ / _ \ '_ \| \ \/ / | | \___ \ 
        \\          | |_) | | | | (_) |  __/ | | | |>  <| |_| |___) |
        \\          | .__/|_| |_|\___/ \___|_| |_|_/_/\_\\___/|____/ 
        \\          |_|                                              
        \\                                  _--_
        \\                                 /   -)
        \\                             ___/___|___
        \\                ____-----=~~///|     ||||~~~==-----_____
        \\              //~////////////~/|     |//|||||\\\\\\\\\\\\\
        \\            ////////////////////|   |///////|\\\\\\\\\\\\\\\
        \\           /////~~~~~~~~~~~~~~~\ |.||/~~~~~~~~~~~~~~~~~`\\\\\
        \\          //~                  /\\|\\                      ~\\
        \\                              ///W^\W\
        \\                             ////|||\\\
        \\                             ~~~~~~~~~~
        \\
        \\
    ;

    var info_storage: [4][64]u8 = undefined;
    const cpu_line = std.fmt.bufPrint(info_storage[0][0..], "CPU: x86_64 ({} cores)", .{getCpuCount()}) catch unreachable;

    const framebuffer = renderer.framebuffer;
    const gpu_line = std.fmt.bufPrint(
        info_storage[1][0..],
        "GPU: framebuffer {}x{}@{}bpp",
        .{ framebuffer.width, framebuffer.height, framebuffer.bpp },
    ) catch unreachable;

    const memory = getMemoryStats();
    const used_mib: u64 = if (memory.total > memory.free) (memory.total - memory.free) / (1024 * 1024) else 0;
    const free_mib: u64 = memory.free / (1024 * 1024);
    const ram_line = std.fmt.bufPrint(
        info_storage[2][0..],
        "RAM: {} MiB used / {} MiB free",
        .{ used_mib, free_mib },
    ) catch unreachable;

    const firmware_line = std.fmt.bufPrint(
        info_storage[3][0..],
        "FW: {s}",
        .{if (firmware_type_request.response) |response| firmwareTypeName(response.firmware_type) else "unknown"},
    ) catch unreachable;

    const info = [_][]const u8{
        "root@phoenixos",
        "--------------",
        "OS: PhoenixOS",
        "Host: QEMU-emulator@10.0.8",
        "Kernel: phoenix-kernel_alpha@0.0.1-x86_64",
        "Shell: axiom-sh_alpha@0.0.1",
        "Terminal: boot-term",
        "Terminal font: terminus-14.psf",
        cpu_line,
        gpu_line,
        ram_line,
        firmware_line,
    };

    const art_rows = countLines(art);
    const info_col: usize = 66;
    const rows = @max(art_rows, info.len);
    const info_start_row: usize = (art_rows - info.len) / 2;

    var art_lines = std.mem.splitScalar(u8, art, '\n');
    var row: usize = 0;
    while (art_lines.next()) |line| : (row += 1) {
        terminal_mod.core().setCursor(0, row);
        terminal_mod.write(line);

        if (row >= info_start_row and row < info_start_row + info.len) {
            terminal_mod.core().setCursor(info_col, row);
            terminal_mod.write(info[row - info_start_row]);
        }
    }

    while (row < rows) : (row += 1) {
        if (row >= info_start_row and row < info_start_row + info.len) {
            terminal_mod.core().setCursor(info_col, row);
            terminal_mod.write(info[row - info_start_row]);
        }
    }

    terminal_mod.finishWrite();
    renderer.renderDirty(terminal_mod.core());
}

export fn _start() noreturn {
    if (!base_revision.isSupported()) {
        @panic("Base revision not supported");
    }

    bitmap.init();

    if (framebuffer_request.response) |framebuffer_response| {
        const framebuffers = framebuffer_response.getFramebuffers();
        if (framebuffers.len == 0) {
            @panic("No framebuffers available");
        }

        const framebuffer = framebuffers[0];
        var renderer = renderer_mod.FramebufferRenderer.init(framebuffer);

        const width: usize = @intCast(framebuffer.width);
        const height: usize = @intCast(framebuffer.height);
        if (width < bitmap.glyph_width or height < bitmap.glyph_height) {
            @panic("Framebuffer too small for terminal");
        }

        const cols = @min(width / bitmap.glyph_width, core.MAX_COLS);
        const rows = @min(height / bitmap.glyph_height, core.MAX_ROWS);

        renderer.clear(0x000000);
        terminal_mod.init(cols, rows, 0x00FF00, 0x000000);

        bootSplash(&renderer);

        keyboard.init();

        var shell: shell_mod.Shell = .{};
        shell.init("root@phoenixos> ");

        var cursor_visible: bool = true;
        var last_cursor_visible: bool = true;
        var last_cursor = terminal_mod.core().cursor();
        var blink_counter: usize = 0;
        const blink_interval: usize = 5300000;

        renderer.renderDirty(terminal_mod.core());
        renderer.renderCursor(terminal_mod.core(), cursor_visible);

        while (true) {
            keyboard.poll();

            var changed = false;
            var input_activity = false;
            while (keyboard.nextEvent()) |event| {
                if (shell.handleEvent(event)) {
                    changed = true;
                    input_activity = true;
                }
            }

            if (input_activity) {
                cursor_visible = true;
                blink_counter = 0;
            } else {
                blink_counter += 1;
                if (blink_counter >= blink_interval) {
                    blink_counter = 0;
                    cursor_visible = !cursor_visible;
                }
            }

            const cursor = terminal_mod.core().cursor();
            if (cursor.x != last_cursor.x or cursor.y != last_cursor.y) {
                terminal_mod.core().markDirtyAt(last_cursor.x, last_cursor.y);
                terminal_mod.core().markDirtyAt(cursor.x, cursor.y);
                changed = true;
                last_cursor = cursor;
            }

            if (cursor_visible != last_cursor_visible) {
                terminal_mod.core().markDirtyAt(cursor.x, cursor.y);
                changed = true;
                last_cursor_visible = cursor_visible;
            }

            if (changed) {
                renderer.renderDirty(terminal_mod.core());
                renderer.renderCursor(terminal_mod.core(), cursor_visible);
            }
        }
    } else {
        @panic("Framebuffer response not present");
    }
}
