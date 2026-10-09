//! A script-inserted external SVG script runs from a task and then gets its
//! load event - at its own element, even when the script removed that
//! element and let every reference to it go (lane edges, item 5). The task
//! keeps the element (script_execution.QueuedSvgScript.element_root), as
//! Blink's PendingScript traces Member<ScriptElementBase> and WebKit's holds
//! Ref<ScriptElement>. It once held only the element's address and
//! generation, checked before the script ran, and fired load at whatever
//! took the freed slot.
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn queuedSvgScriptKeepsItsElement() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\const body = `
        \\  log.push('ran');
        \\  document.currentScript.remove();
        \\  TestUtils.gc();
        \\  globalThis.churn = [];
        \\  for (let i = 0; i < 2000; i++) {
        \\    const other = document.createElementNS('http://www.w3.org/2000/svg', 'script');
        \\    other.addEventListener('load', () => log.push('wrong'));
        \\    churn.push(other);
        \\  }
        \\  TestUtils.gc();
        \\`;
        \\const svg = document.body.appendChild(document.createElementNS('http://www.w3.org/2000/svg', 'svg'));
        \\(() => {
        \\  const script = document.createElementNS('http://www.w3.org/2000/svg', 'script');
        \\  script.addEventListener('load', () => log.push('load'));
        \\  script.addEventListener('error', () => log.push('error'));
        \\  script.setAttribute('href', 'data:text/javascript,' + encodeURIComponent(body));
        \\  svg.appendChild(script);
        \\})();
    );
    try page.turn();
    try page.run(
        \\if (log.join() !== 'ran,load') throw new Error('log: ' + log.join());
    );
}

test "a queued SVG script that removes its element and collects still fires load at that element" {
    try onFreshThread(queuedSvgScriptKeepsItsElement);
}
