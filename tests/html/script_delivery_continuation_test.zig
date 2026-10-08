//! Dropped delivery resumes a surviving document only on a later task.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");

const Fixture = struct {
    ctx: runtime.ContextData = undefined,
    document: *runtime.Instance = undefined,
    tasks: [16]runtime.EventLoopTask = undefined,
    task_count: usize = 0,
    queue_calls: usize = 0,
    drop_tasks: bool = false,
    document_alive: bool = true,

    fn init(self: *@This()) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        self.ctx = try runtime.ContextData.init(std.testing.allocator, .{
            .event_loop = .{ .ptr = self, .vtable = &vtable },
        });
        self.document = try interfaces.Document.init(std.testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
    }

    fn deinit(self: *@This()) void {
        if (self.document_alive) interfaces.Document.deinit(self.document);
        // Task payloads borrow the document. Even after Document.deinit,
        // dropping them must release their own storage without reading it.
        while (self.task_count > 0) {
            const task = self.takeFirst();
            if (task.drop) |drop| drop(task.context);
        }
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn takeFirst(self: *@This()) runtime.EventLoopTask {
        std.debug.assert(self.task_count > 0);
        const task = self.tasks[0];
        self.task_count -= 1;
        std.mem.copyForwards(runtime.EventLoopTask, self.tasks[0..self.task_count], self.tasks[1 .. self.task_count + 1]);
        return task;
    }

    fn runFirst(self: *@This()) void {
        const task = self.takeFirst();
        task.callback(task.context);
    }

    fn queue(context: *anyopaque, task: runtime.EventLoopTask) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.queue_calls += 1;
        if (self.drop_tasks) {
            if (task.drop) |drop| drop(task.context);
            return;
        }
        std.debug.assert(self.task_count < self.tasks.len);
        self.tasks[self.task_count] = task;
        self.task_count += 1;
    }
    fn microtask(_: *anyopaque, _: runtime.EventLoopMicrotask) void {}
    fn flush(_: *anyopaque) void {}
    fn once(_: *anyopaque) bool {
        return false;
    }
    fn allocator(_: *anyopaque) std.mem.Allocator {
        return std.testing.allocator;
    }
    const vtable: runtime.EventLoop.VTable = .{
        .queueTask = queue,
        .queueMicrotask = microtask,
        .runMicrotasks = flush,
        .runOnce = once,
        .promiseAllocator = allocator,
    };
};

test "discarding the last ASAP delivery rechecks load on a later task" {
    var fixture: Fixture = .{};
    try fixture.init();
    defer fixture.deinit();
    const internal = dom.document_internals.getInternal(fixture.document).?;
    // Delivery cleanup has removed the last queue entry and load delay.
    internal.load_waiting_on_delay = true;
    dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
    try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
    try std.testing.expect(internal.load_waiting_on_delay);
    try std.testing.expect(!internal.ready_for_post_load_tasks);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(fixture.document)), fixture.tasks[0].document);
    fixture.runFirst();
    try std.testing.expect(!internal.load_waiting_on_delay);
    try std.testing.expect(internal.ready_for_post_load_tasks);
    try std.testing.expectEqual(@as(usize, 1), fixture.task_count); // load, still queued
}

test "discarding the last deferred delivery continues the end asynchronously" {
    var fixture: Fixture = .{};
    try fixture.init();
    defer fixture.deinit();
    const internal = dom.document_internals.getInternal(fixture.document).?;
    internal.parsing_end_waiting_on_scripts = true;
    dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
    try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
    try std.testing.expect(internal.parsing_end_waiting_on_scripts);
    try std.testing.expect(!internal.ready_for_post_load_tasks);
    fixture.runFirst();
    try std.testing.expect(!internal.parsing_end_waiting_on_scripts);
    try std.testing.expect(internal.ready_for_post_load_tasks);
    try std.testing.expectEqual(@as(usize, 2), fixture.task_count); // DOMContentLoaded, load
}

