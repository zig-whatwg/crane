//! A TreeWalker keeps its root and its current node, which script can set to
//! any node (Blink: NodeIteratorBase::Trace visits root_, TreeWalker::Trace
//! current_). Before lane ownerdoc both were bare pointers.
const od = @import("od_test_helpers.zig");

fn walkerKeepsItsNodes() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  const div = doc.createElement('div');
        \\  div.innerHTML = '<i>1</i>';
        \\  const detached = doc.createTreeWalker(div);
        \\  const elsewhere = document.createTreeWalker(document.body);
        \\  const p = doc.createElement('p');
        \\  p.innerHTML = '<u>u</u>';
        \\  elsewhere.currentNode = p;
        \\  const host = doc.body.appendChild(doc.createElement('div'));
        \\  host.innerHTML = '<p><i>deep</i></p>';
        \\  const moved = doc.createTreeWalker(host);
        \\  moved.nextNode();
        \\  moved.nextNode();
        \\  host.firstChild.remove();
        \\  return { detached, elsewhere, moved };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\checkDocument(kept.detached.root, 'root');
        \\if (kept.detached.firstChild().localName !== 'i') throw new Error('first child');
        \\if (kept.elsewhere.currentNode.localName !== 'p') throw new Error('current node script set');
        \\checkDocument(kept.elsewhere.currentNode, 'current node');
        \\if (kept.elsewhere.firstChild().localName !== 'u') throw new Error('its child');
        \\if (kept.moved.currentNode.localName !== 'i') throw new Error('current node removed from the root');
        \\checkDocument(kept.moved.currentNode, 'removed current node');
    );
}

test "a TreeWalker keeps its root and its current node" {
    try od.onFreshThread(walkerKeepsItsNodes);
}
