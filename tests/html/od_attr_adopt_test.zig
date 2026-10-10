//! Adopt sets the node document of each of an element's attributes (DOM
//! adopt, step 3.1.2), and an Attr node script holds follows its element to
//! the new document - edge and all, so the old document is let go. An
//! attribute script never asked for has no Attr node, and adopting makes
//! none: a 1,000-element tree adopts without one new platform object.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const od = @import("od_test_helpers.zig");

fn instanceOf(page: od.Page, expression: []const u8) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    const realm = context.realm orelse return error.NoRealm;
    const value = try context.evaluateScript(expression);
    defer value.release();
    return engine.convertToPlatformObject(realm, value.borrow()) orelse error.NotAPlatformObject;
}

fn adoptMakesNoAttrNodes() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.d1 = makeDocument();
        \\globalThis.d2 = makeDocument();
        \\globalThis.root = d1.body.appendChild(d1.createElement('div'));
        \\root.innerHTML = Array.from({ length: 1000 }, (_, i) => `<span data-i="${i}" title="t"></span>`).join('');
        \\globalThis.seen = root.firstChild.getAttributeNode('data-i');
        \\if (seen.ownerDocument !== d1) throw new Error('before');
    );
    const slab = runtime.SlabAllocator.get();
    const before = slab.stats().total_allocated;
    try page.run("d2.adoptNode(root)");
    try testing.expectEqual(before, slab.stats().total_allocated);
    try page.run(
        \\if (root.ownerDocument !== d2) throw new Error('the element');
        \\if (seen.ownerDocument !== d2) throw new Error('the Attr node script holds');
        \\if (seen.ownerElement !== root.firstChild) throw new Error('its element');
    );
    // No attribute script never asked for has an Attr node now.
    const root = try instanceOf(page, "root");
    var made: usize = 0;
    var child = try interfaces.Node.get_firstChild(root);
    while (child) |element| : (child = try interfaces.Node.get_nextSibling(element)) {
        for (0..dom.element_attributes.count(element)) |index| {
            if (dom.element_attributes.existingNodeAt(element, index) != null) made += 1;
        }
    }
    try testing.expectEqual(@as(usize, 1), made);
}

test "adopting a tree makes no Attr nodes, and the ones script holds follow it" {
    try od.onFreshThread(adoptMakesNoAttrNodes);
}

fn adoptLetsTheOldDocumentGo() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.weak = null;
        \\globalThis.attr = (() => {
        \\  const oldDoc = makeDocument();
        \\  const newDoc = makeDocument();
        \\  newDoc.od = 'new';
        \\  globalThis.keepNew = newDoc;
        \\  const p = oldDoc.createElement('p');
        \\  p.setAttribute('data-od', 'adopted');
        \\  const attr = p.getAttributeNode('data-od');
        \\  newDoc.adoptNode(p);
        \\  weak = new WeakRef(oldDoc);
        \\  return attr;
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\if (attr.ownerDocument !== keepNew) throw new Error('the new document');
        \\if (weak.deref() !== undefined) throw new Error('the old document is still kept');
    );
}

test "an adopted element's Attr node lets the old document go" {
    try od.onFreshThread(adoptLetsTheOldDocumentGo);
}
