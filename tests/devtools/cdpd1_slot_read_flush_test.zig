//! `cdpd1` D4 slot-read flush: when script calls `HTMLSlotElement.assignedNodes()`,
//! `HTMLSlotElement.assignedElements()`, or reads `Slottable.assignedSlot`, any
//! pending `DOM.distributedNodesUpdated` CDP notifications for that shadow tree
//! are flushed synchronously via `inspector_probes` (matching Blink's lazy
//! `SlotAssignment::RecalcAssignment` -> `probe::DidPerformSlotDistribution`),
//! with no duplicate emitted at the subsequent rendering update, and zero cost
//! when no DOM agent is enabled.

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;
const page = harness.page;
const setUp = harness.setUp;
const expectEvents = harness.expectEvents;

fn attachAndBindOpenSlot(h: *Harness) !void {
    try setUp(h, page, null);
    try h.run("document.getElementById('a').attachShadow({ mode: 'open' }).innerHTML = '<slot></slot>';");
    try h.settle();
    // #document 1, HTML 2, HEAD 3, BODY 4, DIV#a 5, SPAN 6, "x" 7, P#b 8,
    // ShadowRoot 9 -> requestChildNodes binds SLOT 10.
    _ = try h.call("DOM.requestChildNodes", "{\"nodeId\":9}");
}

test "HTMLSlotElement.assignedNodes() flushes pending distributedNodesUpdated synchronously without duplicate on settle" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try attachAndBindOpenSlot(&h);

    const from = h.seen.items.len;
    try h.run(
        \\const host = document.getElementById('a');
        \\const slot = host.shadowRoot.querySelector('slot');
        \\const el = document.createElement('i');
        \\host.appendChild(el);
        \\const assigned = slot.assignedNodes();
        \\if (assigned.length !== 2) throw new Error('expected 2 assigned nodes');
        \\el.setAttribute('data-after', '1');
    );
    // `distributedNodesUpdated` must arrive synchronously at `slot.assignedNodes()`,
    // BEFORE `attributeModified` for `data-after`, and settling must not emit it again.
    try expectEvents(&h, from,
        \\childNodeInserted 5 6 I#11/0
        \\distributedNodesUpdated 10 [SPAN,I]
        \\attributeModified 11 data-after=1
        \\
    );
    const after_read = h.seen.items.len;
    try h.settle();
    try expectEvents(&h, after_read, "");
}

test "HTMLSlotElement.assignedElements() flushes pending distributedNodesUpdated synchronously without duplicate on settle" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try attachAndBindOpenSlot(&h);

    const from = h.seen.items.len;
    try h.run(
        \\const host = document.getElementById('a');
        \\const slot = host.shadowRoot.querySelector('slot');
        \\const el = document.createElement('em');
        \\host.appendChild(el);
        \\const assigned = slot.assignedElements();
        \\if (assigned.length !== 2) throw new Error('expected 2 assigned elements');
        \\el.setAttribute('data-after', '2');
    );
    try expectEvents(&h, from,
        \\childNodeInserted 5 6 EM#11/0
        \\distributedNodesUpdated 10 [SPAN,EM]
        \\attributeModified 11 data-after=2
        \\
    );
    const after_read = h.seen.items.len;
    try h.settle();
    try expectEvents(&h, after_read, "");
}

test "Slottable.assignedSlot flushes pending distributedNodesUpdated for open shadow root (both assigned and unassigned) and ignores unrelated hosts" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    try h.run(
        \\document.getElementById('a').attachShadow({ mode: 'open' }).innerHTML = '<slot></slot>';
        \\document.getElementById('b').attachShadow({ mode: 'open' }).innerHTML = '<slot></slot>';
    );
    try h.settle();
    // DIV#a shadowRoot = 9 (SLOT = 11), P#b shadowRoot = 10 (SLOT = 12).
    _ = try h.call("DOM.requestChildNodes", "{\"nodeId\":9}");
    _ = try h.call("DOM.requestChildNodes", "{\"nodeId\":10}");

    // Mutate BOTH hosts, then read assignedSlot on a child of #a only.
    // Only #a's slot (11) flushes synchronously; #b's slot (12) waits for settle.
    const from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\const b = document.getElementById('b');
        \\const ia = document.createElement('i');
        \\const ib = document.createElement('u');
        \\a.appendChild(ia);
        \\b.appendChild(ib);
        \\if (ia.assignedSlot !== a.shadowRoot.querySelector('slot')) throw new Error('expected slot');
        \\ia.setAttribute('data-mark', 'a');
    );
    try expectEvents(&h, from,
        \\childNodeInserted 5 6 I#13/0
        \\childNodeInserted 8 0 U#14/0
        \\distributedNodesUpdated 11 [SPAN,I]
        \\attributeModified 13 data-mark=a
        \\
    );
    const before_settle = h.seen.items.len;
    try h.settle();
    try expectEvents(&h, before_settle,
        \\distributedNodesUpdated 12 [U]
        \\
    );

    // Unslotting `ia` (moving it to a non-matching slot name) then reading `ia.assignedSlot`
    // (which returns null) still flushes the shadow root's pending slot update synchronously.
    const unslot_from = h.seen.items.len;
    try h.run(
        \\(() => {
        \\  const el = document.querySelector('#a i');
        \\  el.setAttribute('slot', 'missing');
        \\  if (el.assignedSlot !== null) throw new Error('expected null assignedSlot');
        \\  el.setAttribute('data-mark', 'unslotted');
        \\})();
    );
    try expectEvents(&h, unslot_from,
        \\attributeModified 13 slot=missing
        \\distributedNodesUpdated 11 [SPAN]
        \\attributeModified 13 data-mark=unslotted
        \\
    );
    const after_unslot = h.seen.items.len;
    try h.settle();
    try expectEvents(&h, after_unslot, "");
}

