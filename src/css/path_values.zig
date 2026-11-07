//! CSS Shapes §3.1 path(): validate a whole SVG path before serialization.
//! SVG2 §9.3.9; design reference: Blink SVGPathStringSource::ParseSegment.
const std = @import("std");
const values = @import("style_values.zig");
const Allocator = std.mem.Allocator;

/// No units or colors need computation: canonical path text is immutable data.
/// CSS path() rejects the whole string on error, unlike SVG rendering's prefix.
pub fn parse(allocator: Allocator, input: []const u8) Allocator.Error!?*values.SharedText {
    var stream = Stream{ .input = input };
    stream.whitespace();
    if (stream.atEnd() or (input[stream.index] != 'M' and input[stream.index] != 'm')) return null;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var previous: u8 = 0;
    while (!stream.atEnd()) {
        const token = input[stream.index];
        var command: u8 = token;
        if (arity(token) != null) {
            stream.index += 1;
            stream.whitespace();
        } else {
            if (previous == 0 or previous == 'Z' or !numberStart(token)) return null;
            command = switch (previous) {
                'M' => 'L',
                'm' => 'l',
                else => previous,
            };
        }
        const count = arity(command) orelse return null;
        if (out.items.len > 0) try out.append(allocator, ' ');
        try out.append(allocator, if (command == 'z') 'Z' else command);
        for (0..count) |i| {
            if (i > 0) stream.separator();
            const n = if ((command == 'A' or command == 'a') and (i == 3 or i == 4)) stream.flag() else stream.number();
            try out.append(allocator, ' ');
            try values.appendNumber(n orelse return null, &out, allocator);
        }
        previous = if (command == 'z') 'Z' else command;
        stream.whitespace();
        if (!stream.atEnd() and input[stream.index] == ',') {
            if (count == 0) return null;
            stream.index += 1;
            stream.whitespace();
            // Commas separate parameters, never commands or end of input.
            if (stream.atEnd() or !numberStart(input[stream.index])) return null;
        }
    }
    return try values.SharedText.create(allocator, out.items);
}

fn arity(command: u8) ?usize {
    return switch (command) {
        'M', 'm', 'L', 'l', 'T', 't' => 2,
        'Z', 'z' => 0,
        'H', 'h', 'V', 'v' => 1,
        'C', 'c' => 6,
        'S', 's', 'Q', 'q' => 4,
        'A', 'a' => 7,
        else => null,
    };
}
fn numberStart(c: u8) bool {
    return std.ascii.isDigit(c) or c == '+' or c == '-' or c == '.';
}

const Stream = struct {
    input: []const u8,
    index: usize = 0,
    fn atEnd(self: Stream) bool {
        return self.index == self.input.len;
    }
    fn whitespace(self: *Stream) void {
        while (!self.atEnd() and switch (self.input[self.index]) {
            ' ', '\t', '\n', '\r', 0x0c => true,
            else => false,
        }) self.index += 1;
    }
    fn separator(self: *Stream) void {
        self.whitespace();
        if (!self.atEnd() and self.input[self.index] == ',') {
            self.index += 1;
            self.whitespace();
        }
    }
    fn flag(self: *Stream) ?f64 {
        if (self.atEnd()) return null;
        const c = self.input[self.index];
        if (c != '0' and c != '1') return null;
        self.index += 1;
        return @floatFromInt(c - '0');
    }
    fn number(self: *Stream) ?f64 {
        const start = self.index;
        if (!self.atEnd() and (self.input[self.index] == '+' or self.input[self.index] == '-')) self.index += 1;
        const integer_start = self.index;
        while (!self.atEnd() and std.ascii.isDigit(self.input[self.index])) self.index += 1;
        var digits = self.index - integer_start;
        if (!self.atEnd() and self.input[self.index] == '.') {
            self.index += 1;
            const fraction_start = self.index;
            while (!self.atEnd() and std.ascii.isDigit(self.input[self.index])) self.index += 1;
            if (self.index == fraction_start) return null;
            digits += self.index - fraction_start;
        }
        if (digits == 0) return null;
        if (!self.atEnd() and (self.input[self.index] == 'e' or self.input[self.index] == 'E')) {
            self.index += 1;
            if (!self.atEnd() and (self.input[self.index] == '+' or self.input[self.index] == '-')) self.index += 1;
            const exponent_start = self.index;
            while (!self.atEnd() and std.ascii.isDigit(self.input[self.index])) self.index += 1;
            if (self.index == exponent_start) return null;
        }
        const result = std.fmt.parseFloat(f64, self.input[start..self.index]) catch return null;
        return if (std.math.isFinite(result)) result else null;
    }
};

