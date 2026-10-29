//! Scratch bounds for computed shorthand serialization exclude `all`.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const properties = css.properties;

// Select the existing caller's bound until the separate bound is introduced:
// the first native run must fail its capacity assertion, not fail to compile.
const capacity = if (@hasDecl(properties, "max_non_all_assignments"))
    properties.max_non_all_assignments
else
    properties.max_assignments;

test "computed shorthand scratch capacity is independent of the all expansion" {
    // font is the largest current non-all shorthand, including its reset-only
    // components. Keep the expected footprint explicit when this set grows.
    try testing.expectEqual(@as(usize, 19), capacity);
    try testing.expectEqual(properties.Shorthand.font.longhands().len, capacity);
    try testing.expect(capacity < properties.max_assignments);
    try testing.expectEqual(properties.Longhand.count - 2, properties.max_assignments);
}

test "computed shorthand scratch capacity covers every eligible shorthand" {
    inline for (std.meta.tags(properties.Shorthand)) |shorthand| {
        if (shorthand != .all)
            try testing.expect(shorthand.longhands().len <= capacity);
    }
    try testing.expectEqual(properties.max_assignments, properties.Shorthand.all.longhands().len);
}
