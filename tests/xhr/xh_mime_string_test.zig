const std = @import("std");
const xhr = @import("xhr");
test "XHR override MIME parses DOMString code points instead of its UTF-8 bytes" {
    var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
    defer state.deinit();
    try xhr.headers.overrideMimeType(&state, "text/plain;name=\"\xC3\xBF\";invalid=\xEF\xBF\xBD");
    const bytes = try xhr.response.finalMimeTypeBytes(std.testing.allocator, &state);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("text/plain;name=\"\xFF\"", bytes);
}
