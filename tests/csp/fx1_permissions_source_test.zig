//! Permissions Policy accepts only the CSP scheme-source and host-source grammar.
const std = @import("std");
const parsing = @import("csp").parsing;

test "permissions source expression validation accepts schemes, hosts, wildcard ports and paths" {
    const valid = [_][]const u8{
        "https:",                                    "custom+v1.test-scheme:",     "example.test",                            "*.example.test",
        "https://*.example.test:8443/path/to/image", "https://example.test:*",     "*",                                       "https://*/",
        "example.test.",                             "https://example.test/a%20b", "https://example.test/a!$&'()*+=:@-._~/b", "http://127.0.0.1:8000/",
        "example.test/a://b",                        "https://example.test/x//y",
    };
    for (valid) |value| try std.testing.expectEqual(parsing.PermissionsSourceValidity.valid, parsing.classifyPermissionsSourceExpression(value));
}

test "permissions source expression validation rejects malformed schemes, hosts, ports and paths" {
    const invalid = [_][]const u8{
        "",                                   "1https:",                        "https_:",                       "https//example.test",    "https://",
        "https://user@example.test",          "https://user:pass@example.test", "https://example.test:notaport", "https://example.test:",  "https://example.test:80oops",
        "https://.example.test",              "https://example..test",          "https://*example.test",         "https://example.*",      "https://example.test/path?query",
        "https://example.test/path#fragment", "https://example.test/a;b",       "https://example.test/a,b",      "https://example.test/%", "https://example.test/%0",
        "https://example.test/%gg",           "https://example.test//path",     "https://example.test/a b",
        "https://é.test",
        "'self'",
    };
    for (invalid) |value| try std.testing.expectEqual(parsing.PermissionsSourceValidity.invalid, parsing.classifyPermissionsSourceExpression(value));
}

// Port syntax has no numeric bound; URL ports are u16. Keep those facts distinct.
test "permissions source ports above 65535 are valid but cannot match a URL" {
    for ([_][]const u8{ "https://example.test:65535", "https://example.test:0080", "https://example.test:*" }) |value| {
        try std.testing.expectEqual(parsing.PermissionsSourceValidity.valid, parsing.classifyPermissionsSourceExpression(value));
    }
    for ([_][]const u8{ "https://example.test:65536", "https://example.test:00065536", "https://example.test:9999999999999999999999" }) |value| {
        try std.testing.expectEqual(parsing.PermissionsSourceValidity.unmatchable_port, parsing.classifyPermissionsSourceExpression(value));
    }
    try std.testing.expectEqual(parsing.PermissionsSourceValidity.invalid, parsing.classifyPermissionsSourceExpression("https://example.test:notaport"));
}
