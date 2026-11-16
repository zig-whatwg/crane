//! Selector matching over real elements: Element.matches and
//! Element.querySelectorAll (dom.selector_matching).
//!
//! Lane wb1 (the WithBase retirement, node-memory plan v2 X3). These are the
//! tests of two modules that matched selectors over ElementWithBase values
//! and that nothing in production called:
//!
//! - src/selector/matcher.zig, 38 tests ("Matcher: ..."): an old matcher;
//! - src/dom/selectors.zig, 5 tests ("fast path: ...", "generic path: ..."):
//!   an old querySelectorAll with a fast path of its own.
//!
//! Both modules are deleted. Each test is here under its name, asking
//! production's matcher the same question of the same tree - made by
//! createElement and appendChild instead of linked by hand (real_nodes.zig).
//! One assertion changed, toward the spec: "Matcher: element without parent"
//! (see the test).

const std = @import("std");
const testing = std.testing;
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const real_nodes = @import("real_nodes.zig");

const Instance = real_nodes.Instance;
const str = real_nodes.str;

const Attribute = struct { name: []const u8, value: []const u8 };

/// An HTML document and the elements a test makes in it.
const Tree = struct {
    nodes: real_nodes.Nodes,
    document: *Instance = undefined,

    /// In place (the scope must not move).
    fn open(self: *Tree) !void {
        self.* = .{ .nodes = undefined };
        try self.nodes.open(testing.allocator);
        errdefer self.nodes.close();
        self.document = try self.nodes.document();
    }

    fn close(self: *Tree) void {
        self.nodes.close();
    }

    fn element(self: *Tree, tag_name: []const u8) !*Instance {
        return self.nodes.element(self.document, tag_name);
    }

    fn elementWith(self: *Tree, tag_name: []const u8, attributes: []const Attribute) !*Instance {
        const made = try self.element(tag_name);
        for (attributes) |attribute| try self.nodes.setAttribute(made, attribute.name, attribute.value);
        return made;
    }

    /// `parent` with `children` appended in order.
    fn link(self: *Tree, parent: *Instance, children: []const *Instance) !void {
        for (children) |child| try self.nodes.append(parent, child);
    }
};

fn matches(element: *Instance, selector: []const u8) !bool {
    return interfaces.Element.call_matches(element, str(selector));
}

/// `root.querySelectorAll(selector)`, as the elements it holds.
fn queryAll(root: *Instance, selector: []const u8, buffer: []*Instance) ![]*Instance {
    const list = try interfaces.Element.call_querySelectorAll(root, str(selector));
    // A static NodeList is the caller's: freed as its collection would.
    defer runtime.gc.onObjectFreed(list);
    const length = try interfaces.NodeList.get_length(list);
    for (0..length) |index| buffer[index] = (try interfaces.NodeList.call_item(list, @intCast(index))).?;
    return buffer[0..length];
}

// ============================================================================
// src/selector/matcher.zig's tests
// ============================================================================

test "Matcher: universal selector (*)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    try testing.expect(try matches(try tree.element("div"), "*"));
}

test "Matcher: type selector" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    try testing.expect(try matches(try tree.element("div"), "div"));
    try testing.expect(!try matches(try tree.element("span"), "div"));
}

test "Matcher: class selector" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "container active" }});
    try testing.expect(try matches(elem, ".container"));
}

test "Matcher: class selector - multiple classes" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "foo bar baz" }});
    try testing.expect(try matches(elem, ".bar"));
}

test "Matcher: class selector - no match" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "container" }});
    try testing.expect(!try matches(elem, ".active"));
}

test "Matcher: ID selector" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "id", .value = "main" }});
    try testing.expect(try matches(elem, "#main"));
}

test "Matcher: ID selector - no match" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "id", .value = "main" }});
    try testing.expect(!try matches(elem, "#sidebar"));
}

test "Matcher: compound selector (tag + class)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "container" }});
    try testing.expect(try matches(elem, "div.container"));
}

test "Matcher: compound selector (tag + id)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "id", .value = "main" }});
    try testing.expect(try matches(elem, "div#main"));
}

test "Matcher: compound selector (tag + multiple classes)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "container active highlight" }});
    try testing.expect(try matches(elem, "div.container.active"));
}

test "Matcher: compound selector - wrong tag" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("span", &.{.{ .name = "class", .value = "container" }});
    try testing.expect(!try matches(elem, "div.container"));
}

test "Matcher: attribute presence [attr]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("input", &.{.{ .name = "disabled", .value = "" }});
    try testing.expect(try matches(elem, "[disabled]"));
}

test "Matcher: attribute exact [attr=value]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("input", &.{.{ .name = "type", .value = "text" }});
    try testing.expect(try matches(elem, "[type=text]"));
}

