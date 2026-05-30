const io = @import("../../arch/x86_64/io.zig");

pub const Modifier = packed struct(u8) {
    left_shift: bool = false,
    right_shift: bool = false,
    left_ctrl: bool = false,
    right_ctrl: bool = false,
    left_alt: bool = false,
    right_alt: bool = false,
    caps_lock: bool = false,
    num_lock: bool = true,

    pub fn shift(self: Modifier) bool {
        return self.left_shift or self.right_shift;
    }

    pub fn ctrl(self: Modifier) bool {
        return self.left_ctrl or self.right_ctrl;
    }

    pub fn alt(self: Modifier) bool {
        return self.left_alt or self.right_alt;
    }
};

const ScanSet = enum {
    set1,
    set2,
};

pub const KeyCode = enum(u8) {
    unknown = 0,
    escape,
    backspace,
    tab,
    enter,
    space,
    left_shift,
    right_shift,
    left_ctrl,
    right_ctrl,
    left_alt,
    right_alt,
    caps_lock,
    num_lock,
    insert,
    delete,
    home,
    end,
    page_up,
    page_down,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    digit_1,
    digit_2,
    digit_3,
    digit_4,
    digit_5,
    digit_6,
    digit_7,
    digit_8,
    digit_9,
    digit_0,
    keypad_0,
    keypad_1,
    keypad_2,
    keypad_3,
    keypad_4,
    keypad_5,
    keypad_6,
    keypad_7,
    keypad_8,
    keypad_9,
    keypad_dot,
    keypad_slash,
    keypad_star,
    keypad_minus,
    keypad_plus,
    keypad_enter,
    minus,
    equal,
    left_bracket,
    right_bracket,
    backslash,
    semicolon,
    apostrophe,
    grave,
    comma,
    dot,
    slash,
};

pub const KeyEvent = struct {
    code: KeyCode,
    pressed: bool,
    modifiers: Modifier,
    ascii: ?u8,
};

const StatusPort = 0x64;
const DataPort = 0x60;
const OutputBufferFull = 0x01;
const InputBufferFull = 0x02;

const QueueLen = 128;

var initialized = false;
var modifiers: Modifier = .{};
var scan_set: ScanSet = .set2;
var queue: [QueueLen]KeyEvent = undefined;
var head: usize = 0;
var tail: usize = 0;
var extended_prefix = false;
var release_prefix = false;

pub fn init() void {
    if (initialized) return;
    initializeController();
    initialized = true;
}

pub fn poll() void {
    while ((io.in8(StatusPort) & OutputBufferFull) != 0) {
        const scancode = io.in8(DataPort);
        handleScancode(scancode);
    }
}

pub fn nextEvent() ?KeyEvent {
    if (head == tail) return null;
    const event = queue[head];
    head = (head + 1) % QueueLen;
    return event;
}

pub fn modifiersState() Modifier {
    return modifiers;
}

fn handleScancode(scancode: u8) void {
    if (scancode == 0xE0) {
        extended_prefix = true;
        return;
    }

    if (scan_set == .set2 and scancode == 0xF0) {
        release_prefix = true;
        return;
    }

    const released = release_prefix or (scan_set == .set1 and (scancode & 0x80) != 0);
    const code = if (scan_set == .set1 and (scancode & 0x80) != 0) scancode & 0x7F else scancode;
    const key = decodeScancode(code, extended_prefix);
    extended_prefix = false;
    release_prefix = false;

    if (key == .unknown) return;

    updateModifierState(key, !released);
    pushEvent(.{
        .code = key,
        .pressed = !released,
        .modifiers = modifiers,
        .ascii = keyToAscii(key, modifiers, !released),
    });
}

fn updateModifierState(key: KeyCode, pressed: bool) void {
    switch (key) {
        .left_shift => modifiers.left_shift = pressed,
        .right_shift => modifiers.right_shift = pressed,
        .left_ctrl => modifiers.left_ctrl = pressed,
        .right_ctrl => modifiers.right_ctrl = pressed,
        .left_alt => modifiers.left_alt = pressed,
        .right_alt => modifiers.right_alt = pressed,
        .caps_lock => {
            if (pressed) modifiers.caps_lock = !modifiers.caps_lock;
        },
        .num_lock => {
            if (pressed) modifiers.num_lock = !modifiers.num_lock;
        },
        else => {},
    }
}

