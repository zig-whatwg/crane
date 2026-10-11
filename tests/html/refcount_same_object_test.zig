//! Refcount step 5h (lane rc5): an element's [SameObject] sub-objects
//! (classList, dataset, attributes, style) forward their reference to the
//! element STRUCTURALLY in this step: the binding ties the sub-object's
//! wrapper to the element's both ways, and the element's wrapper owns the
//! element's counted reference. A count the sub-object forwards itself
//! (WebKit's NamedNodeMap::ref() is m_element->ref()) is step 7's.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn sameObjectSubObjectForwardsStructurally() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.attrs = (() => {
        \\  const element = document.createElement('div');
        \\  element.setAttribute('x', '1');
        \\  return element.attributes;
        \\})();
    );
    try page.collect();
    // The element, read natively (no wrapper made here): the attribute's
    // owner, through the interface.
    const held = try page.browser.evaluateScript("attrs[0]");
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const attr = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    const interfaces = @import("interfaces");
    const element = (try interfaces.Attr.get_ownerElement(attr)) orelse return error.NoOwner;
    // The sub-object's wrapper keeps its element's wrapper (the binding's
    // [SameObject] back edge), and that wrapper owns the element's counted
    // reference: WebKit's forwarded count, kept structurally (design 5h; a
    // count of the sub-object's own forwarded to the element is step 7's).
    try testing.expect(engine.hasWrapper(element));
    const base = dom.instance_bridge.getNodeBase(@ptrCast(element)) orelse return error.NotANode;
    try expectCount(2, base, "an element script reaches only through its attributes");
}

test "a [SameObject] sub-object script keeps alone keeps its element's counted wrapper" {
    try onFreshThread(sameObjectSubObjectForwardsStructurally);
}
