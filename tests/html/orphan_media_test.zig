//! Lane orphanleak: an audio's, a video's, a source's and a track's own
//! state is made with the element, and needs an exit when the element is an
//! ORPHAN: removed from its tree while script held no wrapper of it, so
//! nothing deinits it before its Browser ends
//! (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//! A media element's state may outlive its element (a queued task holds it),
//! so its exit at the Browser's end is a sweep of its own.
//!
//! The Browser runs on std.testing.allocator, so a block or a string left at
//! its end fails the test. Each test runs on a thread of its own: tests/html
//! is one executable, and a Browser's agent belongs to the thread that made
//! it.
const helpers = @import("edges_node_holders_helpers.zig");

fn parsedMediaDropped() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // The fragment parser makes the elements; nothing ever wraps them. The
    // sources resolve their src (a URL the state owns).
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<audio></audio><audio><source src="a.oga"><track src="t.vtt" kind=subtitles></audio>' +
        \\                 '<video><source src="v.webm" type="video/webm"></video>';
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
    // Selection's stable sections and tasks run, then the page ends.
    try page.turn();
}

test "parsed media elements dropped unwrapped leave nothing at the Browser's end" {
    try helpers.onFreshThread(parsedMediaDropped);
}

fn retainedMediaIntact() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<video><source src="v.webm"><track src="t.vtt"></video>';
        \\globalThis.video = host.firstChild;
        \\host.innerHTML = '';
        \\if (video.firstChild.getAttribute('src') !== 'v.webm' || !video.paused) throw new Error('not intact');
    );
    try page.turn();
    try page.run("collectNow();");
}

test "a retained media element is intact after its tree is dropped" {
    try helpers.onFreshThread(retainedMediaIntact);
}
