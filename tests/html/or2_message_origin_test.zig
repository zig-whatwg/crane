//! Window posts hold the sender's origin through delivery or task disposal.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const h = @import("refcount_holders_helpers.zig");
const OriginRecord = dom.origin_record.OriginRecord;

fn object(page: h.Page, source: []const u8) !*runtime.Instance {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    return engine.convertToPlatformObject(page.browser.getRealm().?, held.borrow()) orelse error.NotAnObject;
}

fn origin(window: *runtime.Instance) !*OriginRecord {
    return (try dom.document_origin.shareable(try interfaces.Window.get_document(window))) orelse error.NoOrigin;
}

fn expectScript(page: h.Page, source: []const u8) !void {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    try std.testing.expect(engine.toBoolean(page.browser.getRealm().?, held.borrow()));
}

fn awaitScript(page: h.Page, source: []const u8) !void {
    for (0..100) |_| {
        const held = try page.browser.evaluateScript(source);
        defer held.release();
        if (engine.toBoolean(page.browser.getRealm().?, held.borrow())) return;
        _ = try page.browser.runEventLoopBlocking(20);
    }
    return error.NoMessage;
}

fn delivered() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.events = [];
        \\addEventListener('message', event => events.push(event));
        \\postMessage('first', '*'); postMessage('second', '*');
    );
    try awaitScript(page, "events.length === 2");
    try expectScript(page,
        \\Origin.from(events[0]).opaque &&
        \\Origin.from(events[0]).isSameOrigin(Origin.from(events[1])) &&
        \\Origin.from(events[0]).isSameOrigin(Origin.from(window)) &&
        \\events[0].origin === 'null' && events[0].data === 'first'
    );
    try page.run("globalThis.keptOrigin = Origin.from(events[0]); events = []; TestUtils.gc(); TestUtils.gc();");
    try expectScript(page, "keptOrigin.isSameOrigin(Origin.from(window))");
}

test "two delivered messages preserve one opaque origin after their events are collected" {
    try h.onFreshThread(delivered);
}

fn undefinedPayload() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.events = [];
        \\addEventListener('message', event => events.push(event));
        \\postMessage(undefined, '*'); postMessage(null, '*');
    );
    try awaitScript(page, "events.length === 2");
    try expectScript(page,
        \\events[0].data === undefined && events[1].data === null &&
        \\new MessageEvent('message', {data: undefined}).data === null &&
        \\new MessageEvent('message').data === null
    );
}

test "posted undefined survives while script constructor dictionary defaults stay null" {
    try h.onFreshThread(undefinedPayload);
}

fn reloaded() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.events = [];
        \\addEventListener('message', event => events.push(event));
        \\globalThis.frame = document.createElement('iframe');
        \\frame.sandbox = 'allow-scripts';
        \\frame.srcdoc = '<script>parent.postMessage(1, "*")<\/script>';
        \\document.body.append(frame);
    );
    try awaitScript(page, "events.length === 1");
    try page.run(
        \\globalThis.first = Origin.from(events[0]);
        \\frame.srcdoc = '<script>parent.postMessage(2, "*")<\/script>';
    );
    try awaitScript(page, "events.length === 2");
    try page.run("globalThis.second = Origin.from(events[1]); frame.remove(); frame = null; TestUtils.gc();");
    try expectScript(page, "first.opaque && second.opaque && !first.isSameOrigin(second) && first.isSameOrigin(Origin.from(events[0]))");
}

test "reloading an opaque sender creates a distinct origin while old events keep the old one" {
    try h.onFreshThread(reloaded);
}

fn taskEnd(comptime remove_target: bool) !void {
    const page = try h.Page.open();
    var closed = false;
    defer if (!closed) page.close();
    const source = try object(page, "window");
    const record = (try origin(source)).retain();
    defer record.release();
    if (remove_target) {
        try page.run("globalThis.frame = document.body.appendChild(document.createElement('iframe'));");
    }
    const before = record.refs;
    try page.run(if (remove_target) "frame.contentWindow.postMessage('drop', '*');" else "postMessage('queued at teardown', '*');");
    const queued = record.refs;
    if (remove_target) {
        try page.run("frame.remove(); frame = null;");
        _ = try page.browser.runEventLoopBlocking(40);
    }
    page.close();
    closed = true;
    // After the Browser ends, only this test's reference is left. The
    // allocator also catches the queue record and payload if either leaked.
    try std.testing.expectEqual(@as(u32, 1), record.refs);
    try std.testing.expectEqual(before + 1, queued);
}

test "a task dropped for a removed target releases the sender origin" {
    try h.onFreshThread(struct {
        fn run() !void {
            try taskEnd(true);
        }
    }.run);
}

test "realm teardown releases an origin held by a still queued message" {
    try h.onFreshThread(struct {
        fn run() !void {
            try taskEnd(false);
        }
    }.run);
}

const NativePost = struct {
    target: *runtime.Instance,
    failure: ?anyerror = null,

    fn run(data: ?*anyopaque) void {
        const self: *NativePost = @ptrCast(@alignCast(data.?));
        interfaces.Window.call_postMessage(self.target, runtime.JSValue.fromStringRef("owned payload"), "*", .notPassed()) catch |err| {
            self.failure = err;
        };
    }
};

fn postTrial(allocator: std.mem.Allocator, page: h.Page, target: *runtime.Instance, record: *OriginRecord) !void {
    const before = record.refs;
    const original = target.ctx.allocator;
    target.ctx.allocator = allocator;
    defer target.ctx.allocator = original;
    var attempt: NativePost = .{ .target = target };
    try engine.runInRealm(page.browser.getRealm().?, NativePost.run, &attempt);
    // The removed target is not fully active: the loop drops the task, so
    // this trial isolates post-time allocations from event construction.
    target.ctx.allocator = original;
    _ = try page.browser.runEventLoopBlocking(20);
    try std.testing.expectEqual(before, record.refs);
    if (attempt.failure) |err| return err;
}

fn postAllocationFailures() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\let frame = document.body.appendChild(document.createElement('iframe'));
        \\globalThis.closedTarget = frame.contentWindow;
        \\frame.remove(); frame = null;
    );
    const target = try object(page, "closedTarget");
    const record = try origin(try object(page, "window"));
    try std.testing.checkAllAllocationFailures(std.testing.allocator, postTrial, .{ page, target, record });
}

test "every failed post allocation releases its payload and origin hold" {
    try h.onFreshThread(postAllocationFailures);
}
