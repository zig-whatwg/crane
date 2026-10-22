//! Autofocus queue ordering, collection, and Document lifetime.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn documentOf(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

fn emptyDocumentHasNoAutofocusAllocation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const document = documentOf(page);
    try std.testing.expect(dom.document_autofocus.ofDocument(document) == null);
    html.autofocus.flush(document);
    try std.testing.expect(dom.document_autofocus.ofDocument(document) == null);
    try std.testing.expect(try dom.top_layer.ofDocument(document, false) == null);
}

fn lazyInteractionAllocationFailures() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.createNullContext(std.testing.allocator);
    defer context.deinit();
    // Fail the private container and each feature's state independently,
    // including whichever feature is the first to need the container.
    for (0..4) |failure_case| {
        const offset = failure_case % 2;
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        const document = try interfaces.Document.init(failing.allocator(), &context);
        defer dom.node_creation.destroyUninserted(document);
        const before = failing.allocated_bytes - failing.freed_bytes;
        failing.fail_index = failing.alloc_index + offset;
        if (failure_case < 2) {
            try std.testing.expect(dom.document_autofocus.ensureForDocument(document) == null);
        } else {
            try std.testing.expectError(error.OutOfMemory, dom.top_layer.ofDocument(document, true));
        }
        try std.testing.expect(dom.document_autofocus.ofDocument(document) == null);
        try std.testing.expect(try dom.top_layer.ofDocument(document, false) == null);
        try std.testing.expectEqual(before, failing.allocated_bytes - failing.freed_bytes);
        failing.fail_index = std.math.maxInt(usize);
        const state = dom.document_autofocus.ensureForDocument(document) orelse return error.NoAutofocusState;
        try std.testing.expect(dom.document_autofocus.ensureForDocument(document) == state);
        // A failed top-layer allocation must preserve the autofocus state.
        const with_autofocus = failing.allocated_bytes - failing.freed_bytes;
        failing.fail_index = failing.alloc_index;
        try std.testing.expectError(error.OutOfMemory, dom.top_layer.ofDocument(document, true));
        try std.testing.expect(try dom.top_layer.ofDocument(document, false) == null);
        try std.testing.expect(dom.document_autofocus.ofDocument(document) == state);
        try std.testing.expectEqual(with_autofocus, failing.allocated_bytes - failing.freed_bytes);
        failing.fail_index = std.math.maxInt(usize);
        try std.testing.expect(try dom.top_layer.ofDocument(document, true) != null);
    }
    // The reverse sibling order: failed autofocus creation keeps an existing
    // top layer intact, including its storage and the shared container.
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const document = try interfaces.Document.init(failing.allocator(), &context);
    defer dom.node_creation.destroyUninserted(document);
    const layer = (try dom.top_layer.ofDocument(document, true)).?;
    const before = failing.allocated_bytes - failing.freed_bytes;
    failing.fail_index = failing.alloc_index;
    try std.testing.expect(dom.document_autofocus.ensureForDocument(document) == null);
    try std.testing.expect(try dom.top_layer.ofDocument(document, false) == layer);
    try std.testing.expectEqual(before, failing.allocated_bytes - failing.freed_bytes);
    failing.fail_index = std.math.maxInt(usize);
    try std.testing.expect(dom.document_autofocus.ensureForDocument(document) != null);
}

fn interactionStatesCoexist() !void {
    for (0..3) |cleanup_case| {
        const autofocus_first = cleanup_case != 1;
        const page = try helpers.Page.open();
        defer page.close();
        const document = documentOf(page);
        try page.run("document.body.innerHTML = '<input id=candidate><div id=layer>'");
        const candidate = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("candidate"))).?;
        const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("layer"))).?;
        if (autofocus_first) {
            _ = dom.document_autofocus.ensureForDocument(document) orelse return error.NoAutofocusState;
            try std.testing.expect(try dom.top_layer.ofDocument(document, false) == null);
        } else {
            _ = (try dom.top_layer.ofDocument(document, true)) orelse return error.NoTopLayerState;
            try std.testing.expect(dom.document_autofocus.ofDocument(document) == null);
        }
        const state = dom.document_autofocus.ensureForDocument(document).?;
        const layer = (try dom.top_layer.ofDocument(document, true)).?;
        try state.append(std.testing.allocator, document, candidate);
        const entry = try layer.pin(element);
        try page.run("document.body.replaceChildren(); TestUtils.gc()");
        try std.testing.expect(state.first.?.element.get() == candidate);
        try std.testing.expect(entry.node() == element);
        if (cleanup_case == 0) {
            state.clear();
            try page.run("TestUtils.gc()");
            try std.testing.expect(entry.node() == element);
        } else if (cleanup_case == 1) {
            layer.remove(entry.id);
            try page.run("TestUtils.gc()");
            try std.testing.expect(state.first.?.element.get() == candidate);
        }
        // Each side is cleared independently, and the final case retains
        // both. Ending the realm must release exactly the remaining holds.
        try page.browser.navigateWithOptions("http://af2.test/interaction-end", .window, .{ .skip_load = true });
    }
}

