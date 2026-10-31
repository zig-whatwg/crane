//! CSS Counter Styles 3 §4: one symbols() grammar for its two consumers.
const std = @import("std");
const tokens = @import("tokenizer.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const Allocator = std.mem.Allocator;

/// An adapter returns one owned, already serialized string or image.
/// URL ranges are relative to text; image holds any separate typed owner.
pub const Symbol = struct {
    text: []const u8,
    image_symbol: bool = false,
    resource_urls: []const resources.ResourceUrl = &.{},
    image: ?values.Value = null,

    pub fn deinit(self: Symbol, allocator: Allocator) void {
        if (self.image) |image| image.release();
        resources.releaseAll(allocator, self.resource_urls);
        allocator.free(self.text);
    }
};

pub const Symbols = struct {
    text: []u8,
    resource_urls: []const resources.ResourceUrl,

    pub fn deinit(self: Symbols, allocator: Allocator) void {
        resources.releaseAll(allocator, self.resource_urls);
        allocator.free(self.text);
    }
};

/// The function name was consumed; the reader owns its tokenizer and supplies
/// take/peek/next/closeFunction/symbol. Content retains its existing images;
/// list-style-type uses shipping string-only symbols (liaison ANSWER Q6).
pub fn consumeSymbols(allocator: Allocator, comptime images: bool, reader: anytype) Allocator.Error!?Symbols {
    if (!reader.take(.left_paren)) return null;
    var system: []const u8 = "symbolic";
    if (reader.peek().token_type == .ident) {
        const token = reader.next();
        const decoded = try tokens.decode(allocator, token.value);
        defer allocator.free(decoded);
        var valid = false;
        inline for (.{ "cyclic", "numeric", "alphabetic", "symbolic", "fixed" }) |candidate| {
            if (std.ascii.eqlIgnoreCase(decoded, candidate)) {
                system = candidate;
                valid = true;
            }
        }
        if (!valid) return null;
    }
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var urls = resources.Builder{ .allocator = allocator };
    defer urls.deinit();
    try out.appendSlice(allocator, "symbols(");
    if (!std.mem.eql(u8, system, "symbolic")) {
        try out.appendSlice(allocator, system);
        try out.append(allocator, ' ');
    }
    var count: usize = 0;
    while (!reader.closeFunction()) {
        const symbol = try reader.symbol() orelse return null;
        defer symbol.deinit(allocator);
        if (!images and symbol.image_symbol) return null;
        if (count != 0) try out.append(allocator, ' ');
        try urls.append(symbol.resource_urls, out.items.len);
        try out.appendSlice(allocator, symbol.text);
        count += 1;
    }
    // §4: numeric and alphabetic need at least two symbols; every other
    // system needs one. Omitting the system means symbolic, not cyclic.
    if (count == 0 or (count < 2 and (std.mem.eql(u8, system, "numeric") or std.mem.eql(u8, system, "alphabetic")))) return null;
    try out.append(allocator, ')');
    const text = try out.toOwnedSlice(allocator);
    errdefer allocator.free(text);
    return .{ .text = text, .resource_urls = try urls.take() };
}
