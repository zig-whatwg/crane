//! Two Browsers on two threads, each dispatching composed events through
//! nested shadow trees at once (lane events1).
//!
//! Dispatch across shadow roots retargets item by item and sets each Window's
//! current event (window.event) around its listeners. That current event was
//! one process-wide list every thread's dispatch appended to and removed from
//! without a lock (EventTarget.zig's `current_events`), so two Browsers'
//! listeners on two threads raced on it. It is now the Window's own state.
//!
//! Each side builds ten nested shadow roots, open and closed alternately, and
//! dispatches 4,000 composed events at the innermost node: a listener in the
//! light tree must see the event retargeted to the outermost host and
//! window.event set to it, and a listener inside a shadow tree must see
//! window.event undefined (DOM inner invoke step 2.10.2). Each Browser has an
//! allocator of its own (AGENTS.md: a shared test allocator makes two
//! Browsers take turns).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const dispatches = 4000;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        const side: *Side = @ptrCast(@alignCast(host.?));
        return interfaces.Window.init(side.gpa.allocator(), r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

const no_hooks: protocol.HostHooks = .{};

const script =
    \\const doc = new Document().implementation.createHTMLDocument('');
    \\const root = doc.body.appendChild(doc.createElement('div'));
    \\let parent = root;
    \\let outermost = null;
    \\for (let depth = 0; depth < 10; ++depth) {
    \\  const host = parent.appendChild(doc.createElement('div'));
    \\  if (!outermost) outermost = host;
    \\  const shadow = host.attachShadow({ mode: depth % 2 ? 'closed' : 'open' });
    \\  parent = shadow.appendChild(doc.createElement('div'));
    \\}
    \\const leaf = parent.appendChild(doc.createElement('span'));
    \\let light = 0, inside = 0, wrong = 0;
    \\root.addEventListener('ev1', e => {
    \\  ++light;
    \\  if (e.target !== outermost || window.event !== e) ++wrong;
    \\});
    \\parent.addEventListener('ev1', e => {
    \\  ++inside;
    \\  if (e.target !== leaf || window.event !== undefined) ++wrong;
    \\});
    \\for (let i = 0; i < N; ++i) leaf.dispatchEvent(new Event('ev1', { bubbles: true, composed: true }));
    \\`${light}|${inside}|${wrong}|${String(window.event)}`
;

const Side = struct {
    gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,
    failure: ?anyerror = null,
    answer: [64]u8 = undefined,
    answer_len: usize = 0,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(self: *Side) !void {
        const allocator = self.gpa.allocator();
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://events.test",
            .browser_scope = &scope,
            .create_global_object = WindowHost.createGlobalObject,
            .host = self,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);

        var source_buf: [script.len + 64]u8 = undefined;
        const source = try std.fmt.bufPrint(&source_buf, "const N = {d};\n{s}", .{ dispatches, script });
        var reports: Reports = .{};
        const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, allocator, reports.reporter());
        defer allocator.free(answer);
        if (reports.count != 0) return error.ScriptThrew;
        if (answer.len > self.answer.len) return error.AnswerTooLong;
        @memcpy(self.answer[0..answer.len], answer);
        self.answer_len = answer.len;
    }
};

test "two Browsers on two threads dispatch composed events through nested shadow trees at once" {
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();

    var sides: [2]Side = .{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&sides, &threads) |*side, *thread| {
        thread.* = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{side});
    }
    for (threads) |thread| thread.join();
    var expected_buf: [64]u8 = undefined;
    const expected = try std.fmt.bufPrint(&expected_buf, "{d}|{d}|0|undefined", .{ dispatches, dispatches });
    for (&sides) |*side| {
        if (side.failure) |err| return err;
        try testing.expectEqualStrings(expected, side.answer[0..side.answer_len]);
        try testing.expect(side.gpa.deinit() == .ok);
    }
}
