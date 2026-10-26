//! Registered custom properties through the style engine (lane vars1b2):
//! the document's registry - @property rules and CSS.registerProperty - is
//! read by the cascade as a snapshot whose initial values are computed once,
//! and a registration added or removed restyles what depends on it.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const allocator = testing.allocator;

const Page = struct {
    scope: runtime.BrowserScope,
    context: runtime.ContextData,
    document: *runtime.Instance = undefined,
    root: *runtime.Instance = undefined,
    shadow: ?*runtime.Instance = null,

    fn init(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = .init(allocator), .context = try runtime.ContextData.init(allocator, .{}) };
        self.context.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.context);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.root = try interfaces.Document.call_createElement(self.document, .initInterned("html"), .notPassed());
        _ = try interfaces.Node.call_appendChild(self.document, self.root);
    }

    fn deinit(self: *Page) void {
        interfaces.Document.deinit(self.document);
        // Native fixtures have no wrapper collector. As in ci1_tree_scope,
        // tear down the host first, then its independently owned shadow tree.
        if (self.shadow) |shadow| interfaces.ShadowRoot.deinit(shadow);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.context.deinit();
    }

    fn sheet(self: *Page, text: []const u8) !*runtime.Instance {
        const element = try interfaces.Document.call_createElement(self.document, .initInterned("style"), .notPassed());
        try interfaces.Node.set_textContent(element, .initInterned(text));
        _ = try interfaces.Node.call_appendChild(self.root, element);
        return element;
    }

    fn engine(self: *Page) *dom.style.StyleEngine {
        return dom.style.hooks.engineOf(self.document).?;
    }
};

fn expectCustom(element: *runtime.Instance, name: []const u8, expected: ?[]const u8) !void {
    const style = (try dom.style.computedStyle(element, null)).?;
    const got = style.customValue(name);
    if (expected) |e| {
        if (got == null) {
            std.debug.print("{s}: expected \"{s}\", got the guaranteed-invalid value\n", .{ name, e });
            return error.TestExpectedEqual;
        }
        try testing.expectEqualStrings(e, got.?.bytes);
    } else if (got) |g| {
        std.debug.print("{s}: expected the guaranteed-invalid value, got \"{s}\"\n", .{ name, g.bytes });
        return error.TestExpectedEqual;
    }
}

test "an @property rule's initial value and syntax reach the cascade, and leave with the rule" {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const body = try interfaces.Document.call_createElement(page.document, .initInterned("body"), .notPassed());
    _ = try interfaces.Node.call_appendChild(page.root, body);
    _ = try page.sheet(":root { font-size: 10px; --y: var(--x); --len: 2em }");
    // No registration: unregistered values, and no snapshot.
    try expectCustom(page.root, "--x", null);
    try expectCustom(page.root, "--len", "2em");
    try testing.expect(page.engine().rare == null or page.engine().rare.?.registered == null);
    const rule = try page.sheet("@property --x { syntax: '<length>'; inherits: false; initial-value: 7px; } @property --len { syntax: '<length>'; inherits: true; initial-value: 0px; }");
    try expectCustom(page.root, "--x", "7px");
    try expectCustom(page.root, "--y", "7px");
    try expectCustom(page.root, "--len", "20px");
    // inherits: true reaches the child; inherits: false is the initial value.
    try expectCustom(body, "--len", "20px");
    try expectCustom(body, "--x", "7px");
    _ = try interfaces.Node.call_removeChild(page.root, rule);
    try expectCustom(page.root, "--x", null);
    try expectCustom(page.root, "--y", null);
    try expectCustom(page.root, "--len", "2em");
}

test "CSS.registerProperty's registration restyles, and one snapshot serves every element" {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const body = try interfaces.Document.call_createElement(page.document, .initInterned("body"), .notPassed());
    _ = try interfaces.Node.call_appendChild(page.root, body);
    _ = try page.sheet(":root { --c: red }");
    try expectCustom(page.root, "--c", "red");
    try page.engine().registerProperty(page.document, .{ .allocator = allocator }, .{ .name = "--c", .syntax = "<color>", .inherits = true, .initial_value = "black" });
    try expectCustom(page.root, "--c", "rgb(255, 0, 0)");
    try expectCustom(body, "--c", "rgb(255, 0, 0)");
    const root_style = (try dom.style.computedStyle(page.root, null)).?;
    const body_style = (try dom.style.computedStyle(body, null)).?;
    try testing.expect(root_style.registered != null);
    try testing.expectEqual(root_style.registered.?, body_style.registered.?);
    try testing.expectEqual(page.engine().rare.?.registered.?, root_style.registered.?);
}
