//! Pure-Zig Thompson-NFA case-insensitive regular expression matcher for
//! `query_heapsnapshot_objects` (`className` and `propertyName`, matching
//! DevTools `HeapSnapshot.queryObjects`'s `new RegExp(pattern, "i")`).
//!
//! Runs in O(pattern_len * text_len) time with zero backtracking blowup and
//! zero heap allocations outside the caller's arena.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CompileError = error{
    InvalidRegex,
} || Allocator.Error;

const CharClass = struct {
    negated: bool = false,
    /// 256-bit ASCII membership mask (4 x u64).
    bits: [4]u64 = .{ 0, 0, 0, 0 },
    /// Match any non-ASCII byte (>= 0x80) if true (used by `\D`, `\W`, `\S`, `[^...]`).
    match_non_ascii: bool = false,

    fn setByte(self: *CharClass, b: u8) void {
        self.bits[b >> 6] |= (@as(u64, 1) << @intCast(b & 63));
    }

    fn setByteCaseInsensitive(self: *CharClass, b: u8) void {
        self.setByte(b);
        if (b >= 'A' and b <= 'Z') self.setByte(b + 32);
        if (b >= 'a' and b <= 'z') self.setByte(b - 32);
    }

    fn setRangeCaseInsensitive(self: *CharClass, lo: u8, hi: u8) void {
        var c: u16 = lo;
        while (c <= hi) : (c += 1) {
            self.setByteCaseInsensitive(@intCast(c));
        }
    }

    fn matches(self: CharClass, b: u8) bool {
        const hit = if (b < 128)
            ((self.bits[b >> 6] & (@as(u64, 1) << @intCast(b & 63))) != 0)
        else
            self.match_non_ascii;
        return if (self.negated) !hit else hit;
    }
};

const Inst = union(enum) {
    match,
    any_non_newline,
    literal: u8, // stored lowercase for ASCII
    class: u32, // index into Regex.classes
    anchor_start,
    anchor_end,
    word_boundary,
    non_word_boundary,
    jmp: u32,
    split: struct { a: u32, b: u32 },
};

pub const Regex = struct {
    start: u32,
    insts: []const Inst,
    classes: []const CharClass,

    pub fn compile(arena: Allocator, pattern: []const u8) CompileError!Regex {
        var p: Parser = .{
            .arena = arena,
            .src = pattern,
            .pos = 0,
            .insts = .empty,
            .classes = .empty,
        };
        const frag = try p.parseAlt();
        if (p.pos != p.src.len) return error.InvalidRegex;
        const match_pc: u32 = @intCast(p.insts.items.len);
        try p.insts.append(arena, .match);
        p.patchList(frag.outs, match_pc);
        return .{
            .start = frag.start,
            .insts = p.insts.items,
            .classes = p.classes.items,
        };
    }

    /// Returns true if `haystack` contains a match anywhere (like JS `RegExp.prototype.test`).
    pub fn testMatch(self: Regex, arena: Allocator, haystack: []const u8) Allocator.Error!bool {
        const n = self.insts.len;
        if (n == 0) return true;
        var curr: std.ArrayList(u32) = .empty;
        var next: std.ArrayList(u32) = .empty;
        const seen = try arena.alloc(u32, n);
        @memset(seen, 0);
        var gen: u32 = 1;

        var start_pos: usize = 0;
        while (start_pos <= haystack.len) : (start_pos += 1) {
            curr.clearRetainingCapacity();
            gen +%= 1;
            if (gen == 0) {
                @memset(seen, 0);
                gen = 1;
            }
            if (try self.addState(arena, &curr, seen, gen, self.start, haystack, start_pos)) return true;

            var pos = start_pos;
            while (pos < haystack.len and curr.items.len > 0) : (pos += 1) {
                const b = haystack[pos];
                const lb = std.ascii.toLower(b);
                next.clearRetainingCapacity();
                gen +%= 1;
                if (gen == 0) {
                    @memset(seen, 0);
                    gen = 1;
                }
                for (curr.items) |pc| {
                    const matched = switch (self.insts[pc]) {
                        .any_non_newline => b != '\n' and b != '\r',
                        .literal => |lit| lb == lit,
                        .class => |cid| self.classes[cid].matches(b),
                        else => false,
                    };
                    if (matched) {
                        if (try self.addState(arena, &next, seen, gen, pc + 1, haystack, pos + 1)) return true;
                    }
                }
                std.mem.swap(std.ArrayList(u32), &curr, &next);
            }
            // Also check trailing zero-width transitions / match at end of slice.
            for (curr.items) |pc| {
                if (self.insts[pc] == .match) return true;
            }
        }
        return false;
    }

    fn addState(
        self: Regex,
        arena: Allocator,
        list: *std.ArrayList(u32),
        seen: []u32,
        gen: u32,
        start_pc: u32,
        haystack: []const u8,
        pos: usize,
    ) Allocator.Error!bool {
        var stack: std.ArrayList(u32) = .empty;
        try stack.append(arena, start_pc);
        while (stack.items.len > 0) {
            const pc = stack.pop().?;
            if (pc >= self.insts.len) continue;
            if (seen[pc] == gen) continue;
            seen[pc] = gen;
            switch (self.insts[pc]) {
                .match => return true,
                .jmp => |target| try stack.append(arena, target),
                .split => |sp| {
                    try stack.append(arena, sp.b);
                    try stack.append(arena, sp.a);
                },
                .anchor_start => {
                    if (pos == 0) try stack.append(arena, pc + 1);
                },
                .anchor_end => {
                    if (pos == haystack.len) try stack.append(arena, pc + 1);
                },
                .word_boundary => {
                    if (isWordBoundary(haystack, pos)) try stack.append(arena, pc + 1);
                },
                .non_word_boundary => {
                    if (!isWordBoundary(haystack, pos)) try stack.append(arena, pc + 1);
                },
                else => try list.append(arena, pc),
            }
        }
        return false;
    }
};

