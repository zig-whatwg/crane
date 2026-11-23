//! The collection after a main frame's navigation (navigation_collection.zig)
//! counts the DOM memory the agent reports (engine.AgentOptions.
//! external_memory) in "the page being left used much memory" - beside V8's
//! heap and its ArrayBuffer backing stores (v8::HeapStatistics
//! used_heap_size + external_memory), which do not show it. Blink's
//! threshold is the renderer's whole footprint (OomInterventionImpl::Check
//! reads the process's private footprint, Chromium 157.0.8103.50
//! third_party/blink/renderer/controller/oom_intervention_impl.cc) - its DOM
//! is on V8's C++ heap. Without the DOM, a page heavy in DOM and light in
//! script could be left uncollected while the same page with a bigger heap
//! was collected: lane tmpl1's realms hold less heap, and four chain figures
//! of the cost window of 2026-11-20 read 10 to 32% higher at the chain's end
//! (load.docs, load.app, memory.page-growth).
//!
//! Each test makes its own agent and its own figure, moved by hand: what the
//! adapter reads is the figure, whoever moves it (dom.instance_bridge does,
//! in a Browser).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;
const megabyte: usize = 1024 * 1024;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
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

/// A tab: an agent that reports `memory`, and its top-level realm, which
/// `navigate` replaces as a navigation's commit does.
const Tab = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(queue: *DeferredTeardown, memory: *ExternalMemory) !Tab {
        test_process.start();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .deferred_teardown = queue,
            .external_memory = memory,
        });
        errdefer protocol.destroyAgent(agent);
        return .{ .agent = agent, .realm = try windowRealm(agent, .new_window_proxy) };
    }

    fn close(self: *Tab) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn windowRealm(agent: *protocol.Agent, global_this: protocol.GlobalThis) !runtime.Context {
        return protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://tmpl1.test",
            .global_this = global_this,
            .create_global_object = WindowHost.createGlobalObject,
        });
    }

    fn isolate(self: Tab) *v8.ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    /// A new Window behind the realm's WindowProxy, and the old document's
    /// realm goes: what a navigation's commit does.
    fn navigate(self: *Tab) !void {
        const next = try windowRealm(self.agent, .{ .window_proxy_of = self.realm });
        protocol.destroyWindowRealm(self.realm, .global_detached);
        self.realm = next;
    }

    /// A script that calls a binding and returns into script: the outermost
    /// binding exit, where the agent reports its figure.
    fn callBinding(self: Tab) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = "void (globalThis.doc ??= new Document()).nodeType;" }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    /// V8's heap as HeapStatistics shows it: its objects plus its
    /// ArrayBuffer backing stores - not the DOM the agent reports.
    fn heapHeld(self: Tab) usize {
        var used: usize = 0;
        var external: usize = 0;
        v8.ffi.v8_Isolate_GetHeapUsage(self.isolate(), &used, null, &external);
        return used + external;
    }

    fn collectionsSent(self: Tab) u64 {
        return v8.protocol_agents.navigationCollectionsOf(self.isolate());
    }
};

test "a navigation that leaves much DOM behind and little heap is collected: the measure counts the DOM the agent reports" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    var tab = try Tab.open(&queue, &memory);
    defer tab.close();

    // A page heavy in DOM: 32 MB of it, reported at the next binding exit.
    memory.add(32 * megabyte);
    defer memory.sub(32 * megabyte);
    try tab.callBinding();
    try testing.expectEqual(memory.live, v8.external_memory.reportedOn(tab.isolate()));
    // A threshold the heap alone does not reach, and the heap with the DOM
    // does.
    const threshold = tab.heapHeld() + 8 * megabyte;
    v8.protocol_agents.setNavigationCollectionThreshold(tab.isolate(), threshold);
    const sent_before = tab.collectionsSent();

    try tab.navigate();
    try testing.expect(tab.heapHeld() < threshold);
    _ = protocol.runEngineTasks(tab.agent);
    try testing.expectEqual(sent_before + 1, tab.collectionsSent());
}

test "a navigation that leaves little DOM and little heap behind is not collected" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    var tab = try Tab.open(&queue, &memory);
    defer tab.close();

    // 1 MB of DOM, reported: the heap and it stay under the threshold.
    memory.add(1 * megabyte);
    defer memory.sub(1 * megabyte);
    try tab.callBinding();
    try testing.expectEqual(memory.live, v8.external_memory.reportedOn(tab.isolate()));
    v8.protocol_agents.setNavigationCollectionThreshold(tab.isolate(), tab.heapHeld() + 8 * megabyte);
    const sent_before = tab.collectionsSent();

    try tab.navigate();
    _ = protocol.runEngineTasks(tab.agent);
    try testing.expectEqual(sent_before, tab.collectionsSent());
}
