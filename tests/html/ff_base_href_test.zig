//! HTML 4.2.3: base.href uses the document fallback URL, ignoring every base.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn expectHref(base: *runtime.Instance, expected: []const u8) !void {
    const actual = try interfaces.HTMLBaseElement.get_href(base);
    defer if (actual.len != 0) base.ctx.allocator.free(actual);
    try testing.expectEqualStrings(expected, actual);
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setURL(document, "https://example.test/original/page.html");
    const base = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("base"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, base);
    try expectHref(base, "https://example.test/original/page.html");
    try interfaces.HTMLBaseElement.set_href(base, "../new/");
    try expectHref(base, "https://example.test/new/");
    const second = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("base"), .notPassed());
    defer dom.node_creation.destroyUninserted(second);
    try interfaces.HTMLBaseElement.set_href(second, "sibling");
    try expectHref(second, "https://example.test/original/sibling");
    try interfaces.HTMLBaseElement.set_href(second, "http://[");
    try expectHref(second, "http://[");
    try interfaces.HTMLBaseElement.set_href(second, "data:text/plain,hello");
    try expectHref(second, "data:text/plain,hello");
    try dom.document_internals.setEncoding(document, "windows-1252");
    try interfaces.HTMLBaseElement.set_href(second, "?q=é");
    try expectHref(second, "https://example.test/original/page.html?q=%E9");
    try dom.document_internals.setURL(document, "about:blank");
    dom.document_lifecycle.setAboutBaseUrl(document, "https://creator.test/path/");
    try interfaces.HTMLBaseElement.set_href(second, "child");
    try expectHref(second, "https://creator.test/path/child");
}

test "base href parses against fallback URL with the document encoding" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
