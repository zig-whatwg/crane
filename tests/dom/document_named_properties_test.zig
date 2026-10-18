//! HTML 3.1.7 a Document's named properties, answered from its tree scope's
//! maps (dom.tree_ordered_map; lane domindex1): the per-name query the
//! [LegacyOverrideBuiltIns] interceptor asks before every property read, the
//! named getter's one element / iframe window / collection, the collection's
//! identity while it lives, and the supported property names in the spec's
//! order. Engine-free: a collection the getter returns is the test's to free
//! (a wrapper would own it).
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const map = dom.tree_ordered_map;

const html_ns = "http://www.w3.org/1999/xhtml";

fn str(value: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(value);
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    body: *runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(testing.allocator, .{});
        self.document = try newDocument(&self.ctx);
        self.body = (try interfaces.Node.get_lastChild((try interfaces.Node.get_firstChild(self.document)).?)).?;
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn add(self: *Fixture, parent: *runtime.Instance, namespace: []const u8, tag: []const u8, id: ?[]const u8, name: ?[]const u8) !*runtime.Instance {
        const element = try interfaces.Document.call_createElementNS(self.document, str(namespace), str(tag), .notPassed());
        errdefer dom.node_creation.destroyUninserted(element);
        if (id) |value| try interfaces.Element.call_setAttribute(element, str("id"), .{ .domstring = str(value) });
        if (name) |value| try interfaces.Element.call_setAttribute(element, str("name"), .{ .domstring = str(value) });
        _ = try interfaces.Node.call_appendChild(parent, element);
        return element;
    }
};

fn newDocument(ctx: *runtime.ContextData) !*runtime.Instance {
    const document = try interfaces.Document.init(testing.allocator, ctx);
    errdefer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const html = try interfaces.Document.call_createElementNS(document, str(html_ns), str("html"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, html);
    const body = try interfaces.Document.call_createElementNS(document, str(html_ns), str("body"), .notPassed());
    _ = try interfaces.Node.call_appendChild(html, body);
    return document;
}

fn supported(document: *runtime.Instance, name: []const u8) !bool {
    return interfaces.Document.isSupportedPropertyName(document, str(name));
}

/// The getter's answer: an element, or the collection (the caller frees it).
const Named = union(enum) { none, element: *runtime.Instance, collection: *runtime.Instance };

fn named(document: *runtime.Instance, name: []const u8) !Named {
    const value = try interfaces.Document.call_getter(document, str(name));
    return switch (value) {
        .instance => |instance| if (instance.stateAs(interfaces.HTMLCollection.State) != null) .{ .collection = instance } else .{ .element = instance },
        else => .none,
    };
}

fn contents(collection: *runtime.Instance, out: []?*runtime.Instance) !usize {
    const length = try interfaces.HTMLCollection.get_length(collection);
    for (out, 0..) |*slot, i| slot.* = if (i < length) try interfaces.HTMLCollection.call_item(collection, @intCast(i)) else null;
    return length;
}

test "only HTML embed, form, iframe, img and object elements are named, by name; object and named img by ID" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    inline for (.{ "embed", "form", "iframe", "img", "object", "div", "span", "a" }) |tag| {
        const element = try f.add(f.body, html_ns, tag, tag ++ "_id", tag ++ "_name");
        const by_name = comptime std.mem.indexOf(u8, "embed form iframe img object", tag) != null and !std.mem.eql(u8, tag, "a");
        const by_id = comptime std.mem.eql(u8, tag, "img") or std.mem.eql(u8, tag, "object");
        try testing.expectEqual(by_name, try supported(f.document, tag ++ "_name"));
        try testing.expectEqual(by_id, try supported(f.document, tag ++ "_id"));
        // An iframe with no content navigable (this document has no
        // browsing context) is returned as the element (step 3).
        if (by_name) try testing.expectEqual(Named{ .element = element }, try named(f.document, tag ++ "_name"));
        if (by_id) try testing.expectEqual(Named{ .element = element }, try named(f.document, tag ++ "_id"));
    }
    // A foreign element, and an HTML element whose local name is not lower
    // case, is none of the five.
    _ = try f.add(f.body, "urn:other", "form", null, "foreign");
    _ = try f.add(f.body, html_ns, "FORM", null, "upper");
    try testing.expect(!try supported(f.document, "foreign"));
    try testing.expect(!try supported(f.document, "upper"));
    try testing.expect(!try supported(f.document, ""));
    try testing.expect(!try supported(f.document, "missing"));
}

