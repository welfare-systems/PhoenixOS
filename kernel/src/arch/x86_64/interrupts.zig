const klog = @import("../../log/klog.zig");
const std = @import("std");

pub const IdtEntry = packed struct(u128) {
    offset_low: u16,
    selector: u16,
    ist: u3,
    reserved: u5 = 0,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    zero: u32 = 0,
};

pub const IdtPtr = packed struct {
    limit: u16,
    base: usize,
};

extern fn load_idt(ptr: *const IdtPtr) callconv(.C) void;

extern fn isr0() callconv(.C) void;
extern fn isr1() callconv(.C) void;
extern fn isr2() callconv(.C) void;
extern fn isr3() callconv(.C) void;
extern fn isr4() callconv(.C) void;
extern fn isr5() callconv(.C) void;
extern fn isr6() callconv(.C) void;
extern fn isr7() callconv(.C) void;
extern fn isr8() callconv(.C) void;
extern fn isr9() callconv(.C) void;
extern fn isr10() callconv(.C) void;
extern fn isr11() callconv(.C) void;
extern fn isr12() callconv(.C) void;
extern fn isr13() callconv(.C) void;
extern fn isr14() callconv(.C) void;
extern fn isr15() callconv(.C) void;
extern fn isr16() callconv(.C) void;
extern fn isr17() callconv(.C) void;
extern fn isr18() callconv(.C) void;
extern fn isr19() callconv(.C) void;
extern fn isr20() callconv(.C) void;
extern fn isr21() callconv(.C) void;
extern fn isr22() callconv(.C) void;
extern fn isr23() callconv(.C) void;
extern fn isr24() callconv(.C) void;
extern fn isr25() callconv(.C) void;
extern fn isr26() callconv(.C) void;
extern fn isr27() callconv(.C) void;
extern fn isr28() callconv(.C) void;
extern fn isr29() callconv(.C) void;
extern fn isr30() callconv(.C) void;
extern fn isr31() callconv(.C) void;
extern fn isr_spurious() callconv(.C) void;

pub var idt: [256]IdtEntry align(16) = std.mem.zeroes([256]IdtEntry);

fn setEntry(vector: usize, handler: usize) void {
    const entry = &idt[vector];
    entry.offset_low = @intCast(handler & 0xFFFF);
    entry.selector = 0x08;
    entry.ist = 1;
    entry.type_attr = 0x8E;
    entry.offset_mid = @intCast((handler >> 16) & 0xFFFF);
    entry.offset_high = @intCast((handler >> 32) & 0xFFFFFFFF);
    entry.zero = 0;
}

fn installExceptionHandlers() void {
    const exception_handlers = [_]usize{
        @intFromPtr(&isr0),
        @intFromPtr(&isr1),
        @intFromPtr(&isr2),
        @intFromPtr(&isr3),
        @intFromPtr(&isr4),
        @intFromPtr(&isr5),
        @intFromPtr(&isr6),
        @intFromPtr(&isr7),
        @intFromPtr(&isr8),
        @intFromPtr(&isr9),
        @intFromPtr(&isr10),
        @intFromPtr(&isr11),
        @intFromPtr(&isr12),
        @intFromPtr(&isr13),
        @intFromPtr(&isr14),
        @intFromPtr(&isr15),
        @intFromPtr(&isr16),
        @intFromPtr(&isr17),
        @intFromPtr(&isr18),
        @intFromPtr(&isr19),
        @intFromPtr(&isr20),
        @intFromPtr(&isr21),
        @intFromPtr(&isr22),
        @intFromPtr(&isr23),
        @intFromPtr(&isr24),
        @intFromPtr(&isr25),
        @intFromPtr(&isr26),
        @intFromPtr(&isr27),
        @intFromPtr(&isr28),
        @intFromPtr(&isr29),
        @intFromPtr(&isr30),
        @intFromPtr(&isr31),
    };

    inline for (exception_handlers, 0..) |handler, vector| {
        setEntry(vector, handler);
    }

    const spurious = @intFromPtr(&isr_spurious);
    var vector: usize = 32;
    while (vector < idt.len) : (vector += 1) {
        setEntry(vector, spurious);
    }
}

pub fn init() void {
    var i: usize = 0;
    while (i < idt.len) : (i += 1) {
        idt[i] = .{ .offset_low = 0, .selector = 0, .ist = 0, .type_attr = 0, .offset_mid = 0, .offset_high = 0, .zero = 0 };
    }

    installExceptionHandlers();

    const ptr: IdtPtr = .{ .limit = @intCast(@sizeOf(@TypeOf(idt)) - 1), .base = @intFromPtr(&idt) };
    load_idt(&ptr);
}
