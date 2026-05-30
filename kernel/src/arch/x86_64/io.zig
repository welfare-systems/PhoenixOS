pub inline fn in8(port: u16) u8 {
    var value: u8 = undefined;
    asm volatile ("inb %[port], %[value]"
        : [value] "={al}" (value),
        : [port] "Nd" (port),
    );
    return value;
}

pub inline fn out8(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [port] "Nd" (port),
          [value] "{al}" (value),
    );
}

pub inline fn ioWait() void {
    out8(0x80, 0);
}
