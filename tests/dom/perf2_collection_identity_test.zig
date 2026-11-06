//! DOM 4.2.6 / 4.5 / 4.9: getElementsByClassName, getElementsByTagName and
//! getElementsByTagNameNS, and HTML 3.1.3 getElementsByName, return the SAME
//! live collection for the same root and argument while it lives (lane
//! perf2). DOM: "When invoked with the same argument, the same
//! HTMLCollection object may be returned as returned by an earlier call";
//! HTML: "the user agent may return the same as the object returned by the
//! earlier call". Blink's and WebKit's NodeListsNodeData cache each list per
//! (owner node, type, name) for as long as the list lives, Gecko's
//! nsContentList hashtables per (root, function, string): every one of the
//! three returns the same object.
//!
//! Engine-free: a collection a getter returns is the test's to free (a
//! wrapper would own it); `runtime.gc.onObjectFreed` is what the wrapper's
//! collection does to it.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

const html_ns = "http://www.w3.org/1999/xhtml";

fn str(value: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(value);
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    body: *runtime.Instance,
    /// Collections the test made through the getters: each freed once.
    made: std.ArrayList(*runtime.Instance) = .empty,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(testing.allocator, .{});
        self.made = .empty;
        self.document = try newDocument(&self.ctx, .html);
        self.body = (try interfaces.Node.get_lastChild((try interfaces.Node.get_firstChild(self.document)).?)).?;
    }

    fn deinit(self: *Fixture) void {
        for (self.made.items) |collection| runtime.gc.onObjectFreed(collection);
        self.made.deinit(testing.allocator);
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    /// Remember `collection` to free at the end, once: the same object
    /// returned twice is one collection.
    fn keep(self: *Fixture, collection: *runtime.Instance) !*runtime.Instance {
        for (self.made.items) |kept| if (kept == collection) return collection;
        try self.made.append(testing.allocator, collection);
        return collection;
    }

    /// Forget `collection` (the test freed it).
    fn drop(self: *Fixture, collection: *runtime.Instance) void {
        for (self.made.items, 0..) |kept, i| if (kept == collection) {
            _ = self.made.swapRemove(i);
            return;
        };
    }

    fn add(self: *Fixture, parent: *runtime.Instance, namespace: []const u8, tag: []const u8, class: ?[]const u8) !*runtime.Instance {
        return addTo(self.document, parent, namespace, tag, class);
    }

    fn byClass(self: *Fixture, root: *runtime.Instance, names: []const u8) !*runtime.Instance {
        const collection = if (root == self.document)
            try interfaces.Document.call_getElementsByClassName(root, str(names))
        else
            try interfaces.Element.call_getElementsByClassName(root, str(names));
        return self.keep(collection);
    }

    fn byTag(self: *Fixture, root: *runtime.Instance, name: []const u8) !*runtime.Instance {
        const collection = if ((try interfaces.Node.get_nodeType(root)) == interfaces.Node.get_DOCUMENT_NODE())
            try interfaces.Document.call_getElementsByTagName(root, str(name))
        else
            try interfaces.Element.call_getElementsByTagName(root, str(name));
        return self.keep(collection);
    }

    fn byTagNS(self: *Fixture, root: *runtime.Instance, namespace: ?[]const u8, name: []const u8) !*runtime.Instance {
        const ns: ?runtime.DOMString = if (namespace) |value| str(value) else null;
        const collection = if (root == self.document)
            try interfaces.Document.call_getElementsByTagNameNS(root, ns, str(name))
        else
            try interfaces.Element.call_getElementsByTagNameNS(root, ns, str(name));
        return self.keep(collection);
    }
};

fn addTo(document: *runtime.Instance, parent: *runtime.Instance, namespace: []const u8, tag: []const u8, class: ?[]const u8) !*runtime.Instance {
    const element = try interfaces.Document.call_createElementNS(document, str(namespace), str(tag), .notPassed());
    errdefer dom.node_creation.destroyUninserted(element);
    if (class) |value| try interfaces.Element.set_className(element, str(value));
    _ = try interfaces.Node.call_appendChild(parent, element);
    return element;
}

