const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const fixture = @import("fm3_fixture.zig");
const create = fixture.create;
const attribute = fixture.attribute;

fn exercise(document: *runtime.Instance) !void {
    inline for (.{ .{ "input", interfaces.HTMLInputElement }, .{ "textarea", interfaces.HTMLTextAreaElement } }) |control| {
        const element = try create(document, control[0]);
        defer dom.node_creation.destroyUninserted(element);
        const cases = [_]struct { []const u8, []const u8 }{
            .{ " \tON\r\n", "on" },                                                                      .{ "WEBAUTHN", "webauthn" },
            .{ " HOME\ntel", "home tel" },                                                               .{ "section- bday", "section- bday" },
            .{ "section-LOGIN shipping work tel webauthn", "section-login shipping work tel webauthn" }, .{ "home country", "" },
            .{ "on webauthn", "" },                                                                      .{ "section-foo webauthn", "" },
        };
        for (cases) |case| {
            try attribute(element, "autocomplete", case[0]);
            var value = try control[1].get_autocomplete(element);
            defer value.deinit(testing.allocator);
            try testing.expectEqualStrings(case[1], value.asSlice());
        }
        const section = try testing.allocator.alloc(u8, 650);
        defer testing.allocator.free(section);
        @memset(section, 'a');
        @memcpy(section[0..8], "section-");
        @memcpy(section[645..], " name");
        try attribute(element, "autocomplete", section);
        var long_value = try control[1].get_autocomplete(element);
        defer long_value.deinit(testing.allocator);
        try testing.expectEqualStrings(section, long_value.asSlice());
        if (comptime control[1] == interfaces.HTMLInputElement) {
            try interfaces.HTMLInputElement.set_type(element, runtime.DOMString.initInterned("hidden"));
            try attribute(element, "autocomplete", " on ");
            var hidden_value = try control[1].get_autocomplete(element);
            defer hidden_value.deinit(testing.allocator);
            try testing.expect(hidden_value.isEmpty());
        }
    }
}

test "autocomplete serializes every token without a fixed section limit" {
    try fixture.run(exercise);
}
