//! Native registration ownership and the document's existing sheet order.
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

    fn expectInitial(self: *Page, expected: ?[]const u8) !void {
        const registry = try self.engine().propertyRegistry(self.document);
        const record = if (registry) |map| map.lookup("--x") else null;
        if (expected) |text| {
            try testing.expect(record != null);
            try testing.expectEqualStrings(text, record.?.initial_text.?);
        } else try testing.expect(record == null);
    }
};

test "pr1 document registry follows sheet order removal and scripted precedence" {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    try page.expectInitial(null);
    try testing.expect(page.engine().rare == null);
    const first = try page.sheet("@property --x { syntax: '<length>'; inherits: false; initial-value: 1px; }");
    _ = first;
    const last = try page.sheet(
        "@property --x { syntax: '<length>'; inherits: false; initial-value: 2px; } " ++
            "@media print { @property --x { syntax: '<length>'; inherits: false; initial-value: 9px; } } " ++
            "@supports (pr1-unknown: impossible) { @property --x { syntax: '<length>'; inherits: false; initial-value: 10px; } }",
    );
    try page.expectInitial("2px");
    try interfaces.HTMLStyleElement.set_disabled(last, true);
    try page.expectInitial("1px");
    try interfaces.HTMLStyleElement.set_disabled(last, false);
    try page.expectInitial("2px");
    try interfaces.HTMLStyleElement.set_media(last, .initInterned("print"));
    try page.expectInitial("1px");
    try interfaces.HTMLStyleElement.set_media(last, .initInterned(""));
    try page.expectInitial("2px");
    const before = (try page.engine().propertyRegistry(page.document)).?.version;
    try page.expectInitial("2px");
    try testing.expectEqual(before, (try page.engine().propertyRegistry(page.document)).?.version);
    _ = try interfaces.Node.call_removeChild(page.root, last);
    try page.expectInitial("1px");
    _ = try interfaces.Node.call_appendChild(page.root, last);
    try page.expectInitial("2px");
    const generation = page.engine().generation;
    try page.engine().registerProperty(page.document, .{ .allocator = allocator }, .{ .name = "--x", .syntax = "<length>", .inherits = true, .initial_value = "3px" });
    try testing.expect(page.engine().generation != generation);
    try page.expectInitial("3px");
    try testing.expectError(error.InvalidModificationError, page.engine().registerProperty(page.document, .{ .allocator = allocator }, .{ .name = "--x", .inherits = true }));
    try interfaces.Node.set_textContent(last, .initInterned("@property --x { syntax: '<length>'; inherits: false; initial-value: 4px; }"));
    try page.expectInitial("3px");
}

test "pr1 property index retains conditional order and skips false supports" {
    const contents = try dom.style.sheet.Contents.parse(allocator,
        \\@property --first {syntax: '*'; inherits: false;}
        \\@media screen { @media (min-width: 700px) {
        \\ @supports (display: block) { @layer properties {
        \\  @property --wide {syntax: '*'; inherits: true;}
        \\ }}
        \\}}
        \\@supports (pr1-unknown: impossible) { @property --ignored {syntax: '*'; inherits: true;} }
        \\@media print { @property --print {syntax: '*'; inherits: true;} }
    , .{});
    defer contents.destroy();
    const entries = contents.property_rules.items;
    try testing.expectEqual(@as(usize, 3), entries.len);
    try testing.expectEqualStrings("--first", entries[0].rule.data.property.name);
    try testing.expectEqualStrings("--wide", entries[1].rule.data.property.name);
    try testing.expectEqualStrings("--print", entries[2].rule.data.property.name);
    try testing.expect(entries[0].condition == null);
    try testing.expect(contents.conditionHolds(entries[1].condition, &.{ .width = 800 }));
    try testing.expect(!contents.conditionHolds(entries[1].condition, &.{ .width = 600 }));
    try testing.expect(!contents.conditionHolds(entries[2].condition, &.{}));
}

fn ruleOom(a: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(a, "@media screen { @property --x {syntax: '<length>'; inherits: false; initial-value: 1px;} }", .{});
    var owned = true;
    defer if (owned) record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    const rule = list.items[0].data.media.children.items[0];
    rule.ref();
    defer rule.unref();
    const registration = rule.data.property;
    registration.ref();
    defer registration.unref();
    record.unref();
    owned = false;
    const text = try rule.serialize(a);
    defer a.free(text);
    try testing.expectEqualStrings("@property --x { syntax: \"<length>\"; inherits: false; initial-value: 1px; }", text);
    try testing.expectEqualStrings("1px", registration.initial_text.?);
}

