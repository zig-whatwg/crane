//! The engine's inspector protocol on V8 (engine_protocol.zig section 4.2b
//! [inspector_protocol]; src/runtime/engines/v8/protocol_inspector.zig;
//! tmp/plans/cdp-part1-design.md 3.4): CDP's JavaScript domains through V8's
//! own inspector, one per agent, shared with the console's REPL.
//!
//! Each test drives a session as a CDP client does - JSON in, JSON out - and
//! checks what Chrome answers for the same: contexts the host registers
//! (with auxData, and an isolated world's type and name),
//! executionContextsCleared at a group's reset, Runtime.evaluate,
//! RemoteObject wrap/unwrap round trips (DOM.describeNode/resolveNode's
//! path), Runtime.addBinding's bindingCalled, Runtime.consoleAPICalled from
//! the Console Standard's console, exceptionThrown from "report an
//! exception", runIfWaitingForDebugger reaching the host, and the console's
//! REPL still answering beside a host session.
//!
//! Written for the CDP test pass (the user's directive of 2026-11-21 5:48 PM
//! ET: implement now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const test_process = @import("test_process.zig");

const supported = engine.capabilities.inspector_protocol != .unsupported;

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

/// What a session's channel received, in order.
const Received = struct {
    messages: std.ArrayListUnmanaged([]u8) = .empty,

    fn send(host: ?*anyopaque, message: []const u8) void {
        const self: *Received = @ptrCast(@alignCast(host.?));
        const copy = testing.allocator.dupe(u8, message) catch return;
        self.messages.append(testing.allocator, copy) catch testing.allocator.free(copy);
    }

    fn channel(self: *Received) engine.InspectorChannel {
        return .{ .context = self, .send = send };
    }

    fn deinit(self: *Received) void {
        for (self.messages.items) |m| testing.allocator.free(m);
        self.messages.deinit(testing.allocator);
    }

    fn clear(self: *Received) void {
        for (self.messages.items) |m| testing.allocator.free(m);
        self.messages.clearRetainingCapacity();
    }

    /// The first message containing every one of `needles`, if any.
    fn find(self: *const Received, needles: []const []const u8) ?[]const u8 {
        outer: for (self.messages.items) |m| {
            for (needles) |needle| if (std.mem.indexOf(u8, m, needle) == null) continue :outer;
            return m;
        }
        return null;
    }

    fn expectFound(self: *const Received, needles: []const []const u8) !void {
        if (self.find(needles) == null) {
            std.debug.print("no message with all of {any}; received:\n", .{needles});
            for (self.messages.items) |m| std.debug.print("  {s}\n", .{m});
            return error.TestExpectedMessage;
        }
    }
};

/// A page whose realm has an HTML document, in an agent of the test's own.
const Page = struct {
    own_runtime: test_process.OwnRuntime,
    browser: *runtime.BrowserScope,
    agent: *engine.Agent,
    realm: runtime.Context,

    fn make() !Page {
        test_process.start();
        const own_runtime = test_process.OwnRuntime.begin(testing.allocator);
        errdefer own_runtime.end();
        const browser = try testing.allocator.create(runtime.BrowserScope);
        errdefer testing.allocator.destroy(browser);
        browser.* = runtime.BrowserScope.init(testing.allocator);
        errdefer browser.deinit();
        const hooks: *const engine.HostHooks = &.{};
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = hooks, .allocator = testing.allocator });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .browser_scope = browser,
            .create_global_object = Host.window,
        });
        const record = realm.getRealm() orelse return error.NoWindow;
        const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
        const document = try interfaces.Document.init(testing.allocator, realm);
        try dom.document_internals.setDocumentType(document, .html);
        dom.window_globals.setDocument(window, document);
        dom.document_browsing_context.setWindow(document, window);
        const made = try eval(realm, "document.appendChild(document.createElement('html')); document.documentElement.appendChild(document.createElement('body')); 'ok'");
        testing.allocator.free(made);
        return .{ .own_runtime = own_runtime, .browser = browser, .agent = agent, .realm = realm };
    }

    fn end(self: *Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        self.browser.deinit();
        testing.allocator.destroy(self.browser);
        self.own_runtime.end();
    }
};

const main_aux = "{\"isDefault\":true,\"type\":\"default\",\"frameId\":\"0123456789ABCDEF0123456789ABCDEF\"}";

fn registerMain(page: *Page) !i64 {
    return engine.inspectorContextCreated(&.{ .realm = page.realm, .group = 1, .origin = "https://example.test", .aux_data = main_aux, .is_default = true });
}