test "several named elements are one live collection, the same one while it lives" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const first = try f.add(f.body, html_ns, "form", null, "live");
    const second = try f.add(f.body, html_ns, "img", null, "live");
    const list = (try named(f.document, "live")).collection;
    defer interfaces.HTMLCollection.deinit(list);
    try testing.expectEqual(Named{ .collection = list }, try named(f.document, "live"));
    var out: [3]?*runtime.Instance = undefined;
    try testing.expectEqual(@as(usize, 2), try contents(list, &out));
    try testing.expectEqualSlices(?*runtime.Instance, &.{ first, second, null }, &out);
    // A move reorders it.
    _ = try interfaces.Node.call_insertBefore(f.body, second, first);
    try testing.expectEqual(@as(usize, 2), try contents(list, &out));
    try testing.expectEqualSlices(?*runtime.Instance, &.{ second, first, null }, &out);
    // A rename takes one out; the getter now answers the one left, and the
    // kept collection still follows (nameditem-tree-order).
    try interfaces.Element.call_setAttribute(first, str("name"), .{ .domstring = str("other") });
    try testing.expectEqual(@as(usize, 1), try contents(list, &out));
    try testing.expectEqual(Named{ .element = second }, try named(f.document, "live"));
    try interfaces.Element.call_setAttribute(first, str("name"), .{ .domstring = str("live") });
    try testing.expectEqual(Named{ .collection = list }, try named(f.document, "live"));
    try testing.expectEqual(@as(usize, 2), try contents(list, &out));
    try testing.expectEqualSlices(?*runtime.Instance, &.{ second, first, null }, &out);
    // Removal empties it; reinsertion refills it.
    _ = try interfaces.Node.call_removeChild(f.body, first);
    _ = try interfaces.Node.call_removeChild(f.body, second);
    try testing.expectEqual(@as(usize, 0), try contents(list, &out));
    try testing.expectEqual(Named.none, try named(f.document, "live"));
    _ = try interfaces.Node.call_appendChild(f.body, second);
    _ = try interfaces.Node.call_appendChild(f.body, first);
    try testing.expectEqual(@as(usize, 2), try contents(list, &out));
    try testing.expectEqualSlices(?*runtime.Instance, &.{ second, first, null }, &out);
}

test "a collection that is gone is not answered again, and its name leaves the cache" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.add(f.body, html_ns, "form", null, "gone");
    _ = try f.add(f.body, html_ns, "form", null, "gone");
    const list = (try named(f.document, "gone")).collection;
    try testing.expectEqual(@as(usize, 1), map.cachedCollectionNames(f.document));
    // Its wrapper collected: the wrapper cache frees it, slot and all.
    runtime.gc.onObjectFreed(list);
    const again = (try named(f.document, "gone")).collection;
    defer interfaces.HTMLCollection.deinit(again);
    try testing.expectEqual(@as(usize, 1), map.cachedCollectionNames(f.document));
    try testing.expectEqual(@as(usize, 2), try interfaces.HTMLCollection.get_length(again));
    // Many names whose collections all went: a sweep takes them out once
    // the cache reaches its sweep size, so it does not grow with them.
    var buffer: [16]u8 = undefined;
    for (0..64) |i| {
        const name = try std.fmt.bufPrint(&buffer, "n{d}", .{i});
        _ = try f.add(f.body, html_ns, "img", null, name);
        _ = try f.add(f.body, html_ns, "img", null, name);
        const made = (try named(f.document, name)).collection;
        runtime.gc.onObjectFreed(made);
    }
    try testing.expect(map.cachedCollectionNames(f.document) <= 17);
}

