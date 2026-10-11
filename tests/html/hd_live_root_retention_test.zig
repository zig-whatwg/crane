//! A live collection holds its root (refcount design 5h; lane rc5): script
//! that keeps only `root.childNodes`, `root.children` or
//! `root.getElementsByTagName(...)` of a detached root keeps the root, its
//! wrapper (an expando) and its tree, and the collection stays live. Written
//! by Codex row 13 (its Q20, the shelved root retention) and handed to the
//! refcount lane red: the tagname case aborted the test binary on Codex's base
//! (a stored element read after the collection's tree was freed), and its
//! Crane twin, crane/hd-retention-tagname.html, is 0/1 on 9d5b3ed490 (a
//! snapshot that neither sees the third span nor keeps its root). The
//! childNodes and children cases passed already, through the binding's
//! [SameObject] edges.
const helpers = @import("edges_node_holders_helpers.zig");

fn childnodes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.hdHeld = (() => {
        \\  const root = document.createElement('div');
        \\  root.hdMarker = 'kept root';
        \\  root.appendChild(document.createElement('span')).id = 'first';
        \\  root.appendChild(document.createElement('span')).id = 'second';
        \\  return root.childNodes;
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (hdHeld.length !== 2) throw new Error('lost detached root: '+hdHeld.length);
        \\if (hdHeld.item(0).id !== 'first' || hdHeld.item(1).id !== 'second') throw new Error('lost children');
        \\const root = hdHeld.item(0).parentNode;
        \\if (root.hdMarker !== 'kept root') throw new Error('lost root wrapper');
        \\root.appendChild(document.createElement('span')).id = 'third';
        \\if (hdHeld.length !== 3 || hdHeld.item(2).id !== 'third') throw new Error('list is not live');
    );
}

test "holding only childnodes keeps a detached root and live view" {
    try helpers.onFreshThread(childnodes);
}

fn children() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.hdHeld = (() => {
        \\  const root = document.createElement('div');
        \\  root.hdMarker = 'kept root';
        \\  root.appendChild(document.createElement('span')).id = 'first';
        \\  root.appendChild(document.createElement('span')).id = 'second';
        \\  return root.children;
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (hdHeld.length !== 2) throw new Error('lost detached root: '+hdHeld.length);
        \\if (hdHeld.item(0).id !== 'first' || hdHeld.item(1).id !== 'second') throw new Error('lost children');
        \\const root = hdHeld.item(0).parentNode;
        \\if (root.hdMarker !== 'kept root') throw new Error('lost root wrapper');
        \\root.appendChild(document.createElement('span')).id = 'third';
        \\if (hdHeld.length !== 3 || hdHeld.item(2).id !== 'third') throw new Error('list is not live');
    );
}

test "holding only children keeps a detached root and live view" {
    try helpers.onFreshThread(children);
}

fn tagname() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.hdHeld = (() => {
        \\  const root = document.createElement('div');
        \\  root.hdMarker = 'kept root';
        \\  root.appendChild(document.createElement('span')).id = 'first';
        \\  root.appendChild(document.createElement('span')).id = 'second';
        \\  return root.getElementsByTagName('span');
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (hdHeld.length !== 2) throw new Error('lost detached root: '+hdHeld.length);
        \\if (hdHeld.item(0).id !== 'first' || hdHeld.item(1).id !== 'second') throw new Error('lost children');
        \\const root = hdHeld.item(0).parentNode;
        \\if (root.hdMarker !== 'kept root') throw new Error('lost root wrapper');
        \\root.appendChild(document.createElement('span')).id = 'third';
        \\if (hdHeld.length !== 3 || hdHeld.item(2).id !== 'third') throw new Error('list is not live');
    );
}

test "holding only tagname keeps a detached root and live view" {
    try helpers.onFreshThread(tagname);
}
