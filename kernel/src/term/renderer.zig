const limine = @import("limine");
const core = @import("core.zig");
const bitmap = @import("../font/bitmap.zig");

pub const FramebufferRenderer = struct {
    framebuffer: *limine.Framebuffer,
    fb_ptr: [*]volatile u32,
    stride_pixels: usize,

    pub fn init(framebuffer: *limine.Framebuffer) FramebufferRenderer {
        return .{
            .framebuffer = framebuffer,
            .fb_ptr = @ptrCast(@alignCast(framebuffer.address)),
            .stride_pixels = framebuffer.pitch / 4,
        };
    }

    pub fn clear(self: *FramebufferRenderer, color: u32) void {
        const width = @as(usize, framebufferDimension(self.framebuffer.width));
        const height = @as(usize, framebufferDimension(self.framebuffer.height));

        var y: usize = 0;
        while (y < height) : (y += 1) {
            var x: usize = 0;
            while (x < width) : (x += 1) {
                self.fb_ptr[y * self.stride_pixels + x] = color;
            }
        }
    }

    pub fn renderDirty(self: *FramebufferRenderer, terminal: *core.TerminalCore) void {
        var row: usize = 0;
        while (row < terminal.rows) : (row += 1) {
            var col: usize = 0;
            while (col < terminal.cols) : (col += 1) {
                const cell = terminal.cellPtr(col, row);
                if (!cell.dirty) continue;
                self.drawCell(col, row, cell.*);
                cell.dirty = false;
            }
        }
    }

    fn drawCell(self: *FramebufferRenderer, col: usize, row: usize, cell: core.Cell) void {
        const glyph = bitmap.BitmapFont.lookup(cell.codepoint);
        const fg = cell.fg;
        const bg = cell.bg;
        const origin_x = col * bitmap.glyph_width;
        const origin_y = row * bitmap.glyph_height;

        var gy: usize = 0;
        while (gy < bitmap.glyph_height) : (gy += 1) {
            const bits = glyph[gy];
            var gx: usize = 0;
            while (gx < bitmap.glyph_width) : (gx += 1) {
                const mask = @as(u8, 0x80) >> @intCast(gx);
                const pixel = if ((bits & mask) != 0) fg else bg;
                self.writePixel(origin_x + gx, origin_y + gy, pixel);
            }
        }
    }

    fn writePixel(self: *FramebufferRenderer, x: usize, y: usize, color: u32) void {
        const width = framebufferDimension(self.framebuffer.width);
        const height = framebufferDimension(self.framebuffer.height);
        if (x >= width or y >= height) return;
        self.fb_ptr[y * self.stride_pixels + x] = color;
    }

};

fn framebufferDimension(value: u64) usize {
    return @intCast(value);
}
