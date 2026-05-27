const psf2 = @import("psf2.zig");

pub var glyph_width: usize = 8;
pub var glyph_height: usize = 16;

pub fn init() void {
    psf2.init();
    const header = psf2.getHeader();
    glyph_width = header.width;
    glyph_height = header.height;
}

pub const BitmapFont = struct {
    pub fn lookup(codepoint: u32) [psf2.MAX_GLYPH_HEIGHT]u8 {
        return psf2.lookupRows(codepoint);
    }
};