test "pr1 property rule and registration outlive their sheet with allocation cleanup" {
    try ruleOom(allocator);
    try testing.checkAllAllocationFailures(allocator, ruleOom, .{});
    try testing.checkAllAllocationFailures(allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            const contents = try dom.style.sheet.Contents.parse(a, "@media screen { @property --x {syntax: '*'; inherits: false;} }", .{});
            defer contents.destroy();
            try testing.expectEqual(@as(usize, 1), contents.property_rules.items.len);
        }
    }.exercise, .{});
}

test "pr1 ordinary sheets allocate no property index" {
    const contents = try dom.style.sheet.Contents.parse(allocator, "a { color: red; }", .{});
    defer contents.destroy();
    try testing.expectEqual(@as(usize, 0), contents.property_rules.capacity);
}

test "pr1 CSSPropertyRule uses the generated CSSRule ownership chain" {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const sheet = try dom.style.SheetRecord.create(allocator, "@property --native {syntax: '*'; inherits: false;}", .{});
    defer sheet.unref();
    const tree = try sheet.rulesWith(.{ .allocator = allocator });
    try testing.expectEqual(@as(usize, 1), tree.items.len);
    const object = try interfaces.CSSPropertyRule.initWith(allocator, &page.context, .{ .css_rule = tree.items[0] });
    defer interfaces.CSSPropertyRule.deinit(object);
    var name = try interfaces.CSSPropertyRule.get_name(object);
    defer name.deinit(allocator);
    try testing.expectEqualStrings("--native", name.asSlice());
    try testing.expectEqual(@as(u16, 0), try interfaces.CSSRule.get_type(object));
    try testing.expect((try interfaces.CSSPropertyRule.get_initialValue(object)) == null);
}

test "pr1 document registries remain isolated across Browser scopes" {
    var first: Page = undefined;
    try first.init();
    defer first.deinit();
    var second: Page = undefined;
    try second.init();
    defer second.deinit();
    try first.engine().registerProperty(first.document, .{ .allocator = allocator }, .{ .name = "--x", .syntax = "<length>", .inherits = false, .initial_value = "1px" });
    try first.expectInitial("1px");
    try second.expectInitial(null);
    try second.engine().registerProperty(second.document, .{ .allocator = allocator }, .{ .name = "--x", .syntax = "<length>", .inherits = true, .initial_value = "2px" });
    try first.expectInitial("1px");
    try second.expectInitial("2px");
}

test "pr1 shadow stylesheet keeps CSSOM records without document registrations" {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const host = try interfaces.Document.call_createElement(page.document, .initInterned("div"), .notPassed());
    _ = try interfaces.Node.call_appendChild(page.root, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    page.shadow = shadow;
    try dom.node_document.set(shadow, page.document);
    const style = try interfaces.Document.call_createElement(page.document, .initInterned("style"), .notPassed());
    try interfaces.Node.set_textContent(style, .initInterned("@property --x {syntax: '<length>'; inherits: false; initial-value: 8px;}"));
    _ = try interfaces.Node.call_appendChild(shadow, style);
    const sheet = dom.style.hooks.sheetOf(style) orelse return error.TestExpectedValue;
    const rules = try sheet.rulesWith(.{ .allocator = allocator });
    try testing.expectEqual(@as(usize, 1), rules.items.len);
    try testing.expectEqualStrings("--x", rules.items[0].data.property.name);
    try page.expectInitial(null);
}

// Registration state behind at-property-non-matching-media-crash.html.
test "pr1 media change removes registration but retains its CSSOM rule" {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const style = try page.sheet("@property --x {syntax: '<length>'; inherits: false; initial-value: 0px;}");
    try page.expectInitial("0px");
    try interfaces.HTMLStyleElement.set_media(style, .initInterned("braille"));
    try page.expectInitial(null);
    const sheet = dom.style.hooks.sheetOf(style) orelse return error.TestExpectedValue;
    const rules = try sheet.rulesWith(.{ .allocator = allocator });
    try testing.expectEqual(@as(usize, 1), rules.items.len);
    try testing.expectEqualStrings("0px", rules.items[0].data.property.initial_text.?);
}
