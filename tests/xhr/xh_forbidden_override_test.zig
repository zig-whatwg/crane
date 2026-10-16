//! XHR setRequestHeader applies Fetch's value-dependent forbidden rule.
const std = @import("std");
const xhr = @import("xhr");

test "XHR method override headers reject a forbidden method in a list" {
    for ([_][]const u8{ "X-HTTP-Method", "X-HTTP-Method-Override", "X-Method-Override" }) |name| {
        var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
        defer state.deinit();
        try xhr.open.open(&state, "POST", "http://example.test/", true, null, null, null, false);
        try xhr.headers.setRequestHeader(&state, name, "GET, tRaCe");
        try std.testing.expect(!state.author_request_headers.contains(name));
        try xhr.headers.setRequestHeader(&state, name, "PATCH");
        try std.testing.expectEqualStrings("PATCH", state.author_request_headers.getFirstValue(name).?);
    }
}
