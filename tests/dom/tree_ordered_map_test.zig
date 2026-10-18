//! The tree scopes' ID and named-property maps (dom.tree_ordered_map):
//! getElementById, and the Document's and Window's named properties, answer
//! from maps a Document and each ShadowRoot keep, which must stay EXACT
//! through every way a node enters or leaves a tree scope - insertion,
//! removal, moveBefore, adoption, id and name changes, a shadow root's
//! attachment, innerHTML, cloning - or, when an allocation fails while they
//! change, give way to a walk of the tree until they can be rebuilt.
//!
//! Each check compares the maps' answer for every key with a walk of the
//! tree written here, apart from the module: elements read through
//! dom.element_data, the tree through NodeBase's links, HTML's rules for
//! "named element" (3.1.7) and "named objects" (7.2.2.3) restated.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const map = dom.tree_ordered_map;
const NodeBase = dom.NodeBase;

const html_ns = "http://www.w3.org/1999/xhtml";
const svg_ns = "http://www.w3.org/2000/svg";

fn str(value: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(value);
}

fn base(instance: *runtime.Instance) *NodeBase {
    return dom.instance_bridge.getNodeBase(instance).?;
}

fn element(document: *runtime.Instance, namespace: []const u8, local_name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, str(namespace), str(local_name), .notPassed());
}

fn setAttribute(target: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(target, str(name), .{ .domstring = str(value) });
}

fn removeAttribute(target: *runtime.Instance, name: []const u8) !void {
    try interfaces.Element.call_removeAttribute(target, str(name));
}

fn append(parent: *runtime.Instance, child: *runtime.Instance) !void {
    _ = try interfaces.Node.call_appendChild(parent, child);
}

// =============================================================================
// The reference walk
// =============================================================================

/// HTML's rules, restated: does `node` have `key` as a `kind`?
fn refHasKey(node: *NodeBase, kind: map.Kind, key: []const u8) bool {
    if (node.node_type != NodeBase.ELEMENT_NODE) return false;
    const instance: *runtime.Instance = @ptrCast(@alignCast(node.owner_instance orelse return false));
    const data = dom.element_data.of(instance) orelse return false;
    const id = data.id.asSlice();
    const is_html = if (data.namespace_uri) |ns| std.mem.eql(u8, ns.asSlice(), html_ns) else false;
    const local = data.local_name.asSlice();
    const name: []const u8 = if (dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "name")) |a| a.value else "";
    const is = struct {
        fn any(l: []const u8, comptime names: []const []const u8) bool {
            inline for (names) |n| if (std.mem.eql(u8, l, n)) return true;
            return false;
        }
    };
    const by_id = std.mem.eql(u8, id, key);
    const by_name = std.mem.eql(u8, name, key);
    return switch (kind) {
        .id => by_id,
        // "an embed, form, iframe, img, or object element whose name content
        // attribute's value is name; an object element whose id content
        // attribute's value is name; or an img element whose id content
        // attribute's value is name, and that has a non-empty name content
        // attribute present also."
        .document_named => is_html and ((is.any(local, &.{ "embed", "form", "iframe", "img", "object" }) and by_name) or
            (std.mem.eql(u8, local, "object") and by_id) or
            (std.mem.eql(u8, local, "img") and by_id and name.len > 0)),
        // "embed, form, img, or object elements that have a name content
        // attribute whose value is name ...; and elements whose ID is name".
        .window_named => (is_html and is.any(local, &.{ "embed", "form", "img", "object" }) and by_name) or by_id,
    };
}

fn refNext(node: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var at = node;
    while (at != root) {
        if (at.next_sibling) |sibling| return sibling;
        at = at.parent_node orelse return null;
    }
    return null;
}

/// The elements of `root`'s light tree with `key` as a `kind`, in tree order.
fn refElements(root: *runtime.Instance, kind: map.Kind, key: []const u8, out: *std.ArrayList(*runtime.Instance)) !void {
    out.clearRetainingCapacity();
    const root_base = base(root);
    var at = root_base.first_child;
    while (at) |node| : (at = refNext(node, root_base)) {
        if (refHasKey(node, kind, key)) try out.append(testing.allocator, @ptrCast(@alignCast(node.owner_instance.?)));
    }
}

