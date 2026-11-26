//! Allocator hardening, batch B2, red tests B1 (cage satellites), B2 (no
//! cross-partition attribute-value -> rare/listener reuse), B4 (satellite leak
//! fails its test scope), and item 4 (name-record reshape: header in objects,
//! page-chosen name bytes in bytes).
//!
//! Design: tmp/plans/allocator-hardening-design.md §§1.2, 3.1, 3.4, 3.5, 3.7
//! and §7 Batch B items 3–4.
//!
//! Every assertion here FAILS on main `a845b0000`:
//! - Satellites live in `.objects` (or `.bytes` for 4-byte-aligned AttributeList),
//!   outside the node cage;
//! - Rare `Bytes` (`nonce`/`is`) had `len: usize` (align 8), landing in `.objects`;
//! - Dynamic `ElementName` and attribute `QualifiedName` records keep page-chosen
//!   name bytes in the same `.objects` block as their pointer header.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

const Heap = runtime.BrowserScope.Heap;

const Range = enum { outside, cage, objects, bytes, metadata };

fn rangeOf(heap: *const Heap.BrowserHeap, ptr: *const anyopaque) Range {
    const address = @intFromPtr(ptr);
    if (address < heap.reserved.base or address - heap.reserved.base >= heap.reserved.size) return .outside;
    const offset: u64 = address - heap.window_base;
    const l = Heap.layout;
    if (offset >= l.cage.offset and offset < l.cage.end()) return .cage;
    if (offset >= l.objects.offset and offset < l.objects.end()) return .objects;
    if (offset >= l.bytes.offset and offset < l.bytes.end()) return .bytes;
    return .metadata;
}

fn heapOf(page: helpers.Page) !*Heap.BrowserHeap {
    const heap = page.browser.scope.heap orelse return error.NoHeap;
    if (!heap.general_pools) return error.SkipZigTest;
    return heap;
}

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn rareAndListenerPlacement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    try page.run(
        \\const el = document.createElement('div');
        \\el.id = 'sat-rare';
        \\el.nonce = 'secret-nonce-value-12345';
        \\el.addEventListener('click', () => {});
        \\el.addEventListener('my-custom-event', () => {});
        \\document.body.appendChild(el);
    );
    const document = try documentOf(page);
    const el = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("sat-rare"))) orelse return error.NoElement;
    const node = dom.instance_bridge.getNodeBase(el) orelse return error.NoNodeBase;

    // Row 6-7: rare block is in the cage.
    const rare_block = node.rare.block orelse return error.NoRareBlock;
    try testing.expectEqual(Range.cage, rangeOf(heap, rare_block));

    // Row 8: rare Bytes (nonce) is page bytes -> bytes range.
    const nonce = dom.node_rare_data.get(node.rare, .nonce) orelse return error.NoNonce;
    try testing.expectEqual(Range.bytes, rangeOf(heap, nonce));

    // Row 9: node target's event listener list block is in the cage;
    // custom event type copy is page bytes -> bytes range.
    const listeners = node.eventListeners();
    const header = listeners.header orelse return error.NoListenerBlock;
    try testing.expectEqual(Range.cage, rangeOf(heap, header));
    try testing.expectEqual(@as(usize, 2), listeners.len());
    const custom_slice = listeners.at(1).type.slice();
    try testing.expectEqualStrings("my-custom-event", custom_slice);
    try testing.expectEqual(Range.bytes, rangeOf(heap, custom_slice.ptr));
}

test "B1: rare block and node listener list are in the cage; rare Bytes and custom event type are in bytes" {
    try helpers.onFreshThread(rareAndListenerPlacement);
}

fn attributesAndSharingCachePlacement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    // Parse >16 distinct attribute sets so SharingCache grows its heap tables too.
    try page.run(
        \\let html = '';
        \\for (let i = 0; i < 24; i++) {
        \\  html += `<div id="a${i}" class="c${i}" data-k="v${i}"></div>`;
        \\}
        \\html += '<div id="shared1" class="same" title="t"></div><div id="shared2" class="same" title="t"></div>';
        \\document.body.innerHTML = html;
    );
    const document = try documentOf(page);
    const el = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a0"))) orelse return error.NoElement;
    const view = dom.element_data.of(el) orelse return error.NoElementData;
    const attrs = view.data.attrs orelse return error.NoAttrs;

    // Row 12: attribute entry block is in the cage.
    try testing.expectEqual(Range.cage, rangeOf(heap, attrs));

    // Row 12: DocumentCache and SharingCache tables are in the cage.
    const doc_state = dom.document_state.Registry.get(document) orelse return error.NoDocState;
    const interaction = doc_state.interaction_state orelse return error.NoInteractionState;
    const cache = interaction.attribute_blocks orelse return error.NoSharingCache;
    try testing.expectEqual(Range.cage, rangeOf(heap, cache));
    try testing.expect(cache.blocks.heap_slots.len > 0);
    try testing.expectEqual(Range.cage, rangeOf(heap, @ptrCast(cache.blocks.heap_slots.ptr)));
    try testing.expectEqual(Range.cage, rangeOf(heap, cache.blocks.heap_hashes.ptr));
}

