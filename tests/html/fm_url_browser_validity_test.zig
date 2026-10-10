//! Browser URL-input validity accepts successful parses with validation errors.
const std = @import("std");
const forms = @import("html").forms;

test "URL typeMismatch follows browser parsing despite recoverable validation errors" {
    for ([_][]const u8{ "https:example.com", "https://example.com/a b", "https://example.com/%", "http://0x7f.1/" }) |value| {
        try std.testing.expect(!try forms.urlTypeMismatch(std.testing.allocator, value));
    }
    for ([_][]const u8{ "relative", "https://[invalid]/", "https://example.com:99999/" }) |value| {
        try std.testing.expect(try forms.urlTypeMismatch(std.testing.allocator, value));
    }
}
