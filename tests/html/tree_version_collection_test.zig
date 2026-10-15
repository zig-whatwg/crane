//! The DOM tree version (dom.refcount.treeVersion) under a real collector:
//! garbage freed by a collection is not a mutation of its document, so an
//! XPath iterator stays valid through it (crane/xp2-result-gc.html), and a
//! live collection's cache - which no longer learns of frees through the
//! version - still reads only live nodes: the collection keeps its root, so
//! its root's tree is never garbage while the collection can be read.
const h = @import("refcount_holders_helpers.zig");
const Page = h.Page;
const onFreshThread = h.onFreshThread;

fn iteratorSurvivesCollection() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.root = document.body.appendChild(document.createElement('section'));
        \\root.innerHTML = '<span>a</span><span>b</span>';
        \\// Garbage of the same document, built BEFORE the evaluation (building
        \\// it mutates a detached tree of the document, which browsers count
        \\// too) and dropped after it: a wrapped detached tree nothing keeps.
        \\globalThis.garbage = document.createElement('div');
        \\garbage.innerHTML = '<p></p><p></p>';
        \\globalThis.result = document.evaluate('./span', root, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE);
        \\garbage = null;
    );
    try page.collect();
    try page.run(
        \\if (result.invalidIteratorState) throw new Error('a collection invalidated the iterator');
        \\const first = result.iterateNext();
        \\if (!first || first.textContent !== 'a') throw new Error('first ' + (first && first.textContent));
        \\if (result.iterateNext().textContent !== 'b' || result.iterateNext() !== null) throw new Error('rest');
        \\// A mutation still invalidates it: character data too, as in browsers.
        \\const again = document.evaluate('./span', root, null, XPathResult.UNORDERED_NODE_ITERATOR_TYPE);
        \\root.firstChild.firstChild.data = 'changed';
        \\if (!again.invalidIteratorState) throw new Error('a character data change left the iterator valid');
        \\let threw = false;
        \\try { again.iterateNext(); } catch (e) { threw = e.name === 'InvalidStateError'; }
        \\if (!threw) throw new Error('iterateNext after a character data change did not throw InvalidStateError');
    );
}

test "an XPath iterator stays valid when a collection frees unrelated garbage of its document" {
    try onFreshThread(iteratorSurvivesCollection);
}

fn collectionsReadLiveNodesAcrossCollections() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\// Garbage first, dropped once every cache is filled: the collector
        \\// then frees it with no version change, so each read below takes the
        \\// cheap path (IndexCache.fresh) over what it remembered.
        \\globalThis.garbage = document.createElement('div');
        \\garbage.innerHTML = '<p></p>'.repeat(50);
        \\globalThis.root = document.createElement('div');
        \\root.innerHTML = '<p>1</p><p>2</p><p>3</p>';
        \\globalThis.tags = root.getElementsByTagName('p');
        \\globalThis.kids = root.children;
        \\globalThis.nodes = root.childNodes;
        \\// Each cache remembers a cursor on the last paragraph.
        \\if (tags[2].textContent !== '3' || kids[2].textContent !== '3' || nodes[2].textContent !== '3') throw new Error('first read');
        \\// A collection that alone keeps its root's tree (script drops `r`).
        \\globalThis.only = (() => {
        \\  const r = document.createElement('div');
        \\  r.innerHTML = '<b>x</b><b>y</b>';
        \\  const c = r.getElementsByTagName('b');
        \\  if (c[1].textContent !== 'y') throw new Error('only, first read');
        \\  return c;
        \\})();
        \\garbage = null;
    );
    try page.collect();
    try page.run(
        \\{
        \\  const read = () => [tags.length, tags[1].textContent, tags[2].textContent, kids.length, kids[2].textContent, nodes.length, nodes[2].textContent, only.length, only[1].textContent].join();
        \\  if (read() !== '3,2,3,3,3,3,3,2,y') throw new Error('after a collection ' + read());
        \\  root.lastChild.remove();
        \\}
    );
    try page.collect();
    try page.run(
        \\{
        \\  const read = () => [tags.length, tags[1].textContent, tags[2], kids.length, nodes.length].join();
        \\  if (read() !== '2,2,,2,2') throw new Error('after a removal and a collection ' + read());
        \\}
    );
}

test "live collections read only live nodes across collections that free other trees" {
    try onFreshThread(collectionsReadLiveNodesAcrossCollections);
}
