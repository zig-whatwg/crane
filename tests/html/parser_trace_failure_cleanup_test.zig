//! A failed parser remains cancellable without resuming its input. The active
//! caller retains native ownership until cleanup unwinds, even without an engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const scripted_parser = html.scripted_parser;

const Loader = struct {
    references: usize = 1,
    releases: usize = 0,

    fn retain(data: ?*anyopaque) void {
        const self: *Loader = @ptrCast(@alignCast(data.?));
        self.references += 1;
    }

    fn release(data: ?*anyopaque) void {
        const self: *Loader = @ptrCast(@alignCast(data.?));
        self.references -= 1;
        self.releases += 1;
    }

    fn load(_: ?*anyopaque, _: []const u8) ?[]const u8 {
        return null;
    }
};

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    var loader = Loader{};
    const parser = try scripted_parser.DocumentParser.createComplete(std.testing.allocator, &context, document, "<!doctype html><body><div>failed input", .{
        .script_loader = .{ .context = &loader, .retain = Loader.retain, .release = Loader.release, .loadScript = Loader.load },
    });
    var initiating_owner = true;
    defer if (initiating_owner) parser.release();
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.input_stream.complete = false;
    parser.input_stream.processInserted();
    const call = try parser.protect();
    var active_owner = true;
    defer if (active_owner) call.deinit();
    parser.release();
    initiating_owner = false;

    // A terminal append failure may follow earlier script preparation. Both
    // parser-owned queues must cancel preparation before their parser detaches.
    const blocker = try interfaces.HTMLScriptElement.init(std.testing.allocator, &context);
    defer interfaces.HTMLScriptElement.deinit(blocker);
    const deferred = try interfaces.HTMLScriptElement.init(std.testing.allocator, &context);
    defer interfaces.HTMLScriptElement.deinit(deferred);
    const scripts = dom.document_scripts.of(document).?;
    defer html.script_execution.discardParserScripts(document);
    for ([_]*runtime.Instance{ blocker, deferred }) |element| {
        try dom.node_document.set(element, document);
        const state = html.script_element.of(element).?;
        state.preparation_time_document = document;
        state.preparation_time_document_generation = runtime.SlabAllocator.generationOf(document);
        state.ready_to_be_parser_executed = true;
        state.delaying_the_load_event = true;
        // A primitive owning value exercises the native queue-root transfer
        // without claiming to inject or measure engine handle ownership.
        state.execution_root = .{ .value = .undefined };
    }
    scripts.pending_parsing_blocking_script = blocker;
    try scripts.addWhenParsingFinished(deferred);

    // Model a terminal trace-append failure while an existing invocation is
    // active. This controls native cleanup; it does not inject a V8 failure.
    parser.trace_failure = error.OutOfMemory;
    parser.input_stream.discardInput();
    try std.testing.expectError(error.OutOfMemory, parser.protect());
    try std.testing.expect(dom.document_internals.getInternal(document).?.salvageable);
    dom.document_lifecycle.abort(document);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser_was_aborted);
    try std.testing.expect(!dom.document_internals.getInternal(document).?.salvageable);
    try std.testing.expect(scripts.pending_parsing_blocking_script == null);
    try std.testing.expectEqual(@as(usize, 0), scripts.scripts_to_execute_when_parsing_finished.items.len);
    for ([_]*runtime.Instance{ blocker, deferred }) |element| {
        const state = html.script_element.of(element).?;
        try std.testing.expect(state.preparation_time_document == null);
        try std.testing.expectEqual(@as(u64, 0), state.preparation_time_document_generation);
        try std.testing.expect(!state.ready_to_be_parser_executed);
        try std.testing.expect(!state.delaying_the_load_event);
        try std.testing.expect(state.execution_root == null);
    }
    try std.testing.expectEqual(error.OutOfMemory, parser.trace_failure.?);
    try std.testing.expectEqual(@as(usize, 2), loader.references);
    try std.testing.expectEqual(@as(usize, 0), loader.releases);
    const mapped_nodes = parser.adapter.node_map.count();
    parser.input_stream.processInserted();
    try std.testing.expectEqual(mapped_nodes, parser.adapter.node_map.count());
    try std.testing.expect(!parser.input_stream.eof_processed);
    try std.testing.expectEqual(error.OutOfMemory, parser.trace_failure.?);
    // The final ActiveCall release drops the parser's acquired loader. Its
    // allocator-owned stages must all be gone before runtime pool teardown.
    call.deinit();
    active_owner = false;
    try std.testing.expectEqual(@as(usize, 1), loader.references);
    try std.testing.expectEqual(@as(usize, 1), loader.releases);
}

test "a failed parser abort detaches without resuming and preserves active-call ownership" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
