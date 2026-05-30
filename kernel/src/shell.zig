const keyboard = @import("drivers/input/keyboard.zig");
const terminal_mod = @import("term/terminal.zig");
const core_mod = @import("term/core.zig");

const MAX_LINE = 256;
const MAX_HISTORY = 32;
const MAX_ARGS = 16;

pub const Shell = struct {
    prompt: []const u8 = "phoenix> ",
    buffer: [MAX_LINE]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    line_row: usize = 0,
    history: [MAX_HISTORY][MAX_LINE]u8 = undefined,
    history_len: [MAX_HISTORY]usize = [_]usize{0} ** MAX_HISTORY,
    history_count: usize = 0,
    history_head: usize = 0,
    browsing: ?usize = null,
    draft_buffer: [MAX_LINE]u8 = undefined,
    draft_len: usize = 0,
    draft_cursor: usize = 0,

    pub fn init(self: *Shell, prompt: []const u8) void {
        self.prompt = prompt;
        self.buffer = undefined;
        self.len = 0;
        self.cursor = 0;
        self.history = undefined;
        self.history_len = [_]usize{0} ** MAX_HISTORY;
        self.history_count = 0;
        self.history_head = 0;
        self.browsing = null;
        self.draft_buffer = undefined;
        self.draft_len = 0;
        self.draft_cursor = 0;
        self.beginPrompt();
    }

    pub fn handleEvent(self: *Shell, event: keyboard.KeyEvent) bool {
        if (!event.pressed) return false;

        if (event.ascii) |byte| {
            switch (byte) {
                '\n' => {
                    self.submitLine();
                    return true;
                },
                '\x08' => {
                    self.backspace();
                    return true;
                },
                else => {
                    if (byte >= 0x20 and byte <= 0x7E or byte >= 0xA0) {
                        self.insert(byte);
                        return true;
                    }
                },
            }
        }

        switch (event.code) {
            .arrow_left => {
                self.moveLeft();
                return true;
            },
            .arrow_right => {
                self.moveRight();
                return true;
            },
            .arrow_up => {
                self.historyUp();
                return true;
            },
            .arrow_down => {
                self.historyDown();
                return true;
            },
            .delete => {
                self.deleteAtCursor();
                return true;
            },
            .home => {
                self.cursor = 0;
                self.redrawLine();
                return true;
            },
            .end => {
                self.cursor = self.len;
                self.redrawLine();
                return true;
            },
            else => return false,
        }
    }

    fn beginPrompt(self: *Shell) void {
        terminal_mod.write(self.prompt);
        terminal_mod.finishWrite();
        const pos = terminal_mod.core().cursor();
        self.line_row = pos.y;
        self.redrawLine();
    }

    fn redrawLine(self: *Shell) void {
        const core = terminal_mod.core();
        core.clearRow(self.line_row);
        core.setCursor(0, self.line_row);
        terminal_mod.write(self.prompt);
        terminal_mod.write(self.buffer[0..self.len]);
        terminal_mod.finishWrite();
        core.setCursor(self.prompt.len + self.cursor, self.line_row);
    }

    fn insert(self: *Shell, byte: u8) void {
        if (self.len >= MAX_LINE) return;

        var index = self.len;
        while (index > self.cursor) : (index -= 1) {
            self.buffer[index] = self.buffer[index - 1];
        }

        self.buffer[self.cursor] = byte;
        self.len += 1;
        self.cursor += 1;
        self.browsing = null;
        self.redrawLine();
    }

    fn backspace(self: *Shell) void {
        if (self.cursor == 0 or self.len == 0) return;

        var index = self.cursor - 1;
        while (index + 1 < self.len) : (index += 1) {
            self.buffer[index] = self.buffer[index + 1];
        }

        self.len -= 1;
        self.cursor -= 1;
        self.browsing = null;
        self.redrawLine();
    }

    fn deleteAtCursor(self: *Shell) void {
        if (self.cursor >= self.len) return;

        var index = self.cursor;
        while (index + 1 < self.len) : (index += 1) {
            self.buffer[index] = self.buffer[index + 1];
        }

        self.len -= 1;
        self.browsing = null;
        self.redrawLine();
    }

    fn moveLeft(self: *Shell) void {
        if (self.cursor == 0) return;
        self.cursor -= 1;
        self.redrawLine();
    }

    fn moveRight(self: *Shell) void {
        if (self.cursor >= self.len) return;
        self.cursor += 1;
        self.redrawLine();
    }

    fn historyUp(self: *Shell) void {
        if (self.history_count == 0) return;

        if (self.browsing == null) {
            self.saveDraft();
            self.browsing = self.history_count - 1;
        } else if (self.browsing.? > 0) {
            self.browsing = self.browsing.? - 1;
        }

        self.loadHistory(self.browsing.?);
    }

    fn historyDown(self: *Shell) void {
        if (self.browsing == null) return;

        if (self.browsing.? + 1 < self.history_count) {
            self.browsing = self.browsing.? + 1;
            self.loadHistory(self.browsing.?);
        } else {
            self.restoreDraft();
            self.browsing = null;
        }
    }

    fn saveDraft(self: *Shell) void {
        @memcpy(self.draft_buffer[0..self.len], self.buffer[0..self.len]);
        self.draft_len = self.len;
        self.draft_cursor = self.cursor;
    }

    fn restoreDraft(self: *Shell) void {
        @memcpy(self.buffer[0..self.draft_len], self.draft_buffer[0..self.draft_len]);
        self.len = self.draft_len;
        self.cursor = self.draft_cursor;
        self.redrawLine();
    }

    fn loadHistory(self: *Shell, history_index: usize) void {
        const slot = self.historySlot(history_index);
        self.len = self.history_len[slot];
        @memcpy(self.buffer[0..self.len], self.history[slot][0..self.len]);
        self.cursor = self.len;
        self.redrawLine();
    }

    fn submitLine(self: *Shell) void {
        const line = self.buffer[0..self.len];
        self.rememberLine(line);

        terminal_mod.write("\n");
        terminal_mod.finishWrite();
        self.execute(line);
        self.resetLine();
    }

    fn resetLine(self: *Shell) void {
        self.len = 0;
        self.cursor = 0;
        self.browsing = null;
        self.beginPrompt();
    }

    fn rememberLine(self: *Shell, line: []const u8) void {
        if (line.len == 0) return;

        const slot = self.history_head;
        const copy_len = @min(line.len, MAX_LINE);
        @memcpy(self.history[slot][0..copy_len], line[0..copy_len]);
        self.history_len[slot] = copy_len;
        self.history_head = (self.history_head + 1) % MAX_HISTORY;
        if (self.history_count < MAX_HISTORY) self.history_count += 1;
    }

    fn historySlot(self: *Shell, history_index: usize) usize {
        const oldest = if (self.history_count < MAX_HISTORY) 0 else self.history_head;
        return (oldest + history_index) % MAX_HISTORY;
    }

    fn execute(self: *Shell, line: []const u8) void {
        var argv: [MAX_ARGS][]const u8 = undefined;
        var parsed_line: [MAX_LINE]u8 = undefined;
        const argc = parseCommandLine(line, &argv, parsed_line[0..]);

        if (argc == 0) return;

        const command = argv[0];
        if (std.mem.eql(u8, command, "help")) {
            terminal_mod.write("Commands: help clear echo history version\n");
        } else if (std.mem.eql(u8, command, "clear")) {
            terminal_mod.core().clear();
        } else if (std.mem.eql(u8, command, "echo")) {
            var i: usize = 1;
            while (i < argc) : (i += 1) {
                if (i > 1) terminal_mod.write(" ");
                terminal_mod.write(argv[i]);
            }
            terminal_mod.write("\n");
        } else if (std.mem.eql(u8, command, "history")) {
            var index: usize = 0;
            while (index < self.history_count) : (index += 1) {
                const slot = self.historySlot(index);
                terminal_mod.write("[");
                var index_buf: [16]u8 = undefined;
                const formatted = std.fmt.bufPrint(&index_buf, "{}", .{index + 1}) catch unreachable;
                terminal_mod.write(formatted);
                terminal_mod.write("] ");
                terminal_mod.write(self.history[slot][0..self.history_len[slot]]);
                terminal_mod.write("\n");
            }
        } else if (std.mem.eql(u8, command, "version")) {
            terminal_mod.write("Axiom shell alpha-0.0.1\n");
        } else {
            terminal_mod.write("command not found: ");
            terminal_mod.write(command);
            terminal_mod.write("\n");
        }

        terminal_mod.finishWrite();
    }
};

