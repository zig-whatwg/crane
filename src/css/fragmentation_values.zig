//! CSS Break 3 §3.4 / Cascade 5 §3.1: page-break-* legacy shorthands.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

pub fn consume(options: properties.ParseOptions, shorthand: properties.Shorthand, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    const token = stream.next();
    if (token.token_type != .ident or !stream.atEnd()) return false;
    const keyword: values.Keyword = for ([_]values.Keyword{ .auto, .avoid, .left, .right, .always }) |candidate| {
        if (tokens.nameEql(token.value, candidate.name())) break candidate;
    } else return false;
    // CSS2 page-break-inside only accepts auto | avoid. Break3's table
    // maps before/after's always to page, and other legacy values to self.
    if (shorthand == .page_break_inside and keyword != .auto and keyword != .avoid) return false;
    const mapped: values.Keyword = if (keyword == .always) .page else keyword;
    try out.append(options.allocator, .{ .longhand = shorthand.longhands()[0], .value = .{ .value = values.Value.kw(mapped) } });
    return true;
}

pub fn serialize(shorthand: properties.Shorthand, assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (assigned.len != 1 or assigned[0] != .value or assigned[0].value != .keyword) return false;
    const keyword = assigned[0].value.keyword;
    const legacy: values.Keyword = switch (keyword) {
        .auto, .avoid => keyword,
        .left, .right => if (shorthand != .page_break_inside) keyword else return false,
        .page => if (shorthand != .page_break_inside) .always else return false,
        else => return false,
    };
    // CSSOM §6.7.2: only emit a spelling whose parser reproduces the value.
    try out.appendSlice(allocator, legacy.name());
    return true;
}