fn insertionOrder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id=first autofocus><input id=second autofocus>';
        \\const first = document.getElementById('first');
        \\first.remove(); document.getElementById('second').before(first);
    );
    const state = dom.document_autofocus.ofDocument(documentOf(page)).?;
    try std.testing.expect(state.hasCandidates());
    html.autofocus.flush(documentOf(page));
    try page.run("if (document.activeElement.id !== 'second') throw new Error('candidate order')");
    try std.testing.expect(state.processed);
    try std.testing.expect(!state.hasCandidates());
}

fn emptyThenLateCandidate() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const document = documentOf(page);
    html.autofocus.flush(document);
    try std.testing.expect(dom.document_autofocus.ofDocument(document) == null);
    try page.run("document.body.innerHTML = '<input autofocus id=late>'");
    html.autofocus.flush(document);
    try page.run("if (document.activeElement.id !== 'late') throw new Error('late candidate')");
}

fn detachedCandidateSurvivesGc() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\(() => {
        \\  const input = document.createElement('input');
        \\  input.autofocus = true; input.id = 'kept';
        \\  document.body.append(input); input.remove();
        \\})();
        \\TestUtils.gc();
    );
    const state = dom.document_autofocus.ofDocument(documentOf(page)).?;
    const held = state.first.?.element.get() orelse return error.CandidateLost;
    var id = try interfaces.Element.get_id(held);
    defer id.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("kept", id.asSlice());
    _ = try interfaces.Node.call_appendChild((try interfaces.Document.get_body(documentOf(page))).?, held);
    html.autofocus.flush(documentOf(page));
    try page.run("if (document.activeElement.id !== 'kept') throw new Error('held candidate')");
}

fn pendingAtTeardown() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<input autofocus>'; document.body.firstChild.remove(); TestUtils.gc()");
    try std.testing.expect(dom.document_autofocus.ofDocument(documentOf(page)).?.hasCandidates());
}

fn endedRealmCleanup() !void {
    const page = try helpers.Page.open();
    defer page.close();
    var state: dom.document_autofocus.State = .{};
    defer state.clear();
    try page.run("document.body.innerHTML = '<input id=held autofocus>'");
    const document = documentOf(page);
    try std.testing.expect(dom.document_autofocus.hasCandidates(document));
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("held"))).?;
    try state.append(std.testing.allocator, document, element);
    // Keep the Browser's slab alive while ending the old document's realm.
    try page.browser.navigateWithOptions("http://af2.test/next", .window, .{ .skip_load = true });
    state.clear();
    try std.testing.expect(!state.hasCandidates());
}

fn allocationTrial(allocator: std.mem.Allocator, document: *runtime.Instance, element: *runtime.Instance) !void {
    var slot: ?*dom.document_autofocus.State = null;
    defer if (slot) |state| state.destroy(allocator);
    const state = dom.document_autofocus.State.ensure(&slot, allocator) catch |err| {
        try std.testing.expect(slot == null);
        return err;
    };
    try std.testing.expect(try dom.document_autofocus.State.ensure(&slot, allocator) == state);
    try state.append(allocator, document, element);
    try state.append(allocator, document, element);
    try std.testing.expect(state.first == state.last);
}

fn allocationFailure() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<input id=held>'");
    const document = documentOf(page);
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("held"))).?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{ document, element });
}

fn reusedSlotsKeepOtherCandidates() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const document = documentOf(page);
    try page.run("document.body.innerHTML = '<input id=a><input id=b><input id=c>'");
    const a = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    const b = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("b"))).?;
    const c = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c"))).?;
    var state: dom.document_autofocus.State = .{};
    defer state.clear();
    try state.append(std.testing.allocator, document, a);
    try state.append(std.testing.allocator, document, b);
    try state.append(std.testing.allocator, document, c);
    try state.append(std.testing.allocator, document, a);
    // Queue order is b,c,a; slot order remains a,b,c. Removing b leaves
    // a hole that can be reused without overwriting a or c's traced edge.
    const removed = state.takeFirst().?;
    const slot = removed.id;
    try std.testing.expect(removed.element.get() == b);
    removed.release();
    try state.append(std.testing.allocator, document, b);
    try std.testing.expectEqual(slot, state.last.?.id);
    try page.run("document.body.replaceChildren(); TestUtils.gc()");
    for ([_]*runtime.Instance{ c, a, b }) |expected| {
        const entry = state.takeFirst().?;
        defer entry.release();
        try std.testing.expect(entry.element.get() == expected);
    }
    try std.testing.expect(state.first_id == null);
}

fn dialogWithoutEngine() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.createNullContext(std.testing.allocator);
    defer context.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(document);
    const dialog = try interfaces.HTMLDialogElement.init(std.testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(dialog);
    try dom.node_document.set(dialog, document);
    // No engine means retain(control) returns null. Its live native
    // generation can still be read, but no navigable exists to complete.
    try interfaces.HTMLDialogElement.call_show(dialog);
    try std.testing.expect(try interfaces.HTMLDialogElement.get_open(dialog));
    try std.testing.expect(dom.document_autofocus.ofDocument(document) == null);
}

