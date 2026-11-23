//! Pointer Events touch-action (lane maj1): auto | none | [ pan-x || pan-y
//! || pinch-zoom ] | manipulation, not inherited, initial auto. A
//! combination serializes in the canonical order pan-x pan-y pinch-zoom
//! (pointerevents/parsing/touch-action-valid.html: "pan-y pan-x" reads back
//! "pan-x pan-y" in Chrome, Firefox and Safari).
//!
//! Golden rule 2: Pointer Events 3 §11.1 also lists pan-left, pan-right,
//! pan-up and pan-down, which Chrome alone ships (css-typed-om
//! the-stylepropertymap/properties/touch-action.html "Can set 'touch-action'
//! to the 'pan-left' keyword": Chrome PASS, Safari FAIL, Firefox no such
//! property); the majority takes them as invalid. pinch-zoom is Chrome's and
//! Safari's.
const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const values = @import("style_values.zig");

const Value = values.Value;
const Keyword = values.Keyword;

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (properties.takeKeyword(stream, &.{ .auto, .none, .manipulation })) |k| return Value.kw(k);
    const order = [_]Keyword{ .pan_x, .pan_y, .pinch_zoom };
    var seen = [_]bool{ false, false, false };
    var count: usize = 0;
    while (properties.takeKeyword(stream, &order)) |k| {
        const i = std.mem.indexOfScalar(Keyword, &order, k).?;
        if (seen[i]) return null;
        seen[i] = true;
        count += 1;
    }
    if (count == 0) return null;
    if (count == 1) {
        for (order, seen) |k, s| {
            if (s) return Value.kw(k);
        }
    }
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(options.allocator);
    for (order, seen) |k, s| {
        if (!s) continue;
        if (text.items.len != 0) try text.append(options.allocator, ' ');
        try text.appendSlice(options.allocator, k.name());
    }
    return .{ .text = try values.SharedText.create(options.allocator, text.items) };
}
