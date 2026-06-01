const renderer_mod = @import("term/renderer.zig");
const terminal_mod = @import("term/terminal.zig");

var active_renderer: ?renderer_mod.FramebufferRenderer = null;

pub fn setRenderer(renderer: renderer_mod.FramebufferRenderer) void {
    active_renderer = renderer;
}

pub fn rendererPtr() ?*renderer_mod.FramebufferRenderer {
    if (active_renderer) |*renderer| {
        return renderer;
    }
    return null;
}

pub fn renderDirty() void {
    if (rendererPtr()) |renderer| {
        renderer.renderDirty(terminal_mod.core());
    }
}

pub fn renderCursor(visible: bool) void {
    if (rendererPtr()) |renderer| {
        renderer.renderCursor(terminal_mod.core(), visible);
    }
}