test "a discarded ordered head releases its already-ready successor" {
    var fixture: Fixture = .{};
    try fixture.init();
    defer fixture.deinit();
    const successor = try interfaces.HTMLScriptElement.init(std.testing.allocator, &fixture.ctx);
    defer interfaces.HTMLScriptElement.deinit(successor);
    try dom.node_document.set(successor, fixture.document);
    const state = html.script_element.of(successor).?;
    state.preparation_time_document = fixture.document;
    state.preparation_time_document_generation = runtime.SlabAllocator.generationOf(fixture.document);
    state.ready_to_be_parser_executed = true;
    state.result = .null; // The ready result is a failed fetch, with no JS.
    const lists = dom.document_scripts.of(fixture.document).?;
    try lists.appendInOrder(successor);
    // The discarded head is already gone; its successor previously waited
    // behind it even though the successor's own delivery task had run.
    dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
    try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
    try std.testing.expectEqual(@as(usize, 1), lists.scripts_to_execute_in_order_asap.items.len);
    fixture.runFirst();
    try std.testing.expectEqual(@as(usize, 0), lists.scripts_to_execute_in_order_asap.items.len);
    try std.testing.expect(!dom.document_lifecycle.isReadyForPostLoadTasks(fixture.document));
}

test "discarding a parser blocker resumes the same paused input stream" {
    var fixture: Fixture = .{};
    try fixture.init();
    defer fixture.deinit();
    const parser = try html.scripted_parser.DocumentParser.createComplete(std.testing.allocator, &fixture.ctx, fixture.document, "<p>after blocker", .{});
    defer parser.release();
    try std.testing.expect(dom.document_lifecycle.associateParser(fixture.document, parser));
    parser.tree_builder.waiting_for_parser_blocking_script = true;
    parser.tree_builder.parser_pause_flag = true;
    dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, true);
    try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
    try std.testing.expect(parser.tree_builder.waiting_for_parser_blocking_script);
    try std.testing.expect(!parser.input_stream.eof_processed);
    fixture.runFirst();
    try std.testing.expect(!parser.tree_builder.waiting_for_parser_blocking_script);
    try std.testing.expect(!parser.tree_builder.parser_pause_flag);
    try std.testing.expect(parser.input_stream.eof_processed);
    try std.testing.expect(dom.document_internals.getInternal(fixture.document).?.active_parser == null);
    try std.testing.expect(dom.document_lifecycle.isReadyForPostLoadTasks(fixture.document));
}

test "a replacement parser cannot consume an older delivery continuation" {
    var fixture: Fixture = .{};
    try fixture.init();
    defer fixture.deinit();
    const first = try html.scripted_parser.DocumentParser.createComplete(std.testing.allocator, &fixture.ctx, fixture.document, "<p>old", .{});
    defer first.release();
    try std.testing.expect(dom.document_lifecycle.associateParser(fixture.document, first));
    dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, true);
    try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
    const replacement = try html.scripted_parser.DocumentParser.createComplete(std.testing.allocator, &fixture.ctx, fixture.document, "<p>new", .{});
    defer replacement.release();
    try std.testing.expect(dom.document_lifecycle.associateParser(fixture.document, replacement));
    replacement.tree_builder.waiting_for_parser_blocking_script = true;
    replacement.tree_builder.parser_pause_flag = true;
    fixture.runFirst();
    try std.testing.expect(replacement.tree_builder.waiting_for_parser_blocking_script);
    try std.testing.expect(replacement.tree_builder.parser_pause_flag);
    try std.testing.expect(!replacement.input_stream.eof_processed);
    try std.testing.expect(!dom.document_lifecycle.isReadyForPostLoadTasks(fixture.document));
}

