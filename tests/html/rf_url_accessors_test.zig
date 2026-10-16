//! Special URL getters and the generated URL reflection they override.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

fn check(tag: []const u8, attribute: []const u8, input: []const u8, expected: []const u8, get: *const fn (*runtime.Instance) anyerror!runtime.USVString) !void {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "https://example.test/dir/page");
    const element = try interfaces.Document.call_createElement(page.document, str(tag), .notPassed());
    defer runtime.Instance.deinit(element);
    try interfaces.Element.call_setAttribute(element, str(attribute), .{ .domstring = str(input) });
    const value = try get(element);
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings(expected, value);
}

test "script src getter resolves relative URLs" {
    try check("script", "src", " child?q=é ", "https://example.test/dir/child?q=%C3%A9", interfaces.HTMLScriptElement.get_src);
}

test "iframe src getter resolves the empty URL" {
    try check("iframe", "src", "", "https://example.test/dir/page", interfaces.HTMLIFrameElement.get_src);
}

test "iframe longDesc reads and resolves its content attribute" {
    try check("iframe", "longdesc", "../description", "https://example.test/description", interfaces.HTMLIFrameElement.get_longDesc);
}

test "form action resolves nonempty URLs and keeps the empty document-URL default" {
    try check("form", "action", "submit", "https://example.test/dir/submit", interfaces.HTMLFormElement.get_action);
    try check("form", "action", "", "https://example.test/dir/page", interfaces.HTMLFormElement.get_action);
    try check("form", "action", "http://[", "http://[", interfaces.HTMLFormElement.get_action);
}