test "Slottable.assignedSlot does not flush a closed shadow root's pending distribution" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    try h.run("window.closedRoot = document.getElementById('a').attachShadow({ mode: 'closed' }); window.closedRoot.innerHTML = '<slot></slot>';");
    try h.settle();
    _ = try h.call("DOM.requestChildNodes", "{\"nodeId\":9}");

    const from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\const el = document.createElement('i');
        \\a.appendChild(el);
        \\if (el.assignedSlot !== null) throw new Error('closed shadow root must return null');
        \\el.setAttribute('data-closed', '1');
    );
    // Closed shadow root must NOT flush on el.assignedSlot; it flushes at settle.
    try expectEvents(&h, from,
        \\childNodeInserted 5 6 I#11/0
        \\attributeModified 11 data-closed=1
        \\
    );
    const before_settle = h.seen.items.len;
    try h.settle();
    try expectEvents(&h, before_settle,
        \\distributedNodesUpdated 10 [SPAN,I]
        \\
    );
}

test "HTMLSlotElement.assignedNodes({flatten: true}) flushes nested shadow root slot distribution" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    try h.run(
        \\(() => {
        \\  const outer = document.getElementById('a');
        \\  const outerRoot = outer.attachShadow({ mode: 'open' });
        \\  outerRoot.innerHTML = '<div id=inner><slot></slot></div>';
        \\  const inner = outerRoot.getElementById('inner');
        \\  const innerRoot = inner.attachShadow({ mode: 'open' });
        \\  innerRoot.innerHTML = '<slot></slot>';
        \\})();
    );
    try h.settle();
    // Bind outerRoot (9) -> DIV#inner (10) -> innerRoot (11) & outer SLOT (12) -> inner SLOT (13).
    _ = try h.call("DOM.requestChildNodes", "{\"nodeId\":9,\"depth\":-1,\"pierce\":true}");

    const from = h.seen.items.len;
    try h.run(
        \\(() => {
        \\  const outer = document.getElementById('a');
        \\  const inner = outer.shadowRoot.getElementById('inner');
        \\  const innerSlot = inner.shadowRoot.querySelector('slot');
        \\  const el = document.createElement('b');
        \\  outer.appendChild(el);
        \\  const flat = innerSlot.assignedNodes({ flatten: true });
        \\  if (flat.length !== 2) throw new Error('expected 2 flattened nodes');
        \\  el.setAttribute('data-flat', '1');
        \\})();
    );
    // `outer.appendChild(el)` dirties outer's slot; reading `innerSlot.assignedNodes({flatten: true})`
    // traverses into outer's slot and flushes its distribution synchronously before `data-flat=1`.
    h.drain();
    var saw_distributed = false;
    var saw_attr = false;
    for (h.seen.items[from..]) |parsed| {
        const method = parsed.value.object.get("method") orelse continue;
        if (std.mem.eql(u8, method.string, "DOM.distributedNodesUpdated")) {
            try testing.expect(!saw_attr);
            saw_distributed = true;
        } else if (std.mem.eql(u8, method.string, "DOM.attributeModified")) {
            saw_attr = true;
        }
    }
    try testing.expect(saw_distributed);
    try testing.expect(saw_attr);

    const after_read = h.seen.items.len;
    try h.settle();
    try expectEvents(&h, after_read, "");
}

test "slot reads work with zero observer cost when no DOM agent is enabled" {
    const before = devtools.dom_events.enabledAgentCount();
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    // DOM domain NOT enabled: gate remains closed.
    try testing.expectEqual(before, devtools.dom_events.enabledAgentCount());
    try h.run(
        \\const a = document.getElementById('a');
        \\const root = a.attachShadow({ mode: 'open' });
        \\root.innerHTML = '<slot></slot>';
        \\const slot = root.querySelector('slot');
        \\const el = document.createElement('i');
        \\a.appendChild(el);
        \\if (slot.assignedNodes().length !== 2) throw new Error('assignedNodes failed');
        \\if (slot.assignedElements().length !== 2) throw new Error('assignedElements failed');
        \\if (el.assignedSlot !== slot) throw new Error('assignedSlot failed');
    );
    try testing.expectEqual(before, devtools.dom_events.enabledAgentCount());
}
