//! Server Timing §2: parse response metrics; strings in the result are owned.
//!
//! Browser behavior takes precedence over the draft's incomplete parser:
//! HTTP tokens delimit names and unquoted values, parameters are ASCII
//! case-insensitive, and the first occurrence wins even when it is invalid.
//! Design: Blink ParseServerTimingHeader, HeaderFieldTokenizer and
//! ServerTimingHeader::SetParameter (platform/network/). WPT's 85 parsing
//! fixtures pass in Chrome/Firefox; Safari differs on five assertions.

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

pub const Metric = struct {
    name: []const u8,
    duration: f64 = 0,
    description: []const u8 = "",

    fn free(self: Metric, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
    }
};

pub fn deinit(allocator: Allocator, metrics: []Metric) void {
    for (metrics) |metric| metric.free(allocator);
    allocator.free(metrics);
}

pub fn clone(allocator: Allocator, metrics: []const Metric) ![]Metric {
    const copy = try allocator.alloc(Metric, metrics.len);
    var initialized: usize = 0;
    errdefer {
        for (copy[0..initialized]) |metric| metric.free(allocator);
        allocator.free(copy);
    }
    for (metrics, copy) |metric, *out| {
        const name = try allocator.dupe(u8, metric.name);
        errdefer allocator.free(name);
        out.* = .{ .name = name, .duration = metric.duration, .description = try allocator.dupe(u8, metric.description) };
        initialized += 1;
    }
    return copy;
}

/// Fetch's header values are byte sequences. Descriptions are isomorphic
/// decoded to UTF-8 after unquoting; metric/parameter names are ASCII tokens.
pub fn parse(allocator: Allocator, headers: []const []const u8) ![]Metric {
    var metrics: std.ArrayListUnmanaged(Metric) = .empty;
    errdefer {
        for (metrics.items) |metric| metric.free(allocator);
        metrics.deinit(allocator);
    }
    for (headers) |header| {
        var cursor = Cursor{ .text = header };
        cursor.whitespace();
        while (cursor.token()) |name| {
            var metric = Metric{ .name = try allocator.dupe(u8, name) };
            errdefer metric.free(allocator);
            var have_duration = false;
            var have_description = false;
            cursor.skipJunk();
            while (cursor.consume(';')) {
                const parameter = cursor.token() orelse break;
                var value: []const u8 = "";
                var unquoted: std.ArrayListUnmanaged(u8) = .empty;
                defer unquoted.deinit(allocator);
                if (cursor.consume('=')) {
                    value = try cursor.value(allocator, &unquoted);
                    cursor.skipJunk();
                }
                if (std.ascii.eqlIgnoreCase(parameter, "dur") and !have_duration) {
                    have_duration = true;
                    metric.duration = duration(value);
                } else if (std.ascii.eqlIgnoreCase(parameter, "desc") and !have_description) {
                    have_description = true;
                    metric.description = try infra.bytes.isomorphicDecodeToUtf8(allocator, value);
                }
            }
            try metrics.append(allocator, metric);
            if (!cursor.consume(',')) break;
        }
    }
    return metrics.toOwnedSlice(allocator);
}

const Cursor = struct {
    text: []const u8,
    at: usize = 0,

    fn whitespace(self: *Cursor) void {
        while (self.at < self.text.len and (self.text[self.at] == ' ' or self.text[self.at] == '\t')) self.at += 1;
    }

    fn consume(self: *Cursor, character: u8) bool {
        if (self.at == self.text.len or self.text[self.at] != character) return false;
        self.at += 1;
        self.whitespace();
        return true;
    }

    fn token(self: *Cursor) ?[]const u8 {
        const start = self.at;
        while (self.at < self.text.len and isToken(self.text[self.at])) self.at += 1;
        if (start == self.at) return null;
        const result = self.text[start..self.at];
        self.whitespace();
        return result;
    }

    fn skipJunk(self: *Cursor) void {
        while (self.at < self.text.len and self.text[self.at] != ';' and self.text[self.at] != ',') self.at += 1;
    }

    fn value(self: *Cursor, allocator: Allocator, unquoted: *std.ArrayListUnmanaged(u8)) ![]const u8 {
        if (self.at == self.text.len) return "";
        if (self.text[self.at] != '"') return self.token() orelse "";
        self.at += 1;
        while (self.at < self.text.len) {
            var character = self.text[self.at];
            self.at += 1;
            if (character == '"') {
                self.whitespace();
                return unquoted.items;
            }
            if (character == '\\') {
                if (self.at == self.text.len) return "";
                character = self.text[self.at];
                self.at += 1;
            }
            try unquoted.append(allocator, character);
        }
        // An unterminated quoted string has no value, not a partial one.
        return "";
    }
};

fn isToken(character: u8) bool {
    return std.ascii.isAlphanumeric(character) or switch (character) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        else => false,
    };
}

fn duration(value: []const u8) f64 {
    // Decimal only: parseFloat also accepts Zig's hexadecimal/underscore
    // forms, which are not Server-Timing numbers. The whole value must parse.
    if (value.len == 0) return 0;
    for (value) |character| switch (character) {
        '0'...'9', '+', '-', '.', 'e', 'E' => {},
        else => return 0,
    };
    const number = std.fmt.parseFloat(f64, value) catch return 0;
    return if (std.math.isFinite(number)) number else 0;
}
