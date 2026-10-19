//! A request's header list as the HTTP cache sees it: httpRequest's - the
//! request's own list (`author`) followed by what HTTP-network-or-cache fetch
//! appends to the request it sends (`added`: Origin, User-Agent, Cookie...;
//! Fetch 4.6 steps 8.7-8.21), or the NetworkRequest's whole list (`added`
//! alone), which is both. Read in place, never copied: a lookup allocates
//! nothing.
//!
//! RFC 9111 4.1 compares the request fields a stored response's Vary names
//! "after any normalization": whitespace around values is dropped and
//! several lines of one name combine with ", " (RFC 9110 5.2), so a field
//! sent as two lines matches the same field sent as one.

const std = @import("std");
const Allocator = std.mem.Allocator;
const HeaderListHeader = @import("../internal/header_list.zig").Header;
const NetworkHeader = @import("../network/backend.zig").NetworkRequest.Header;

pub const HeaderView = struct {
    author: []const HeaderListHeader = &.{},
    added: []const NetworkHeader = &.{},

    /// Whether any line is named `name`.
    pub fn contains(self: HeaderView, name: []const u8) bool {
        var lines = self.iterate(name);
        return lines.next() != null;
    }

    /// The first line named `name`, as sent.
    pub fn first(self: HeaderView, name: []const u8) ?[]const u8 {
        var lines = self.iterate(name);
        return lines.next();
    }

    /// The lines named `name` as one list value: every comma-separated
    /// element of every line, trimmed, empty ones dropped, joined with ", ".
    /// Null when there is no line. OWNED.
    pub fn combined(self: HeaderView, allocator: Allocator, name: []const u8) Allocator.Error!?[]u8 {
        if (!self.contains(name)) return null;
        var out: std.ArrayListUnmanaged(u8) = .empty;
        errdefer out.deinit(allocator);
        var elements: Elements = .{ .lines = self.iterate(name) };
        while (elements.next()) |element| {
            if (out.items.len > 0) try out.appendSlice(allocator, ", ");
            try out.appendSlice(allocator, element);
        }
        return try out.toOwnedSlice(allocator);
    }

    /// Whether the lines named `name` equal `expected` as lists - element by
    /// element, whitespace around them and empty ones aside - null meaning
    /// absent, which matches only absent (RFC 9111 4.1). Allocates nothing.
    pub fn matches(self: HeaderView, name: []const u8, expected: ?[]const u8) bool {
        const want = expected orelse return !self.contains(name);
        if (!self.contains(name)) return false;
        var presented: Elements = .{ .lines = self.iterate(name) };
        var stored: Elements = .{ .lines = .{ .view = .{}, .name = name }, .line = want, .pending = true };
        while (true) {
            const a = presented.next();
            const b = stored.next();
            if (a == null or b == null) return a == null and b == null;
            if (!std.mem.eql(u8, a.?, b.?)) return false;
        }
    }

    /// The comma-separated elements of a run of lines, trimmed, empty ones
    /// skipped.
    const Elements = struct {
        lines: Lines,
        line: []const u8 = "",
        pending: bool = false,

        fn next(self: *Elements) ?[]const u8 {
            while (true) {
                if (!self.pending) {
                    self.line = self.lines.next() orelse return null;
                    self.pending = true;
                }
                const comma = std.mem.indexOfScalar(u8, self.line, ',');
                const element = trim(self.line[0 .. comma orelse self.line.len]);
                if (comma) |c| self.line = self.line[c + 1 ..] else self.pending = false;
                if (element.len > 0) return element;
            }
        }
    };

    pub fn iterate(self: HeaderView, name: []const u8) Lines {
        return .{ .view = self, .name = name };
    }

    pub const Lines = struct {
        view: HeaderView,
        name: []const u8,
        index: usize = 0,

        pub fn next(self: *Lines) ?[]const u8 {
            while (self.index < self.view.author.len + self.view.added.len) {
                const i = self.index;
                self.index += 1;
                if (i < self.view.author.len) {
                    const header = self.view.author[i];
                    if (std.ascii.eqlIgnoreCase(header.name, self.name)) return header.value;
                } else {
                    const header = self.view.added[i - self.view.author.len];
                    if (std.ascii.eqlIgnoreCase(header.name, self.name)) return header.value;
                }
            }
            return null;
        }
    };
};

fn trim(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \t");
}

test "HeaderView: lines of one name combine across both lists" {
    const author = [_]HeaderListHeader{.{ .name = "Accept", .value = " a " }};
    const added = [_]NetworkHeader{ .{ .name = "x", .value = "1" }, .{ .name = "accept", .value = "b" } };
    const view: HeaderView = .{ .author = &author, .added = &added };
    const value = (try view.combined(std.testing.allocator, "ACCEPT")).?;
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings("a, b", value);
    try std.testing.expect(view.matches("Accept", "a, b"));
    try std.testing.expect(view.matches("Accept", "a,b"));
    try std.testing.expect(view.matches("Accept", " a ,, b"));
    try std.testing.expect(!view.matches("Accept", "a"));
    try std.testing.expect(!view.matches("Accept", "a, b, c"));
    try std.testing.expect(!view.matches("Accept", null));
    try std.testing.expect(view.matches("Missing", null));
    try std.testing.expect(!view.matches("Missing", ""));
}
