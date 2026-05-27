const core = @import("core.zig");

pub const Utf8Decoder = struct {
    needed: u8 = 0,
    seen: u8 = 0,
    codepoint: u32 = 0,
    min_codepoint: u32 = 0,

    pub fn reset(self: *Utf8Decoder) void {
        self.* = .{};
    }

    pub fn feed(self: *Utf8Decoder, byte: u8) ?u32 {
        if (self.needed == 0) {
            if (byte <= 0x7F) {
                return @as(u32, byte);
            } else if (byte >= 0xC2 and byte <= 0xDF) {
                self.needed = 2;
                self.seen = 1;
                self.codepoint = byte & 0x1F;
                self.min_codepoint = 0x80;
                return null;
            } else if (byte >= 0xE0 and byte <= 0xEF) {
                self.needed = 3;
                self.seen = 1;
                self.codepoint = byte & 0x0F;
                self.min_codepoint = 0x800;
                return null;
            } else if (byte >= 0xF0 and byte <= 0xF4) {
                self.needed = 4;
                self.seen = 1;
                self.codepoint = byte & 0x07;
                self.min_codepoint = 0x10000;
                return null;
            }
            return core.replacement_codepoint;
        }

        if ((byte & 0xC0) != 0x80) {
            self.reset();
            return core.replacement_codepoint;
        }

        self.codepoint = (self.codepoint << 6) | (byte & 0x3F);
        self.seen += 1;

        if (self.seen < self.needed) {
            return null;
        }

        const decoded = self.codepoint;
        const min_cp = self.min_codepoint;
        self.reset();

        if (decoded < min_cp) return core.replacement_codepoint;
        if (decoded > 0x10FFFF) return core.replacement_codepoint;
        if (decoded >= 0xD800 and decoded <= 0xDFFF) return core.replacement_codepoint;
        if (decoded > 0xFFFF) return core.replacement_codepoint;

        return decoded;
    }

    pub fn flush(self: *Utf8Decoder) ?u32 {
        if (self.needed != 0) {
            self.reset();
            return core.replacement_codepoint;
        }
        return null;
    }
};
