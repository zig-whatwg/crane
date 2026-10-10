//! An Attr keeps its element (Blink: Attr::Trace visits element_). Before
//! lane ownerdoc it held a generation-checked pointer, and `ownerElement`
//! read null once script let the element go.
const od = @import("od_test_helpers.zig");

fn attrKeepsItsElement() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  const p = doc.createElement('p');
        \\  p.setAttribute('data-od', 'kept');
        \\  const attached = p.getAttributeNode('data-od');
        \\  const q = doc.body.appendChild(doc.createElement('q'));
        \\  q.setAttribute('data-od', 'removed');
        \\  const removed = q.getAttributeNode('data-od');
        \\  q.removeAttributeNode(removed);
        \\  return { attached, removed };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\if (kept.attached.ownerElement === null) throw new Error('its element went');
        \\if (kept.attached.ownerElement.localName !== 'p') throw new Error('another element');
        \\if (kept.attached.value !== 'kept') throw new Error('value');
        \\checkDocument(kept.attached, 'attribute');
        \\checkDocument(kept.attached.ownerElement, 'element');
        \\if (kept.removed.ownerElement !== null) throw new Error('a removed attribute has no element');
        \\checkDocument(kept.removed, 'removed attribute');
    );
}

test "an Attr keeps its element" {
    try od.onFreshThread(attrKeepsItsElement);
}
