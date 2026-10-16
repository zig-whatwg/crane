const std = @import("std");
const xhr = @import("xhr");
const fetch = @import("fetch");
test "XHR saved client owns the site until the eventual request takes a copy" {
    if (!@hasField(fetch.internal.RequestClient, "top_level_site")) return error.TestUnexpectedResult;
    var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
    defer state.deinit();
    var site = [_]u8{'a'};
    try state.setClient(.{ .top_level_site = &site });
    site[0] = 'b';
    try std.testing.expectEqualStrings("a", state.client.top_level_site.?);
    try state.setClient(.{});
    try std.testing.expect(state.client.top_level_site == null);
}
