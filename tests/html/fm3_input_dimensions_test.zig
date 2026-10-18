const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const fixture = @import("fm3_fixture.zig");
const create = fixture.create;
const attribute = fixture.attribute;

fn exercise(document: *runtime.Instance) !void {
    const input = try create(document, "input");
    defer dom.node_creation.destroyUninserted(input);
    try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("image"));
    const cases = [_]struct { []const u8, u32 }{
        .{ "30", 30 },     .{ " +10px", 10 },             .{ "-0.5", 0 },
        .{ "50%", 50 },    .{ "2147483647", 2147483647 }, .{ "-10", 0 },
        .{ "invalid", 0 },
    };
    for (cases) |case| {
        try attribute(input, "width", case[0]);
        try attribute(input, "height", case[0]);
        try testing.expectEqual(case[1], try interfaces.HTMLInputElement.get_width(input));
        try testing.expectEqual(case[1], try interfaces.HTMLInputElement.get_height(input));
    }
    try attribute(input, "width", "30");
    try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("text"));
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLInputElement.get_width(input));
}

test "image input dimensions parse attributes without an image" {
    try fixture.run(exercise);
}