fn isWordChar(b: u8) bool {
    return std.ascii.isAlphanumeric(b) or b == '_';
}

fn isWordBoundary(haystack: []const u8, pos: usize) bool {
    const left = if (pos > 0) isWordChar(haystack[pos - 1]) else false;
    const right = if (pos < haystack.len) isWordChar(haystack[pos]) else false;
    return left != right;
}

const PatchSlot = struct {
    pc: u32,
    branch: enum { jmp, split_a, split_b },
};

const Frag = struct {
    start: u32,
    outs: std.ArrayList(PatchSlot),
};

const Parser = struct {
    arena: Allocator,
    src: []const u8,
    pos: usize,
    insts: std.ArrayList(Inst),
    classes: std.ArrayList(CharClass),

    fn patchList(self: *Parser, outs: std.ArrayList(PatchSlot), target: u32) void {
        for (outs.items) |slot| {
            switch (slot.branch) {
                .jmp => self.insts.items[slot.pc] = .{ .jmp = target },
                .split_a => self.insts.items[slot.pc].split.a = target,
                .split_b => self.insts.items[slot.pc].split.b = target,
            }
        }
    }

    fn emitEmpty(self: *Parser) Allocator.Error!Frag {
        const pc: u32 = @intCast(self.insts.items.len);
        try self.insts.append(self.arena, .{ .jmp = 0 });
        var outs: std.ArrayList(PatchSlot) = .empty;
        try outs.append(self.arena, .{ .pc = pc, .branch = .jmp });
        return .{ .start = pc, .outs = outs };
    }

    fn parseAlt(self: *Parser) CompileError!Frag {
        var left = try self.parseConcat();
        while (self.pos < self.src.len and self.src[self.pos] == '|') {
            self.pos += 1;
            const right = try self.parseConcat();
            const split_pc: u32 = @intCast(self.insts.items.len);
            try self.insts.append(self.arena, .{ .split = .{ .a = left.start, .b = right.start } });
            var outs = left.outs;
            try outs.appendSlice(self.arena, right.outs.items);
            left = .{ .start = split_pc, .outs = outs };
        }
        return left;
    }

    fn parseConcat(self: *Parser) CompileError!Frag {
        var acc: ?Frag = null;
        while (self.pos < self.src.len) {
            const c = self.src[self.pos];
            if (c == '|' or c == ')') break;
            const atom = try self.parseQuantified();
            if (acc) |*prev| {
                self.patchList(prev.outs, atom.start);
                prev.outs = atom.outs;
            } else {
                acc = atom;
            }
        }
        return acc orelse try self.emitEmpty();
    }

    fn parseQuantified(self: *Parser) CompileError!Frag {
        const atom_start_pos = self.pos;
        const frag = try self.parseAtom();
        if (self.pos >= self.src.len) return frag;
        const q = self.src[self.pos];
        switch (q) {
            '*' => {
                self.pos += 1;
                if (self.pos < self.src.len and self.src[self.pos] == '?') self.pos += 1;
                const split_pc: u32 = @intCast(self.insts.items.len);
                try self.insts.append(self.arena, .{ .split = .{ .a = frag.start, .b = 0 } });
                self.patchList(frag.outs, split_pc);
                var outs: std.ArrayList(PatchSlot) = .empty;
                try outs.append(self.arena, .{ .pc = split_pc, .branch = .split_b });
                return .{ .start = split_pc, .outs = outs };
            },
            '+' => {
                self.pos += 1;
                if (self.pos < self.src.len and self.src[self.pos] == '?') self.pos += 1;
                const split_pc: u32 = @intCast(self.insts.items.len);
                try self.insts.append(self.arena, .{ .split = .{ .a = frag.start, .b = 0 } });
                self.patchList(frag.outs, split_pc);
                var outs: std.ArrayList(PatchSlot) = .empty;
                try outs.append(self.arena, .{ .pc = split_pc, .branch = .split_b });
                return .{ .start = frag.start, .outs = outs };
            },
            '?' => {
                self.pos += 1;
                if (self.pos < self.src.len and self.src[self.pos] == '?') self.pos += 1;
                const split_pc: u32 = @intCast(self.insts.items.len);
                try self.insts.append(self.arena, .{ .split = .{ .a = frag.start, .b = 0 } });
                var outs = frag.outs;
                try outs.append(self.arena, .{ .pc = split_pc, .branch = .split_b });
                return .{ .start = split_pc, .outs = outs };
            },
            '{' => {
                const saved = self.pos;
                if (self.tryParseBraceQuantifier()) |bounds| {
                    if (self.pos < self.src.len and self.src[self.pos] == '?') self.pos += 1;
                    return self.buildRepetition(atom_start_pos, saved, bounds.min, bounds.max);
                }
                self.pos = saved;
                return frag;
            },
            else => return frag,
        }
    }

    const QuantBounds = struct { min: usize, max: ?usize };

    fn tryParseBraceQuantifier(self: *Parser) ?QuantBounds {
        if (self.pos >= self.src.len or self.src[self.pos] != '{') return null;
        var i = self.pos + 1;
        const min_start = i;
        while (i < self.src.len and std.ascii.isDigit(self.src[i])) : (i += 1) {}
        if (i == min_start) return null;
        const min = std.fmt.parseInt(usize, self.src[min_start..i], 10) catch return null;
        if (min > 256) return null;
        if (i < self.src.len and self.src[i] == '}') {
            self.pos = i + 1;
            return .{ .min = min, .max = min };
        }
        if (i >= self.src.len or self.src[i] != ',') return null;
        i += 1;
        if (i < self.src.len and self.src[i] == '}') {
            self.pos = i + 1;
            return .{ .min = min, .max = null };
        }
        const max_start = i;
        while (i < self.src.len and std.ascii.isDigit(self.src[i])) : (i += 1) {}
        if (i == max_start or i >= self.src.len or self.src[i] != '}') return null;
        const max = std.fmt.parseInt(usize, self.src[max_start..i], 10) catch return null;
        if (max < min or max > 256) return null;
        self.pos = i + 1;
        return .{ .min = min, .max = max };
    }

    fn buildRepetition(self: *Parser, atom_start: usize, atom_end: usize, min: usize, max: ?usize) CompileError!Frag {
        const after_quant = self.pos;
        defer self.pos = after_quant;

        var acc: ?Frag = null;
        for (0..min) |_| {
            self.pos = atom_start;
            const copy = try self.parseAtom();
            if (self.pos != atom_end) return error.InvalidRegex;
            if (acc) |*prev| {
                self.patchList(prev.outs, copy.start);
                prev.outs = copy.outs;
            } else {
                acc = copy;
            }
        }
        if (max) |m| {
            for (min..m) |_| {
                self.pos = atom_start;
                const copy = try self.parseAtom();
                const split_pc: u32 = @intCast(self.insts.items.len);
                try self.insts.append(self.arena, .{ .split = .{ .a = copy.start, .b = 0 } });
                var opt_outs = copy.outs;
                try opt_outs.append(self.arena, .{ .pc = split_pc, .branch = .split_b });
                const opt: Frag = .{ .start = split_pc, .outs = opt_outs };
                if (acc) |*prev| {
                    self.patchList(prev.outs, opt.start);
                    prev.outs = opt.outs;
                } else {
                    acc = opt;
                }
            }
        } else {
            self.pos = atom_start;
            const copy = try self.parseAtom();
            const split_pc: u32 = @intCast(self.insts.items.len);
            try self.insts.append(self.arena, .{ .split = .{ .a = copy.start, .b = 0 } });
            self.patchList(copy.outs, split_pc);
            var star_outs: std.ArrayList(PatchSlot) = .empty;
            try star_outs.append(self.arena, .{ .pc = split_pc, .branch = .split_b });
            const star: Frag = .{ .start = split_pc, .outs = star_outs };
            if (acc) |*prev| {
                self.patchList(prev.outs, star.start);
                prev.outs = star.outs;
            } else {
                acc = star;
            }
        }
        return acc orelse try self.emitEmpty();
    }

    fn emitSingle(self: *Parser, inst: Inst) Allocator.Error!Frag {
        const pc: u32 = @intCast(self.insts.items.len);
        try self.insts.append(self.arena, inst);
        const jmp_pc: u32 = @intCast(self.insts.items.len);
        try self.insts.append(self.arena, .{ .jmp = 0 });
        var outs: std.ArrayList(PatchSlot) = .empty;
        try outs.append(self.arena, .{ .pc = jmp_pc, .branch = .jmp });
        return .{ .start = pc, .outs = outs };
    }

    fn parseAtom(self: *Parser) CompileError!Frag {
        if (self.pos >= self.src.len) return error.InvalidRegex;
        const c = self.src[self.pos];
        switch (c) {
            '^' => {
                self.pos += 1;
                return self.emitSingle(.anchor_start);
            },
            '$' => {
                self.pos += 1;
                return self.emitSingle(.anchor_end);
            },
            '.' => {
                self.pos += 1;
                return self.emitSingle(.any_non_newline);
            },
            '(' => {
                self.pos += 1;
                if (self.pos + 1 < self.src.len and self.src[self.pos] == '?' and self.src[self.pos + 1] == ':') {
                    self.pos += 2;
                }
                const inner = try self.parseAlt();
                if (self.pos >= self.src.len or self.src[self.pos] != ')') return error.InvalidRegex;
                self.pos += 1;
                return inner;
            },
            '[' => return self.parseCharClass(),
            '\\' => return self.parseEscape(),
            '*', '+', '?' => return error.InvalidRegex,
            else => {
                self.pos += 1;
                return self.emitSingle(.{ .literal = std.ascii.toLower(c) });
            },
        }
    }

    fn parseEscape(self: *Parser) CompileError!Frag {
        self.pos += 1;
        if (self.pos >= self.src.len) return error.InvalidRegex;
        const c = self.src[self.pos];
        self.pos += 1;
        switch (c) {
            'b' => return self.emitSingle(.word_boundary),
            'B' => return self.emitSingle(.non_word_boundary),
            'd', 'D', 'w', 'W', 's', 'S' => {
                var cc: CharClass = .{};
                addShorthandClass(&cc, c);
                const cid: u32 = @intCast(self.classes.items.len);
                try self.classes.append(self.arena, cc);
                return self.emitSingle(.{ .class = cid });
            },
            'n' => return self.emitSingle(.{ .literal = '\n' }),
            'r' => return self.emitSingle(.{ .literal = '\r' }),
            't' => return self.emitSingle(.{ .literal = '\t' }),
            else => return self.emitSingle(.{ .literal = std.ascii.toLower(c) }),
        }
    }

    fn parseCharClass(self: *Parser) CompileError!Frag {
        self.pos += 1; // skip '['
        var cc: CharClass = .{};
        if (self.pos < self.src.len and self.src[self.pos] == '^') {
            cc.negated = true;
            self.pos += 1;
        }
        var first = true;
        while (self.pos < self.src.len) {
            const c = self.src[self.pos];
            if (c == ']' and !first) {
                self.pos += 1;
                const cid: u32 = @intCast(self.classes.items.len);
                try self.classes.append(self.arena, cc);
                return self.emitSingle(.{ .class = cid });
            }
            first = false;
            if (c == '\\') {
                self.pos += 1;
                if (self.pos >= self.src.len) return error.InvalidRegex;
                const esc = self.src[self.pos];
                self.pos += 1;
                switch (esc) {
                    'd', 'D', 'w', 'W', 's', 'S' => {
                        addShorthandClass(&cc, esc);
                        continue;
                    },
                    'n' => cc.setByte('\n'),
                    'r' => cc.setByte('\r'),
                    't' => cc.setByte('\t'),
                    else => cc.setByteCaseInsensitive(esc),
                }
                continue;
            }
            self.pos += 1;
            if (self.pos + 1 < self.src.len and self.src[self.pos] == '-' and self.src[self.pos + 1] != ']') {
                self.pos += 1;
                const hi = self.src[self.pos];
                self.pos += 1;
                if (hi < c) return error.InvalidRegex;
                cc.setRangeCaseInsensitive(c, hi);
            } else {
                cc.setByteCaseInsensitive(c);
            }
        }
        return error.InvalidRegex;
    }
};

