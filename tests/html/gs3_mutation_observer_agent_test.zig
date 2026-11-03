//! DOM 4.3: the mutation observer microtask queued flag, the pending mutation
//! observers and the signal slots are the similar-origin window agent's - each
//! agent's host keeps them (html AgentHost.mutation_observers, found from a
//! realm with dom.mutation_observer_algorithms.agentOf; lane gstate3). They
//! were one per thread.
//!
//! The two cases that ran on a bare tests/v8 agent (no host, so no mutation
//! observer state now) moved here, where every agent has its host: a
//! MutationObserver's callback kept across a collection (from
//! tests/v8/callback_argument_borrowed_test.zig) and a notify microtask an
//! aborted checkpoint discards (from tests/v8/microtask_dropped_end_test.zig).
//!
//! Each test runs on a thread of its own.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
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

fn openBrowser(url: []const u8, markup: []const u8) !*Browser {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = url });
    return browser;
}

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn answer(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport });
}

fn expectAnswer(realm: runtime.Context, source: []const u8, want: []const u8) !void {
    const got = try answer(realm, source);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
    try testing.expectEqualStrings(want, got);
}

fn statePerAgent() !void {
    const a = try openBrowser("http://gs3-mo-a.test/", "<!doctype html><body>");
    // A frame made by script: its realm exists once it is connected.
    const made = try a.evaluateScript("document.body.appendChild(document.createElement('iframe')); true");
    made.release();
    defer a.deinit();
    const b = try openBrowser("http://gs3-mo-b.test/", "<!doctype html><body>");
    defer b.deinit();
    const realm_a = a.getRealm().?;
    const realm_b = b.getRealm().?;

    const state_a = dom.mutation_observer_algorithms.agentOf(realm_a) orelse return error.NoState;
    const state_b = dom.mutation_observer_algorithms.agentOf(realm_b) orelse return error.NoState;
    // Each agent its own.
    try testing.expect(state_a != state_b);

    // A frame's realm is of its page's agent: the same state.
    const frame_document = try a.evaluateScript("document.querySelector('iframe').contentDocument");
    defer frame_document.release();
    const frame_realm = (engine.convertToPlatformObject(realm_a, frame_document.borrow()) orelse return error.NoFrameDocument).ctx;
    try testing.expect(frame_realm != realm_a);
    try testing.expectEqual(state_a, dom.mutation_observer_algorithms.agentOf(frame_realm).?);
}

test "the mutation observer state is each agent's: one per Browser, shared by a page and its frames" {
    try onThread(statePerAgent);
}

fn keptAfterCollection() !void {
    const browser = try openBrowser("http://gs3-mo.test/", "<!doctype html><body>");
    defer browser.deinit();
    const realm = browser.getRealm().?;
    const agent = browser.getAgent().?;
    try expectAnswer(realm,
        \\globalThis.probeDocument = new Document().implementation.createHTMLDocument("");
        \\globalThis.probeRoot = probeDocument.createElement("div");
        \\globalThis.seen = 0;
        \\globalThis.mo = new MutationObserver(() => { seen++; });
        \\mo.observe(probeRoot, { childList: true });
        \\probeRoot.appendChild(probeDocument.createElement('b'));
        \\"ok"
    , "ok");
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.performMicrotaskCheckpoint(agent);
    try expectAnswer(realm, "seen === 1 ? 'ok' : 'seen ' + seen", "ok");
}

test "take site: new MutationObserver(f) notifies f after a collection" {
    try onThread(keptAfterCollection);
}

/// `abortAgent()`: engine.abortRunningScript on the agent, as a worker's
/// termination and a script deadline do.
fn abortSteps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
    engine.abortRunningScript(@ptrCast(@alignCast(data.?)));
    return .undefined;
}

fn discardedNotifyLeavesNothing() !void {
    const browser = try openBrowser("http://gs3-mo.test/", "<!doctype html><body>");
    defer browser.deinit();
    const realm = browser.getRealm().?;
    const agent = browser.getAgent().?;
    try expectAnswer(realm,
        \\globalThis.d = new Document();
        \\globalThis.n = d.createTextNode('a');
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(n, { characterData: true });
        \\"ok"
    , "ok");
    // A microtask that aborts the agent's script runs first; the notify
    // microtask the mutation queues waits behind it, and the aborted
    // checkpoint discards it. Then the agent runs script again.
    var abort_function: runtime.BuiltinFunction = .{ .steps = abortSteps, .data = agent };
    try engine.defineBuiltinFunction(realm, "abortAgent", 0, &abort_function);
    if (answer(realm, "queueMicrotask(() => { abortAgent(); for (;;) {} });\nn.data = 'b';")) |got| testing.allocator.free(got) else |_| {}
    engine.resumeScripts(agent);
    // The agent runs script again; what the discarded microtask would have
    // notified is still the observer's, and the Browser's end frees it
    // (std.testing.allocator reports what is left).
    try expectAnswer(realm, "String(mo.takeRecords().length)", "1");
}

test "a mutation observer microtask discarded with an aborted checkpoint leaves nothing behind" {
    try onThread(discardedNotifyLeavesNothing);
}
