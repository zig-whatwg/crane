//! Lane orphanleak: node types whose state was already a block of the
//! runtime arena - embed, object, iframe, frame, link, style, details, Attr -
//! keep it when they are ORPHANS (removed from their tree while script held
//! no wrapper of them), and what the state owns beyond its block has an exit
//! at the Browser's end too: an object's custom validity, an iframe's cached
//! attribute strings, an Attr's names and value
//! (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//!
//! The Browser runs on std.testing.allocator, so a block or a string left at
//! its end fails the test. Each test runs on a thread of its own: tests/html
//! is one executable, and a Browser's agent belongs to the thread that made
//! it.
const helpers = @import("edges_node_holders_helpers.zig");

fn parsedArenaStatesDropped() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<embed type="text/plain"><object type="text/plain"></object><iframe name=f allow="" width=3></iframe>' +
        \\                 '<style>p { color: red }</style><link rel=stylesheet href="data:text/css,p{}">' +
        \\                 '<details open><summary>s</summary>d</details>';
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
    try page.turn();
}

test "parsed arena-state elements dropped unwrapped leave nothing at the Browser's end" {
    try helpers.onFreshThread(parsedArenaStatesDropped);
}

fn scriptSetStateReplaced() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\(() => {
        \\  host.appendChild(document.createElement('frame'));
        \\  const object = host.appendChild(document.createElement('object'));
        \\  object.setCustomValidity('object error');
        \\  const iframe = host.appendChild(document.createElement('iframe'));
        \\  iframe.name = 'named';
        \\  iframe.allow = 'fullscreen';
        \\  const p = host.appendChild(document.createElement('p'));
        \\  p.setAttribute('title', 't');
        \\  p.getAttributeNode('title').value = 'changed';
        \\  p.setAttribute('data-x', 'y');
        \\  p.removeAttributeNode(p.getAttributeNode('data-x'));
        \\})();
    );
    try page.turn();
    try page.run("collectNow();");
    try page.run(
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
    try page.turn();
    try page.run("collectNow();");
}

test "arena-state elements with script-set state, their tree replaced, leave nothing" {
    try helpers.onFreshThread(scriptSetStateReplaced);
}
