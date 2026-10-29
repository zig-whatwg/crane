//! CSS Scroll Snap 1 §§4.1 and 5.2: canonical keyword-only pairs.
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const Keyword = values.Keyword;
const Value = values.Value;
const Stream = properties.Stream;

fn take(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| {
        if (tokens.nameEql(token.value, candidate.name())) {
            _ = stream.next();
            return candidate;
        }
    }
    return null;
}

pub fn consume(longhand: properties.Longhand, stream: *Stream) ?Value {
    return switch (longhand) {
        .scroll_snap_type => snapType(stream),
        .scroll_snap_align => snapAlign(stream),
        else => unreachable,
    };
}

fn snapType(stream: *Stream) ?Value {
    // §4.1: none | [ x | y | block | inline | both | pair ]
    // [ mandatory | proximity ]?. Proximity is the omitted strictness.
    // Q7: pair is a newer WG-approved value; unsupported engines lag.
    if (take(stream, &.{.none})) |single| return Value.kw(single);
    const axis = take(stream, &.{ .x, .y, .block, .@"inline", .both, .pair }) orelse return null;
    const strictness = take(stream, &.{ .mandatory, .proximity }) orelse .proximity;
    if (strictness == .proximity) return Value.kw(axis);
    return .{ .box_keywords = .{ .first = axis, .second = strictness } };
}

fn snapAlign(stream: *Stream) ?Value {
    // §5.2: [none | start | end | center]{1,2}. An omitted second axis
    // duplicates the first; CSSOM omits that repeated keyword.
    const allowed: []const Keyword = &.{ .none, .start, .end, .center };
    const first = take(stream, allowed) orelse return null;
    const second = take(stream, allowed) orelse first;
    if (first == second) return Value.kw(first);
    return .{ .box_keywords = .{ .first = first, .second = second } };
}
