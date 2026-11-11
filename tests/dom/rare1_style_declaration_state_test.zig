//! What element.style's object costs beyond the rare block (lane rare1 batch
//! 1, step 4; tmp/redesign/nodedata/framework-pages.md table J: 236-296
//! bytes for the CSSStyleProperties object with its slot and wrapper-cache
//! entry, before anything is written).
//!
//! CSSOM: "the style attribute ... must return a CSSStyleProperties object
//! whose readonly flag is unset, whose parent CSS rule is null, and whose
//! owner node is this" ([SameObject]). The object must exist and keep its
//! identity, but an inline declaration's object reads only its owner: its
//! declarations are the element's inline block (dom.style), not its own.
//! Every object carried the state of all four kinds - a computed one's held
//! element, pseudo-element and no-object flag, a detached one's own
//! DeclarationBlock - so each element.style read paid for them. Blink's
//! InlineCSSStyleDeclaration is its parent element and nothing else
//! (core/css/inline_css_style_declaration.h: `Member<Element>
//! parent_element_`), and its computed and property-set declarations are
//! classes of their own.
//!
//! RED at d7d5a0be246: the size pin. The behaviour tests hold before and
//! after.
//!
//! These name only generated interfaces and their States (AGENTS.md "The
//! impls boundary").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

/// CSSStyleDeclaration's InternalState, as its generated State keeps it.
const DeclarationState = std.meta.Child(std.meta.Child(@FieldType(@FieldType(interfaces.CSSStyleDeclaration.State, "own"), "_internal")));

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn printLayout(comptime T: type) void {
    std.debug.print("\n{s}: {d} bytes, align {d}\n", .{ @typeName(T), @sizeOf(T), @alignOf(T) });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("  {s:<26} +{d:<4} {d:>4} B  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @typeName(F) });
    }
}

test "a style declaration's own state is at most 56 bytes: the kinds that need more keep it out of line" {
    // Kept: the kind, the inline owner and its generation, the rule, the
    // allocator, and one pointer to what only a computed or a detached
    // declaration reads.
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(DeclarationState), @alignOf(DeclarationState));
    if (@sizeOf(DeclarationState) > 56) {
        printLayout(DeclarationState);
        std.debug.print("{d} bytes in a {d}-byte arena block, at most 56 wanted\n", .{ @sizeOf(DeclarationState), held });
        return error.DeclarationStateTooLarge;
    }
    try testing.expect(held <= 64);
}

// ============================================================================
// Each kind still works (engine-less)
// ============================================================================

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
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

    fn expectString(self: *Page, expected: []const u8, got: runtime.DOMString) !void {
        var value = got;
        defer value.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, value.asSlice());
    }
};

test "inline: element.style reads and writes the element's style attribute" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const style = try interfaces.HTMLElement.get_style(page.div);
    try testing.expectEqual(@as(u32, 0), try interfaces.CSSStyleDeclaration.get_length(style));
    try interfaces.CSSStyleDeclaration.call_setProperty(style, str("color"), str("red"), .notPassed());
    try interfaces.CSSStyleDeclaration.call_setProperty(style, str("margin-left"), str("2px"), .notPassed());
    try page.expectString("red", try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str("color")));
    try testing.expectEqual(@as(u32, 2), try interfaces.CSSStyleDeclaration.get_length(style));
    var attribute = (try interfaces.Element.call_getAttribute(page.div, str("style"))).?;
    defer attribute.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("color: red; margin-left: 2px;", attribute.asSlice());
    // The attribute written: the same object reads it.
    try interfaces.Element.call_setAttribute(page.div, str("style"), .{ .domstring = str("top: 1px") });
    try page.expectString("top: 1px;", try interfaces.CSSStyleDeclaration.get_cssText(style));
    try page.expectString("", try interfaces.CSSStyleDeclaration.call_removeProperty(style, str("color")));
    try page.expectString("1px", try interfaces.CSSStyleDeclaration.call_removeProperty(style, str("top")));
    try testing.expectEqual(@as(u32, 0), try interfaces.CSSStyleDeclaration.get_length(style));
}

