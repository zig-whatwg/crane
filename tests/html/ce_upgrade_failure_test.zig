//! HTML upgrade step 10 preserves the state reached before construction failed.
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
    std.debug.print("CE failed-upgrade fixture script error: {s}\n", .{info.message});
}

fn exercise() !void {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var host = AgentHost.init(testing.allocator);
    defer host.deinit();
    const agent = try engine.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .allocator = testing.allocator,
        .host = &host,
        .hooks = &.{},
    });
    defer engine.destroyAgent(agent);
    defer host.custom_elements.releasePending();
    var capture = Capture{};
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .create_global_object = makeWindow,
        .host = &capture,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const window = capture.window orelse return error.NoWindow;
    const document = try interfaces.Document.init(testing.allocator, realm);
    try dom.document_internals.setDocumentType(document, .html);
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);

    // Throwing before super() isolates upgrade's failure cleanup from the
    // HTMLConstructor host hook. The same callback cannot be retried later.
    const setup = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\globalThis.attempts = 0;
        \\globalThis.callbacks = 0;
        \\class ThrowsDuringUpgrade extends HTMLElement {
        \\  static observedAttributes = ['watch'];
        \\  constructor() { ++attempts; throw new Error('expected upgrade failure'); }
        \\  attributeChangedCallback() { ++callbacks; }
        \\}
        \\customElements.define('ce-native-throws', ThrowsDuringUpgrade);
    }, "ce-failed-upgrade-setup.js", null, .{ .report = report });
    defer setup.release();
    const registry = try interfaces.Document.get_customElementRegistry(document);
    const definition = dom.custom_elements.lookup(registry, html.custom_element_creation.html_namespace, "ce-native-throws", null) orelse return error.NoDefinition;
    const element = try html.custom_element_creation.createInternal(.{
        .document = document,
        .local_name = "ce-native-throws",
        .namespace = html.custom_element_creation.html_namespace,
    }, .undefined, .autonomous);
    const root = try engine.retainValue(realm, .{ .instance = element });
    defer root.release();
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("watch"), .{ .domstring = runtime.DOMString.initInterned("old") });

    const scope = runtime.CEReactions.begin(document);
    var ended = false;
    defer if (!ended) runtime.CEReactions.end(scope);
    const exception = (try html.upgrade.upgradeElement(element, definition)) orelse return error.ExpectedException;
    defer exception.release();
    const data = dom.custom_elements.get(element) orelse return error.NoElementData;
    try testing.expectEqual(dom.custom_elements.State.precustomized, data.state);
    try testing.expectEqual(@as(?*dom.custom_elements.Definition, null), data.definition);
    try testing.expectEqual(@as(usize, 0), definition.construction_stack.items.len);
    try testing.expectEqual(@as(usize, 0), host.custom_elements.active_constructors.len);
    try testing.expect((try html.upgrade.upgradeElement(element, definition)) == null);
    runtime.CEReactions.end(scope);
    ended = true;
    const check = try engine.evaluateClassicScript(realm, .{ .utf8 = "attempts === 1 && callbacks === 0" }, "ce-failed-upgrade-check.js", null, .{ .report = report });
    defer check.release();
    try testing.expect(engine.toBoolean(realm, check.value));
}

test "CE upgrade: a throwing constructor preserves precustomized state and clears queued callbacks" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                std.debug.print("CE failed-upgrade fixture failed: {s}\n", .{@errorName(err)});
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