fn dialogCompletesAfterRemoval() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<dialog><input></dialog>';
        \\const dialog = document.querySelector('dialog');
        \\let calls = 0;
        \\dialog.firstChild.addEventListener('focus', event => {
        \\  ++calls; event.target.remove(); TestUtils.gc();
        \\});
        \\dialog.show();
        \\if (calls !== 1) throw new Error('dialog focus did not run');
    );
    const state = dom.document_autofocus.ofDocument(documentOf(page)).?;
    try std.testing.expect(state.processed);
    try std.testing.expect(!state.hasCandidates());
}

fn makeNativeWindow(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(std.testing.allocator, realm) catch null;
}

fn dialogBeforeToggleRetiresRealm() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const engine = @import("engine");
    // As in ce_scope_agent_test, explicitly create a child realm afresh.
    // The process may have been started without a snapshot by another test.
    const realm = try engine.createWindowRealm(&.{
        .agent = page.browser.agent.?,
        .allocator = std.testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .parent = page.browser.getRealm().?,
        .browser_scope = page.browser.scope,
        .create_global_object = makeNativeWindow,
    });
    defer if (realm.hasEngine()) engine.destroyWindowRealm(realm, .global_detached);
    const document = try interfaces.Document.init(std.testing.allocator, realm);
    const dialog = try interfaces.HTMLDialogElement.init(std.testing.allocator, realm);
    try dom.node_document.set(dialog, document);
    // Engine-backed show() keeps the existing beforetoggle cleanup path.
    try interfaces.HTMLDialogElement.call_show(dialog);
    try std.testing.expect(try interfaces.HTMLDialogElement.get_open(dialog));

    const event = try interfaces.ToggleEvent.call_constructor(realm, runtime.DOMString.initInterned("beforetoggle"), .passed(.{
        .base = .{},
        .oldState = runtime.DOMString.initInterned("closed"),
        .newState = runtime.DOMString.initInterned("open"),
    }));
    const generation = runtime.SlabAllocator.generationOf(event);
    const held_event = try engine.retainValue(realm, .{ .instance = event });
    defer held_event.release();
    event.releaseIfUnwrapped(generation);
    try std.testing.expectEqual(generation, runtime.SlabAllocator.generationOf(event));
    var old_state = try interfaces.ToggleEvent.get_oldState(event);
    defer old_state.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("closed", old_state.asSlice());

    // Like ce_scope_agent_test, end this native fixture's realm explicitly.
    // navigable_destroyed would only detach it while the wrapper is held.
    // No WindowProxy was handed to a successor, so global_detached ends it.
    engine.destroyWindowRealm(realm, .global_detached);
    try std.testing.expect(!realm.hasEngine());
    try std.testing.expect(realm.agent != null);
    event.releaseIfUnwrapped(generation);
}

test "autofocus reinsertion moves a candidate to the end" {
    try helpers.onFreshThread(insertionOrder);
}
test "autofocus state keeps Document in its existing allocation class" {
    const size = @sizeOf(dom.document_internals.InternalState);
    if (size > 2048) std.debug.print("autofocus Document state is {d} B\n", .{size});
    try std.testing.expect(size <= 2048);
}
test "empty Document lookup and autofocus flush allocate no autofocus state" {
    try helpers.onFreshThread(emptyDocumentHasNoAutofocusAllocation);
}
test "lazy Document interaction allocations fail without publishing partial state" {
    try helpers.onFreshThread(lazyInteractionAllocationFailures);
}
test "autofocus and top-layer state coexist in either creation order through realm end" {
    try helpers.onFreshThread(interactionStatesCoexist);
}
test "empty autofocus flush leaves later insertion eligible" {
    try helpers.onFreshThread(emptyThenLateCandidate);
}
test "autofocus holds a detached candidate after script drops every reference" {
    try helpers.onFreshThread(detachedCandidateSurvivesGc);
}
test "Document teardown releases pending autofocus candidates" {
    try helpers.onFreshThread(pendingAtTeardown);
}
test "autofocus candidate cleanup after realm teardown uses only live owners" {
    try helpers.onFreshThread(endedRealmCleanup);
}
test "autofocus candidate allocation failure leaves no hold" {
    try helpers.onFreshThread(allocationFailure);
}
test "autofocus slot reuse after reinsertion keeps every other detached candidate" {
    try helpers.onFreshThread(reusedSlotsKeepOtherCandidates);
}
test "dialog focusing without an engine or node navigable leaves autofocus unprocessed" {
    try helpers.onFreshThread(dialogWithoutEngine);
}
test "dialog focusing completes autofocus after removing and collecting its control" {
    try helpers.onFreshThread(dialogCompletesAfterRemoval);
}
test "dialog beforetoggle realm retirement and later event collection do not double free" {
    helpers.onFreshThread(dialogBeforeToggleRetiresRealm) catch |err| {
        std.debug.print("dialog realm fixture failed: {s}\n", .{@errorName(err)});
        return err;
    };
}