test "detached: a declaration of its own keeps its block until it goes" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const style = try interfaces.CSSStyleDeclaration.init(page.ctx.allocator, &page.ctx);
    defer interfaces.CSSStyleDeclaration.deinit(style);
    try interfaces.CSSStyleDeclaration.set_cssText(style, str("color: blue; padding: 1px 2px"));
    try testing.expectEqual(@as(u32, 5), try interfaces.CSSStyleDeclaration.get_length(style));
    try page.expectString("blue", try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str("color")));
    try page.expectString("1px 2px", try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str("padding")));
    try interfaces.CSSStyleDeclaration.call_setProperty(style, str("color"), str("green"), .notPassed());
    try page.expectString("color: green; padding: 1px 2px;", try interfaces.CSSStyleDeclaration.get_cssText(style));
}

/// A page with a Window, so getComputedStyle resolves (tests/dom/bx1_transform_alias_test.zig's shape).
const WindowPage = struct {
    scope: runtime.BrowserScope,
    context: runtime.ContextData,
    window: *runtime.Instance = undefined,
    document: *runtime.Instance = undefined,
    target: *runtime.Instance = undefined,

    fn init(self: *WindowPage) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = .init(testing.allocator), .context = try runtime.ContextData.init(testing.allocator, .{}) };
        errdefer self.context.deinit();
        errdefer self.scope.deinit();
        self.context.browser_scope = &self.scope;
        self.window = try interfaces.Window.init(testing.allocator, &self.context);
        errdefer interfaces.Window.deinit(self.window);
        const document = try interfaces.Document.init(testing.allocator, &self.context);
        try dom.document_internals.setContentType(document, "text/html");
        try dom.document_internals.setDocumentType(document, .html);
        dom.window_globals.setDocument(self.window, document);
        dom.document_browsing_context.setWindow(document, self.window);
        self.document = document;
        const root = try interfaces.Document.call_createElement(document, str("html"), .notPassed());
        _ = try interfaces.Node.call_appendChild(document, root);
        self.target = try interfaces.Document.call_createElement(document, str("div"), .notPassed());
        _ = try interfaces.Node.call_appendChild(root, self.target);
    }

    fn deinit(self: *WindowPage) void {
        interfaces.Window.deinit(self.window);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.context.deinit();
    }
};

fn expectValue(style: *runtime.Instance, name: []const u8, expected: []const u8) !void {
    var value = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str(name));
    defer value.deinit(style.ctx.allocator);
    try testing.expectEqualStrings(expected, value.asSlice());
}

test "computed: getComputedStyle reads the element's resolved style, read-only, and holds its element" {
    var page: WindowPage = undefined;
    try page.init();
    defer page.deinit();

    const inline_style = try interfaces.HTMLElement.get_style(page.target);
    try interfaces.CSSStyleDeclaration.call_setProperty(inline_style, str("display"), str("block"), .notPassed());
    try interfaces.CSSStyleDeclaration.call_setProperty(inline_style, str("color"), str("rgb(1, 2, 3)"), .notPassed());
    const computed = try interfaces.Window.call_getComputedStyle(page.window, page.target, .notPassed());
    defer interfaces.CSSStyleProperties.deinit(computed);
    try expectValue(computed, "color", "rgb(1, 2, 3)");
    try expectValue(computed, "display", "block");
    try testing.expect((try interfaces.CSSStyleDeclaration.get_length(computed)) > 100);
    try testing.expectError(error.NoModificationAllowedError, interfaces.CSSStyleDeclaration.set_cssText(computed, str("color: red")));
    // Live: a later change reads through.
    try interfaces.CSSStyleDeclaration.call_setProperty(inline_style, str("color"), str("rgb(4, 5, 6)"), .notPassed());
    try expectValue(computed, "color", "rgb(4, 5, 6)");
}

fn computedWithFailures(failing: std.mem.Allocator, page: *WindowPage) !void {
    const style = try interfaces.CSSStyleProperties.initWith(failing, &page.context, .{
        .computed_for = dom.style.ComputedFor{ .element = page.target, .pseudo = "::before" },
    });
    defer interfaces.CSSStyleProperties.deinit(style);
    // Its serialization allocates too; the value itself is not this test's.
    var value = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str("display"));
    value.deinit(style.ctx.allocator);
}

test "computed: a construction that runs out of memory leaves no state behind" {
    // The out-of-line part and the pseudo-element's copy are allocations of
    // their own: each failure must take the registry entry with it, or the
    // address's next declaration inherits it.
    var page: WindowPage = undefined;
    try page.init();
    defer page.deinit();
    try testing.checkAllAllocationFailures(testing.allocator, computedWithFailures, .{&page});
}
