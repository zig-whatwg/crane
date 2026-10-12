//! An HTML element's inline style declarations are its own state, of a type
//! that lives in `dom.cssom` (`InlineStyle`): HTMLElement's state embeds one
//! and installs `dom.cssom.inlineStyleOf`, so that the element's `style`
//! CSSStyleDeclaration - and getBoundingClientRect, and getComputedStyle -
//! read and write it without naming HTMLElement's impl (impls boundary B4,
//! tmp/plans/impls-boundary-design.md 3.3). The declarations outlive the
//! CSSStyleDeclaration object, whose wrapper the collector may take.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const allocator = testing.allocator;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

test "an HTML element's inline style is read and written in place" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    const style = try interfaces.HTMLElement.get_style(page.div);
    try interfaces.CSSStyleDeclaration.set_cssText(style, str("width: 10px; height: 4px"));

    // The declarations are the element's.
    const inline_style = dom.cssom.inlineStyleOf(page.div) orelse return error.NoInlineStyle;
    try testing.expectEqualStrings("10px", inline_style.getProperty("width").?);
    try testing.expectEqual(@as(u32, 2), inline_style.propertyCount());
    try testing.expectEqualStrings("width: 10px; height: 4px", inline_style.cssText());

    // The style object reads them back ...
    const width = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str("width"));
    try testing.expectEqualStrings("10px", width.asSlice());
    try testing.expectEqual(@as(u32, 2), try interfaces.CSSStyleDeclaration.get_length(style));
    // ... and so does getBoundingClientRect, which sizes the box from them.
    const rect = try interfaces.Element.call_getBoundingClientRect(page.div);
    try testing.expectEqual(@as(f64, 10), try interfaces.DOMRect.get_width(rect));
    try testing.expectEqual(@as(f64, 4), try interfaces.DOMRect.get_height(rect));
    interfaces.DOMRect.deinit(rect);

    // A shorthand set through the style object expands into the element's
    // declarations.
    try interfaces.CSSStyleDeclaration.call_setNamedItem(style, str("margin"), str("1px"));
    try testing.expectEqualStrings("1px", inline_style.getProperty("margin-left").?);

    // Only an HTML element has one here; a Text node has none.
    const text = try interfaces.Document.call_createTextNode(page.document, str("x"));
    _ = try interfaces.Node.call_appendChild(page.div, text);
    try testing.expect(dom.cssom.inlineStyleOf(text) == null);
}
