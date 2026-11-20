//! Lane maj5:
//! - CSS Cascade 5 §2.4 (@import): `[ layer | layer(<layer-name>) ]?` is
//!   optional, so an @import whose layer() does not hold a <layer-name> is
//!   still an @import: the layer() part, and what follows, is its
//!   <import-conditions> - here a <media-query-list> whose first query starts
//!   with a <general-enclosed> function (Chrome, Firefox and Safari:
//!   css/css-cascade/parsing/layer-import-parsing.html,
//!   css/cssom/CSSImportRule-layer-false-positive.html).
//! - Compat §3.4.1: -webkit-filter and the -webkit-transition family are
//!   legacy name aliases of filter and transition (all three browsers:
//!   custom-elements/reactions/CSSStyleDeclaration.html,
//!   css/cssom/computed-style-set-property.html).
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const allocator = testing.allocator;
const Rule = dom.style.rules.Rule;

const Import = struct {
    css_text: []u8,
    layer: ?[]const u8,
    media: []u8,
};

/// The one rule `text` parses to, as an @import: its serialization, layer
/// name and media list.
fn parseImport(text: []const u8) !Import {
    var tree: std.ArrayList(*Rule) = .empty;
    defer {
        for (tree.items) |r| r.unref();
        tree.deinit(allocator);
    }
    try dom.style.rules.parseSheet(.{ .parse = .{ .allocator = allocator } }, text, &tree, null);
    if (tree.items.len != 1) {
        std.debug.print("\"{s}\": {d} rules\n", .{ text, tree.items.len });
        return error.NotOneRule;
    }
    const rule = tree.items[0];
    if (rule.data != .import) return error.NotAnImport;
    const css_text = try rule.serialize(allocator);
    errdefer allocator.free(css_text);
    const media = try dom.style.rules.serializeMedia(allocator, &rule.data.import.media);
    errdefer allocator.free(media);
    return .{ .css_text = css_text, .layer = if (rule.data.import.layer) |l| try allocator.dupe(u8, l) else null, .media = media };
}

fn freeImport(i: Import) void {
    allocator.free(i.css_text);
    if (i.layer) |l| allocator.free(l);
    allocator.free(i.media);
}

fn expectImport(text: []const u8, css_text: []const u8, layer: ?[]const u8) !void {
    const i = parseImport(text) catch |err| {
        std.debug.print("\"{s}\" is not an @import rule ({})\n", .{ text, err });
        return err;
    };
    defer freeImport(i);
    if (!std.mem.eql(u8, css_text, i.css_text)) std.debug.print("\"{s}\"\n  expected \"{s}\"\n  got      \"{s}\"\n", .{ text, css_text, i.css_text });
    try testing.expectEqualStrings(css_text, i.css_text);
    if (layer) |l| try testing.expectEqualStrings(l, i.layer orelse "<null>") else try testing.expect(i.layer == null);
}

test "an @import whose layer() holds no layer name keeps it as media" {
    try expectImport("@import \"data:text/css,\" layer() screen;", "@import url(\"data:text/css,\") not all;", null);
    try expectImport("@import \"data:text/css,\" layer() screen, print;", "@import url(\"data:text/css,\") not all, print;", null);
    try expectImport("@import \"data:text/css,\" layer() supports((display: grid)) screen;", "@import url(\"data:text/css,\") not all;", null);
    try expectImport("@import \"data:text/css,\" layer(foo bar) screen;", "@import url(\"data:text/css,\") not all;", null);
    try expectImport("@import \"data:text/css,\" layer(foo bar) supports((display: grid)) screen;", "@import url(\"data:text/css,\") not all;", null);
    for ([_][]const u8{ "layer()", "layer(A B)", "layer(A . B)", "layer(A, B, C)" }) |bad| {
        var buffer: [96]u8 = undefined;
        const i = try parseImport(try std.fmt.bufPrint(&buffer, "@import url(\"nonexist.css\") {s};", .{bad}));
        defer freeImport(i);
        try testing.expect(i.layer == null);
        try testing.expect(i.media.len != 0);
    }
}

test "a valid layer is still the rule's layer, and a layer() elsewhere is not" {
    try expectImport("@import \"data:text/css,\" layer(foo);", "@import url(\"data:text/css,\") layer(foo);", "foo");
    try expectImport("@import \"data:text/css,\" layer;", "@import url(\"data:text/css,\") layer;", "");
    try expectImport("@import url(nonexist.css) layer(A.B);", "@import url(\"nonexist.css\") layer(A.B);", "A.B");
    try expectImport("@import \"data:text/css,\" supports((color: layer(foo)));", "@import url(\"data:text/css,\") supports((color: layer(foo)));", null);
    try expectImport("@import \"data:text/css,\" screen and (foo: layer(bar));", "@import url(\"data:text/css,\") screen and (foo: layer(bar));", null);
}

