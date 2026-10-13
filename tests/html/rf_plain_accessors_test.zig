//! Plain reflection must read and mutate the element's actual attribute list.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

const Pair = struct {
    name: []const u8,
    get: *const fn (*runtime.Instance) anyerror!runtime.DOMString,
    set: *const fn (*runtime.Instance, runtime.DOMString) anyerror!void,
};

fn check(element: *runtime.Instance, pair: Pair) !void {
    try interfaces.Element.call_setAttribute(element, str(pair.name), .{ .domstring = str("content") });
    var value = try pair.get(element);
    defer value.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("content", value.asSlice());
    try pair.set(element, str("property"));
    var attribute = (try interfaces.Element.call_getAttribute(element, str(pair.name))).?;
    defer attribute.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("property", attribute.asSlice());
}

test "iframe string accessors reflect the content attribute rather than a cached field" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const element = try interfaces.Document.call_createElement(page.document, str("iframe"), .notPassed());
    defer runtime.Instance.deinit(element);
    for ([_]Pair{
        .{ .name = "width", .get = interfaces.HTMLIFrameElement.get_width, .set = interfaces.HTMLIFrameElement.set_width },
        .{ .name = "height", .get = interfaces.HTMLIFrameElement.get_height, .set = interfaces.HTMLIFrameElement.set_height },
        .{ .name = "align", .get = interfaces.HTMLIFrameElement.get_align, .set = interfaces.HTMLIFrameElement.set_align },
        .{ .name = "scrolling", .get = interfaces.HTMLIFrameElement.get_scrolling, .set = interfaces.HTMLIFrameElement.set_scrolling },
        .{ .name = "frameborder", .get = interfaces.HTMLIFrameElement.get_frameBorder, .set = interfaces.HTMLIFrameElement.set_frameBorder },
        .{ .name = "marginheight", .get = interfaces.HTMLIFrameElement.get_marginHeight, .set = interfaces.HTMLIFrameElement.set_marginHeight },
        .{ .name = "marginwidth", .get = interfaces.HTMLIFrameElement.get_marginWidth, .set = interfaces.HTMLIFrameElement.set_marginWidth },
    }) |pair| try check(element, pair);
}

test "iframe allowFullscreen uses presence and removes its attribute when false" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const element = try interfaces.Document.call_createElement(page.document, str("iframe"), .notPassed());
    defer runtime.Instance.deinit(element);
    try interfaces.Element.call_setAttribute(element, str("allowfullscreen"), .{ .domstring = str("false") });
    try std.testing.expect(try interfaces.HTMLIFrameElement.get_allowFullscreen(element));
    try interfaces.HTMLIFrameElement.set_allowFullscreen(element, false);
    try std.testing.expect(!(try interfaces.Element.call_hasAttribute(element, str("allowfullscreen"))));
}

test "frameset rows and cols use the generated string reflection" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const element = try interfaces.Document.call_createElement(page.document, str("frameset"), .notPassed());
    defer runtime.Instance.deinit(element);
    try check(element, .{ .name = "cols", .get = interfaces.HTMLFrameSetElement.get_cols, .set = interfaces.HTMLFrameSetElement.set_cols });
    try check(element, .{ .name = "rows", .get = interfaces.HTMLFrameSetElement.get_rows, .set = interfaces.HTMLFrameSetElement.set_rows });
}

test "document color attributes reflect its current body, and no body is a no-op" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    _ = try interfaces.Node.call_removeChild(page.document, page.element);
    runtime.Instance.deinit(page.element);
    page.element = try page.append(page.document, "html");
    const pairs = [_]Pair{
        .{ .name = "text", .get = interfaces.Document.get_fgColor, .set = interfaces.Document.set_fgColor },
        .{ .name = "link", .get = interfaces.Document.get_linkColor, .set = interfaces.Document.set_linkColor },
        .{ .name = "vlink", .get = interfaces.Document.get_vlinkColor, .set = interfaces.Document.set_vlinkColor },
        .{ .name = "alink", .get = interfaces.Document.get_alinkColor, .set = interfaces.Document.set_alinkColor },
        .{ .name = "bgcolor", .get = interfaces.Document.get_bgColor, .set = interfaces.Document.set_bgColor },
    };
    for (pairs) |pair| {
        try pair.set(page.document, str("ignored"));
        var value = try pair.get(page.document);
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("", value.asSlice());
    }
    const body = try page.append(page.element, "body");
    for (pairs) |pair| {
        try interfaces.Element.call_setAttribute(body, str(pair.name), .{ .domstring = str("body-value") });
        var value = try pair.get(page.document);
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("body-value", value.asSlice());
        try pair.set(page.document, str("new-value"));
        var attribute = (try interfaces.Element.call_getAttribute(body, str(pair.name))).?;
        defer attribute.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("new-value", attribute.asSlice());
    }
}