fn newDocument(ctx: *runtime.ContextData, doc_type: dom.document_internals.DocType) !*runtime.Instance {
    const document = try interfaces.Document.init(testing.allocator, ctx);
    errdefer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, if (doc_type == .html) "text/html" else "application/xml");
    try dom.document_internals.setDocumentType(document, doc_type);
    const html = try interfaces.Document.call_createElementNS(document, str(html_ns), str("html"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, html);
    const body = try interfaces.Document.call_createElementNS(document, str(html_ns), str("body"), .notPassed());
    _ = try interfaces.Node.call_appendChild(html, body);
    return document;
}

fn length(collection: *runtime.Instance) !u32 {
    return interfaces.HTMLCollection.get_length(collection);
}

test "getElementsByClassName returns the same live collection for the same root and argument" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const section = try f.add(f.body, html_ns, "section", null);
    const first = try f.add(section, html_ns, "span", "tag");
    const list = try f.byClass(f.document, "tag");
    try testing.expectEqual(list, try f.byClass(f.document, "tag"));
    // Another argument, another root: another collection.
    try testing.expect(list != try f.byClass(f.document, "tag other"));
    try testing.expect(list != try f.byClass(f.document, "TAG"));
    const scoped = try f.byClass(section, "tag");
    try testing.expect(scoped != list);
    try testing.expectEqual(scoped, try f.byClass(section, "tag"));
    try testing.expectEqual(@as(u32, 1), try length(list));
    // Still live: a match added, then every match gone (an empty answer is an
    // answer, never the old contents).
    const second = try f.add(f.body, html_ns, "b", "tag");
    try testing.expectEqual(@as(u32, 2), try length(try f.byClass(f.document, "tag")));
    try testing.expectEqual(second, (try interfaces.HTMLCollection.call_item(list, 1)).?);
    try interfaces.Element.set_className(first, str("gone"));
    _ = try interfaces.Node.call_removeChild(f.body, second);
    try testing.expectEqual(list, try f.byClass(f.document, "tag"));
    try testing.expectEqual(@as(u32, 0), try length(list));
    try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.HTMLCollection.call_item(list, 0));
    try testing.expectEqual(@as(u32, 0), try length(scoped));
    dom.node_creation.destroyUninserted(second);
}

test "getElementsByTagName and getElementsByTagNameNS return the same collection per argument" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.add(f.body, html_ns, "div", null);
    _ = try f.add(f.body, "urn:x", "x", null);
    const divs = try f.byTag(f.document, "div");
    try testing.expectEqual(divs, try f.byTag(f.document, "div"));
    try testing.expect(divs != try f.byTag(f.document, "DIV"));
    try testing.expect(divs != try f.byTag(f.body, "div"));
    try testing.expectEqual(@as(u32, 1), try length(divs));
    // DOM 4.2.6 step 1 makes "" null before anything else: one argument.
    const xs = try f.byTagNS(f.document, "urn:x", "x");
    try testing.expectEqual(xs, try f.byTagNS(f.document, "urn:x", "x"));
    try testing.expectEqual(@as(u32, 1), try length(xs));
    const no_ns = try f.byTagNS(f.document, null, "x");
    try testing.expectEqual(no_ns, try f.byTagNS(f.document, "", "x"));
    try testing.expect(no_ns != xs);
    try testing.expectEqual(@as(u32, 0), try length(no_ns));
    const all = try f.byTagNS(f.document, "*", "*");
    try testing.expectEqual(all, try f.byTagNS(f.document, "*", "*"));
    try testing.expect(all != try f.byTag(f.document, "*"));
    // A tag-name list and a class list with one string are two lists.
    try testing.expect(divs != try f.byClass(f.document, "div"));
}

test "getElementsByName returns the same live NodeList" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const input = try f.add(f.body, html_ns, "input", null);
    const list = try f.keep(try interfaces.Document.call_getElementsByName(f.document, str("q")));
    try testing.expectEqual(list, try f.keep(try interfaces.Document.call_getElementsByName(f.document, str("q"))));
    try testing.expect(list != try f.keep(try interfaces.Document.call_getElementsByName(f.document, str("r"))));
    try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(list));
    try interfaces.Element.call_setAttribute(input, str("name"), .{ .domstring = str("q") });
    try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(list));
    try interfaces.Element.call_removeAttribute(input, str("name"));
    try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(list));
}