fn pushEvent(event: KeyEvent) void {
    const next_tail = (tail + 1) % QueueLen;
    if (next_tail == head) return;
    queue[tail] = event;
    tail = next_tail;
}

fn flushController() void {
    while ((io.in8(StatusPort) & OutputBufferFull) != 0) {
        _ = io.in8(DataPort);
    }
}

fn initializeController() void {
    _ = waitInputReady();
    io.out8(StatusPort, 0xAD);
    io.ioWait();

    flushController();

    io.out8(StatusPort, 0x20);
    io.ioWait();
    var config = io.in8(DataPort);
    config &= ~@as(u8, 0x40);

    _ = waitInputReady();
    io.out8(StatusPort, 0x60);
    io.ioWait();
    io.out8(DataPort, config);
    io.ioWait();

    _ = waitInputReady();
    io.out8(StatusPort, 0xAE);
    io.ioWait();

    if (sendKeyboardSet(0x02)) {
        scan_set = .set2;
    } else if (sendKeyboardSet(0x01)) {
        scan_set = .set1;
    }

    _ = sendKeyboardCommand(0xF4);
}

fn sendKeyboardCommand(command: u8) bool {
    _ = waitInputReady();
    io.out8(DataPort, command);
    io.ioWait();
    return waitOutputReady() and io.in8(DataPort) == 0xFA;
}

fn sendKeyboardSet(set_id: u8) bool {
    if (!sendKeyboardCommand(0xF0)) return false;
    _ = waitInputReady();
    io.out8(DataPort, set_id);
    io.ioWait();
    return waitOutputReady() and io.in8(DataPort) == 0xFA;
}

fn waitInputReady() bool {
    var attempts: usize = 0;
    while ((io.in8(StatusPort) & InputBufferFull) != 0) : (attempts += 1) {
        if (attempts > 100000) return false;
    }
    return true;
}

fn waitOutputReady() bool {
    var attempts: usize = 0;
    while ((io.in8(StatusPort) & OutputBufferFull) == 0) : (attempts += 1) {
        if (attempts > 100000) return false;
    }
    return true;
}

fn decodeSet1(scancode: u8, extended: bool) KeyCode {
    if (extended) {
        return switch (scancode) {
            0x1C => .enter,
            0x1D => .right_ctrl,
            0x35 => .slash,
            0x38 => .right_alt,
            0x47 => .home,
            0x48 => .arrow_up,
            0x49 => .page_up,
            0x4B => .arrow_left,
            0x4D => .arrow_right,
            0x4F => .end,
            0x50 => .arrow_down,
            0x51 => .page_down,
            0x52 => .insert,
            0x53 => .delete,
            else => .unknown,
        };
    }

    return switch (scancode) {
        0x01 => .escape,
        0x0E => .backspace,
        0x0F => .tab,
        0x1C => .enter,
        0x1D => .left_ctrl,
        0x2A => .left_shift,
        0x36 => .right_shift,
        0x38 => .left_alt,
        0x3A => .caps_lock,
        0x3B => .f1,
        0x3C => .f2,
        0x3D => .f3,
        0x3E => .f4,
        0x3F => .f5,
        0x40 => .f6,
        0x41 => .f7,
        0x42 => .f8,
        0x43 => .f9,
        0x44 => .f10,
        0x57 => .f11,
        0x58 => .f12,
        0x39 => .space,
        0x1E => .a,
        0x30 => .b,
        0x2E => .c,
        0x20 => .d,
        0x12 => .e,
        0x21 => .f,
        0x22 => .g,
        0x23 => .h,
        0x17 => .i,
        0x24 => .j,
        0x25 => .k,
        0x26 => .l,
        0x32 => .m,
        0x31 => .n,
        0x18 => .o,
        0x19 => .p,
        0x10 => .q,
        0x13 => .r,
        0x1F => .s,
        0x14 => .t,
        0x16 => .u,
        0x2F => .v,
        0x11 => .w,
        0x2D => .x,
        0x15 => .y,
        0x2C => .z,
        0x02 => .digit_1,
        0x03 => .digit_2,
        0x04 => .digit_3,
        0x05 => .digit_4,
        0x06 => .digit_5,
        0x07 => .digit_6,
        0x08 => .digit_7,
        0x09 => .digit_8,
        0x0A => .digit_9,
        0x0B => .digit_0,
        0x0C => .minus,
        0x0D => .equal,
        0x1A => .left_bracket,
        0x1B => .right_bracket,
        0x2B => .backslash,
        0x27 => .semicolon,
        0x28 => .apostrophe,
        0x29 => .grave,
        0x33 => .comma,
        0x34 => .dot,
        0x35 => .slash,
        else => .unknown,
    };
}