const keys = [_][]const u8{ "a", "b", "c" };

/// Every key of every kind `scope` keeps answers what the walk finds: the
/// maps' list, getElementById's first and the named readers' first and count.
fn expectExact(scope: *runtime.Instance, is_document: bool) !void {
    var expected: std.ArrayList(*runtime.Instance) = .empty;
    defer expected.deinit(testing.allocator);
    const kinds: []const map.Kind = if (is_document) &.{ .id, .document_named, .window_named } else &.{.id};
    for (kinds) |kind| {
        for (keys) |key| {
            try refElements(scope, kind, key, &expected);
            const actual = try map.elementsFor(scope, kind, key, testing.allocator);
            defer testing.allocator.free(actual);
            testing.expectEqualSlices(*runtime.Instance, expected.items, actual) catch |err| {
                std.debug.print("kind {s} key {s}: expected {d} elements, the maps answer {d}\n", .{ @tagName(kind), key, expected.items.len, actual.len });
                return err;
            };
            const first: ?*runtime.Instance = if (expected.items.len > 0) expected.items[0] else null;
            switch (kind) {
                .id => {
                    const by_id = if (is_document)
                        try interfaces.Document.call_getElementById(scope, str(key))
                    else
                        try interfaces.DocumentFragment.call_getElementById(scope, str(key));
                    try testing.expectEqual(first, by_id);
                },
                .document_named, .window_named => {
                    const named_kind: map.NamedKind = if (kind == .document_named) .document else .window;
                    const answer = map.named(scope, named_kind, key);
                    try testing.expectEqual(@min(expected.items.len, 2), @min(answer.count, 2));
                    if (expected.items.len == 1) try testing.expectEqual(first, answer.first);
                    try testing.expectEqual(expected.items.len > 0, map.isNamed(scope, named_kind, key));
                },
            }
        }
    }
}

fn expectIndexed(scope: *runtime.Instance) !void {
    const state = map.inspect(scope, .id, "a") orelse return error.NotATreeScope;
    try testing.expect(!state.degraded);
}

// =============================================================================
// Fixtures
// =============================================================================

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    html: *runtime.Instance,
    body: *runtime.Instance,

    fn init(self: *Fixture, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(allocator, .{});
        self.document = try newDocument(allocator, &self.ctx);
        self.html = (try interfaces.Node.get_firstChild(self.document)).?;
        self.body = (try interfaces.Node.get_lastChild(self.html)).?;
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

/// An HTML document with an html element and a body.
fn newDocument(allocator: std.mem.Allocator, ctx: *runtime.ContextData) !*runtime.Instance {
    const document = try interfaces.Document.init(allocator, ctx);
    errdefer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const html = try element(document, html_ns, "html");
    try append(document, html);
    try append(html, try element(document, html_ns, "body"));
    return document;
}

// =============================================================================
// Item 1: the maps follow the tree
// =============================================================================

test "a document keeps its elements' IDs: insertion, duplicates in tree order, id changes, removal" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const first = try element(f.document, html_ns, "div");
    const second = try element(f.document, html_ns, "span");
    try setAttribute(first, "id", "a");
    try setAttribute(second, "id", "a");
    try append(f.body, second);
    // Indexed at the insertion, before any reader asked.
    try testing.expectEqual(@as(u32, 1), map.inspect(f.document, .id, "a").?.count);
    try testing.expect(map.inspect(f.document, .id, "a").?.first_known);
    _ = try interfaces.Node.call_insertBefore(f.body, first, second);
    try testing.expectEqual(@as(u32, 2), map.inspect(f.document, .id, "a").?.count);
    // A second element forgets the first; the reader finds it in tree order.
    try testing.expect(!map.inspect(f.document, .id, "a").?.first_known);
    try expectExact(f.document, true);
    try testing.expect(map.inspect(f.document, .id, "a").?.first_known);
    try setAttribute(first, "id", "b");
    try expectExact(f.document, true);
    try removeAttribute(second, "id");
    try testing.expectEqual(@as(u32, 0), map.inspect(f.document, .id, "a").?.count);
    try expectExact(f.document, true);
    _ = try interfaces.Node.call_removeChild(f.body, first);
    defer dom.node_creation.destroyUninserted(first);
    try testing.expectEqual(@as(usize, 0), map.inspect(f.document, .id, "b").?.keys);
    try expectExact(f.document, true);
    try expectIndexed(f.document);
}

