pub const InterruptFrame = extern struct {
    vector: u64,
    error_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
};

pub fn exceptionName(vector: u64) []const u8 {
    return switch (vector) {
        0 => "divide-by-zero",
        1 => "debug",
        2 => "nmi",
        3 => "breakpoint",
        4 => "overflow",
        5 => "bound-range",
        6 => "invalid-opcode",
        7 => "device-not-available",
        8 => "double-fault",
        9 => "coprocessor-overrun",
        10 => "invalid-tss",
        11 => "segment-not-present",
        12 => "stack-segment",
        13 => "general-protection",
        14 => "page-fault",
        16 => "x87-fp",
        17 => "alignment-check",
        18 => "machine-check",
        19 => "simd-fp",
        20 => "virtualization",
        30 => "security",
        else => "unknown",
    };
}

pub fn hasErrorCode(vector: u64) bool {
    return switch (vector) {
        8, 10, 11, 12, 13, 14, 17, 30 => true,
        else => false,
    };
}