fn decodeScancode(scancode: u8, extended: bool) KeyCode {
    return switch (scan_set) {
        .set1 => decodeSet1(scancode, extended),
        .set2 => decodeSet2(scancode, extended),
    };
}

fn decodeSet2(scancode: u8, extended: bool) KeyCode {
    if (extended) {
        return switch (scancode) {
            0x11 => .right_alt,
            0x14 => .right_ctrl,
            0x4A => .keypad_slash,
            0x5A => .keypad_enter,
            0x69 => .end,
            0x6B => .arrow_left,
            0x6C => .home,
            0x70 => .insert,
            0x71 => .delete,
            0x72 => .arrow_down,
            0x74 => .arrow_right,
            0x75 => .arrow_up,
            0x7A => .page_down,
            0x7D => .page_up,
            else => .unknown,
        };
    }

    return switch (scancode) {
        0x76 => .escape,
        0x66 => .backspace,
        0x0D => .tab,
        0x5A => .enter,
        0x14 => .left_ctrl,
        0x12 => .left_shift,
        0x59 => .right_shift,
        0x11 => .left_alt,
        0x58 => .caps_lock,
        0x77 => .num_lock,
        0x05 => .f1,
        0x06 => .f2,
        0x04 => .f3,
        0x0C => .f4,
        0x03 => .f5,
        0x0B => .f6,
        0x83 => .f7,
        0x0A => .f8,
        0x01 => .f9,
        0x09 => .f10,
        0x78 => .f11,
        0x07 => .f12,
        0x29 => .space,
        0x1C => .a,
        0x32 => .b,
        0x21 => .c,
        0x23 => .d,
        0x24 => .e,
        0x2B => .f,
        0x34 => .g,
        0x33 => .h,
        0x43 => .i,
        0x3B => .j,
        0x42 => .k,
        0x4B => .l,
        0x3A => .m,
        0x31 => .n,
        0x44 => .o,
        0x4D => .p,
        0x15 => .q,
        0x2D => .r,
        0x1B => .s,
        0x2C => .t,
        0x3C => .u,
        0x2A => .v,
        0x1D => .w,
        0x22 => .x,
        0x35 => .y,
        0x1A => .z,
        0x16 => .digit_1,
        0x1E => .digit_2,
        0x26 => .digit_3,
        0x25 => .digit_4,
        0x2E => .digit_5,
        0x36 => .digit_6,
        0x3D => .digit_7,
        0x3E => .digit_8,
        0x46 => .digit_9,
        0x45 => .digit_0,
        0x4E => .minus,
        0x55 => .equal,
        0x54 => .left_bracket,
        0x5B => .right_bracket,
        0x5D => .backslash,
        0x4C => .semicolon,
        0x52 => .apostrophe,
        0x0E => .grave,
        0x41 => .comma,
        0x49 => .dot,
        0x4A => .slash,
        0x70 => .keypad_0,
        0x69 => .keypad_1,
        0x72 => .keypad_2,
        0x7A => .keypad_3,
        0x6B => .keypad_4,
        0x73 => .keypad_5,
        0x74 => .keypad_6,
        0x6C => .keypad_7,
        0x75 => .keypad_8,
        0x7D => .keypad_9,
        0x71 => .keypad_dot,
        0x7C => .keypad_star,
        0x7B => .keypad_minus,
        0x79 => .keypad_plus,
        else => .unknown,
    };
}