/// One segment of canonical path text in absolute coordinates.
pub const Segment = struct {
    /// The command letter: M, L, H, V, C, S, Q, T, A or Z (lower case for a
    /// relative command read by Reader; always upper case from Absolutizer).
    command: u8,
    /// The parameters, `count` of them, in the command's order; the arc
    /// flags (A's fourth and fifth) are 0 or 1.
    args: [7]f64 = undefined,
    count: usize = 0,
};

/// Canonical, already-validated path text, one segment at a time as
/// written: the command letter keeps its case (relative commands stay
/// relative).
pub const Reader = struct {
    stream: Stream,

    pub fn init(input: []const u8) Reader {
        return .{ .stream = .{ .input = input } };
    }

    /// The next segment, its command letter as written; null at the end.
    pub fn next(self: *Reader) ?Segment {
        if (self.stream.atEnd()) return null;
        const input = self.stream.input;
        const command = input[self.stream.index];
        self.stream.index += 1;
        const absolute = std.ascii.toUpper(command);
        const count = arity(command).?;
        var segment: Segment = .{ .command = command, .count = count };
        for (segment.args[0..count], 0..) |*arg, i| {
            self.stream.separator();
            arg.* = (if (absolute == 'A' and (i == 3 or i == 4)) self.stream.flag() else self.stream.number()).?;
        }
        self.stream.whitespace();
        return segment;
    }
};

/// SVG2 §§9.3.1, 9.3.3–9.3.9: canonical, already-validated path text as
/// absolute segments. Design reference: Blink SVGPathAbsolutizer::EmitSegment.
/// Every relative point uses the segment's initial current point; close
/// restores its subpath.
pub const Absolutizer = struct {
    reader: Reader,
    current: [2]f64 = .{ 0, 0 },
    subpath: [2]f64 = .{ 0, 0 },

    pub fn init(input: []const u8) Absolutizer {
        return .{ .reader = .init(input) };
    }

    /// The next segment, its command letter upper case; null at the end.
    /// error.NonFinite when a finite relative input produces a non-finite
    /// absolute sum (Q50).
    pub fn next(self: *Absolutizer) error{NonFinite}!?Segment {
        var segment = self.reader.next() orelse return null;
        const command = segment.command;
        const absolute = std.ascii.toUpper(command);
        const count = segment.count;
        const args = &segment.args;
        segment.command = absolute;
        if (std.ascii.isLower(command)) {
            switch (absolute) {
                'H' => args[0] += self.current[0],
                'V' => args[0] += self.current[1],
                'A' => {
                    args[5] += self.current[0];
                    args[6] += self.current[1];
                },
                else => for (args[0..count], 0..) |*arg, i| {
                    arg.* += self.current[i % 2];
                },
            }
            for (args[0..count]) |arg| {
                if (!std.math.isFinite(arg)) return error.NonFinite;
            }
        }
        switch (absolute) {
            'Z' => self.current = self.subpath,
            'H' => self.current[0] = args[0],
            'V' => self.current[1] = args[0],
            else => {
                self.current = .{ args[count - 2], args[count - 1] };
                if (absolute == 'M') self.subpath = self.current;
            },
        }
        return segment;
    }
};

/// One segment as canonical path text: the command letter, then each
/// parameter after a space.
pub fn appendSegment(segment: Segment, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.append(allocator, segment.command);
    for (segment.args[0..segment.count]) |arg| {
        try out.append(allocator, ' ');
        try values.appendNumber(arg, out, allocator);
    }
}

/// Canonical path text with every segment absolute.
/// Q50: if a finite input produces a non-finite sum, preserve the WHOLE input.
pub fn serializeAbsolute(input: []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var converted: std.ArrayList(u8) = .empty;
    defer converted.deinit(allocator);
    var segments = Absolutizer.init(input);
    while (segments.next() catch return out.appendSlice(allocator, input)) |segment| {
        if (converted.items.len > 0) try converted.append(allocator, ' ');
        try appendSegment(segment, &converted, allocator);
    }
    try out.appendSlice(allocator, converted.items);
}
