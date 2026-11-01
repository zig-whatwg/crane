//! Lists3 §4.7 / Counter Styles3 §2.1: none is not a counter-style name.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const a = std.testing.allocator;

const invalid = .{
    "counter(foo, none)",
    "counters(foo, \"\", none)",
    "\"z\" counter(foo, none)",
    "\"z\" counters(foo, \"\", none)",
    "counter(foo, none) \"z\"",
    "counters(foo, \"\", none) \"z\"",
    "counter(foo, NoNe)",
    "counters(foo, \".\", NONE)",
    "counter(foo, n\\6f ne)",
    "counters(foo, \".\", \\4e ONE)",
};

test "content counters reject none styles including case and identifier escapes" {
    // Row131 Q49: Firefox and Safari implement the newer grammar;
    // Chrome's six failures in content-invalid.html retain CSS2 behavior.
    inline for (invalid) |input| {
        var block = h.Block.init(a);
        defer block.deinit();
        try std.testing.expect(!try block.setProperty(.{ .allocator = a }, "content", input, ""));
        try h.specified(&block, "content", "", a);
        const style = try h.compute(a, &block, null);
        defer style.destroy();
        try h.expect(style, "content", "normal", a);
    }
}

test "content counter style rejection preserves valid names and symbols" {
    inline for (.{
        .{ "counter(foo)", "counter(foo)" },
        .{ "counter(foo, decimal)", "counter(foo)" },
        .{ "counter(foo, NoneStyle)", "counter(foo, NoneStyle)" },
        .{ "counters(foo, \".\", inside)", "counters(foo, \".\", inside)" },
        .{ "counter(foo, symbols(\"a\" \"b\"))", "counter(foo, symbols(\"a\" \"b\"))" },
    }) |item| try h.check(a, "content", item[0], item[1], false);
}

test "invalid content counter style releases every partial allocation" {
    try std.testing.checkAllAllocationFailures(a, h.check, .{ "content", "\"z\" counters(foo, \".\", n\\6f ne)", "", false });
}