fn keyToAscii(key: KeyCode, mods: Modifier, pressed: bool) ?u8 {
    if (!pressed) return null;

    const shifted = mods.shift();
    const caps = mods.caps_lock;
    const alpha_upper = shifted != caps;

    return switch (key) {
        .space => ' ',
        .tab => '\t',
        .enter => '\n',
        .backspace => '\x08',
        .keypad_0 => if (mods.num_lock) '0' else null,
        .keypad_1 => if (mods.num_lock) '1' else null,
        .keypad_2 => if (mods.num_lock) '2' else null,
        .keypad_3 => if (mods.num_lock) '3' else null,
        .keypad_4 => if (mods.num_lock) '4' else null,
        .keypad_5 => if (mods.num_lock) '5' else null,
        .keypad_6 => if (mods.num_lock) '6' else null,
        .keypad_7 => if (mods.num_lock) '7' else null,
        .keypad_8 => if (mods.num_lock) '8' else null,
        .keypad_9 => if (mods.num_lock) '9' else null,
        .keypad_dot => if (mods.num_lock) '.' else null,
        .keypad_slash => '/',
        .keypad_star => '*',
        .keypad_minus => '-',
        .keypad_plus => '+',
        .keypad_enter => '\n',
        .a => if (alpha_upper) 'A' else 'a',
        .b => if (alpha_upper) 'B' else 'b',
        .c => if (alpha_upper) 'C' else 'c',
        .d => if (alpha_upper) 'D' else 'd',
        .e => if (alpha_upper) 'E' else 'e',
        .f => if (alpha_upper) 'F' else 'f',
        .g => if (alpha_upper) 'G' else 'g',
        .h => if (alpha_upper) 'H' else 'h',
        .i => if (alpha_upper) 'I' else 'i',
        .j => if (alpha_upper) 'J' else 'j',
        .k => if (alpha_upper) 'K' else 'k',
        .l => if (alpha_upper) 'L' else 'l',
        .m => if (alpha_upper) 'M' else 'm',
        .n => if (alpha_upper) 'N' else 'n',
        .o => if (alpha_upper) 'O' else 'o',
        .p => if (alpha_upper) 'P' else 'p',
        .q => if (alpha_upper) 'Q' else 'q',
        .r => if (alpha_upper) 'R' else 'r',
        .s => if (alpha_upper) 'S' else 's',
        .t => if (alpha_upper) 'T' else 't',
        .u => if (alpha_upper) 'U' else 'u',
        .v => if (alpha_upper) 'V' else 'v',
        .w => if (alpha_upper) 'W' else 'w',
        .x => if (alpha_upper) 'X' else 'x',
        .y => if (alpha_upper) 'Y' else 'y',
        .z => if (alpha_upper) 'Z' else 'z',
        .digit_1 => if (shifted) '!' else '1',
        .digit_2 => if (shifted) '@' else '2',
        .digit_3 => if (shifted) '#' else '3',
        .digit_4 => if (shifted) '$' else '4',
        .digit_5 => if (shifted) '%' else '5',
        .digit_6 => if (shifted) '^' else '6',
        .digit_7 => if (shifted) '&' else '7',
        .digit_8 => if (shifted) '*' else '8',
        .digit_9 => if (shifted) '(' else '9',
        .digit_0 => if (shifted) ')' else '0',
        .minus => if (shifted) '_' else '-',
        .equal => if (shifted) '+' else '=',
        .left_bracket => if (shifted) '{' else '[',
        .right_bracket => if (shifted) '}' else ']',
        .backslash => if (shifted) '|' else '\\',
        .semicolon => if (shifted) ':' else ';',
        .apostrophe => if (shifted) '"' else '\'',
        .grave => if (shifted) '~' else '`',
        .comma => if (shifted) '<' else ',',
        .dot => if (shifted) '>' else '.',
        .slash => if (shifted) '?' else '/',
        else => null,
    };
}
