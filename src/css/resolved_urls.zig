//! CSS Values4 §4.5 / CSSOM serialize-a-URL: replace only frozen URL spans.
//! Specified text stays authored; this module never parses or resolves URLs.
//! Design: Blink CSSUrlData separates relative_url_ from absolute_url_ and
//! MakeComputed preserves local/empty URLs. No engine implementation copied.
const std = @import("std");
const resources = @import("resource_values.zig");
const values = @import("style_values.zig");
const properties = @import("properties.zig");
const Allocator = std.mem.Allocator;

/// Append computed CSS, retaining modifiers, string-option form and every
/// non-URL span. Both text and metadata are borrowed for this call only.
pub fn append(text: []const u8, urls: []const resources.ResourceUrl, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var cursor: usize = 0;
    var previous_end: usize = 0;
    for (urls) |url| {
        std.debug.assert(url.range.start >= previous_end);
        std.debug.assert(url.range.start <= url.range.end and url.range.end <= text.len);
        previous_end = url.range.end;
        const replacement = url.argument_range orelse url.range;
        std.debug.assert(replacement.start >= url.range.start and replacement.end <= url.range.end);
        std.debug.assert(replacement.start <= replacement.end);
        // Values4 §4.5.1.1: local URLs serialize as just their fragment.
        // §4.5.2: empty/failed URLs retain their specified invalid spelling.
        if (url.local_fragment or !url.valid) continue;
        try out.appendSlice(allocator, text[cursor..replacement.start]);
        if (url.argument_range == null) try out.appendSlice(allocator, "url(");
        try values.appendString(url.url, out, allocator);
        if (url.argument_range == null) try out.append(allocator, ')');
        cursor = replacement.end;
    }
    try out.appendSlice(allocator, text[cursor..]);
}

/// Aggregates that resolve another component while serializing (paint and
/// filter currentcolor) call this at each URL leaf, before offsets can shift.
pub fn serialize(longhand: properties.Longhand, value: values.Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const text = switch (value) {
        .text => |v| v.bytes,
        .content => |v| v.serialization,
        .cursor => |v| v.text.bytes,
        .layers => |v| v.text.bytes,
        .image => |v| v.text.bytes,
        else => return properties.serializeValue(longhand, value, out, allocator),
    };
    try append(text, value.resourceUrls(), out, allocator);
}
