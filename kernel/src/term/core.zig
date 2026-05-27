pub const MAX_COLS: usize = 320;
pub const MAX_ROWS: usize = 100;
pub const MAX_CELLS: usize = MAX_COLS * MAX_ROWS;
pub const replacement_codepoint: u32 = 0xFFFD;

pub const Cell = struct {
    codepoint: u32,
    fg: u32,
    bg: u32,
    dirty: bool,
};

pub const TerminalCore = struct {
    cols: usize,
    rows: usize,
    cursor_x: usize,
    cursor_y: usize,
    tab_width: usize,
    current_fg: u32,
    current_bg: u32,
    cells: [MAX_CELLS]Cell,

    pub fn initAt(self: *TerminalCore, cols: usize, rows: usize, fg: u32, bg: u32) void {
        if (cols == 0 or rows == 0 or cols > MAX_COLS or rows > MAX_ROWS) {
            @panic("Terminal dimensions out of bounds");
        }

        self.* = .{
            .cols = cols,
            .rows = rows,
            .cursor_x = 0,
            .cursor_y = 0,
            .tab_width = 4,
            .current_fg = fg,
            .current_bg = bg,
            .cells = undefined,
        };
        self.resetCells(false);
    }

    fn resetCells(self: *TerminalCore, mark_dirty: bool) void {
        const count = self.rows * self.cols;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            self.cells[i] = .{
                .codepoint = ' ',
                .fg = self.current_fg,
                .bg = self.current_bg,
                .dirty = mark_dirty,
            };
        }
        self.cursor_x = 0;
        self.cursor_y = 0;
    }

    pub fn clear(self: *TerminalCore) void {
        self.resetCells(true);
    }

    pub fn writeCodepoint(self: *TerminalCore, codepoint: u32) void {
        switch (codepoint) {
            '\n' => self.newline(),
            '\r' => self.cursor_x = 0,
            '\x08' => self.backspace(),
            '\t' => self.tab(),
            else => self.putPrintable(codepoint),
        }
    }

    pub fn markAllDirty(self: *TerminalCore) void {
        var row: usize = 0;
        while (row < self.rows) : (row += 1) {
            var col: usize = 0;
            while (col < self.cols) : (col += 1) {
                self.cellPtr(col, row).dirty = true;
            }
        }
    }

    fn putPrintable(self: *TerminalCore, codepoint: u32) void {
        if (self.cursor_x >= self.cols) {
            self.newline();
        }

        if (self.cursor_y >= self.rows) {
            self.scrollUp();
            self.cursor_y = self.rows - 1;
        }

        const cp = if (codepoint <= 0xFFFF) codepoint else replacement_codepoint;
        const cell = self.cellPtr(self.cursor_x, self.cursor_y);
        cell.* = .{
            .codepoint = cp,
            .fg = self.current_fg,
            .bg = self.current_bg,
            .dirty = true,
        };

        self.cursor_x += 1;
    }

    fn backspace(self: *TerminalCore) void {
        if (self.cursor_x == 0 and self.cursor_y == 0) return;

        if (self.cursor_x == 0) {
            self.cursor_y -= 1;
            self.cursor_x = self.cols - 1;
        } else {
            self.cursor_x -= 1;
        }

        const cell = self.cellPtr(self.cursor_x, self.cursor_y);
        cell.codepoint = ' ';
        cell.fg = self.current_fg;
        cell.bg = self.current_bg;
        cell.dirty = true;
    }

    fn tab(self: *TerminalCore) void {
        const next_tab_stop = ((self.cursor_x / self.tab_width) + 1) * self.tab_width;
        while (self.cursor_x < next_tab_stop) {
            self.putPrintable(' ');
        }
    }

    fn newline(self: *TerminalCore) void {
        self.cursor_x = 0;
        self.cursor_y += 1;
        if (self.cursor_y >= self.rows) {
            self.scrollUp();
            self.cursor_y = self.rows - 1;
        }
    }

    fn scrollUp(self: *TerminalCore) void {
        var row: usize = 1;
        while (row < self.rows) : (row += 1) {
            var col: usize = 0;
            while (col < self.cols) : (col += 1) {
                const dst = self.cellPtr(col, row - 1);
                const src = self.cellPtr(col, row);
                dst.* = src.*;
                dst.dirty = true;
            }
        }

        var col: usize = 0;
        while (col < self.cols) : (col += 1) {
            const cell = self.cellPtr(col, self.rows - 1);
            cell.* = .{
                .codepoint = ' ',
                .fg = self.current_fg,
                .bg = self.current_bg,
                .dirty = true,
            };
        }
    }

    pub fn cellPtr(self: *TerminalCore, x: usize, y: usize) *Cell {
        return &self.cells[y * self.cols + x];
    }
};
