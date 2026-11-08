//! Lane perf2: querySelector, querySelectorAll, matches and closest take
//! fast paths - candidates found through the tree scope's ID map (Blink
//! SelectorQuery's ID lookup), and a parsed selector a document keeps
//! (Blink's SelectorQueryCache) - and every answer is the general walk's.
//! Each path is checked against `dom.selector_matching`'s general entry
//! points (a fresh parse, every descendant walked) on the same inputs:
//! duplicate IDs, an ID element outside the scope or above it, sibling
//! combinators, shadow trees, a disconnected root, quirks mode (IDs compare
//! ASCII case-insensitively, so the exact map cannot answer), and the tree
//! changing between queries.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const sm = dom.selector_matching;

const html_ns = "http://www.w3.org/1999/xhtml";

fn str(value: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(value);
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    body: *runtime.Instance,
    shadow: *runtime.Instance = undefined,
    loose: *runtime.Instance = undefined,
    /// Elements by a name the test gives them.
    named: std.StringHashMapUnmanaged(*runtime.Instance) = .empty,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(testing.allocator, .{});
        self.named = .empty;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        const html = try self.make("html", null, null);
        _ = try interfaces.Node.call_appendChild(self.document, html);
        self.body = try self.make("body", null, null);
        _ = try interfaces.Node.call_appendChild(html, self.body);
        try self.build();
    }

    fn deinit(self: *Fixture) void {
        self.named.deinit(testing.allocator);
        dom.node_creation.destroyUninserted(self.loose);
        interfaces.ShadowRoot.deinit(self.shadow);
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn make(self: *Fixture, tag: []const u8, id: ?[]const u8, class: ?[]const u8) !*runtime.Instance {
        const element = try interfaces.Document.call_createElementNS(self.document, str(html_ns), str(tag), .notPassed());
        errdefer dom.node_creation.destroyUninserted(element);
        if (id) |value| try interfaces.Element.call_setAttribute(element, str("id"), .{ .domstring = str(value) });
        if (class) |value| try interfaces.Element.set_className(element, str(value));
        return element;
    }

    fn add(self: *Fixture, parent: *runtime.Instance, name: ?[]const u8, tag: []const u8, id: ?[]const u8, class: ?[]const u8) !*runtime.Instance {
        const element = try self.make(tag, id, class);
        _ = try interfaces.Node.call_appendChild(parent, element);
        if (name) |key| try self.named.put(testing.allocator, key, element);
        return element;
    }

    fn get(self: *Fixture, name: []const u8) *runtime.Instance {
        return self.named.get(name).?;
    }

    /// The tree every case runs over (each `name` is the test's handle).
    fn build(self: *Fixture) !void {
        const a1 = try self.add(self.body, "a1", "div", "a", "x");
        _ = try self.add(a1, null, "span", null, "y");
        const b = try self.add(a1, "b", "p", "b", "y");
        _ = try self.add(b, null, "i", null, "z");
        const a2 = try self.add(self.body, "a2", "div", "a", "w");
        _ = try self.add(a2, null, "span", null, "y");
        const c = try self.add(self.body, "c", "section", "c", null);
        _ = try self.add(c, null, "div", null, "k");
        const d = try self.add(c, "d", "div", "d", "k");
        _ = try self.add(d, null, "em", null, "z");
        _ = try self.add(c, null, "div", null, "k");
        const outer = try self.add(self.body, "outer", "article", "outer", null);
        const inner = try self.add(outer, "inner", "div", "inner", null);
        _ = try self.add(inner, null, "b", null, "x");
        _ = try self.add(inner, "e", "b", "e", "x");
        _ = try self.add(inner, "E", "b", "E", "x");
        // A shadow tree: its own tree scope, with its own #a.
        const host = try self.add(self.body, "host", "div", "host", null);
        self.shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
        try dom.node_document.set(self.shadow, self.document);
        const sa = try self.add(self.shadow, "sa", "div", "a", "x");
        _ = try self.add(sa, null, "span", null, "y");
        _ = try self.add(self.shadow, null, "span", "b", "y");
        // A tree in no tree scope.
        self.loose = try self.make("div", "loose", null);
        const la = try self.add(self.loose, "la", "div", "a", "x");
        _ = try self.add(la, null, "span", null, "y");
    }

    fn scopes(self: *Fixture) [10]*runtime.Instance {
        return .{ self.document, self.body, self.get("a1"), self.get("c"), self.get("inner"), self.get("d"), self.shadow, self.get("sa"), self.loose, self.get("la") };
    }
};