test "a shadow root keeps its own tree's IDs, apart from its host's document" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const host = try element(f.document, html_ns, "div");
    try append(f.body, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    defer interfaces.ShadowRoot.deinit(shadow);
    try dom.node_document.set(shadow, f.document);
    const inner = try element(f.document, html_ns, "p");
    try setAttribute(inner, "id", "a");
    try append(shadow, inner);
    try testing.expectEqual(@as(u32, 1), map.inspect(shadow, .id, "a").?.count);
    try testing.expectEqual(@as(u32, 0), map.inspect(f.document, .id, "a").?.count);
    try expectExact(shadow, false);
    try expectExact(f.document, true);
    // Its host leaving the document moves nothing in the shadow tree's map.
    _ = try interfaces.Node.call_removeChild(f.body, host);
    try testing.expectEqual(@as(u32, 1), map.inspect(shadow, .id, "a").?.count);
    try expectExact(shadow, false);
    try append(f.body, host);
    try testing.expectEqual(@as(u32, 1), map.inspect(shadow, .id, "a").?.count);
    // Into the document tree, and back.
    try interfaces.ParentNode.call_moveBefore(f.body, inner, null);
    try testing.expectEqual(@as(u32, 0), map.inspect(shadow, .id, "a").?.count);
    try testing.expectEqual(@as(u32, 1), map.inspect(f.document, .id, "a").?.count);
    try expectExact(shadow, false);
    try expectExact(f.document, true);
    try interfaces.ParentNode.call_moveBefore(shadow, inner, null);
    try expectExact(shadow, false);
    try expectExact(f.document, true);
    try expectIndexed(shadow);
}

test "a plain DocumentFragment keeps no map and getElementById walks it" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const fragment = try interfaces.Document.call_createDocumentFragment(f.document);
    defer interfaces.DocumentFragment.deinit(fragment);
    const inner = try element(f.document, html_ns, "p");
    try setAttribute(inner, "id", "a");
    try append(fragment, inner);
    try testing.expectEqual(@as(?map.Inspection, null), map.inspect(fragment, .id, "a"));
    try testing.expectEqual(@as(?*runtime.Instance, inner), try interfaces.DocumentFragment.call_getElementById(fragment, str("a")));
    try testing.expectEqual(@as(u32, 0), map.inspect(f.document, .id, "a").?.count);
}

test "adoption takes elements out of the old document's maps; insertion puts them in the new one's" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const other = try newDocument(testing.allocator, &f.ctx);
    defer interfaces.Document.deinit(other);
    const object = try element(f.document, html_ns, "object");
    try setAttribute(object, "id", "a");
    try append(f.body, object);
    try testing.expectEqual(@as(u32, 1), map.inspect(f.document, .document_named, "a").?.count);
    _ = try interfaces.Document.call_adoptNode(other, object);
    try testing.expectEqual(@as(u32, 0), map.inspect(f.document, .document_named, "a").?.count);
    try testing.expectEqual(@as(u32, 0), map.inspect(other, .document_named, "a").?.count);
    const other_body = (try interfaces.Node.get_lastChild((try interfaces.Node.get_firstChild(other)).?)).?;
    try append(other_body, object);
    try testing.expectEqual(@as(u32, 1), map.inspect(other, .document_named, "a").?.count);
    try expectExact(f.document, true);
    try expectExact(other, true);
}

test "an img's ID names it in the document only while it has a non-empty name" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const img = try element(f.document, html_ns, "img");
    try setAttribute(img, "id", "a");
    try append(f.body, img);
    try testing.expect(!map.isNamed(f.document, .document, "a"));
    try testing.expect(map.isNamed(f.document, .window, "a"));
    try setAttribute(img, "name", "b");
    try testing.expect(map.isNamed(f.document, .document, "a"));
    try testing.expect(map.isNamed(f.document, .document, "b"));
    try setAttribute(img, "name", "");
    try testing.expect(!map.isNamed(f.document, .document, "a"));
    try expectExact(f.document, true);
    // A foreign element and a differently cased local name are no img.
    const svg_img = try element(f.document, svg_ns, "img");
    try setAttribute(svg_img, "name", "c");
    try append(f.body, svg_img);
    const upper = try element(f.document, html_ns, "IMG");
    try setAttribute(upper, "name", "c");
    try append(f.body, upper);
    try testing.expect(!map.isNamed(f.document, .document, "c"));
    try testing.expect(!map.isNamed(f.document, .window, "c"));
    try expectExact(f.document, true);
}