test "abort or destruction suppresses an already queued continuation" {
    for (0..3) |kind| {
        var fixture: Fixture = .{};
        try fixture.init();
        defer fixture.deinit();
        dom.document_internals.getInternal(fixture.document).?.load_waiting_on_delay = true;
        dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
        try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
        switch (kind) {
            0 => dom.document_lifecycle.abort(fixture.document),
            1 => dom.document_lifecycle.destroy(fixture.document),
            2 => {
                interfaces.Document.deinit(fixture.document);
                fixture.document_alive = false;
            },
            else => unreachable,
        }
        // Cancellation itself and later cleanup cannot restart normal load.
        dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
        try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
        fixture.runFirst();
        try std.testing.expectEqual(@as(usize, 0), fixture.task_count);
        if (fixture.document_alive) try std.testing.expect(!dom.document_lifecycle.isReadyForPostLoadTasks(fixture.document));
    }
}

test "a dropped continuation never runs inline or queues another continuation" {
    var fixture: Fixture = .{};
    try fixture.init();
    defer fixture.deinit();
    const internal = dom.document_internals.getInternal(fixture.document).?;
    internal.load_waiting_on_delay = true;
    fixture.drop_tasks = true;
    dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
    try std.testing.expectEqual(@as(usize, 1), fixture.queue_calls);
    try std.testing.expectEqual(@as(usize, 0), fixture.task_count);
    try std.testing.expect(internal.load_waiting_on_delay);
    try std.testing.expect(!internal.ready_for_post_load_tasks);
}

test "unavailable continuation allocation or event loop has no inline fallback" {
    for (0..2) |kind| {
        var fixture: Fixture = .{};
        try fixture.init();
        defer fixture.deinit();
        const internal = dom.document_internals.getInternal(fixture.document).?;
        internal.load_waiting_on_delay = true;
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        const original_allocator = fixture.ctx.allocator;
        if (kind == 0) fixture.ctx.allocator = failing.allocator() else fixture.ctx.event_loop = null;
        dom.document_lifecycle.scriptDeliveryDiscarded(fixture.document, false);
        fixture.ctx.allocator = original_allocator;
        try std.testing.expectEqual(@as(usize, 0), fixture.task_count);
        try std.testing.expect(internal.load_waiting_on_delay);
        try std.testing.expect(!internal.ready_for_post_load_tasks);
    }
}

test "load undelay defers ready deferred-script work and has no inline fallback" {
    for (0..3) |kind| {
        var fixture: Fixture = .{};
        try fixture.init();
        defer fixture.deinit();
        const internal = dom.document_internals.getInternal(fixture.document).?;
        const script = try interfaces.HTMLScriptElement.init(std.testing.allocator, &fixture.ctx);
        defer {
            internal.script_delivery_continuation_suppressed = true;
            html.script_execution.discardParserScripts(fixture.document);
            interfaces.HTMLScriptElement.deinit(script);
        }
        try dom.node_document.set(script, fixture.document);
        const state = html.script_element.of(script).?;
        state.preparation_time_document = fixture.document;
        state.preparation_time_document_generation = runtime.SlabAllocator.generationOf(fixture.document);
        state.ready_to_be_parser_executed = true;
        state.result = .null;
        const lists = dom.document_scripts.of(fixture.document).?;
        try lists.scripts_to_execute_when_parsing_finished.append(std.testing.allocator, script);
        internal.parsing_end_waiting_on_scripts = true;
        dom.document_lifecycle.delayLoadEvent(fixture.document);
        if (kind == 1) fixture.drop_tasks = true;
        if (kind == 2) fixture.ctx.event_loop = null;
        dom.document_lifecycle.undelayLoadEvent(fixture.document);
        try std.testing.expectEqual(@as(usize, 1), lists.scripts_to_execute_when_parsing_finished.items.len);
        try std.testing.expect(internal.parsing_end_waiting_on_scripts);
        try std.testing.expect(!internal.ready_for_post_load_tasks);
        if (kind == 0) {
            try std.testing.expectEqual(@as(usize, 1), fixture.task_count);
            fixture.runFirst();
            try std.testing.expectEqual(@as(usize, 0), lists.scripts_to_execute_when_parsing_finished.items.len);
            try std.testing.expect(!internal.parsing_end_waiting_on_scripts);
            try std.testing.expect(internal.ready_for_post_load_tasks);
        } else try std.testing.expectEqual(@as(usize, 0), fixture.task_count);
    }
}
