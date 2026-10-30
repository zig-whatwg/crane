//! Integrator Q56: pin the explicit canonical-text reconstruction exception.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Case = struct { grammar: []const u8, input: []const u8, computed: []const u8, count: usize = 1 };
const cases = [_]Case{
    .{ .grammar = "<length>", .input = "2em", .computed = "20px" },
    // Values 4, sort a calculation's children steps3-4: percentage terms precede dimensions (Q100).
    .{ .grammar = "<length-percentage>", .input = "calc(2em + 25%)", .computed = "calc(25% + 20px)" },
    .{ .grammar = "<number>", .input = "calc(1 / 2)", .computed = "0.5" },
    .{ .grammar = "<integer>", .input = "calc(3.5)", .computed = "4" },
    .{ .grammar = "<percentage>", .input = "25%", .computed = "25%" },
    .{ .grammar = "<color>", .input = "red", .computed = "rgb(255, 0, 0)" },
    .{ .grammar = "<image>", .input = "linear-gradient(red, blue)", .computed = "linear-gradient(rgb(255, 0, 0), rgb(0, 0, 255))" },
    .{ .grammar = "<url>", .input = "url(https://example.test/a.png)", .computed = "url(\"https://example.test/a.png\")" },
    .{ .grammar = "<custom-ident>", .input = "foo\\ bar", .computed = "foo\\ bar" },
    .{ .grammar = "<transform-function>", .input = "translateX(2em)", .computed = "translateX(20px)" },
    .{ .grammar = "<transform-list>", .input = "translateX(2em) rotate(1turn)", .computed = "translateX(20px) rotate(360deg)", .count = 2 },
    .{ .grammar = "<angle>", .input = "1turn", .computed = "360deg" },
    .{ .grammar = "<time>", .input = "500ms", .computed = "0.5s" },
    .{ .grammar = "<resolution>", .input = "96dpi", .computed = "1dppx" },
    .{ .grammar = "<length>+", .input = "1in 2em", .computed = "96px 20px", .count = 2 },
    .{ .grammar = "<length>#", .input = "1in, 2em", .computed = "96px, 20px", .count = 2 },
    .{ .grammar = "<custom-ident>#", .input = "foo, --bar", .computed = "foo, --bar", .count = 2 },
    .{ .grammar = "*", .input = "foo /* retained */  bar", .computed = "foo /* retained */  bar" },
};

fn roundTrip(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "registered_values")) return std.testing.expect(false);
    var definition = try css.syntax_definitions.parse(allocator, case.grammar);
    defer definition.deinit();
    var specified = (try definition.parseValue(.{ .allocator = allocator }, case.input)) orelse return error.TestExpectedValue;
    defer specified.deinit();
    var computed = try specified.compute(allocator, .{ .math = .{ .font_size = 10, .root_font_size = 16 } });
    defer computed.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try computed.serialize(&text, allocator);
    try std.testing.expectEqualStrings(case.computed, text.items);
    const owner = (try css.typed_om.registered_values.parseComputed(.{ .allocator = allocator }, &definition, text.items)) orelse return error.TestExpectedValue;
    defer owner.release();
    try std.testing.expectEqual(case.count, owner.count());
    try std.testing.expectEqual(std.meta.activeTag(computed.data), std.meta.activeTag(owner.value.data));
    if (computed.data == .list) try std.testing.expectEqual(computed.data.list.separator, owner.value.data.list.separator);
    var after: std.ArrayList(u8) = .empty;
    defer after.deinit(allocator);
    try owner.value.serialize(&after, allocator);
    try std.testing.expectEqualStrings(text.items, after.items);
    for (0..case.count) |index| {
        const before: ?css.syntax_values.Item = switch (computed.data) {
            .universal => null,
            .single => |item| item,
            .list => |list| list.items[index],
        };
        const result = owner.item(index);
        if (before) |item| {
            const other = result orelse return error.TestExpectedValue;
            try std.testing.expectEqual(std.meta.activeTag(item), std.meta.activeTag(other));
            switch (item) {
                .numeric => |n| {
                    try std.testing.expectEqual(n.data_type, other.numeric.data_type);
                    try std.testing.expectEqual(std.meta.activeTag(n.number), std.meta.activeTag(other.numeric.number));
                    switch (n.number) {
                        .literal => |literal| {
                            try std.testing.expectEqual(literal.unit, other.numeric.number.literal.unit);
                            try std.testing.expectEqual(literal.value, other.numeric.number.literal.value);
                        },
                        .calculation => |expression| try std.testing.expect(expression.typ.eql(other.numeric.number.calculation.typ)),
                    }
                },
                .ident => |ident| try std.testing.expectEqualStrings(ident, other.ident),
                .string => |string| try std.testing.expectEqualStrings(string, other.string),
                .url, .image => |resource| {
                    const rebuilt = if (other == .url) other.url else other.image;
                    const urls = resource.value.resourceUrls();
                    const rebuilt_urls = rebuilt.value.resourceUrls();
                    try std.testing.expectEqual(urls.len, rebuilt_urls.len);
                    for (urls, rebuilt_urls) |url, rebuilt_url| try std.testing.expectEqualStrings(url.url, rebuilt_url.url);
                },
                .transform => |transform| try std.testing.expectEqual(transform.kind, other.transform.kind),
                .color => {}, // Both use the existing color tree; serialized canonical channels are pinned above.
            }
        } else try std.testing.expect(result == null);
    }
    owner.retain();
    owner.release();
}

test "every registered syntax component and repetition round trips through the existing parser" {
    for (cases) |case| try roundTrip(a, case);
}

test "registered computed value reconstruction owns every component at every allocation failure" {
    for (cases) |case| try std.testing.checkAllAllocationFailures(a, roundTrip, .{case});
}
