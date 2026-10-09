//! A StaticRange keeps its two containers for as long as script holds it,
//! and only then. Blink's StaticRange traces Member<Node> start_container_
//! and end_container_; Crane's held bare pointers (lifefix2's PR-N1 audit).
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn staticRangeKeepsItsContainers() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const range = (() => {
        \\  const start = document.createTextNode('start');
        \\  const end = document.createElement('div');
        \\  end.ed = 'end';
        \\  return new StaticRange({ startContainer: start, startOffset: 2, endContainer: end, endOffset: 0 });
        \\})();
        \\collectNow();
        \\if (range.startContainer.data !== 'start') throw new Error('start container');
        \\if (range.endContainer.ed !== 'end') throw new Error('end container');
    );
    try page.run(
        \\globalThis.weak = [];
        \\(() => {
        \\  const node = document.createTextNode('x');
        \\  weak.push(new WeakRef(node));
        \\  const range = new StaticRange({ startContainer: node, startOffset: 0, endContainer: node, endOffset: 1 });
        \\  weak.push(new WeakRef(range));
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weak.some(ref => ref.deref() !== undefined)) throw new Error('a dropped StaticRange still keeps its containers');
    );
}

test "a StaticRange keeps its containers while script holds it, and only then" {
    try onFreshThread(staticRangeKeepsItsContainers);
}