fn contextsAndEvaluate() !void {
    var page = try Page.make();
    defer page.end();
    var received: Received = .{};
    defer received.deinit();
    const session = try engine.inspectorConnect(page.agent, 1, received.channel());
    defer engine.inspectorDisconnect(session);

    const id = try registerMain(&page);
    try testing.expect(id > 0);
    try testing.expectEqual(@as(?i64, id), engine.inspectorContextId(page.realm));
    try testing.expectEqual(@as(?runtime.Context, page.realm), engine.inspectorRealmOfContextId(page.agent, id));
    // Registering again in the same group answers the same id.
    try testing.expectEqual(id, try registerMain(&page));

    // Runtime.enable replays the registered context, auxData and all.
    engine.inspectorDispatch(session, "{\"id\":1,\"method\":\"Runtime.enable\"}");
    try received.expectFound(&.{ "Runtime.executionContextCreated", "\"isDefault\":true", "\"frameId\":\"0123456789ABCDEF0123456789ABCDEF\"", "https://example.test" });
    try received.expectFound(&.{"\"id\":1"});

    // Runtime.evaluate with no contextId: the group's default context.
    engine.inspectorDispatch(session, "{\"id\":2,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":\"document.body.tagName + (1 + 2)\",\"returnByValue\":true}}");
    try received.expectFound(&.{ "\"id\":2", "\"value\":\"BODY3\"" });

    try testing.expect(engine.inspectorCanDispatch("Runtime.evaluate"));
    try testing.expect(engine.inspectorCanDispatch("HeapProfiler.collectGarbage"));
    try testing.expect(!engine.inspectorCanDispatch("Page.navigate"));

    // A group's reset clears its contexts: executionContextsCleared, and
    // the realm is no longer registered.
    received.clear();
    engine.inspectorResetGroup(page.agent, 1);
    try received.expectFound(&.{"Runtime.executionContextsCleared"});
    try testing.expectEqual(@as(?i64, null), engine.inspectorContextId(page.realm));
}

test "a host session sees the contexts it registers, evaluates in them, and a reset clears them" {
    if (supported) try contextsAndEvaluate() else return error.SkipZigTest;
}

fn wrapUnwrap() !void {
    var page = try Page.make();
    defer page.end();
    var received: Received = .{};
    defer received.deinit();
    const session = try engine.inspectorConnect(page.agent, 1, received.channel());
    defer engine.inspectorDisconnect(session);
    _ = try registerMain(&page);

    // The body as a RemoteObject of the session (DOM.resolveNode's step).
    const global = try engine.evaluateClassicScript(page.realm, .{ .utf8 = "document.body" }, "", null, Ignored.reporter);
    defer global.release();
    const remote = try engine.inspectorWrap(session, page.realm, global.value, "test-group", testing.allocator);
    defer testing.allocator.free(remote);
    try testing.expect(std.mem.indexOf(u8, remote, "\"objectId\"") != null);
    try testing.expect(std.mem.indexOf(u8, remote, "HTMLBodyElement") != null);

    // Its objectId back to the same node (DOM.describeNode's step).
    var parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, remote, .{});
    defer parsed.deinit();
    const object_id = parsed.value.object.get("objectId").?.string;
    const unwrapped = (try engine.inspectorUnwrap(session, object_id)) orelse return error.NotUnwrapped;
    defer unwrapped.value.release();
    try testing.expectEqual(page.realm, unwrapped.realm);
    try testing.expect(engine.sameValue(page.realm, unwrapped.value.borrow(), global.value));
    // An id that names nothing.
    try testing.expectEqual(@as(?engine.InspectorUnwrapped, null), try engine.inspectorUnwrap(session, "{\"injectedScriptId\":999,\"id\":1}"));

    // The object group's release drops it.
    received.clear();
    engine.inspectorDispatch(session, "{\"id\":3,\"method\":\"Runtime.releaseObjectGroup\",\"params\":{\"objectGroup\":\"test-group\"}}");
    try received.expectFound(&.{"\"id\":3"});
    try testing.expectEqual(@as(?engine.InspectorUnwrapped, null), try engine.inspectorUnwrap(session, object_id));
}

test "a value wraps as the session's RemoteObject and its objectId unwraps to the same value" {
    if (supported) try wrapUnwrap() else return error.SkipZigTest;
}

fn worldContexts() !void {
    var page = try Page.make();
    defer page.end();
    var received: Received = .{};
    defer received.deinit();
    const session = try engine.inspectorConnect(page.agent, 1, received.channel());
    defer engine.inspectorDisconnect(session);
    _ = try registerMain(&page);
    const world = try engine.createWorldRealm(page.realm, &.{ .world = 1, .name = "__puppeteer_utility_world__25.11.0", .universal_access = true });
    engine.inspectorDispatch(session, "{\"id\":1,\"method\":\"Runtime.enable\"}");
    const world_id = try engine.inspectorContextCreated(&.{
        .realm = world,
        .group = 1,
        .name = "__puppeteer_utility_world__25.11.0",
        .origin = "https://example.test",
        .aux_data = "{\"isDefault\":false,\"type\":\"isolated\",\"frameId\":\"0123456789ABCDEF0123456789ABCDEF\"}",
    });
    try received.expectFound(&.{ "Runtime.executionContextCreated", "\"type\":\"isolated\"", "__puppeteer_utility_world__25.11.0" });
    // Evaluation in the world: its own global, the page's DOM.
    var buffer: [256]u8 = undefined;
    const request = try std.fmt.bufPrint(&buffer, "{{\"id\":2,\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"typeof pageOnly + ':' + document.body.tagName\",\"contextId\":{d},\"returnByValue\":true}}}}", .{world_id});
    const page_global = try eval(page.realm, "globalThis.pageOnly = 1; 'ok'");
    testing.allocator.free(page_global);
    engine.inspectorDispatch(session, request);
    try received.expectFound(&.{ "\"id\":2", "\"value\":\"undefined:BODY\"" });
    // The world's end tells the session.
    received.clear();
    engine.destroyWorldRealms(page.realm);
    try received.expectFound(&.{"Runtime.executionContextDestroyed"});
}