fn parseCommandLine(line: []const u8, argv: *[MAX_ARGS][]const u8, storage: []u8) usize {
    var argc: usize = 0;
    var index: usize = 0;
    var write_index: usize = 0;

    while (index < line.len) {
        while (index < line.len and isWhitespace(line[index])) : (index += 1) {}
        if (index >= line.len) break;
        if (argc >= MAX_ARGS) break;

        const token_start = write_index;
        var quoted: ?u8 = null;

        while (index < line.len) : (index += 1) {
            const ch = line[index];
            if (quoted) |quote_char| {
                if (ch == quote_char) {
                    quoted = null;
                    continue;
                }
            } else {
                if (isWhitespace(ch)) break;
                if (ch == '"' or ch == '\'') {
                    quoted = ch;
                    continue;
                }
            }

            if (ch == '\\' and index + 1 < line.len) {
                index += 1;
                if (write_index < storage.len) {
                    storage[write_index] = line[index];
                    write_index += 1;
                }
                continue;
            }

            if (write_index < storage.len) {
                storage[write_index] = ch;
                write_index += 1;
            }
        }

        argv[argc] = storage[token_start..write_index];
        argc += 1;

        while (index < line.len and isWhitespace(line[index])) : (index += 1) {}
    }

    return argc;
}

fn isWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r';
}

const std = @import("std");