const selectors = [_][]const u8{
    "#a",          "#b",         "#c",             "#missing",           "#a .y",      "#a > .y",
    "#b .z",       "#c .k",      "#c > div + div", "#d ~ .k",            "#d + .k",    ".k + #d",
    "#d ~ div .z", "#c > #d .z", "#outer #e",      "#outer .x",          "#inner .x",  "div#a",
    "span#a",      "#a, #c",     "#a.w .y",        ":not(#a) .y",        ":is(#a) .y", "#a:first-child",
    "#c :scope",   ":scope #d",  ":scope > #d",    "#e",                 "#E",         "#outer #E",
    "[id=a] .y",   "* #d",       "#a *",           "#host",              "#a #b .z",   "#loose .y",
    "#la .y",      "#sa .y",     "#a ~ #c .k",     "section#c div#d em", ".y",         "div",
    "*",           "span",       ".k.z",           "[class~=x]",
};

fn nodeListItems(list: *runtime.Instance, out: *std.ArrayList(*runtime.Instance)) !void {
    const n = try interfaces.NodeList.get_length(list);
    for (0..n) |i| try out.append(testing.allocator, (try interfaces.NodeList.call_item(list, @intCast(i))).?);
}

fn queryAll(scope: *runtime.Instance, selector: []const u8, out: *std.ArrayList(*runtime.Instance)) !void {
    const node_type = try interfaces.Node.get_nodeType(scope);
    const list = switch (node_type) {
        9 => try interfaces.Document.call_querySelectorAll(scope, str(selector)),
        11 => try interfaces.DocumentFragment.call_querySelectorAll(scope, str(selector)),
        else => try interfaces.Element.call_querySelectorAll(scope, str(selector)),
    };
    defer runtime.gc.onObjectFreed(list);
    try nodeListItems(list, out);
}

fn queryFirst(scope: *runtime.Instance, selector: []const u8) !?*runtime.Instance {
    const node_type = try interfaces.Node.get_nodeType(scope);
    return switch (node_type) {
        9 => try interfaces.Document.call_querySelector(scope, str(selector)),
        11 => try interfaces.DocumentFragment.call_querySelector(scope, str(selector)),
        else => try interfaces.Element.call_querySelector(scope, str(selector)),
    };
}

fn generalAll(scope: *runtime.Instance, selector: []const u8, out: *std.ArrayList(*runtime.Instance)) !void {
    var bases: std.ArrayList(*dom.NodeBase) = .empty;
    defer bases.deinit(testing.allocator);
    try sm.querySelectorAllGeneral(testing.allocator, scope, selector, &bases);
    for (bases.items) |base| try out.append(testing.allocator, @ptrCast(@alignCast(base.ownerInstance().?)));
}

/// Every scope and selector: the query's answers are the general walk's.
fn expectAllAgree(f: *Fixture) !void {
    var fast: std.ArrayList(*runtime.Instance) = .empty;
    defer fast.deinit(testing.allocator);
    var general: std.ArrayList(*runtime.Instance) = .empty;
    defer general.deinit(testing.allocator);
    for (f.scopes()) |scope| {
        for (selectors) |selector| {
            fast.clearRetainingCapacity();
            general.clearRetainingCapacity();
            try queryAll(scope, selector, &fast);
            try generalAll(scope, selector, &general);
            testing.expectEqualSlices(*runtime.Instance, general.items, fast.items) catch |err| {
                std.debug.print("querySelectorAll('{s}') differs from the general walk\n", .{selector});
                return err;
            };
            const first = try queryFirst(scope, selector);
            const expected: ?*runtime.Instance = if (general.items.len > 0) general.items[0] else null;
            testing.expectEqual(expected, first) catch |err| {
                std.debug.print("querySelector('{s}') differs from the general walk\n", .{selector});
                return err;
            };
        }
    }
}

/// Every element of the tree and selector: matches() and closest() answer
/// as a fresh parse does.
fn expectMatchesAgree(f: *Fixture) !void {
    var it = f.named.valueIterator();
    while (it.next()) |element| {
        for (selectors) |selector| {
            const general = try sm.matchesGeneral(element.*, selector);
            testing.expectEqual(general, try interfaces.Element.call_matches(element.*, str(selector))) catch |err| {
                std.debug.print("matches('{s}') differs from a fresh parse\n", .{selector});
                return err;
            };
            testing.expectEqual(try sm.closestGeneral(element.*, selector), try interfaces.Element.call_closest(element.*, str(selector))) catch |err| {
                std.debug.print("closest('{s}') differs from a fresh parse\n", .{selector});
                return err;
            };
        }
    }
}

