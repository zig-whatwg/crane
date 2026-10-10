//! A live range keeps its start and end nodes (Blink: Range::Trace visits
//! start_ and end_). Before lane ownerdoc they were bare pointers: a range
//! whose nodes' tree was collected answered from freed nodes, or crashed.
const od = @import("od_test_helpers.zig");

fn rangeKeepsItsContainers() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  const p = doc.body.appendChild(doc.createElement('p'));
        \\  p.textContent = 'in the document';
        \\  const inTree = doc.createRange();
        \\  inTree.selectNodeContents(p);
        \\  const a = doc.createElement('a');
        \\  a.textContent = 'start';
        \\  const b = doc.createElement('b');
        \\  b.textContent = 'end';
        \\  const span = doc.createElement('span');
        \\  span.append(a, b);
        \\  const apart = doc.createRange();
        \\  apart.setStart(a.firstChild, 1);
        \\  apart.setEnd(b.firstChild, 2);
        \\  const host = doc.body.appendChild(doc.createElement('div'));
        \\  host.innerHTML = '<s>moved</s>';
        \\  const moved = doc.createRange();
        \\  moved.selectNodeContents(host.firstChild);
        \\  host.innerHTML = '';
        \\  return { inTree, apart, moved, clone: apart.cloneRange() };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\checkDocument(kept.inTree.startContainer, 'start');
        \\if (kept.inTree.toString() !== 'in the document') throw new Error('contents');
        \\if (kept.apart.startContainer.data !== 'start' || kept.apart.endContainer.data !== 'end') throw new Error('both containers');
        \\if (kept.apart.toString() !== 'tarten') throw new Error('apart: ' + kept.apart.toString());
        \\checkDocument(kept.apart.endContainer, 'end');
        \\if (kept.clone.toString() !== 'tarten') throw new Error('clone');
        \\if (kept.moved.startContainer.localName !== 'div') throw new Error('moved by the removal');
        \\checkDocument(kept.moved.startContainer, 'moved');
    );
}

test "a live range keeps its boundary nodes" {
    try od.onFreshThread(rangeKeepsItsContainers);
}
