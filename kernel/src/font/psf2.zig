const core = @import("../term/core.zig");

pub const MAX_GLYPH_HEIGHT: usize = 32;
pub const BMP_MAP_LEN: usize = 65536;
pub const missing_glyph: u16 = 0xFFFF;

const PSF2_MAGIC: u32 = 0x864ab572;
const PSF2_HAS_UNICODE_TABLE: u32 = 0x01;

const embedded_font = @embedFile("../assets/terminus-14.psf");

pub const Header = struct {
    width: usize,
    height: usize,
    glyph_count: usize,
    bytes_per_glyph: usize,
};

var header: Header = .{
    .width = 8,
    .height = 16,
    .glyph_count = 0,
    .bytes_per_glyph = 16,
};

var glyph_data: []const u8 = &.{};
var bmp_map: [BMP_MAP_LEN]u16 = [_]u16{missing_glyph} ** BMP_MAP_LEN;
var initialized = false;

pub fn init() void {
    if (initialized) return;
    parse(embedded_font);
    initialized = true;
}

pub fn getHeader() Header {
    return header;
}

pub fn lookupRows(codepoint: u32) [MAX_GLYPH_HEIGHT]u8 {
    var rows: [MAX_GLYPH_HEIGHT]u8 = [_]u8{0} ** MAX_GLYPH_HEIGHT;
    const glyph = glyphBytes(codepoint);
    @memcpy(rows[0..header.height], glyph[0..header.height]);
    return rows;
}

fn glyphBytes(codepoint: u32) []const u8 {
    const index = glyphIndex(codepoint);
    const offset = index * header.bytes_per_glyph;
    if (offset + header.bytes_per_glyph > glyph_data.len) {
        return glyph_data[0..header.bytes_per_glyph];
    }
    return glyph_data[offset .. offset + header.bytes_per_glyph];
}

fn glyphIndex(codepoint: u32) usize {
    if (codepoint > 0xFFFF) return 0;
    const mapped = bmp_map[codepoint];
    if (mapped != missing_glyph) return mapped;
    if (codepoint != core.replacement_codepoint) {
        const replacement = bmp_map[core.replacement_codepoint];
        if (replacement != missing_glyph) return replacement;
    }
    return 0;
}

fn parse(data: []const u8) void {
    if (data.len < 32) @panic("PSF2 file too small");
    if (readU32(data, 0) != PSF2_MAGIC) @panic("PSF2 magic mismatch");

    const flags = readU32(data, 12);
    const glyph_count = readU32(data, 16);
    const bytes_per_glyph = readU32(data, 20);
    const height = readU32(data, 24);
    const width = readU32(data, 28);

    if (width == 0 or height == 0 or height > MAX_GLYPH_HEIGHT) {
        @panic("Unsupported PSF2 glyph dimensions");
    }
    if (bytes_per_glyph > MAX_GLYPH_HEIGHT) @panic("PSF2 bytes per glyph too large");

    header = .{
        .width = @intCast(width),
        .height = @intCast(height),
        .glyph_count = @intCast(glyph_count),
        .bytes_per_glyph = @intCast(bytes_per_glyph),
    };

    const glyphs_end = 32 + header.glyph_count * header.bytes_per_glyph;
    if (glyphs_end > data.len) @panic("PSF2 glyph data truncated");
    glyph_data = data[32..glyphs_end];

    if ((flags & PSF2_HAS_UNICODE_TABLE) == 0) {
        @panic("PSF2 font must include a Unicode table");
    }

    buildBmpMap(data[glyphs_end..]);
}

fn buildBmpMap(table: []const u8) void {
    for (&bmp_map) |*entry| {
        entry.* = missing_glyph;
    }

    var offset: usize = 0;
    var current_glyph_idx: u16 = 0;

    while (offset < table.len and current_glyph_idx < header.glyph_count) {
        if (table[offset] == 0xFF) {
            offset += 1;
            current_glyph_idx += 1;
            continue;
        }

        const bytes_left = table.len - offset;
        var len: usize = 0;
        const b0 = table[offset];

        if (b0 <= 0x7F) {
            len = 1;
        } else if (b0 >= 0xC2 and b0 <= 0xDF) {
            len = 2;
        } else if (b0 >= 0xE0 and b0 <= 0xEF) {
            len = 3;
        } else if (b0 >= 0xF0 and b0 <= 0xF4) {
            len = 4;
        } else {
            offset += 1;
            continue;
        }

        if (len > bytes_left) break;

        if (decodeUtf8(table[offset .. offset + len])) |codepoint| {
            if (codepoint <= 0xFFFF) {
                bmp_map[@intCast(codepoint)] = current_glyph_idx;
            }
        }

        offset += len;

        if (offset < table.len and table[offset] == 0xFF) {
            offset += 1;
            current_glyph_idx += 1;
        }
    }
}

fn decodeUtf8(bytes: []const u8) ?u32 {
    if (bytes.len == 0) return null;
    const b0 = bytes[0];
    if (b0 <= 0x7F) return b0;
    if (bytes.len < 2) return null;
    if (b0 >= 0xC2 and b0 <= 0xDF) {
        if ((bytes[1] & 0xC0) != 0x80) return null;
        return (@as(u32, b0 & 0x1F) << 6) | (bytes[1] & 0x3F);
    }
    if (bytes.len < 3) return null;
    if (b0 >= 0xE0 and b0 <= 0xEF) {
        if ((bytes[1] & 0xC0) != 0x80 or (bytes[2] & 0xC0) != 0x80) return null;
        return (@as(u32, b0 & 0x0F) << 12) | (@as(u32, bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F);
    }
    if (bytes.len < 4) return null;
    if (b0 >= 0xF0 and b0 <= 0xF4) {
        if ((bytes[1] & 0xC0) != 0x80 or (bytes[2] & 0xC0) != 0x80 or (bytes[3] & 0xC0) != 0x80) return null;
        return (@as(u32, b0 & 0x07) << 18) | (@as(u32, bytes[1] & 0x3F) << 12) |
            (@as(u32, bytes[2] & 0x3F) << 6) | (bytes[3] & 0x3F);
    }
    return null;
}

fn readU32(data: []const u8, offset: usize) u32 {
    return @as(u32, data[offset]) |
        (@as(u32, data[offset + 1]) << 8) |
        (@as(u32, data[offset + 2]) << 16) |
        (@as(u32, data[offset + 3]) << 24);
}