test "the ID path and the kept parse answer as the general walk, in every scope" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try expectAllAgree(&f);
    // Twice: the second round reads every selector from the document's cache.
    try expectAllAgree(&f);
    try expectMatchesAgree(&f);
}

test "in quirks mode IDs match ASCII case-insensitively, which the exact ID map cannot answer" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try dom.document_internals.setMode(f.document, .quirks);
    try expectAllAgree(&f);
    // #e and #E name two elements; in quirks mode each selector finds both.
    var found: std.ArrayList(*runtime.Instance) = .empty;
    defer found.deinit(testing.allocator);
    try queryAll(f.document, "#E", &found);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try expectMatchesAgree(&f);
}

test "the answers follow the tree as IDs come, go and repeat" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try expectAllAgree(&f);
    // The duplicate #a becomes unique, then gone, then back.
    try interfaces.Element.call_removeAttribute(f.get("a2"), str("id"));
    try expectAllAgree(&f);
    try interfaces.Element.call_setAttribute(f.get("a1"), str("id"), .{ .domstring = str("other") });
    try testing.expectEqual(@as(?*runtime.Instance, null), try queryFirst(f.document, "#a .y"));
    try expectAllAgree(&f);
    try interfaces.Element.call_setAttribute(f.get("a2"), str("id"), .{ .domstring = str("a") });
    try expectAllAgree(&f);
    // An ID element leaves the tree, and comes back somewhere else.
    const d = f.get("d");
    _ = try interfaces.Node.call_removeChild(f.get("c"), d);
    try testing.expectEqual(@as(?*runtime.Instance, null), try queryFirst(f.document, "#d"));
    try expectAllAgree(&f);
    _ = try interfaces.Node.call_appendChild(f.get("inner"), d);
    try expectAllAgree(&f);
    // A second #d, before the first in tree order.
    _ = try interfaces.Node.call_insertBefore(f.body, try f.make("div", "d", "k"), f.get("a1"));
    try expectAllAgree(&f);
    try expectMatchesAgree(&f);
}

test "a document parses a selector string once while it keeps it, and keeps at most 256" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const before = dom.tree_ordered_map.cachedSelectors(f.document);
    _ = try queryFirst(f.document, "#a .y");
    _ = try queryFirst(f.document, "#a .y");
    _ = try interfaces.Element.call_matches(f.get("b"), str("#a .y"));
    try testing.expectEqual(before + 1, dom.tree_ordered_map.cachedSelectors(f.document));
    // An invalid selector throws every time and is not kept.
    for (0..2) |_| try testing.expectError(error.SyntaxError, queryFirst(f.document, "##"));
    try testing.expectError(error.SyntaxError, interfaces.Element.call_matches(f.get("b"), str("a[")));
    try testing.expectEqual(before + 1, dom.tree_ordered_map.cachedSelectors(f.document));
    // Blink's bound: 256 selectors, one entry evicted for each new one past it.
    var buffer: [32]u8 = undefined;
    for (0..300) |i| _ = try queryFirst(f.document, try std.fmt.bufPrint(&buffer, "#n-{d} .leaf", .{i}));
    try testing.expectEqual(@as(usize, 256), dom.tree_ordered_map.cachedSelectors(f.document));
    try expectAllAgree(&f);
}

test "a kept selector owns its text: the caller's string may be freed" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    // The test allocator overwrites what it frees: a selector that borrowed
    // the first string would match against the overwritten bytes.
    const first = try testing.allocator.dupe(u8, "#a > .y");
    var fast: std.ArrayList(*runtime.Instance) = .empty;
    defer fast.deinit(testing.allocator);
    try queryAll(f.document, first, &fast);
    testing.allocator.free(first);
    const second = try testing.allocator.dupe(u8, "#a > .y");
    defer testing.allocator.free(second);
    var again: std.ArrayList(*runtime.Instance) = .empty;
    defer again.deinit(testing.allocator);
    try queryAll(f.document, second, &again);
    try testing.expectEqual(@as(usize, 3), again.items.len);
    try testing.expectEqualSlices(*runtime.Instance, fast.items, again.items);
    try testing.expect(try interfaces.Element.call_matches(f.get("b"), str(second)));
}
