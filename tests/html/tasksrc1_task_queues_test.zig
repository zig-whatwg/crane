//! HTML §8.1.7.2 per-source task queues (lane tasksrc1):
//! - Per-source FIFO ordering on both `browser.EventLoop` and `html.WorkerEventLoop`.
//! - Inter-source priority (Golden Rule 2: Blink/Gecko/WebKit):
//!   `user_interaction` runs ahead of normal-priority sources (`timer`,
//!   `networking`, `dom_manipulation`, `posted_message`, etc.) with bounded
//!   anti-starvation (`TaskSource.max_starvation_tasks = 5`, matching Chromium
//!   `TaskQueueSelector::kMaxStarvationTasks`), and equal-priority sources run
//!   in deterministic FIFO enqueue order (Blink `EnqueueOrder`).
//! - Cross-thread `TaskSink` propagates `TaskSource` into both loops.
//! - Document activity (`discardDocumentTasks` / bfcache suspend/resume) works
//!   across multiple task sources without leaks.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const dom = @import("dom");
const browser_mod = @import("browser");
const html = @import("html");

const Task = runtime.EventLoopTask;
const TaskSource = runtime.EventLoopTask.Source;
const WorkerLink = html.WorkerLink;
const WorkerEventLoop = html.WorkerEventLoop;

const Trace = struct {
    allocator: std.mem.Allocator,
    order: std.ArrayListUnmanaged(u8) = .empty,
    dropped: std.ArrayListUnmanaged(u8) = .empty,

    fn deinit(self: *Trace) void {
        self.order.deinit(self.allocator);
        self.dropped.deinit(self.allocator);
    }
};

const Entry = struct {
    trace: *Trace,
    tag: u8,

    fn run(ctx: ?*anyopaque) void {
        const self: *Entry = @ptrCast(@alignCast(ctx.?));
        self.trace.order.append(self.trace.allocator, self.tag) catch {};
    }

    fn drop(ctx: ?*anyopaque) void {
        const self: *Entry = @ptrCast(@alignCast(ctx.?));
        self.trace.dropped.append(self.trace.allocator, self.tag) catch {};
    }

    fn task(self: *Entry, source: TaskSource) Task {
        return .{
            .callback = &run,
            .context = self,
            .drop = &drop,
            .source = source,
        };
    }
};

test "window event loop: user_interaction preempts timer, networking, and dom_manipulation while preserving per-source FIFO and equal-priority enqueue order" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;
    const queue = loop.eventLoop();

    var trace: Trace = .{ .allocator = testing.allocator };
    defer trace.deinit();

    var t1: Entry = .{ .trace = &trace, .tag = 'T' };
    var t2: Entry = .{ .trace = &trace, .tag = 't' };
    var n1: Entry = .{ .trace = &trace, .tag = 'N' };
    var d1: Entry = .{ .trace = &trace, .tag = 'D' };
    var p1: Entry = .{ .trace = &trace, .tag = 'P' };
    var ui1: Entry = .{ .trace = &trace, .tag = 'U' };
    var ui2: Entry = .{ .trace = &trace, .tag = 'u' };

    // Enqueue normal-priority tasks first, then two user_interaction tasks.
    queue.queueTask(t1.task(.timer));
    queue.queueTask(n1.task(.networking));
    queue.queueTask(t2.task(.timer));
    queue.queueTask(d1.task(.dom_manipulation));
    queue.queueTask(p1.task(.posted_message));
    queue.queueTask(ui1.task(.user_interaction));
    queue.queueTask(ui2.task(.user_interaction));

    _ = loop.runOnceBlocking(0);

    // High-priority user_interaction tasks run first in FIFO order ('U', 'u'),
    // followed by normal-priority sources in deterministic FIFO enqueue order
    // ('T', 'N', 't', 'D', 'P') preserving timer FIFO ('T' before 't').
    try testing.expectEqualStrings("UuTNtDP", trace.order.items);
    try testing.expectEqualStrings("", trace.dropped.items);
}

test "window event loop: anti-starvation services a ready normal-priority task after max_starvation_tasks consecutive user_interaction tasks" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;
    const queue = loop.eventLoop();

    var trace: Trace = .{ .allocator = testing.allocator };
    defer trace.deinit();

    // Enqueue 2 timers, then 8 user_interaction tasks.
    var t1: Entry = .{ .trace = &trace, .tag = 'A' };
    var t2: Entry = .{ .trace = &trace, .tag = 'B' };
    var ui: [8]Entry = undefined;
    for (&ui, 0..) |*e, i| e.* = .{ .trace = &trace, .tag = @intCast('1' + i) };

    queue.queueTask(t1.task(.timer));
    queue.queueTask(t2.task(.timer));
    for (&ui) |*e| queue.queueTask(e.task(.user_interaction));

    _ = loop.runOnceBlocking(0);

    // After 5 consecutive user_interaction tasks ('1'..'5'), anti-starvation
    // runs one ready timer ('A'), then remaining user_interaction ('6'..'8'),
    // then the second timer ('B').
    try testing.expectEqual(@as(u8, 5), TaskSource.max_starvation_tasks);
    try testing.expectEqualStrings("12345A678B", trace.order.items);
}