test "an isolated world's realm registers as an isolated context, evaluates in its own global, and its end is reported" {
    if (supported) try worldContexts() else return error.SkipZigTest;
}

fn bindingsConsoleExceptions() !void {
    var page = try Page.make();
    defer page.end();
    var received: Received = .{};
    defer received.deinit();
    const session = try engine.inspectorConnect(page.agent, 1, received.channel());
    defer engine.inspectorDisconnect(session);
    _ = try registerMain(&page);
    engine.inspectorDispatch(session, "{\"id\":1,\"method\":\"Runtime.enable\"}");

    // Runtime.addBinding: a function in the registered context whose calls
    // come back as bindingCalled.
    engine.inspectorDispatch(session, "{\"id\":2,\"method\":\"Runtime.addBinding\",\"params\":{\"name\":\"craneBinding\"}}");
    const called = try eval(page.realm, "craneBinding('payload'); typeof craneBinding");
    defer testing.allocator.free(called);
    try testing.expectEqualStrings("function", called);
    try received.expectFound(&.{ "Runtime.bindingCalled", "craneBinding", "payload" });

    // The Console Standard's console reaches the session through V8's own.
    const logged = try eval(page.realm, "console.log('from page', 42); console.warn('careful'); 'ok'");
    defer testing.allocator.free(logged);
    try received.expectFound(&.{ "Runtime.consoleAPICalled", "\"type\":\"log\"", "from page" });
    try received.expectFound(&.{ "Runtime.consoleAPICalled", "\"type\":\"warning\"", "careful" });

    // HTML "report an exception" reaches it as exceptionThrown.
    _ = engine.inspectorExceptionThrown(page.realm, runtime.JSValue.jsUndefined, &.{ .message = "Uncaught Error: boom", .url = "https://example.test/a.js", .line = 3, .column = 7 });
    try received.expectFound(&.{ "Runtime.exceptionThrown", "Uncaught Error: boom" });
}

test "Runtime.addBinding, the console and reported exceptions reach a session with Runtime enabled" {
    if (supported) try bindingsConsoleExceptions() else return error.SkipZigTest;
}

fn clientHooks() !void {
    var page = try Page.make();
    defer page.end();
    const Client = struct {
        released: ?engine.InspectorGroup = null,
        fn runIfWaiting(host: ?*anyopaque, group: engine.InspectorGroup) void {
            const self: *@This() = @ptrCast(@alignCast(host.?));
            self.released = group;
        }
    };
    var state: Client = .{};
    const client: engine.InspectorClient = .{ .host = &state, .runIfWaitingForDebugger = Client.runIfWaiting };
    engine.installInspectorClient(page.agent, &client);
    defer engine.installInspectorClient(page.agent, null);
    var received: Received = .{};
    defer received.deinit();
    const session = try engine.inspectorConnect(page.agent, 7, received.channel());
    defer engine.inspectorDisconnect(session);
    engine.inspectorDispatch(session, "{\"id\":1,\"method\":\"Runtime.runIfWaitingForDebugger\"}");
    try testing.expectEqual(@as(?engine.InspectorGroup, 7), state.released);
    try received.expectFound(&.{"\"id\":1"});
}

test "Runtime.runIfWaitingForDebugger reaches the host's client for the session's group" {
    if (supported) try clientHooks() else return error.SkipZigTest;
}

fn replBesideSession() !void {
    var page = try Page.make();
    defer page.end();
    var received: Received = .{};
    defer received.deinit();
    const session = try engine.inspectorConnect(page.agent, 1, received.channel());
    defer engine.inspectorDisconnect(session);
    _ = try registerMain(&page);
    // The console's REPL evaluates in the host's group now (the realm is
    // registered there): it still answers, through the agent's one inspector.
    const Steps = struct {
        got: ?[]u8 = null,
        fn fulfilled(data: ?*anyopaque, value: runtime.JSValue) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            _ = value;
            self.got = testing.allocator.dupe(u8, "fulfilled") catch null;
        }
        const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled };
    };
    var steps: Steps = .{};
    defer if (steps.got) |g| testing.allocator.free(g);
    if (engine.capabilities.repl_mode != .unsupported) {
        _ = try engine.evaluateReplScript(page.realm, "let replValue = 5; replValue", &Steps.steps, &steps);
        try engine.performMicrotaskCheckpoint(page.agent);
        try testing.expectEqualStrings("fulfilled", steps.got orelse "none");
    }
}

test "the console's REPL keeps answering beside a host session on the agent's one inspector" {
    if (supported) try replBesideSession() else return error.SkipZigTest;
}