test "inserting and removing a subtree indexes its light tree and leaves its shadow trees alone" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const outer = try element(f.document, html_ns, "section");
    const host = try element(f.document, html_ns, "div");
    try append(outer, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._closed_ });
    defer interfaces.ShadowRoot.deinit(shadow);
    try dom.node_document.set(shadow, f.document);
    const hidden = try element(f.document, html_ns, "form");
    try setAttribute(hidden, "name", "a");
    try setAttribute(hidden, "id", "b");
    try append(shadow, hidden);
    const light = try element(f.document, html_ns, "form");
    try setAttribute(light, "name", "a");
    try append(host, light);
    try append(f.body, outer);
    try testing.expectEqual(@as(u32, 1), map.inspect(f.document, .document_named, "a").?.count);
    try testing.expectEqual(@as(u32, 0), map.inspect(f.document, .id, "b").?.count);
    try testing.expectEqual(@as(u32, 1), map.inspect(shadow, .id, "b").?.count);
    try expectExact(f.document, true);
    try expectExact(shadow, false);
    _ = try interfaces.Node.call_removeChild(f.body, outer);
    defer dom.node_creation.destroyUninserted(outer);
    try testing.expectEqual(@as(usize, 0), map.inspect(f.document, .id, "a").?.keys);
    try testing.expectEqual(@as(u32, 1), map.inspect(shadow, .id, "b").?.count);
    try expectExact(f.document, true);
    try expectExact(shadow, false);
}

test "innerHTML and cloning index what they insert, and replace-all takes out what it removes" {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    const container = try element(f.document, html_ns, "div");
    try append(f.body, container);
    try interfaces.Element.set_innerHTML(container, .{ .domstring = str("<img id=a name=b><form name=a><div id=c><object id=b></object></div></form>") });
    try expectExact(f.document, true);
    try testing.expectEqual(@as(u32, 2), map.inspect(f.document, .document_named, "a").?.count);
    const copy = try interfaces.Node.call_cloneNode(container, .{ .was_passed = true, .value = true });
    try append(f.body, copy);
    try expectExact(f.document, true);
    try testing.expectEqual(@as(u32, 4), map.inspect(f.document, .document_named, "a").?.count);
    // Replace-all: the old children leave the maps with their removal.
    var old: std.ArrayList(*runtime.Instance) = .empty;
    defer old.deinit(testing.allocator);
    var child = try interfaces.Node.get_firstChild(container);
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) try old.append(testing.allocator, c);
    try interfaces.Element.set_innerHTML(container, .{ .domstring = str("<p id=a></p>") });
    for (old.items) |c| dom.node_creation.destroyUninserted(c);
    try expectExact(f.document, true);
    try testing.expectEqual(@as(u32, 2), map.inspect(f.document, .document_named, "a").?.count);
    try expectIndexed(f.document);
}

// =============================================================================
// Exact or walk: an allocation that fails while the maps change
// =============================================================================

