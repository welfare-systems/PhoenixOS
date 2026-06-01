pub inline fn in8(port: u16) u8 {
    var value: u8 = undefined;
    asm volatile ("inb %%dx, %%al"
        : [value] "={al}" (value),
        : [port] "{dx}" (port),
    );
    return value;
}

pub inline fn out8(port: u16, value: u8) void {
    asm volatile ("outb %%al, %%dx"
        :
        : [port] "{dx}" (port),
          [value] "{al}" (value),
    );
}

pub inline fn ioWait() void {
    out8(0x80, 0);
}