test "an img's ID names it only while its name is non-empty, in a kept collection too" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const first = try f.add(f.body, html_ns, "img", "pair", "a");
    const second = try f.add(f.body, html_ns, "img", "pair", "b");
    const list = (try named(f.document, "pair")).collection;
    defer interfaces.HTMLCollection.deinit(list);
    var out: [3]?*runtime.Instance = undefined;
    try testing.expectEqual(@as(usize, 2), try contents(list, &out));
    try interfaces.Element.call_removeAttribute(first, str("name"));
    try testing.expectEqual(@as(usize, 1), try contents(list, &out));
    try testing.expectEqual(@as(?*runtime.Instance, second), out[0]);
    try interfaces.Element.call_setAttribute(first, str("name"), .{ .domstring = str("") });
    try testing.expectEqual(@as(usize, 1), try contents(list, &out));
    try interfaces.Element.call_setAttribute(first, str("name"), .{ .domstring = str("restored") });
    try testing.expectEqual(@as(usize, 2), try contents(list, &out));
    try testing.expectEqualSlices(?*runtime.Instance, &.{ first, second, null }, &out);
}

test "named properties follow document-tree membership: shadow trees and adoption" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const form = try f.add(f.body, html_ns, "form", null, "moving");
    const host = try f.add(f.body, html_ns, "div", null, null);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    defer interfaces.ShadowRoot.deinit(shadow);
    try dom.node_document.set(shadow, f.document);
    try testing.expectEqual(Named{ .element = form }, try named(f.document, "moving"));
    _ = try interfaces.Node.call_appendChild(shadow, form);
    try testing.expect(!try supported(f.document, "moving"));
    _ = try interfaces.Node.call_appendChild(f.body, form);
    try testing.expectEqual(Named{ .element = form }, try named(f.document, "moving"));
    const other = try newDocument(&f.ctx);
    defer interfaces.Document.deinit(other);
    _ = try interfaces.Document.call_adoptNode(other, form);
    try testing.expect(!try supported(f.document, "moving"));
    try testing.expect(!try supported(other, "moving"));
    const other_body = (try interfaces.Node.get_lastChild((try interfaces.Node.get_firstChild(other)).?)).?;
    _ = try interfaces.Node.call_appendChild(other_body, form);
    try testing.expectEqual(Named{ .element = form }, try named(other, "moving"));
}

test "the supported property names are in tree order, an element's ID before its name, without duplicates" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    // None while the document has no named element.
    const empty = try interfaces.Document.getSupportedPropertyNames(f.document, testing.allocator);
    try testing.expectEqual(@as(usize, 0), empty.len);
    _ = try f.add(f.body, html_ns, "img", "image-id", "image-name");
    _ = try f.add(f.body, html_ns, "form", "ignored-form-id", "form-name");
    _ = try f.add(f.body, html_ns, "div", "ignored-div-id", "ignored-div-name");
    _ = try f.add(f.body, html_ns, "object", "object-id", "image-name");
    _ = try f.add(f.body, html_ns, "embed", null, "form-name");
    const names = try interfaces.Document.getSupportedPropertyNames(f.document, testing.allocator);
    defer {
        for (names) |*name| name.deinit(testing.allocator);
        testing.allocator.free(names);
    }
    const expected = [_][]const u8{ "image-id", "image-name", "form-name", "object-id" };
    try testing.expectEqual(expected.len, names.len);
    for (names, expected) |actual, wanted| {
        try testing.expectEqualStrings(wanted, actual.asSlice());
        try testing.expect(try supported(f.document, wanted));
    }
}

test "a named element never shadows Document's unforgeable location" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.add(f.body, html_ns, "form", null, "location");
    _ = try f.add(f.body, html_ns, "form", null, "kept");
    try testing.expect(!try supported(f.document, "location"));
    try testing.expect(try supported(f.document, "kept"));
    const names = try interfaces.Document.getSupportedPropertyNames(f.document, testing.allocator);
    defer {
        for (names) |*name| name.deinit(testing.allocator);
        testing.allocator.free(names);
    }
    try testing.expectEqual(@as(usize, 1), names.len);
    try testing.expectEqualStrings("kept", names[0].asSlice());
}