test "window event loop: cross-thread TaskSink propagates TaskSource priority" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;
    const sink = loop.taskSink();

    var trace: Trace = .{ .allocator = testing.allocator };
    defer trace.deinit();

    var m1: Entry = .{ .trace = &trace, .tag = 'M' };
    var b1: Entry = .{ .trace = &trace, .tag = 'B' };
    var ui1: Entry = .{ .trace = &trace, .tag = 'U' };

    try testing.expect(sink.post(.{ .run = &Entry.run, .drop = &Entry.drop, .data = &m1, .source = .port_message }));
    try testing.expect(sink.post(.{ .run = &Entry.run, .drop = &Entry.drop, .data = &b1, .source = .broadcast_channel }));
    try testing.expect(sink.post(.{ .run = &Entry.run, .drop = &Entry.drop, .data = &ui1, .source = .user_interaction }));

    _ = loop.runOnceBlocking(0);

    // user_interaction posted after port_message & broadcast_channel still runs first.
    try testing.expectEqualStrings("UMB", trace.order.items);
}

test "window event loop: discardDocumentTasks drops matching document tasks across all task sources" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;
    const queue = loop.eventLoop();

    var trace: Trace = .{ .allocator = testing.allocator };
    defer trace.deinit();

    var fake_doc: u8 = 0;
    const doc_ptr: *anyopaque = @ptrCast(&fake_doc);
    const doc_gen: u64 = 42;

    var u_doc: Entry = .{ .trace = &trace, .tag = 'U' };
    var t_doc: Entry = .{ .trace = &trace, .tag = 'T' };
    var n_doc: Entry = .{ .trace = &trace, .tag = 'N' };
    var keep_t: Entry = .{ .trace = &trace, .tag = 'k' };

    queue.queueTask(.{ .callback = &Entry.run, .context = &u_doc, .drop = &Entry.drop, .document = doc_ptr, .document_generation = doc_gen, .source = .user_interaction });
    queue.queueTask(.{ .callback = &Entry.run, .context = &t_doc, .drop = &Entry.drop, .document = doc_ptr, .document_generation = doc_gen, .source = .timer });
    queue.queueTask(.{ .callback = &Entry.run, .context = &n_doc, .drop = &Entry.drop, .document = doc_ptr, .document_generation = doc_gen, .source = .networking });
    queue.queueTask(keep_t.task(.dom_manipulation));

    loop.discardDocumentTasks(doc_ptr, doc_gen);
    // All three document tasks across distinct sources were dropped immediately.
    try testing.expectEqual(@as(usize, 3), trace.dropped.items.len);

    _ = loop.runOnceBlocking(0);
    // Only the non-document task ran.
    try testing.expectEqualStrings("k", trace.order.items);
}

test "worker event loop: per-source FIFO, user_interaction priority, anti-starvation, and drop on close" {
    const owner_sink = try runtime.TaskSink.create(testing.allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(testing.allocator, owner_sink);
    defer link.release();
    var loop = try WorkerEventLoop.init(testing.allocator, link);
    defer loop.deinit();
    const queue = loop.eventLoop();

    var trace: Trace = .{ .allocator = testing.allocator };
    defer trace.deinit();

    // 1. Priority + anti-starvation + FIFO within each source.
    var n1: Entry = .{ .trace = &trace, .tag = 'N' };
    var p1: Entry = .{ .trace = &trace, .tag = 'P' };
    var n2: Entry = .{ .trace = &trace, .tag = 'n' };
    var ui: [6]Entry = undefined;
    for (&ui, 0..) |*e, i| e.* = .{ .trace = &trace, .tag = @intCast('1' + i) };

    queue.queueTask(n1.task(.networking));
    try testing.expect(link.worker_sink.post(.{ .run = &Entry.run, .drop = &Entry.drop, .data = &p1, .source = .port_message }));
    queue.queueTask(n2.task(.networking));
    for (&ui) |*e| queue.queueTask(e.task(.user_interaction));

    // Arm a 0ms timer so step 5 of `turn()` does not block waiting on `sink.waitForWork(null)`.
    _ = loop.timers.setTimeout(0, &struct {
        fn noop(_: ?*anyopaque) void {}
    }.noop, null);

    // One turn drains snapshot: 5 user_interaction ('1'..'5'), then anti-starvation
    // runs oldest normal task ('N'), then 6th user_interaction ('6'), then 'n'
    // (queued before takePosted's 'P'), then 'P'.
    try testing.expect(loop.turn());
    try testing.expectEqualStrings("12345N6nP", trace.order.items);
    try testing.expectEqualStrings("", trace.dropped.items);

    // 2. Remaining tasks across multiple sources are dropped cleanly on dropTasks().
    var d_ui: Entry = .{ .trace = &trace, .tag = 'x' };
    var d_ws: Entry = .{ .trace = &trace, .tag = 'y' };
    var d_db: Entry = .{ .trace = &trace, .tag = 'z' };
    queue.queueTask(d_ui.task(.user_interaction));
    queue.queueTask(d_ws.task(.websocket));
    queue.queueTask(d_db.task(.database_access));
    loop.dropTasks();
    try testing.expectEqual(@as(usize, 3), trace.dropped.items.len);
}