const Page = struct {
    scope: runtime.BrowserScope,
    context: runtime.ContextData,
    window: *runtime.Instance = undefined,
    document: *runtime.Instance = undefined,
    target: *runtime.Instance = undefined,
    target_style: *runtime.Instance = undefined,

    fn init(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = .init(allocator), .context = try runtime.ContextData.init(allocator, .{}) };
        errdefer self.context.deinit();
        errdefer self.scope.deinit();
        self.context.browser_scope = &self.scope;
        self.window = try interfaces.Window.init(allocator, &self.context);
        errdefer interfaces.Window.deinit(self.window);
        self.document = blk: {
            const document = try interfaces.Document.init(allocator, &self.context);
            errdefer interfaces.Document.deinit(document);
            try dom.document_internals.setContentType(document, "text/html");
            try dom.document_internals.setDocumentType(document, .html);
            dom.window_globals.setDocument(self.window, document);
            dom.document_browsing_context.setWindow(document, self.window);
            break :blk document;
        };
        const root = try self.append(self.document, "html");
        self.target = try self.append(root, "div");
        self.target_style = try interfaces.HTMLElement.get_style(self.target);
    }

    fn deinit(self: *Page) void {
        interfaces.Window.deinit(self.window);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.context.deinit();
    }

    fn append(self: *Page, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
        const element = try interfaces.Document.call_createElement(self.document, .initInterned(name), .notPassed());
        errdefer dom.node_creation.destroyRoot(element);
        _ = try interfaces.Node.call_appendChild(parent, element);
        return element;
    }
};

fn expectValue(style: *runtime.Instance, name: []const u8, expected: []const u8) !void {
    var value = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, .initInterned(name));
    defer value.deinit(style.ctx.allocator);
    try testing.expectEqualStrings(expected, value.asSlice());
}

fn fresh(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn aliasCases() !void {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const style = page.target_style;
    // -webkit-filter sets and reads filter; the style attribute names filter.
    try interfaces.CSSStyleDeclaration.call_setProperty(style, .initInterned("-webkit-filter"), .initInterned("grayscale(20%)"), .notPassed());
    try expectValue(style, "filter", "grayscale(20%)");
    try expectValue(style, "-webkit-filter", "grayscale(20%)");
    var text = try interfaces.CSSStyleDeclaration.get_cssText(style);
    defer text.deinit(style.ctx.allocator);
    try testing.expectEqualStrings("filter: grayscale(20%);", text.asSlice());
    // -webkit-transition is transition's alias, its longhands their own.
    try interfaces.CSSStyleDeclaration.call_setProperty(style, .initInterned("-webkit-transition"), .initInterned("opacity 2s"), .notPassed());
    try expectValue(style, "transition-duration", "2s");
    try expectValue(style, "-webkit-transition-duration", "2s");
    try expectValue(style, "-webkit-transition-property", "opacity");
    try interfaces.CSSStyleDeclaration.call_setProperty(style, .initInterned("-webkit-transition-delay"), .initInterned("1s"), .notPassed());
    try expectValue(style, "transition-delay", "1s");
    // The computed declaration is read-only for the alias as for the
    // property (CSSOM setProperty step 1).
    const computed = try interfaces.Window.call_getComputedStyle(page.window, page.target, .notPassed());
    defer interfaces.CSSStyleProperties.deinit(computed);
    try testing.expectError(error.NoModificationAllowedError, interfaces.CSSStyleDeclaration.call_setProperty(computed, .initInterned("-webkit-transition"), .initInterned(""), .notPassed()));
    try expectValue(computed, "-webkit-filter", "grayscale(20%)");
}

test "-webkit-filter and -webkit-transition are legacy name aliases" {
    try fresh(aliasCases);
}

test "the aliases are supported properties with webkit-cased attributes" {
    const css = dom.style.css;
    for ([_][]const u8{ "-webkit-filter", "-webkit-transition", "-webkit-transition-delay", "-webkit-transition-duration", "-webkit-transition-property", "-webkit-transition-timing-function" }) |name| {
        if (css.properties.lookup(name) == null) {
            std.debug.print("{s} is not a supported property\n", .{name});
            return error.TestUnexpectedResult;
        }
    }
    var webkit_filter = false;
    var webkit_transition = false;
    for (dom.style.css_attributes.attributes) |a| {
        if (std.mem.eql(u8, a.name, "webkitFilter")) webkit_filter = std.mem.eql(u8, a.property, "-webkit-filter");
        if (std.mem.eql(u8, a.name, "webkitTransition")) webkit_transition = std.mem.eql(u8, a.property, "-webkit-transition");
    }
    try testing.expect(webkit_filter);
    try testing.expect(webkit_transition);
}
