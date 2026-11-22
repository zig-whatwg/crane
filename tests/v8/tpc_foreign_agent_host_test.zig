//! An agent made with a host of another type is never read as html's
//! AgentHost (lesson architecture-a-host-pointer-an-agent-was-given-is-only-
//! its-creators-type.md). `AgentOptions.host` is `?*anyopaque` on purpose -
//! it is what every hook is passed, and a test's agent passes a struct of its
//! own - so the html and dom code that needs the agent's state (custom
//! element reactions, mutation observers, form past names, media elements,
//! the agent's fetches) finds it through the type the engine protocol names
//! for it (`engine.hostStateOf`), never by casting `engine.agentHost`.
//!
//! Before (lane tpc, 2026-11-22): a page whose agent had a test struct as its
//! host panicked in `document.createElement` under -Dsanitize-thread
//! (custom_elements/driver.zig read the struct as reaction queues: index out
//! of bounds in reactions.zig hasCurrentQueue) and crashed on macOS; on
//! Linux the plain build read and wrote the garbage silently.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const test_process = @import("test_process.zig");

const Host = struct {
    fn window(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, r) catch null;
    }
};

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
    const reporter: engine.Reporter = .{ .report = report, .host = null };
};

fn eval(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, Ignored.reporter);
}

/// A test's own host: 1 MiB, far past html's AgentHost (a few KiB of
/// registries and lists), every byte a pattern, so any read of it as an
/// AgentHost reads nonsense and any write into it shows.
const Foreign = struct {
    const words = (1 << 20) / 8;
    const pattern: u64 = 0x5a5a_5a5a_5a5a_5a5a;
    bytes: [words]u64 = @splat(pattern),

    fn untouched(self: *const Foreign) bool {
        for (self.bytes) |word| if (word != pattern) return false;
        return true;
    }
};

fn foreignHostPage(foreign: *Foreign) !void {
    test_process.start();
    const own_runtime = test_process.OwnRuntime.begin(testing.allocator);
    defer own_runtime.end();
    var browser = runtime.BrowserScope.init(testing.allocator);
    defer browser.deinit();
    const hooks: *const engine.HostHooks = &.{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = hooks, .host = foreign, .allocator = testing.allocator });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = false,
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .browser_scope = &browser,
        .create_global_object = Host.window,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const record = realm.getRealm() orelse return error.NoWindow;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
    const document = try interfaces.Document.init(testing.allocator, realm);
    try dom.document_internals.setDocumentType(document, .html);
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);

    // What reaches the agent's state from script: element creation (custom
    // element reactions around every [CEReactions] call), a custom element
    // definition and construction, a mutation observer and a mutation it
    // sees, a form's named access (form past names), a media element. Each
    // step's exception is caught: an agent with no html state may refuse a
    // step, never read another type's struct.
    const result = try eval(realm,
        \\const steps = [];
        \\const step = (name, f) => { try { f(); steps.push(name); } catch (e) { steps.push(name + ':' + e.name); } };
        \\step('tree', () => { document.appendChild(document.createElement('html')); document.documentElement.appendChild(document.createElement('body')); });
        \\step('define', () => customElements.define('x-foreign', class extends HTMLElement {}));
        \\step('construct', () => document.body.appendChild(document.createElement('x-foreign')));
        \\step('observe', () => { new MutationObserver(() => {}).observe(document.body, { childList: true }); document.body.appendChild(document.createElement('div')); });
        \\step('form', () => { const f = document.createElement('form'); const i = document.createElement('input'); i.name = 'n'; f.appendChild(i); document.body.appendChild(f); void f.n; });
        \\step('media', () => document.body.appendChild(document.createElement('audio')));
        \\'done ' + steps.join(' ')
    );
    defer testing.allocator.free(result);
    try testing.expect(std.mem.startsWith(u8, result, "done "));
    // Nothing of html's wrote into the test's host.
    try testing.expect(foreign.untouched());
}

test "an agent whose host is a test's own struct runs script that reaches html's agent state, and its host is never read or written as an AgentHost" {
    const foreign = try testing.allocator.create(Foreign);
    defer testing.allocator.destroy(foreign);
    foreign.* = .{};
    try foreignHostPage(foreign);
}
