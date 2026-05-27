const builtin = @import("builtin");
const limine = @import("limine");
const bitmap = @import("font/bitmap.zig");
const core = @import("term/core.zig");
const renderer_mod = @import("term/renderer.zig");
const terminal_mod = @import("term/terminal.zig");

export var start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};
export var end_marker: limine.RequestsEndMarker linksection(".limine_requests_end") = .{};

export var base_revision: limine.BaseRevision linksection(".limine_requests") = .init(3);
export var framebuffer_request: limine.FramebufferRequest linksection(".limine_requests") = .{};

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

        terminal_mod.write("PhoenixOS terminal UTF-8 listo.\n");
        terminal_mod.write("Hola, mundo! Español: áéíóú ñ Ñ.\n");
        terminal_mod.write("Tab\ttest, backspace: ABC\x08 \x08D\n");
        terminal_mod.write("BMP check: U+263A -> \xE2\x98\xBA\n");
        terminal_mod.write("Más símbolos: ¿¡€ «» — …\n");
        terminal_mod.finishWrite();
        renderer.renderDirty(terminal_mod.core());
    } else {
        @panic("Framebuffer response not present");
    }

    hcf();
}