test "a collection that is gone is not answered again, and the cache does not grow with them" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.add(f.body, html_ns, "span", "tag");
    const list = try f.byClass(f.document, "tag");
    const generation = runtime.SlabAllocator.generationOf(list);
    // Its wrapper collected: the wrapper cache frees it, slot and all.
    f.drop(list);
    runtime.gc.onObjectFreed(list);
    const again = try f.byClass(f.document, "tag");
    try testing.expect(again != list or runtime.SlabAllocator.generationOf(again) != generation);
    try testing.expectEqual(@as(u32, 1), try length(again));
    // Collections of many roots, each gone before the next: the cache sweeps
    // them out once it reaches its sweep size.
    for (0..64) |_| {
        const root = try f.add(f.body, html_ns, "div", null);
        const made = try interfaces.Element.call_getElementsByClassName(root, str("tag"));
        runtime.gc.onObjectFreed(made);
    }
    try testing.expect(dom.tree_ordered_map.cachedLiveCollections(f.document) <= 17);
}

test "a root adopted into an XML document gets a new collection, which matches as XML" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const root = try f.add(f.body, html_ns, "section", null);
    _ = try f.add(root, html_ns, "div", null);
    // In an HTML document an HTML element's qualified name is compared in
    // ASCII lowercase (DOM 4.2.6 step 2).
    const html_list = try f.byTag(root, "DIV");
    try testing.expectEqual(@as(u32, 1), try length(html_list));
    const xml = try newDocument(&f.ctx, .xml);
    defer interfaces.Document.deinit(xml);
    _ = try interfaces.Document.call_adoptNode(xml, root);
    // "as long as root's node document's type has not changed": it has.
    const xml_list = try f.byTag(root, "DIV");
    try testing.expect(xml_list != html_list);
    try testing.expectEqual(@as(u32, 0), try length(xml_list));
    // The earlier list keeps the filter it was made with
    // (dom/nodes/Element-getElementsByTagName-change-document-HTMLNess.html).
    try testing.expectEqual(@as(u32, 1), try length(html_list));
    _ = try interfaces.Document.call_adoptNode(f.document, root);
    _ = try interfaces.Node.call_appendChild(f.body, root);
}

test "class names match ASCII case-insensitively in a quirks-mode document, through the kept collection" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try dom.document_internals.setMode(f.document, .quirks);
    _ = try f.add(f.body, html_ns, "p", "Foo");
    const list = try f.byClass(f.document, "foo");
    try testing.expectEqual(@as(u32, 1), try length(list));
    try testing.expectEqual(list, try f.byClass(f.document, "foo"));
    try testing.expectEqual(@as(u32, 1), try length(try f.byClass(f.document, "FOO")));
}

test "a disconnected root and a shadow-tree root keep their collections" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const loose = try interfaces.Document.call_createElementNS(f.document, str(html_ns), str("div"), .notPassed());
    defer dom.node_creation.destroyUninserted(loose);
    const list = try f.byClass(loose, "c");
    try testing.expectEqual(list, try f.byClass(loose, "c"));
    _ = try addTo(f.document, loose, html_ns, "i", "c");
    try testing.expectEqual(@as(u32, 1), try length(list));

    const host = try f.add(f.body, html_ns, "div", null);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    defer interfaces.ShadowRoot.deinit(shadow);
    try dom.node_document.set(shadow, f.document);
    const inner = try addTo(f.document, shadow, html_ns, "div", null);
    const shadowed = try f.byClass(inner, "c");
    try testing.expectEqual(shadowed, try f.byClass(inner, "c"));
    _ = try addTo(f.document, inner, html_ns, "i", "c");
    try testing.expectEqual(@as(u32, 1), try length(shadowed));
    // The document's own list does not see into the shadow tree.
    try testing.expectEqual(@as(u32, 0), try length(try f.byClass(f.document, "c")));
}

test "a collection made natively is the caller's own, apart from the one script is given" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.add(f.body, html_ns, "iframe", null);
    const shared = try f.byTag(f.document, "iframe");
    const own = try dom.live_collections.newCollection(f.document, .{ .qualified_name = "iframe" });
    try testing.expect(own != shared);
    try testing.expectEqual(@as(u32, 1), try length(own));
    // Freeing its own leaves the shared one working.
    runtime.Instance.deinit(own);
    try testing.expectEqual(@as(u32, 1), try length(shared));
    try testing.expectEqual(shared, try f.byTag(f.document, "iframe"));
}