test "B1: attribute entry block and its sharing cache live in the cage" {
    try helpers.onFreshThread(attributesAndSharingCachePlacement);
}

fn observerSlotAndStylePlacement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    try page.run(
        \\const host = document.createElement('div');
        \\host.id = 'sat-host';
        \\host.style.color = 'red';
        \\const shadow = host.attachShadow({ mode: 'open' });
        \\const slot = document.createElement('slot');
        \\slot.id = 'sat-slot';
        \\slot.name = 'main-slot';
        \\shadow.appendChild(slot);
        \\const child = document.createElement('span');
        \\child.id = 'sat-child';
        \\child.slot = 'main-slot';
        \\host.appendChild(child);
        \\document.body.appendChild(host);
        \\slot.assignedNodes();
        \\const mo = new MutationObserver(() => {});
        \\mo.observe(host, { attributes: true, childList: true });
        \\globalThis.__mo = mo;
        \\globalThis.__slot = slot;
    );
    const document = try documentOf(page);
    const host = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("sat-host"))) orelse return error.NoHost;
    const child = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("sat-child"))) orelse return error.NoChild;
    const host_node = dom.instance_bridge.getNodeBase(host) orelse return error.NoHostNode;
    const child_node = dom.instance_bridge.getNodeBase(child) orelse return error.NoChildNode;

    // Row 19: registered observer list head & registration entry are in the cage.
    const reg_head = dom.node_rare_data.get(host_node.rare, .registered_observers) orelse return error.NoRegHead;
    try testing.expectEqual(Range.cage, rangeOf(heap, reg_head));
    var regs = host_node.registeredObservers();
    const reg = regs.next() orelse return error.NoRegEntry;
    const reg_node: *dom.node_base.ObserverRegistration = @fieldParentPtr("registered", reg);
    try testing.expectEqual(Range.cage, rangeOf(heap, reg_node));

    // Row 21: SlottableState (own block in rare data) is in the cage.
    const slottable = dom.node_rare_data.get(child_node.rare, .slottable) orelse return error.NoSlottable;
    try testing.expectEqual(Range.cage, rangeOf(heap, slottable));
    const slot_base = slottable.assignedSlot() orelse return error.NoAssignedSlot;
    const slot_state = dom.slot_helpers.slotState(slot_base) orelse return error.NoSlotState;
    try testing.expect(slot_state.assigned_nodes.items.len > 0);
    try testing.expectEqual(Range.cage, rangeOf(heap, slot_state.assigned_nodes.items.ptr));
    try testing.expectEqualStrings("main-slot", slot_state.name);
    try testing.expectEqual(Range.bytes, rangeOf(heap, slot_state.name.ptr));

    // Row 23: ElementStyle is in the cage.
    const el_style = dom.style.element_style.existingOf(host) orelse return error.NoElementStyle;
    try testing.expectEqual(Range.cage, rangeOf(heap, el_style));
}

test "B1: observer registrations, slot state, and ElementStyle live in the cage" {
    try helpers.onFreshThread(observerSlotAndStylePlacement);
}

fn noCrossPartitionReuseB2() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    const scope = page.browser.scope;
    const document = try documentOf(page);

    const el = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .notPassed());
    defer runtime.Instance.deinit(el);
    const node = dom.instance_bridge.getNodeBase(el) orelse return error.NoNodeBase;

    // 10,000 alternating attribute-value record frees and rare-block / listener-list
    // allocations of the same size class: never share an address, always segregated.
    var seen_value_addrs: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer seen_value_addrs.deinit(testing.allocator);

    var buf: [40]u8 = undefined;
    for (0..10_000) |i| {
        const val = try std.fmt.bufPrint(&buf, "val-class-48-{d:0>20}", .{i});
        const vid = try dom.attribute_values.intern(scope, val);
        const vptr = @intFromPtr(dom.attribute_values.bytesIn(dom.attribute_values.tableOf(scope), vid).ptr);
        try testing.expectEqual(Range.bytes, rangeOf(heap, @as(*const anyopaque, @ptrFromInt(vptr))));
        try seen_value_addrs.put(testing.allocator, vptr, {});
        dom.attribute_values.release(scope, vid);

        // Allocate a rare block on a fresh holder, verify cage + zero collision, then free.
        var holder: dom.node_rare_data.Holder = .{};
        const ctx = node.rareContext();
        try dom.node_rare_data.put(ctx, &holder, .class_list, el);
        const rptr = @intFromPtr(holder.block.?);
        try testing.expectEqual(Range.cage, rangeOf(heap, holder.block.?));
        try testing.expect(!seen_value_addrs.contains(rptr));
        dom.node_rare_data.destroy(ctx, &holder);
    }
}

