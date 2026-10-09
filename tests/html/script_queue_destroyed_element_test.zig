//! DW-N3 (tmp/analysis/fix-list.md): a script element destroyed while it is
//! on its document's script lists leaves them. The lists hold bare element
//! pointers (dom/document_scripts.zig); State.deinit released the queue's
//! execution root and left the pointer, for the next drain to read - a freed
//! slot, or whatever element the slab reissued there. Explicit destruction
//! erases the membership (script_element.forgetQueueMembership, from
//! HTMLScriptElement.deinit). Engine-less: no execution root, no wrapper,
//! only the native lists.
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const dom = @import("dom");

const interfaces = html.interfaces;
const testing = std.testing;

fn queuedScript(allocator: std.mem.Allocator, ctx: runtime.Context, document: *runtime.Instance) !*runtime.Instance {
    const element = try interfaces.HTMLScriptElement.init(allocator, ctx);
    errdefer interfaces.HTMLScriptElement.deinit(element);
    try dom.node_document.set(element, document);
    const state = html.script_element.of(element) orelse return error.NoScriptElementState;
    state.preparation_time_document = document;
    state.preparation_time_document_generation = runtime.SlabAllocator.generationOf(document);
    state.ready_to_be_parser_executed = true;
    return element;
}

test "a script element destroyed while queued leaves every script list of its document" {
    @import("interfaces").process_hooks.startHooksForTest();
    const allocator = testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const document = try interfaces.Document.init(allocator, ctx);
    defer dom.node_creation.destroyUninserted(document);
    const scripts = dom.document_scripts.of(document) orelse return error.NoDocumentScripts;

    // One on each list, one as the pending parsing-blocking script, and one
    // that stays queued.
    const asap = try queuedScript(allocator, ctx, document);
    try scripts.addAsap(asap);
    const in_order = try queuedScript(allocator, ctx, document);
    try scripts.appendInOrder(in_order);
    const deferred = try queuedScript(allocator, ctx, document);
    try scripts.addWhenParsingFinished(deferred);
    const blocking = try queuedScript(allocator, ctx, document);
    (html.script_element.of(blocking) orelse return error.NoScriptElementState).parser_document = document;
    scripts.pending_parsing_blocking_script = blocking;
    const kept = try queuedScript(allocator, ctx, document);
    defer dom.node_creation.destroyUninserted(kept);
    try scripts.appendInOrder(kept);

    for ([_]*runtime.Instance{ asap, in_order, deferred, blocking }) |element| dom.node_creation.destroyUninserted(element);

    // Gone from every list; the kept one is untouched.
    try testing.expectEqual(@as(usize, 0), scripts.scripts_to_execute_asap.items.len);
    try testing.expectEqual(@as(usize, 1), scripts.scripts_to_execute_in_order_asap.items.len);
    try testing.expect(scripts.scripts_to_execute_in_order_asap.items[0] == kept);
    try testing.expectEqual(@as(usize, 0), scripts.scripts_to_execute_when_parsing_finished.items.len);
    try testing.expect(scripts.pending_parsing_blocking_script == null);

    // Draining reaches none of them: no parsing-blocking script to run, no
    // deferred one, and the in-order head is the kept element.
    try testing.expect(!html.script_execution.executePendingParserBlockingScript(allocator, document));
    html.script_execution.executeScriptsWhenParsingFinished(allocator, document);
    try testing.expect(scripts.firstInOrder() == kept);

    // What is still queued when the document goes is discarded, not run.
    html.script_execution.discardDocumentScripts(document);
}
