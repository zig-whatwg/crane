//! Lane orphanleak: a shadow host removed from its tree while script held no
//! wrapper of it is an ORPHAN, and so is its shadow root: nothing deinits
//! either before its Browser ends, and the root's own state needs an exit
//! (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//!
//! The Browser runs on std.testing.allocator, so a block left at its end
//! fails the test. Each test runs on a thread of its own: tests/html is one
//! executable, and a Browser's agent belongs to the thread that made it.
const helpers = @import("edges_node_holders_helpers.zig");

fn declarativeHostDropped() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.setHTMLUnsafe('<div><template shadowrootmode=open><span>in</span><slot></slot></template>light</div>');
        \\// Read without wrapping the host: its light tree only.
        \\if (host.innerHTML !== '<div>light</div>') throw new Error('no declarative root');
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "a declarative shadow host dropped unwrapped leaves nothing at the Browser's end" {
    try helpers.onFreshThread(declarativeHostDropped);
}

fn scriptedHostOrphaned() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\(() => {
        \\  const element = host.appendChild(document.createElement('div'));
        \\  const root = element.attachShadow({ mode: 'closed' });
        \\  root.innerHTML = '<p>shadow</p>';
        \\  root.adoptedStyleSheets = [new CSSStyleSheet()];
        \\})();
    );
    try page.turn();
    try page.run("collectNow();");
    try page.run(
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "a scripted shadow host, wrappers collected, dropped, leaves nothing" {
    try helpers.onFreshThread(scriptedHostOrphaned);
}

fn retainedHostKeepsRoot() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\const element = host.appendChild(document.createElement('div'));
        \\const root = element.attachShadow({ mode: 'open' });
        \\host.innerHTML = '';
        \\if (element.shadowRoot !== root || root.host !== element) throw new Error('lost its root');
    );
}

test "a retained host keeps its shadow root after its tree is dropped" {
    try helpers.onFreshThread(retainedHostKeepsRoot);
}