test "B2: freed attribute value records are never reissued as rare blocks across 10,000 cycles" {
    try helpers.onFreshThread(noCrossPartitionReuseB2);
}

fn satelliteLeakCountedB4() !void {
    // Even with general_memory = .host, satellites live in the cage and a leaked
    // satellite is reported by the heap's leak report (design §4.2, B4).
    const browser = try browser_mod.Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .general_memory = .host,
    });
    var leaked: usize = 0;
    {
        errdefer browser.deinit();
        const heap = browser.scope.heap orelse return error.NoHeap;
        // Allocate a rare block directly via the node's rareContext and deliberately leak it.
        const context = browser.current_context orelse return error.NoPage;
        const document = context.document_instance orelse return error.NoDocument;
        const el = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .notPassed());
        defer runtime.Instance.deinit(el);
        const node = dom.instance_bridge.getNodeBase(el) orelse return error.NoNodeBase;
        var leaked_holder: dom.node_rare_data.Holder = .{};
        try dom.node_rare_data.put(node.rareContext(), &leaked_holder, .class_list, el);
        const block = leaked_holder.block orelse return error.NoRareBlock;
        if (rangeOf(heap, block) != .cage) {
            // Today: block is on testing.allocator; free it so only this assertion fails.
            dom.node_rare_data.destroy(node.rareContext(), &leaked_holder);
            return error.SatelliteOutsideCage;
        }
        browser.scope.heap_leak_count_out = &leaked;
    }
    browser.deinit();
    try testing.expectEqual(@as(usize, 1), leaked);
}

test "B4: a satellite block leaked on purpose is caught by the heap leak report even under general_memory=.host" {
    try helpers.onFreshThread(satelliteLeakCountedB4);
}

fn nameRecordReshape() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    const scope = page.browser.scope;

    // Dynamic ElementName: header in objects, all page-chosen name bytes in bytes.
    const el_name = try dom.element_name.intern(scope, "urn:hard1b2-ns", "pfx", "x-custom-tag");
    defer dom.element_name.release(scope, el_name);
    try testing.expectEqual(Range.objects, rangeOf(heap, el_name));
    try testing.expectEqual(Range.bytes, rangeOf(heap, el_name.local_name.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, el_name.prefix.?.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, el_name.namespace_uri.?.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, el_name.qualified_name.ptr));

    // HTML dynamic ElementName also has uppercase bytes in bytes.
    const html_custom = try dom.element_name.intern(scope, "http://www.w3.org/1999/xhtml", "p", "x-widget");
    defer dom.element_name.release(scope, html_custom);
    try testing.expectEqual(Range.objects, rangeOf(heap, html_custom));
    try testing.expectEqual(Range.bytes, rangeOf(heap, html_custom.local_name.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, html_custom.qualified_name.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, html_custom.qualified_name_upper.ptr));

    // Dynamic attribute QualifiedName: header in objects, name bytes in bytes.
    const attr_id = try dom.attribute_names.intern(scope, "urn:hard1b2-attr", "ap", "data-custom-attr");
    defer dom.attribute_names.release(scope, attr_id);
    const attr_rec = dom.attribute_names.record(dom.attribute_names.tableOf(scope), attr_id);
    try testing.expectEqual(Range.objects, rangeOf(heap, attr_rec));
    try testing.expectEqual(Range.bytes, rangeOf(heap, attr_rec.local_name.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, attr_rec.prefix.?.ptr));
    try testing.expectEqual(Range.bytes, rangeOf(heap, attr_rec.namespace_uri.?.ptr));
}

test "Item 4: dynamic ElementName and attribute QualifiedName headers live in objects and name bytes live in bytes" {
    try helpers.onFreshThread(nameRecordReshape);
}
