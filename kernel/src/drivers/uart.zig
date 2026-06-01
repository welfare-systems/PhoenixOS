const std = @import("std");
const io = @import("../arch/x86_64/io.zig");

pub const Uart = struct {
    port: u16,

    pub fn init(self: *Uart, port: u16) void {
        self.port = port;
        // Basic 16550 init: disable interrupts
        const p1: u16 = port + 1;
        io.out8(p1, 0x00);
        // Enable DLAB to set baud rate divisor
        const p3: u16 = port + 3;
        io.out8(p3, 0x80);
        // Set divisor to 3 (38400) - works for QEMU debugging
        const p0: u16 = port + 0;
        io.out8(p0, 0x03);
        io.out8(p1, 0x00);
        // 8 bits, no parity, one stop bit
        io.out8(p3, 0x03);
        // Enable FIFO, clear them, with 14-byte threshold
        const p2: u16 = port + 2;
        io.out8(p2, 0xC7);
        // IRQs enabled, RTS/DSR set
        const p4: u16 = port + 4;
        io.out8(p4, 0x0B);
    }

    pub fn putc(self: *Uart, c: u8) void {
        // Wait for Transmitter Holding Register empty (LSR bit 5)
        const p5: u16 = self.port + 5;
        while ((io.in8(p5) & 0x20) == 0) {}
        io.out8(self.port, c);
    }

    pub fn write(self: *Uart, bytes: []const u8) void {
        var i: usize = 0;
        while (i < bytes.len) : (i += 1) {
            self.putc(bytes[i]);
        }
    }
};

pub var uart: Uart = .{ .port = 0 };

pub fn init() void {
    uart.init(0x3F8);
}
