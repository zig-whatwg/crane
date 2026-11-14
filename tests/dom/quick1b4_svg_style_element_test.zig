//! An SVG style element runs HTML's "update a style block" (SVG 2 15.3: the
//! style element's "semantics and processing" are HTML's;
//! src/html/style_block.zig): connected with text/css text it has a sheet,
//! its owner the element; disconnected or with another type it has none;
//! and while the parser has it on its stack of open elements it waits, so a
//! parsed SVG style updates once, with its whole text.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const svg_ns = "http://www.w3.org/2000/svg";

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// An engine-less HTML document with a body (tests/dom/perf3d1_sheet_hooks_test.zig's).
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    body: *runtime.Instance = undefined,

    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(testing.allocator), .ctx = try runtime.ContextData.init(testing.allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.body = try interfaces.Document.call_createElement(self.document, str("body"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.body);
    }

    fn svgStyle(self: *Page, text: []const u8) !*runtime.Instance {
        const el = try interfaces.Document.call_createElementNS(self.document, str(svg_ns), str("style"), .{ .was_passed = false, .value = undefined });
        try interfaces.Node.set_textContent(el, str(text));
        return el;
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

test "a connected SVG style element has a sheet, its owner the element; disconnected, none" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const style = try page.svgStyle("rect { fill: green }");
    try testing.expect(dom.style.hooks.sheetOf(style) == null);
    _ = try interfaces.Node.call_appendChild(page.body, style);
    const record = dom.style.hooks.sheetOf(style) orelse return error.NoSheet;
    try testing.expect(record.owner_node == style);
    try testing.expect((try interfaces.SVGStyleElement.get_sheet(style)) != null);
    _ = try interfaces.Node.call_removeChild(page.body, style);
    try testing.expect(dom.style.hooks.sheetOf(style) == null);
    try testing.expect((try interfaces.SVGStyleElement.get_sheet(style)) == null);
    // Back in the tree, for the document's teardown to free it.
    _ = try interfaces.Node.call_appendChild(page.body, style);
    try testing.expect(dom.style.hooks.sheetOf(style) != null);
}

test "an SVG style element whose type is not text/css has no sheet; type, media and title reflect" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const style = try page.svgStyle("rect { fill: green }");
    try interfaces.SVGStyleElement.set_type(style, str("text/plain"));
    try interfaces.SVGStyleElement.set_media(style, str("print"));
    try interfaces.SVGStyleElement.set_title(style, str("t"));
    _ = try interfaces.Node.call_appendChild(page.body, style);
    try testing.expect(dom.style.hooks.sheetOf(style) == null);
    var type_value = try interfaces.SVGStyleElement.get_type(style);
    defer type_value.deinit(testing.allocator);
    try testing.expectEqualStrings("text/plain", type_value.asSlice());
    var media = try interfaces.SVGStyleElement.get_media(style);
    defer media.deinit(testing.allocator);
    try testing.expectEqualStrings("print", media.asSlice());
    var title = try interfaces.SVGStyleElement.get_title(style);
    defer title.deinit(testing.allocator);
    try testing.expectEqualStrings("t", title.asSlice());
    try interfaces.SVGStyleElement.set_type(style, str("text/css"));
    // Changing type is no trigger of update a style block (HTML 4.2.6);
    // the next children change is.
    try interfaces.Node.set_textContent(style, str("rect { fill: blue }"));
    try testing.expect(dom.style.hooks.sheetOf(style) != null);
    try testing.expect(!try interfaces.SVGStyleElement.get_disabled(style));
    try interfaces.SVGStyleElement.set_disabled(style, true);
    try testing.expect(try interfaces.SVGStyleElement.get_disabled(style));
}

test "an SVG style element the parser holds waits for its pop, then updates once" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const style = try page.svgStyle("");
    dom.style_sheet_owners.createdByParser(style, null);
    _ = try interfaces.Node.call_appendChild(page.body, style);
    try interfaces.Node.set_textContent(style, str("rect { fill: green }"));
    try testing.expect(dom.style.hooks.sheetOf(style) == null);
    dom.style_sheet_owners.poppedByParser(style);
    const record = dom.style.hooks.sheetOf(style) orelse return error.NoSheet;
    try testing.expect(record.owner_node == style);
}

test "an HTML style element and an SVG one each read only their own sheet" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const svg_style = try page.svgStyle("rect { fill: green }");
    const html_style = try interfaces.Document.call_createElement(page.document, str("style"), .{ .was_passed = false, .value = undefined });
    try interfaces.Node.set_textContent(html_style, str("p { color: green }"));
    _ = try interfaces.Node.call_appendChild(page.body, svg_style);
    _ = try interfaces.Node.call_appendChild(page.body, html_style);
    try testing.expect(dom.style.hooks.sheetOf(svg_style).?.owner_node == svg_style);
    try testing.expect(dom.style.hooks.sheetOf(html_style).?.owner_node == html_style);
}
