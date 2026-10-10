const std = @import("std");
const csp = @import("csp");

test "external stylesheets use the nonce in their effective source list" {
    for ([_][]const u8{ "style-src", "style-src-elem", "default-src" }) |directive| {
        const text = try std.fmt.allocPrint(std.testing.allocator, "{s} 'nonce-abc'", .{directive});
        defer std.testing.allocator.free(text);
        var policy = try csp.parsing.parseSerializedCSP(std.testing.allocator, text, .header, .enforce);
        defer policy.deinit();
        var request: csp.request_check.Request = .{
            .url = .{ .scheme = "https", .host = "example.test", .path = "/style.css" },
            .destination = "style",
            .nonce = "abc",
        };
        try std.testing.expect(csp.request_check.doesRequestViolatePolicy(request, &policy) == null);
        request.nonce = "wrong";
        try std.testing.expect(csp.request_check.doesRequestViolatePolicy(request, &policy) != null);
        request.nonce = "";
        try std.testing.expect(csp.request_check.doesRequestViolatePolicy(request, &policy) != null);
        request.nonce = "abc";
        request.destination = "image";
        if (std.mem.eql(u8, directive, "default-src"))
            try std.testing.expect(csp.request_check.doesRequestViolatePolicy(request, &policy) != null);
    }
}
