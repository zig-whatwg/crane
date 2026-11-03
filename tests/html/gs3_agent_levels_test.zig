//! An agent's event loop levels are the agent's own (lane gstate3): the timer
//! nesting level (HTML timer initialization steps, step 3 - the running
//! task's, set while a timer's callback runs) and the termination nesting
//! level (HTML "unload" steps 7 and 14 - raised while unload handlers run, and
//! read by window.open). Both are on the agent's host
//! (html AgentHost.timer_nesting_level / termination_nesting_level); they were
//! threadlocals, which two agents on one thread shared.
//!
//! A pin: no web content can run in two agents at once, so the old per-thread
//! levels showed wrong only when one agent's level was read while another's
//! task ran. The probe reads both Browsers' levels from inside the first
//! one's timer callback and unload handler.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const html = @import("html");
const Browser = @import("browser").Browser;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}

fn openBrowser(url: []const u8) !*Browser {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = url });
    return browser;
}

fn hostOf(browser: *Browser) *html.agent_host.AgentHost {
    return dom.agent_hosts.of(browser.getRealm().?).?;
}

/// What `probe()` saw: both Browsers' levels, read while the first one's
/// script ran.
const Probe = struct {
    first: *html.agent_host.AgentHost,
    second: *html.agent_host.AgentHost,
    calls: usize = 0,
    first_timer: u32 = 0,
    second_timer: u32 = 0,
    first_termination: u32 = 0,
    second_termination: u32 = 0,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Probe = @ptrCast(@alignCast(data.?));
        self.calls += 1;
        self.first_timer = self.first.timer_nesting_level;
        self.second_timer = self.second.timer_nesting_level;
        self.first_termination = self.first.termination_nesting_level;
        self.second_termination = self.second.termination_nesting_level;
        return .undefined;
    }
};

fn truthy(browser: *Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    return engine.toBoolean(browser.getRealm().?, held.borrow());
}

fn timerLevelIsTheAgents() !void {
    const a = try openBrowser("http://gs3-levels-a.test/");
    defer a.deinit();
    const b = try openBrowser("http://gs3-levels-b.test/");
    defer b.deinit();
    var probe: Probe = .{ .first = hostOf(a), .second = hostOf(b) };
    var function: runtime.BuiltinFunction = .{ .steps = Probe.steps, .data = &probe };
    try engine.defineBuiltinFunction(a.getRealm().?, "probe", 0, &function);

    // A timer set from a task that is not a timer's: its nesting level is 1,
    // and while its callback runs that is its agent's level - only its.
    try testing.expect(try truthy(a, "setTimeout(() => { probe(); }, 0) > 0"));
    var turns: usize = 0;
    while (probe.calls == 0 and turns < 200) : (turns += 1) _ = try a.runEventLoopBlocking(10);
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expectEqual(@as(u32, 1), probe.first_timer);
    try testing.expectEqual(@as(u32, 0), probe.second_timer);
    // Back to 0 once the task is over.
    try testing.expectEqual(@as(u32, 0), probe.first.timer_nesting_level);
}

test "the timer nesting level is the agent's: set for its own timer's callback, never another agent's" {
    try onThread(timerLevelIsTheAgents);
}

fn terminationLevelIsTheAgents() !void {
    const a = try openBrowser("http://gs3-levels-a.test/");
    defer a.deinit();
    const b = try openBrowser("http://gs3-levels-b.test/");
    defer b.deinit();
    var probe: Probe = .{ .first = hostOf(a), .second = hostOf(b) };
    var function: runtime.BuiltinFunction = .{ .steps = Probe.steps, .data = &probe };
    try engine.defineBuiltinFunction(a.getRealm().?, "probe", 0, &function);
    try testing.expect(try truthy(a, "addEventListener('unload', () => { globalThis.opened = window.open('about:blank'); probe(); }); true"));

    // The first Browser's document unloads: its unload handler runs at its
    // agent's raised termination nesting level - where window.open opens
    // nothing - and the other Browser's level is untouched.
    dom.document_lifecycle.unload(a.current_context.?.document_instance.?);
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expectEqual(@as(u32, 1), probe.first_termination);
    try testing.expectEqual(@as(u32, 0), probe.second_termination);
    try testing.expect(try truthy(a, "globalThis.opened === null"));
    try testing.expectEqual(@as(u32, 0), probe.first.termination_nesting_level);
}

test "the termination nesting level is the agent's: raised around its own unload handlers, never another agent's" {
    try onThread(terminationLevelIsTheAgents);
}
