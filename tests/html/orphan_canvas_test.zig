//! Lane orphanleak: a canvas's own state - its context mode and its 2D
//! context - is made with the element, and needs an exit when the canvas is
//! an ORPHAN: removed from its tree while script held no wrapper of it, so
//! nothing deinits it before its Browser ends
//! (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//!
//! The Browser runs on std.testing.allocator, so a block left at its end
//! fails the test. Each test runs on a thread of its own: tests/html is one
//! executable, and a Browser's agent belongs to the thread that made it.
const helpers = @import("edges_node_holders_helpers.zig");

fn parsedCanvasDropped() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<canvas width=4 height=4></canvas><canvas></canvas>';
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "parsed canvases dropped unwrapped leave nothing at the Browser's end" {
    try helpers.onFreshThread(parsedCanvasDropped);
}

fn canvasWithContextOrphaned() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<canvas width=4 height=4></canvas>';
        \\(() => {
        \\  const context = host.firstChild.getContext('2d');
        \\  if (host.firstChild.getContext('2d') !== context) throw new Error('not the same context');
        \\})();
    );
    try page.turn();
    try page.run("collectNow();");
    try page.run(
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "a canvas with a 2d context, wrappers collected, tree dropped, leaves nothing" {
    try helpers.onFreshThread(canvasWithContextOrphaned);
}

fn retainedCanvasKeepsContext() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<canvas width=4 height=4></canvas>';
        \\const canvas = host.firstChild;
        \\const context = canvas.getContext('2d');
        \\host.innerHTML = '';
        \\if (canvas.getContext('2d') !== context || context.canvas !== canvas) throw new Error('lost its context');
    );
}

test "a retained canvas keeps its context after its tree is dropped" {
    try helpers.onFreshThread(retainedCanvasKeepsContext);
}
