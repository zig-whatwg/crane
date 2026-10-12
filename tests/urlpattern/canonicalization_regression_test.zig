//! URLPattern encoding callbacks use URL parser states on fixed text only.
const std = @import("std");
const up = @import("urlpattern");

test "URLPattern canonicalizes fixed text, prefixes and suffixes" {
    const cases = [_]struct { input: up.URLPatternInit, component: []const u8, expected: []const u8 }{
        .{ .input = .{ .pathname = "/a/../b" }, .component = "pathname", .expected = "/b" },
        .{ .input = .{ .pathname = "/a/%2e%2e/b" }, .component = "pathname", .expected = "/b" },
        .{ .input = .{ .pathname = "/{caf\xc3\xa9:part}" }, .component = "pathname", .expected = "/{caf%C3%A9:part}" },
        .{ .input = .{ .hostname = "0x7f.1" }, .component = "hostname", .expected = "127.0.0.1" },
        .{ .input = .{ .hostname = "%65xample.com" }, .component = "hostname", .expected = "example.com" },
        .{ .input = .{ .hostname = "[2001\\:DB8\\:\\:1]" }, .component = "hostname", .expected = "[2001\\:db8\\:\\:1]" },
        .{ .input = .{ .search = "a'b" }, .component = "search", .expected = "a%27b" },
        .{ .input = .{ .search = "?a\\?b" }, .component = "search", .expected = "a\\?b" },
        .{ .input = .{ .hash = "##hash" }, .component = "hash", .expected = "#hash" },
        .{ .input = .{ .protocol = "data", .pathname = "/a/../b" }, .component = "pathname", .expected = "/a/../b" },
    };
    for (cases) |case| {
        var pattern = try up.URLPattern.create(std.testing.allocator, .{ .init = case.input }, .{});
        defer pattern.deinit(std.testing.allocator);
        inline for (.{ "protocol", "hostname", "pathname", "search", "hash" }) |name| {
            if (std.mem.eql(u8, case.component, name)) try std.testing.expectEqualStrings(case.expected, @field(pattern, name).pattern_string);
        }
    }
}

test "URLPattern rejects fixed components that fail URL canonicalization" {
    const cases = [_]up.URLPatternInit{
        .{ .protocol = "1http" },
        .{ .hostname = "bad host" },
        .{ .port = "65536" },
        .{ .base_url = "not a URL" },
    };
    for (cases) |input| {
        if (up.URLPattern.create(std.testing.allocator, .{ .init = input }, .{})) |result| {
            var pattern = result;
            pattern.deinit(std.testing.allocator);
            return error.TestUnexpectedResult;
        } else |_| {}
    }
}
