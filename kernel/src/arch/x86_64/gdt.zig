const std = @import("std");

extern fn load_gdt(ptr: *const GdtPtr) callconv(.C) void;
extern fn load_tss(selector: u16) callconv(.C) void;
extern var isr_emergency_stack_top: u8;

pub const GdtPtr = packed struct {
    limit: u16,
    base: usize,
};

pub const Tss = packed struct {
    reserved0: u32 = 0,
    rsp0: u64 = 0,
    rsp1: u64 = 0,
    rsp2: u64 = 0,
    reserved1: u64 = 0,
    ist1: u64 = 0,
    ist2: u64 = 0,
    ist3: u64 = 0,
    ist4: u64 = 0,
    ist5: u64 = 0,
    ist6: u64 = 0,
    ist7: u64 = 0,
    reserved2: u64 = 0,
    reserved3: u16 = 0,
    iomap_base: u16 = @sizeOf(Tss),
};

var gdt: [5]u64 align(16) = .{
    0,
    0x00AF9A000000FFFF,
    0x00AF92000000FFFF,
    0,
    0,
};

var tss: Tss align(16) = .{};

fn buildTssDescriptor(base: usize, limit: usize) u128 {
    var descriptor: u128 = 0;
    descriptor |= @as(u128, limit & 0xFFFF);
    descriptor |= @as(u128, base & 0xFFFFFF) << 16;
    descriptor |= @as(u128, 0x89) << 40;
    descriptor |= @as(u128, (limit >> 16) & 0xF) << 48;
    descriptor |= @as(u128, (base >> 24) & 0xFF) << 56;
    descriptor |= @as(u128, (base >> 32) & 0xFFFFFFFF) << 64;
    return descriptor;
}

pub fn init() void {
    const stack_top = @intFromPtr(&isr_emergency_stack_top);
    tss.rsp0 = stack_top;
    tss.ist1 = stack_top;

    const tss_descriptor = buildTssDescriptor(@intFromPtr(&tss), @sizeOf(Tss) - 1);
    gdt[3] = @as(u64, @truncate(tss_descriptor));
    gdt[4] = @as(u64, @truncate(tss_descriptor >> 64));

    const ptr: GdtPtr = .{ .limit = @intCast(@sizeOf(@TypeOf(gdt)) - 1), .base = @intFromPtr(&gdt) };
    load_gdt(&ptr);
    load_tss(0x18);
}