fn addShorthandClass(cc: *CharClass, kind: u8) void {
    switch (kind) {
        'd' => cc.setRangeCaseInsensitive('0', '9'),
        'D' => {
            var b: u16 = 0;
            while (b < 128) : (b += 1) {
                if (b < '0' or b > '9') cc.setByte(@intCast(b));
            }
            cc.match_non_ascii = true;
        },
        'w' => {
            cc.setRangeCaseInsensitive('0', '9');
            cc.setRangeCaseInsensitive('a', 'z');
            cc.setByte('_');
        },
        'W' => {
            var b: u16 = 0;
            while (b < 128) : (b += 1) {
                if (!isWordChar(@intCast(b))) cc.setByte(@intCast(b));
            }
            cc.match_non_ascii = true;
        },
        's' => {
            for ([_]u8{ ' ', '\t', '\n', '\r', 0x0b, 0x0c }) |sp| cc.setByte(sp);
        },
        'S' => {
            var b: u16 = 0;
            while (b < 128) : (b += 1) {
                const c: u8 = @intCast(b);
                if (c != ' ' and c != '\t' and c != '\n' and c != '\r' and c != 0x0b and c != 0x0c) cc.setByte(c);
            }
            cc.match_non_ascii = true;
        },
        else => {},
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "Regex case-insensitive matching: literals, alternation, anchors, classes, quantifiers" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const r1 = try Regex.compile(arena, "leakywidget|cache");
    try testing.expect(try r1.testMatch(arena, "LeakyWidget"));
    try testing.expect(try r1.testMatch(arena, "SubCache"));
    try testing.expect(!try r1.testMatch(arena, "Array"));

    const r2 = try Regex.compile(arena, "^detached\\s+html(div|span)element$");
    try testing.expect(try r2.testMatch(arena, "Detached HTMLSpanElement"));
    try testing.expect(!try r2.testMatch(arena, "HTMLSpanElement"));

    const r3 = try Regex.compile(arena, "widget-[a-z]{3,5}\\d+");
    try testing.expect(try r3.testMatch(arena, "my-widget-Alpha42!"));
    try testing.expect(!try r3.testMatch(arena, "widget-ab42"));

    try testing.expectError(error.InvalidRegex, Regex.compile(arena, "[unterminated"));
    try testing.expectError(error.InvalidRegex, Regex.compile(arena, "(unclosed"));
}
