const std = @import("std");
const uart_drv = @import("../drivers/uart.zig");

pub const Level = enum {
    DEBUG,
    INFO,
    WARN,
    ERROR,
};

const RING_LINES = 128;
const LINE_SIZE = 256;

pub const Logger = struct {
    buf: [RING_LINES][LINE_SIZE]u8,
    head: usize,
    initialized: bool,

    pub fn init(self: *Logger) void {
        uart_drv.init();
        self.head = 0;
        self.initialized = true;
    }

    pub fn log(self: *Logger, level: Level, msg: []const u8) void {
        var tmp: [512]u8 = undefined;
        var pos: usize = 0;
        const level_str = levelToStr(level);

        var i: usize = 0;
        while (i < level_str.len) : (i += 1) {
            if (pos + i < tmp.len) tmp[pos + i] = level_str[i] else break;
        }
        pos += level_str.len;
        if (pos < tmp.len) {
            tmp[pos] = ' ';
            pos += 1;
        }

        const to_copy = if (msg.len <= tmp.len - pos) msg.len else tmp.len - pos - 1;
        var j: usize = 0;
        while (j < to_copy) : (j += 1) {
            tmp[pos + j] = msg[j];
        }
        pos += to_copy;

        // newline
        if (pos < tmp.len) {
            tmp[pos] = '\n';
            pos += 1;
        }

        var dest = self.buf[self.head][0..];
        const copy_len = if (pos > dest.len) dest.len else pos;
        var k: usize = 0;
        while (k < copy_len) : (k += 1) {
            dest[k] = tmp[k];
        }
        if (copy_len < dest.len) dest[copy_len] = 0;
        self.head = (self.head + 1) % RING_LINES;

        // write out via UART if initialized
        if (self.initialized) {
            uart_drv.uart.write(tmp[0..copy_len]);
        }
    }

    pub fn debug(self: *Logger, msg: []const u8) void {
        self.log(.DEBUG, msg);
    }
    pub fn info(self: *Logger, msg: []const u8) void {
        self.log(.INFO, msg);
    }
    pub fn warn(self: *Logger, msg: []const u8) void {
        self.log(.WARN, msg);
    }
    pub fn err(self: *Logger, msg: []const u8) void {
        self.log(.ERROR, msg);
    }
};

fn levelToStr(level: Level) []const u8 {
    return switch (level) {
        .DEBUG => "DEBUG",
        .INFO => "INFO",
        .WARN => "WARN",
        .ERROR => "ERROR",
    };
}

pub var klog: Logger = .{ .buf = undefined, .head = 0, .initialized = false };
