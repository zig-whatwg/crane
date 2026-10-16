//! URL Standard port state 2.1.2 and 2.2 distinguish parser failure from
//! the forgiving URL setters, which ignore that result.
const std = @import("std");
const url = @import("url");
const parser = url.parser.basic_url_parser;

test "URL port state override reports overflowing and absent numbers" {
    const cases = .{
        .{ "65536", error.PortOutOfRange },
        .{ "100000", error.PortOutOfRange },
        .{ "invalid80", error.PortInvalid },
        .{ "", error.PortInvalid },
    };
    inline for (cases) |case| {
        var record = try parser.parse(std.testing.allocator, "https://old.example:8443/path", null);
        defer record.deinit();
        try std.testing.expectError(case[1], parser.parseWithStateOverride(std.testing.allocator, case[0], null, .port, &record));
        try std.testing.expectEqual(@as(?u16, 8443), record.port);
    }
}

test "URL host state preserves the host change when the port fails" {
    const cases = .{
        .{ "new.example:invalid", error.PortInvalid },
        .{ "new.example:65536", error.PortOutOfRange },
    };
    inline for (cases) |case| {
        var record = try parser.parse(std.testing.allocator, "https://old.example:8443/path", null);
        defer record.deinit();
        try std.testing.expectError(case[1], parser.parseWithStateOverride(std.testing.allocator, case[0], null, .host, &record));
        const hostname = try url.host_serializer.serializeHost(std.testing.allocator, record.host.?);
        defer std.testing.allocator.free(hostname);
        try std.testing.expectEqualStrings("new.example", hostname);
        try std.testing.expectEqual(@as(?u16, 8443), record.port);
    }
}
