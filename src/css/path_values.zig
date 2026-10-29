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

/// SVG2 §§9.3.1, 9.3.3–9.3.9: resolve canonical, already-validated path text.
/// Design reference: Blink SVGPathAbsolutizer::EmitSegment. Every relative
/// point uses the segment's initial current point; close restores its subpath.
/// Q50: if a finite input produces a non-finite sum, preserve the WHOLE input.
pub fn serializeAbsolute(input: []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var converted: std.ArrayList(u8) = .empty;
    defer converted.deinit(allocator);
    var stream = Stream{ .input = input };
    var current: [2]f64 = .{ 0, 0 };
    var subpath: [2]f64 = .{ 0, 0 };
    while (!stream.atEnd()) {
        const command = input[stream.index];
        stream.index += 1;
        const absolute = std.ascii.toUpper(command);
        const count = arity(command).?;
        var args: [7]f64 = undefined;
        for (args[0..count], 0..) |*arg, i| {
            stream.separator();
            arg.* = (if (absolute == 'A' and (i == 3 or i == 4)) stream.flag() else stream.number()).?;
        }
        if (std.ascii.isLower(command)) {
            switch (absolute) {
                'H' => args[0] += current[0],
                'V' => args[0] += current[1],
                'A' => {
                    args[5] += current[0];
                    args[6] += current[1];
                },
                else => for (args[0..count], 0..) |*arg, i| {
                    arg.* += current[i % 2];
                },
            }
            for (args[0..count]) |arg| {
                if (!std.math.isFinite(arg)) return out.appendSlice(allocator, input);
            }
        }
        switch (absolute) {
            'Z' => current = subpath,
            'H' => current[0] = args[0],
            'V' => current[1] = args[0],
            else => {
                current = .{ args[count - 2], args[count - 1] };
                if (absolute == 'M') subpath = current;
            },
        }
        if (converted.items.len > 0) try converted.append(allocator, ' ');
        try converted.append(allocator, absolute);
        for (args[0..count]) |arg| {
            try converted.append(allocator, ' ');
            try values.appendNumber(arg, &converted, allocator);
        }
        stream.whitespace();
    }
    try out.appendSlice(allocator, converted.items);
}