/// An allocator that fails its `fail_at`-th allocation, and only that one.
const OneFailure = struct {
    inner: std.mem.Allocator,
    fail_at: usize,
    index: usize = 0,
    failed: bool = false,

    fn allocator(self: *OneFailure) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *OneFailure = @ptrCast(@alignCast(ctx));
        defer self.index += 1;
        if (self.index == self.fail_at) {
            self.failed = true;
            return null;
        }
        return self.inner.rawAlloc(len, alignment, ra);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *OneFailure = @ptrCast(@alignCast(ctx));
        return self.inner.rawResize(memory, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *OneFailure = @ptrCast(@alignCast(ctx));
        return self.inner.rawRemap(memory, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *OneFailure = @ptrCast(@alignCast(ctx));
        self.inner.rawFree(memory, alignment, ra);
    }
};

/// The OOM scenario: the maps' allocations come from `failing`; the DOM's
/// own from the testing allocator. Returns whether the failure degraded the
/// maps at some step (it must leave them exact or walking either way).
fn oomScenario(failing: *OneFailure) !bool {
    var f: Fixture = undefined;
    try f.init(testing.allocator);
    defer f.deinit();
    map.useAllocatorForTest(f.document, failing.allocator());
    var degraded = false;
    var made: [6]*runtime.Instance = undefined;
    const tags = [_][]const u8{ "img", "form", "div", "object", "img", "embed" };
    for (&made, tags, 0..) |*slot, tag, i| {
        slot.* = try element(f.document, html_ns, tag);
        try setAttribute(slot.*, "id", keys[i % 3]);
        try setAttribute(slot.*, "name", keys[(i + 1) % 3]);
        try append(f.body, slot.*);
        if (map.inspect(f.document, .id, "a").?.degraded) degraded = true;
        try expectExact(f.document, true);
    }
    for (made, 0..) |el, i| {
        try setAttribute(el, "id", keys[(i + 2) % 3]);
        if (map.inspect(f.document, .id, "a").?.degraded) degraded = true;
        try expectExact(f.document, true);
        try setAttribute(el, "name", "");
        if (map.inspect(f.document, .id, "a").?.degraded) degraded = true;
        try expectExact(f.document, true);
    }
    _ = try interfaces.Node.call_removeChild(f.body, made[2]);
    defer dom.node_creation.destroyUninserted(made[2]);
    if (map.inspect(f.document, .id, "a").?.degraded) degraded = true;
    try expectExact(f.document, true);
    try expectIndexed(f.document);
    return degraded;
}

test "an allocation that fails while the maps change leaves them exact or walking, and rebuilt by the next reader" {
    // How many allocations the maps make in the scenario.
    var dry: OneFailure = .{ .inner = testing.allocator, .fail_at = std.math.maxInt(usize) };
    try testing.expect(!try oomScenario(&dry));
    try testing.expect(dry.index > 0);
    var degraded_runs: usize = 0;
    for (0..dry.index) |fail_at| {
        var failing: OneFailure = .{ .inner = testing.allocator, .fail_at = fail_at };
        if (try oomScenario(&failing)) degraded_runs += 1;
        try testing.expect(failing.failed);
    }
    // The failures inside a change degraded the maps (others - an ordered
    // list a reader builds - only made that reader walk).
    try testing.expect(degraded_runs > 0);
}

// =============================================================================
// Randomized: every operation, every key, against the walk
// =============================================================================

const Random = struct {
    f: Fixture = undefined,
    other: *runtime.Instance = undefined,
    other_body: *runtime.Instance = undefined,
    park: *runtime.Instance = undefined,
    scratch: *runtime.Instance = undefined,
    /// A shadow root no pool element enters, for innerHTML.
    scratch_shadow: *runtime.Instance = undefined,
    clones: *runtime.Instance = undefined,
    pool: [32]*runtime.Instance = undefined,
    /// The shadow roots, each with its host: s1's host is in the document,
    /// s2's in the detached park; more are attached to pool elements.
    shadows: std.ArrayList(*runtime.Instance) = .empty,
    containers: std.ArrayList(*runtime.Instance) = .empty,
    clone_count: usize = 0,
    rng: std.Random.DefaultPrng,

    const tags = [_][]const u8{ "div", "span", "img", "form", "object", "iframe", "embed", "p" };

    fn init(self: *Random) !void {
        try self.f.init(testing.allocator);
        const d = self.f.document;
        self.other = try newDocument(testing.allocator, &self.f.ctx);
        self.other_body = (try interfaces.Node.get_lastChild((try interfaces.Node.get_firstChild(self.other)).?)).?;
        self.park = try element(d, html_ns, "div");
        self.scratch = try element(d, html_ns, "div");
        try append(self.f.body, self.scratch);
        self.clones = try element(d, html_ns, "div");
        try append(self.f.body, self.clones);
        try self.containers.appendSlice(testing.allocator, &.{ self.f.body, self.park, self.other_body });
        const host1 = try element(d, html_ns, "div");
        try append(self.f.body, host1);
        try self.attach(host1);
        const host2 = try element(d, html_ns, "div");
        try append(self.park, host2);
        try self.attach(host2);
        const host3 = try element(d, html_ns, "div");
        try append(self.f.body, host3);
        try self.attach(host3);
        // Not a container: innerHTML replaces what it holds.
        self.scratch_shadow = self.containers.pop().?;
        const random = self.rng.random();
        for (&self.pool) |*slot| {
            const tag = tags[random.uintLessThan(usize, tags.len)];
            const namespace = if (random.uintLessThan(u8, 8) == 0) svg_ns else html_ns;
            slot.* = try element(d, namespace, tag);
            try append(self.park, slot.*);
            try self.containers.append(testing.allocator, slot.*);
        }
    }

    fn attach(self: *Random, host: *runtime.Instance) !void {
        const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
        errdefer interfaces.ShadowRoot.deinit(shadow);
        try dom.node_document.set(shadow, try interfaces.Node.get_ownerDocument(host) orelse self.f.document);
        try self.shadows.append(testing.allocator, shadow);
        try self.containers.append(testing.allocator, shadow);
    }

    /// Frees each tree once: the documents, the park, then each shadow root
    /// after its host (its host's teardown tells it).
    fn deinit(self: *Random) void {
        const other_base = base(self.other);
        const park_base = base(self.park);
        const document_base = base(self.f.document);
        // Where each shadow root's host is, before anything goes.
        const roots = testing.allocator.alloc(*NodeBase, self.shadows.items.len) catch unreachable;
        defer testing.allocator.free(roots);
        for (self.shadows.items, roots) |shadow, *root| {
            const host = interfaces.ShadowRoot.get_host(shadow) catch unreachable;
            var at = base(host);
            while (at.parent_node) |parent| at = parent;
            root.* = at;
        }
        const done = testing.allocator.alloc(bool, self.shadows.items.len) catch unreachable;
        defer testing.allocator.free(done);
        @memset(done, false);
        interfaces.Document.deinit(self.other);
        dom.node_creation.destroyUninserted(self.park);
        // The fixture's document goes last, with its context.
        var freed: std.ArrayList(*NodeBase) = .empty;
        defer freed.deinit(testing.allocator);
        freed.appendSlice(testing.allocator, &.{ other_base, park_base }) catch unreachable;
        // The fixture's document is freed by f.deinit below; free it now in
        // the order instead, so shadow roots hosted there wait for it.
        interfaces.Document.deinit(self.f.document);
        freed.append(testing.allocator, document_base) catch unreachable;
        var progress = true;
        while (progress) {
            progress = false;
            for (self.shadows.items, roots, done) |shadow, root, *is_done| {
                if (is_done.*) continue;
                const host_gone = for (freed.items) |gone| {
                    if (gone == root) break true;
                } else false;
                if (!host_gone) continue;
                freed.append(testing.allocator, base(shadow)) catch unreachable;
                interfaces.ShadowRoot.deinit(shadow);
                is_done.* = true;
                progress = true;
            }
        }
        for (done) |is_done| std.debug.assert(is_done);
        self.shadows.deinit(testing.allocator);
        self.containers.deinit(testing.allocator);
        self.f.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn pick(self: *Random, comptime T: type, items: []const T) T {
        return items[self.rng.random().uintLessThan(usize, items.len)];
    }

    /// One random operation; a DOM exception (a hierarchy the operation
    /// would break) is an answer, not a failure.
    fn step(self: *Random) !void {
        const random = self.rng.random();
        const el = self.pick(*runtime.Instance, &self.pool);
        switch (random.uintLessThan(u8, 10)) {
            0 => _ = interfaces.Node.call_appendChild(self.pick(*runtime.Instance, self.containers.items), el) catch {},
            1 => {
                const parent = self.pick(*runtime.Instance, self.containers.items);
                const reference = interfaces.Node.get_firstChild(parent) catch null;
                _ = interfaces.Node.call_insertBefore(parent, el, reference) catch {};
            },
            2 => _ = interfaces.Node.call_appendChild(self.park, el) catch {},
            3 => {
                const value = self.pick([]const u8, &.{ "a", "b", "c", "" });
                if (random.boolean()) try setAttribute(el, "id", value) else try removeAttribute(el, "id");
            },
            4 => {
                const value = self.pick([]const u8, &.{ "a", "b", "c", "" });
                if (random.boolean()) try setAttribute(el, "name", value) else try removeAttribute(el, "name");
            },
            5 => interfaces.ParentNode.call_moveBefore(self.pick(*runtime.Instance, self.containers.items), el, null) catch {},
            6 => {
                const to = if (random.boolean()) self.other else self.f.document;
                _ = interfaces.Document.call_adoptNode(to, el) catch {};
                _ = interfaces.Node.call_appendChild(if (to == self.other) self.other_body else self.f.body, el) catch {};
            },
            7 => {
                var local = try interfaces.Element.get_localName(el);
                defer local.deinit(testing.allocator);
                const can_host = std.mem.eql(u8, local.asSlice(), "div") or std.mem.eql(u8, local.asSlice(), "span") or std.mem.eql(u8, local.asSlice(), "p");
                var namespace = try interfaces.Element.get_namespaceURI(el);
                defer if (namespace) |*ns| ns.deinit(testing.allocator);
                const html = if (namespace) |ns| std.mem.eql(u8, ns.asSlice(), html_ns) else false;
                if (can_host and html and dom.shadow_hosts.rootForHost(el) == null and self.shadows.items.len < 8) try self.attach(el);
            },
            8 => {
                // innerHTML in a container no pool element enters: its old
                // children are freed after their removal.
                const target = if (random.boolean()) self.scratch else self.scratch_shadow;
                var old: std.ArrayList(*runtime.Instance) = .empty;
                defer old.deinit(testing.allocator);
                var child = try interfaces.Node.get_firstChild(target);
                while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) try old.append(testing.allocator, c);
                const markup = self.pick([]const u8, &.{
                    "<img id=a name=b><form name=a><div id=c><object id=b></object></div></form>",
                    "<embed name=c><iframe name=b id=a></iframe>",
                    "<p id=b></p><img name=a>",
                    "",
                });
                if (target == self.scratch)
                    try interfaces.Element.set_innerHTML(target, .{ .domstring = str(markup) })
                else
                    try interfaces.ShadowRoot.set_innerHTML(target, .{ .domstring = str(markup) });
                for (old.items) |c| dom.node_creation.destroyUninserted(c);
            },
            9 => {
                // A clone, deep, kept in the document's tree to the end.
                if (self.clone_count >= 12) return;
                if (dom.tree_teardown.countUpTo(base(el), 8) >= 8) return;
                const copy = try interfaces.Node.call_cloneNode(el, .{ .was_passed = true, .value = true });
                _ = interfaces.Node.call_appendChild(self.clones, copy) catch {
                    dom.node_creation.destroyUninserted(copy);
                    return;
                };
                self.clone_count += 1;
            },
            else => unreachable,
        }
    }

    /// A step can leave a pool element detached - moveBefore removes before
    /// it inserts, and an insertion it then refuses leaves the node out
    /// (a moveBefore deviation of its own, not the maps') - so every pool
    /// element with no parent goes back to the park: each is in a tree the
    /// teardown frees.
    fn repark(self: *Random) !void {
        for (self.pool) |el| {
            if (try interfaces.Node.get_parentNode(el) == null) try append(self.park, el);
        }
    }

    fn check(self: *Random) !void {
        try expectExact(self.f.document, true);
        try expectExact(self.other, true);
        for (self.shadows.items) |shadow| try expectExact(shadow, false);
        try expectIndexed(self.f.document);
        try expectIndexed(self.other);
        for (self.shadows.items) |shadow| try expectIndexed(shadow);
    }
};

test "randomized: the maps answer every key as a walk of the tree does, after every operation" {
    for ([_]u64{ 1, 7, 0xdecaf, 20261018 }) |seed| {
        var r: Random = .{ .rng = .init(seed) };
        try r.init();
        defer r.deinit();
        for (0..400) |i| {
            r.step() catch |err| {
                std.debug.print("seed {d} step {d}: {}\n", .{ seed, i, err });
                return err;
            };
            try r.repark();
            r.check() catch |err| {
                std.debug.print("seed {d}: inexact after step {d}\n", .{ seed, i });
                return err;
            };
        }
    }
}
