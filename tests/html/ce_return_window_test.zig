//! The create-an-element result has only an Instance pointer between its
//! native return and the binding's conversion, while CEReactions runs script.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const AgentHost = @import("html_core").agent_host.AgentHost;

const Capture = struct { window: ?*runtime.Instance = null };
fn makeWindow(realm: runtime.Context, _: runtime.JSValue, data: ?*anyopaque) ?*runtime.Instance {
    const capture: *Capture = @ptrCast(@alignCast(data orelse return null));
    const window = interfaces.Window.init(testing.allocator, realm) catch return null;
    capture.window = window;
    return window;
}
fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("CE return-window fixture script error: {s}\n", .{info.message});
}

fn exercise() !void {
    if (engine.capabilities.html_constructor == .unsupported) return error.SkipZigTest;
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var host = AgentHost.init(testing.allocator);
    defer host.deinit();
    const hooks: engine.HostHooks = .{ .htmlConstructor = html.custom_element_constructor.construct };
    const agent = try engine.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .allocator = testing.allocator,
        .host = &host,
        .hooks = &hooks,
    });
    defer engine.destroyAgent(agent);
    defer host.custom_elements.releasePending();
    var capture = Capture{};
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "http://ce.test",
        .create_global_object = makeWindow,
        .host = &capture,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const window = capture.window orelse return error.NoWindow;
    const document = try interfaces.Document.init(testing.allocator, realm);
    try dom.document_internals.setDocumentType(document, .html);
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);

    const setup = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\globalThis.collectorRan = false;
        \\class WindowReturned extends HTMLElement {
        \\  constructor() { super(); this.marker = 731; }
        \\}
        \\customElements.define('ce-native-returned', WindowReturned);
        \\class WindowCollector extends HTMLElement {
        \\  connectedCallback() {
        \\    TestUtils.gc();
        \\    globalThis.collectorRan = true;
        \\  }
        \\}
        \\customElements.define('ce-native-collector', WindowCollector);
        \\globalThis.collector = document.createElement('ce-native-collector');
    }, "ce-return-window-setup.js", null, .{ .report = report });
    defer setup.release();
    const collector_value = try engine.evaluateClassicScript(realm, .{ .utf8 = "collector" }, "ce-return-window-collector.js", null, .{ .report = report });
    defer collector_value.release();
    const check = try engine.evaluateClassicScript(realm, .{ .utf8 = "value => collectorRan && value instanceof WindowReturned && value.marker === 731" }, "ce-return-window-check.js", null, .{ .report = report });
    defer check.release();
    const collector = engine.convertToPlatformObject(realm, collector_value.value) orelse return error.NoCollector;
    const definition = (dom.custom_elements.get(collector) orelse return error.NoDefinition).definition orelse return error.NoDefinition;

    // A generated IDL bracket runs inside its caller's script context. Keep
    // that context open so callback cleanup cannot insert a task checkpoint
    // between the implementation and the binding's result conversion.
    const caller = try engine.prepareToRunScript(realm);
    defer engine.cleanUpAfterRunningScript(caller);
    // Exactly the generated bracket's order: begin, implementation, end,
    // result conversion. Queue a DIFFERENT element, so the reaction cannot
    // accidentally root the result through its own `this` or queue record.
    const scope = runtime.CEReactions.begin(document);
    var ended = false;
    defer if (!ended) runtime.CEReactions.end(scope);
    try html.custom_elements.enqueueCallback(collector, definition, .connected, .none);
    const returned = try html.custom_element_creation.create(.{
        .document = document,
        .local_name = "ce-native-returned",
        .namespace = "http://www.w3.org/1999/xhtml",
        .synchronous = true,
    });
    const generation = runtime.SlabAllocator.generationOf(returned);
    runtime.CEReactions.end(scope);
    ended = true;
    // Detect a collected Instance without following it, then perform exactly
    // the platform-value conversion that must still find its custom wrapper.
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(returned));
    const converted = try engine.retainValue(realm, .{ .instance = returned });
    defer converted.release();
    const outcome = try engine.invokeCallbackFunction(realm, &.{ .function = check, .context = realm }, .undefined, &.{converted.value}, .rethrow);
    switch (outcome) {
        .normal => |value| {
            defer value.release();
            try testing.expect(engine.toBoolean(realm, value.value));
        },
        .throw => |value| {
            defer value.release();
            return error.CheckThrew;
        },
    }
}

test "CE return: a different element collects after construction and before result conversion" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                std.debug.print("CE return-window fixture failed: {s}\n", .{@errorName(err)});
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
