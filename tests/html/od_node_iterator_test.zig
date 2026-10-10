//! A NodeIterator keeps its root and its reference node (Blink:
//! NodeIteratorBase::Trace visits root_, NodeIterator::Trace reference_).
//! Before lane ownerdoc both were bare pointers: `root` read a freed node
//! once the iterator's tree was collected.
const od = @import("od_test_helpers.zig");

fn iteratorKeepsItsNodes() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  const div = doc.body.appendChild(doc.createElement('div'));
        \\  div.innerHTML = '<b>1</b><b>2</b>';
        \\  const inTree = doc.createNodeIterator(div);
        \\  const detached = doc.createElement('section');
        \\  detached.innerHTML = '<i>1</i><i>2</i>';
        \\  const partWay = doc.createNodeIterator(detached, NodeFilter.SHOW_ELEMENT);
        \\  partWay.nextNode();
        \\  partWay.nextNode();
        \\  return { inTree, partWay };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\checkDocument(kept.inTree.root, 'root');
        \\if (kept.inTree.root.localName !== 'div') throw new Error('root');
        \\if (kept.inTree.nextNode() !== kept.inTree.root) throw new Error('first node');
        \\if (kept.partWay.referenceNode.textContent !== '1') throw new Error('reference');
        \\checkDocument(kept.partWay.referenceNode, 'reference');
        \\if (kept.partWay.nextNode().textContent !== '2') throw new Error('next');
    );
}

test "a NodeIterator keeps its root and its reference node" {
    try od.onFreshThread(iteratorKeepsItsNodes);
}