test "Matcher: attribute prefix [attr^=value]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("a", &.{.{ .name = "href", .value = "https://example.com" }});
    try testing.expect(try matches(elem, "[href^=https]"));
}

test "Matcher: attribute suffix [attr$=value]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("a", &.{.{ .name = "href", .value = "document.pdf" }});
    try testing.expect(try matches(elem, "[href$='.pdf']"));
}

test "Matcher: attribute substring [attr*=value]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "data-id", .value = "user-123-profile" }});
    try testing.expect(try matches(elem, "[data-id*='123']"));
}

test "Matcher: attribute includes [attr~=value]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "data-tags", .value = "important featured new" }});
    try testing.expect(try matches(elem, "[data-tags~=featured]"));
}

test "Matcher: attribute dash [attr|=value]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "lang", .value = "en-US" }});
    try testing.expect(try matches(elem, "[lang|=en]"));
}

test "Matcher: attribute case-insensitive [attr=value i]" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("input", &.{.{ .name = "type", .value = "TEXT" }});
    try testing.expect(try matches(elem, "[type=text i]"));
}

test "Matcher: child combinator (>)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("article");
    const child = try tree.element("p");
    try tree.link(parent, &.{child});
    try testing.expect(try matches(child, "article > p"));
}

test "Matcher: descendant combinator (space)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const grandparent = try tree.element("div");
    const parent = try tree.element("section");
    const child = try tree.element("p");
    try tree.link(grandparent, &.{parent});
    try tree.link(parent, &.{child});
    try testing.expect(try matches(child, "div p"));
}

test "Matcher: next-sibling combinator (+)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("div");
    const sibling1 = try tree.element("h1");
    const sibling2 = try tree.element("p");
    try tree.link(parent, &.{ sibling1, sibling2 });
    try testing.expect(try matches(sibling2, "h1 + p"));
}

test "Matcher: subsequent-sibling combinator (~)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("div");
    const sibling1 = try tree.element("h1");
    const sibling2 = try tree.element("span");
    const sibling3 = try tree.element("p");
    try tree.link(parent, &.{ sibling1, sibling2, sibling3 });
    try testing.expect(try matches(sibling3, "h1 ~ p"));
}

test "Matcher: :first-child" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("div");
    const child1 = try tree.element("p");
    const child2 = try tree.element("p");
    try tree.link(parent, &.{ child1, child2 });
    try testing.expect(try matches(child1, "p:first-child"));
    try testing.expect(!try matches(child2, "p:first-child"));
}

test "Matcher: :last-child" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("div");
    const child1 = try tree.element("p");
    const child2 = try tree.element("p");
    try tree.link(parent, &.{ child1, child2 });
    try testing.expect(!try matches(child1, "p:last-child"));
    try testing.expect(try matches(child2, "p:last-child"));
}

test "Matcher: :only-child" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("div");
    const child = try tree.element("p");
    try tree.link(parent, &.{child});
    try testing.expect(try matches(child, "p:only-child"));
}

test "Matcher: :empty" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const empty_elem = try tree.element("div");
    const non_empty = try tree.element("div");
    try tree.link(non_empty, &.{try tree.element("span")});
    try testing.expect(try matches(empty_elem, "div:empty"));
    try testing.expect(!try matches(non_empty, "div:empty"));
}

test "Matcher: :nth-child(2)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("ul");
    const child1 = try tree.element("li");
    const child2 = try tree.element("li");
    const child3 = try tree.element("li");
    try tree.link(parent, &.{ child1, child2, child3 });
    try testing.expect(!try matches(child1, "li:nth-child(2)"));
    try testing.expect(try matches(child2, "li:nth-child(2)"));
    try testing.expect(!try matches(child3, "li:nth-child(2)"));
}

test "Matcher: :nth-child(odd)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const parent = try tree.element("ul");
    const child1 = try tree.element("li");
    const child2 = try tree.element("li");
    const child3 = try tree.element("li");
    try tree.link(parent, &.{ child1, child2, child3 });
    try testing.expect(try matches(child1, "li:nth-child(odd)")); // 1st = odd
    try testing.expect(!try matches(child2, "li:nth-child(odd)")); // 2nd = even
    try testing.expect(try matches(child3, "li:nth-child(odd)")); // 3rd = odd
}

test "Matcher: :not(selector)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    try testing.expect(try matches(try tree.element("div"), ":not(span)"));
    try testing.expect(!try matches(try tree.element("span"), ":not(span)"));
}

test "Matcher: :is(selector, selector)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    try testing.expect(try matches(try tree.element("div"), ":is(div, span)"));
    try testing.expect(try matches(try tree.element("span"), ":is(div, span)"));
    try testing.expect(!try matches(try tree.element("p"), ":is(div, span)"));
}

