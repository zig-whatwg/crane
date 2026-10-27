//! Lane editing4: "move preserving ranges" (common.zig Edit.movePreservingRanges)
//! with ranges script let go of. The move calls insertBefore, which can
//! allocate and start a collection whose second passes free those ranges
//! (src/dom/live_range_list.zig); the boundary points must be written only
//! to ranges still on the document's live list. A copy of the list kept
//! across the move crashed in Range.setStartBoundary (lane editing4's
//! native probe of editing/run/delete.html, 2026-10-26).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn garbageRangesDuringMoves() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // Each round: thousands of ranges nobody keeps, then a delete whose step
    // 7 sets a dt's tag name - moving its children preserving ranges - where
    // one moved child is a custom element whose connectedCallback collects
    // garbage. The callback runs at the end of the move's insertBefore (its
    // [CEReactions] scope), after the move read the live ranges and before
    // it writes their points back: the collection is forced exactly there,
    // and TestUtils.gc() tears the dropped ranges down at once.
    try page.run(
        \\customElements.define('gc-on-connect', class extends HTMLElement {
        \\  connectedCallback() { if (globalThis.collectOnConnect) TestUtils.gc(); }
        \\});
        \\globalThis.churnRanges = () => { for (let i = 0; i < 4000; i++) document.createRange(); };
        \\globalThis.round = () => {
        \\  setupHost('foo<dl><dt>[]bar<gc-on-connect></gc-on-connect></dt><dd>baz</dd></dl>');
        \\  churnRanges();
        \\  globalThis.collectOnConnect = true;
        \\  document.execCommand('delete');
        \\  globalThis.collectOnConnect = false;
        \\  return hostHTML();
        \\};
    );
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const html = try page.evaluate("round()");
        defer std.testing.allocator.free(html);
        try std.testing.expectEqualStrings("foo<div>bar<gc-on-connect></gc-on-connect></div><dl><dd>baz</dd></dl>", html);
    }
    // A range the page keeps still follows the moved node: the dt's text
    // moves into the new div, and the kept range with it.
    try harness.expectEval(page, "(() => { setupHost('foo<dl><dt>[]bar<dd>baz</dl>'); const t = host.querySelector('dt').firstChild; const kept = document.createRange(); kept.setStart(t, 1); kept.setEnd(t, 2); churnRanges(); document.execCommand('delete'); return kept.startContainer.data + ':' + kept.startOffset + ':' + kept.endOffset + ':' + kept.startContainer.parentNode.localName; })()", "bar:1:2:div");
}

test "moving nodes preserving ranges skips ranges freed during the move" {
    try helpers.onFreshThread(garbageRangesDuringMoves);
}