test "Matcher: selector list (comma-separated)" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    try testing.expect(try matches(try tree.element("div"), "div, span"));
    try testing.expect(try matches(try tree.element("span"), "div, span"));
    try testing.expect(!try matches(try tree.element("p"), "div, span"));
}

test "Matcher: deeply nested selectors" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    var chain: [6]*Instance = undefined;
    for (&chain, [_][]const u8{ "html", "body", "div", "article", "section", "p" }) |*slot, name| slot.* = try tree.element(name);
    for (chain[0..5], chain[1..6]) |parent, child| try tree.link(parent, &.{child});
    try testing.expect(try matches(chain[5], "html body div article section p"));
}

test "Matcher: element without parent" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const orphan = try tree.element("div");
    // CHANGED with the move to production's matcher. The old matcher said a
    // parentless element is not `:first-child`, as Selectors 3 worded it (a
    // child of some other element). Selectors 4's child-indexed
    // pseudo-classes are defined on an element's index among its siblings
    // and no longer need a parent (WPT css/selectors/
    // child-indexed-no-parent.html holds that for the root element).
    // Production counts the siblings before and after: an orphan has none.
    try testing.expect(try matches(orphan, ":first-child"));
    try testing.expect(try matches(orphan, ":last-child"));
    // What stays true of an orphan: it is the child of nothing.
    try testing.expect(!try matches(orphan, "* > div"));
}

test "Matcher: element without class attribute" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    try testing.expect(!try matches(try tree.element("div"), ".someclass"));
}

test "Matcher: empty class attribute" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "" }});
    try testing.expect(!try matches(elem, ".foo"));
}

test "Matcher: class with extra whitespace" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "class", .value = "  foo   bar  " }});
    try testing.expect(try matches(elem, ".foo"));
}

test "Matcher: :lang() pseudo-class" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const elem = try tree.elementWith("div", &.{.{ .name = "lang", .value = "en-US" }});
    try testing.expect(try matches(elem, ":lang(en)"));
}

// ============================================================================
// src/dom/selectors.zig's tests (scope-match a selectors string)
// ============================================================================

test "fast path: simple tag selector" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    // Build tree: div > span + span + p
    const div = try tree.element("div");
    const span1 = try tree.element("span");
    const span2 = try tree.element("span");
    try tree.link(div, &.{ span1, span2, try tree.element("p") });

    // Query for "span" returns both spans, in tree order
    var buffer: [4]*Instance = undefined;
    try testing.expectEqualSlices(*Instance, &.{ span1, span2 }, try queryAll(div, "span", &buffer));
}

test "fast path: simple tag selector case-insensitive" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const root = try tree.element("div");
    const span = try tree.element("SPAN");
    try tree.link(root, &.{span});

    // An HTML element in an HTML document: "span" and "SPAN" both name it
    var buffer: [4]*Instance = undefined;
    try testing.expectEqualSlices(*Instance, &.{span}, try queryAll(root, "span", &buffer));
    try testing.expectEqualSlices(*Instance, &.{span}, try queryAll(root, "SPAN", &buffer));
}

test "fast path: simple class selector" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const root = try tree.element("div");
    const elem1 = try tree.elementWith("span", &.{.{ .name = "class", .value = "highlight active" }});
    const elem2 = try tree.elementWith("div", &.{.{ .name = "class", .value = "container" }});
    const elem3 = try tree.elementWith("p", &.{.{ .name = "class", .value = "active note" }});
    try tree.link(root, &.{ elem1, elem2, elem3 });

    // Query for ".active" returns elem1 and elem3
    var buffer: [4]*Instance = undefined;
    try testing.expectEqualSlices(*Instance, &.{ elem1, elem3 }, try queryAll(root, ".active", &buffer));
}

test "fast path: simple id selector" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const root = try tree.element("div");
    const elem1 = try tree.elementWith("span", &.{.{ .name = "id", .value = "main" }});
    const elem2 = try tree.elementWith("div", &.{.{ .name = "id", .value = "sidebar" }});
    try tree.link(root, &.{ elem1, elem2 });

    // Query for "#main" returns only elem1
    var buffer: [4]*Instance = undefined;
    try testing.expectEqualSlices(*Instance, &.{elem1}, try queryAll(root, "#main", &buffer));
}

test "generic path: complex selector falls back to full parser" {
    var tree: Tree = undefined;
    try tree.open();
    defer tree.close();
    const root = try tree.element("div");
    const article = try tree.element("article");
    const p_elem = try tree.element("p");
    try tree.link(root, &.{article});
    try tree.link(article, &.{p_elem});

    var buffer: [4]*Instance = undefined;
    try testing.expectEqualSlices(*Instance, &.{p_elem}, try queryAll(root, "article > p", &buffer));
}
