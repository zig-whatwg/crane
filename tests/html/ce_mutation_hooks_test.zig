//! Exercise reaction hook points independently of HTMLConstructor: a native
//! fixture supplies an already-custom element, then script uses the real IDL.
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
    std.debug.print("CE mutation fixture script error in {s}: {s}\n", .{ info.filename, info.message });
}

fn expectScriptBoolean(realm: runtime.Context, value: runtime.JSValue, stage: []const u8) !void {
    if (engine.toBoolean(realm, value)) return;
    const events = try engine.evaluateClassicScript(realm, .{ .utf8 = "JSON.stringify(events)" }, "ce-mutation-diagnostic.js", null, .{ .report = report });
    defer events.release();
    const actual = try engine.convertToDOMString(realm, events.value, testing.allocator);
    defer testing.allocator.free(actual);
    std.debug.print("CE mutation {s}: actual events {s}\n", .{ stage, actual });
    return error.TestUnexpectedResult;
}

fn exercise() !void {
    var ordering_failed = false;
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
    const global = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "ce-mutation-global.js", null, .{ .report = report });
    defer global.release();
    const document = try interfaces.Document.init(testing.allocator, realm);
    try dom.document_internals.setDocumentType(document, .html);
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);
    const target_document = try interfaces.Document.init(testing.allocator, realm);
    try dom.document_internals.setDocumentType(target_document, .html);
    // A second document with no custom element registry: adoption makes the
    // subject's registry null, and inserting it still enqueues
    // connectedCallback, as Chrome, Edge and Firefox do (CE2-S3; the cached
    // DOM text gates insert step 7.7.3 on a non-null registry).
    try engine.setProperty(realm, global.value, "targetDocument", .{ .instance = target_document });
    const setup = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\globalThis.events = [];
        \\globalThis.container = document.createElement('div');
        \\document.appendChild(container);
        \\class NativeHooks extends HTMLElement {
        \\  static observedAttributes = ['watch'];
        \\  attributeChangedCallback(name, oldValue, newValue, namespace) {
        \\    events.push(['attr', name, oldValue, newValue, namespace, this === subject]);
        \\    if (newValue === 'parser') {
        \\      try { document.write(''); events.push(['counter', 'not blocked']); }
        \\      catch (error) { events.push(['counter', error.name]); }
        \\    }
        \\  }
        \\  connectedCallback() { events.push(['connected', this === subject]); }
        \\  disconnectedCallback() { events.push(['disconnected', this === subject]); }
        \\  adoptedCallback(oldDocument, newDocument) {
        \\    events.push(['adopted', oldDocument === document, newDocument === targetDocument, this === subject]);
        \\  }
        \\}
        \\customElements.define('ce-native-hooks', NativeHooks);
    }, "ce-mutation-hooks-setup.js", null, .{ .report = report });
    defer setup.release();
    const registry = try interfaces.Document.get_customElementRegistry(document);
    const definition = dom.custom_elements.lookup(registry, html.custom_element_creation.html_namespace, "ce-native-hooks", null) orelse return error.NoDefinition;
    // Only fixture creation bypasses construction. The definition, element
    // state, mutation entry points, generated brackets and callbacks are real.
    const element = try html.custom_element_creation.createInternal(.{
        .document = document,
        .local_name = "ce-native-hooks",
        .namespace = html.custom_element_creation.html_namespace,
    }, .custom, .autonomous);
    dom.custom_elements.setDefinition(element, definition);
    try engine.setProperty(realm, global.value, "subject", .{ .instance = element });

    const outcome = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\subject.setAttribute('watch', 'one');
        \\subject.setAttribute('watch', 'two');
        \\subject.setAttributeNS('urn:ce', 'p:watch', 'ns');
        \\subject.removeAttribute('watch');
        \\container.appendChild(subject);
        \\targetDocument.adoptNode(subject);
        \\targetDocument.appendChild(subject);
        \\JSON.stringify(events) === JSON.stringify([
        \\  ['attr', 'watch', null, 'one', null, true],
        \\  ['attr', 'watch', 'one', 'two', null, true],
        \\  ['attr', 'watch', null, 'ns', 'urn:ce', true],
        \\  ['attr', 'watch', 'two', null, null, true],
        \\  ['connected', true],
        \\  ['disconnected', true],
        \\  ['adopted', true, true, true],
        \\  ['connected', true]
        \\]);
    }, "ce-mutation-hooks-check.js", null, .{ .report = report });
    defer outcome.release();
    expectScriptBoolean(realm, outcome.value, "attribute/connection/adoption") catch {
        ordering_failed = true;
    };
    try testing.expectEqual(@as(usize, 0), host.custom_elements.queues.depth);

    // An upgrade has queued its old attributes and connection before calling
    // the constructor. Reinserting `this` must enqueue the element even in
    // the precustomized state: the nested scope drains those older callbacks.
    const prepare_reentry = try engine.evaluateClassicScript(realm, .{ .utf8 = "container.appendChild(subject); events.length = 0" }, "ce-reentry-prepare.js", null, .{ .report = report });
    defer prepare_reentry.release();
    dom.custom_elements.setState(element, .precustomized);
    try html.custom_elements.enqueueCallback(element, definition, .attribute_changed, .{ .attribute_changed = .{
        .local_name = "watch",
        .old_value = null,
        .new_value = "reentrant",
        .namespace = null,
    } });
    try html.custom_elements.enqueueCallback(element, definition, .connected, .none);
    const reentry = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\container.appendChild(subject);
        \\JSON.stringify(events) === JSON.stringify([
        \\  ['attr', 'watch', null, 'reentrant', null, true],
        \\  ['connected', true]
        \\]);
    }, "ce-reentry-check.js", null, .{ .report = report });
    defer reentry.release();
    dom.custom_elements.setState(element, .custom);
    expectScriptBoolean(realm, reentry.value, "precustomized reinsertion") catch {
        ordering_failed = true;
    };

    // HTML create-for-token steps 8–12: a fragment remains asynchronous;
    // the full parser owns an outer scope through token attributes and their
    // callbacks, with dynamic markup insertion still blocked inside a callback.
    const fragment = try html.custom_element_parser.Scope.begin(document, "ce-native-hooks", html.custom_element_creation.html_namespace, null, true);
    try testing.expect(!fragment.synchronous);
    fragment.end();
    try testing.expectEqual(@as(usize, 0), host.custom_elements.queues.depth);
    const parser_scope = try html.custom_element_parser.Scope.begin(document, "ce-native-hooks", html.custom_element_creation.html_namespace, null, false);
    var parser_ended = false;
    defer if (!parser_ended) parser_scope.end();
    try testing.expect(parser_scope.synchronous);
    const parsed = try html.custom_element_creation.createInternal(.{
        .document = document,
        .local_name = "ce-native-hooks",
        .namespace = html.custom_element_creation.html_namespace,
    }, .custom, .autonomous);
    dom.custom_elements.setDefinition(parsed, definition);
    try engine.setProperty(realm, global.value, "subject", .{ .instance = parsed });
    const reset = try engine.evaluateClassicScript(realm, .{ .utf8 = "events.length = 0" }, "ce-parser-reset.js", null, .{ .report = report });
    defer reset.release();
    html.parser_script_execution.appendParsedAttribute(parsed, .{ .name = "watch", .value = "parser", .namespace = null });
    const before_end = try engine.evaluateClassicScript(realm, .{ .utf8 = "events.length === 0" }, "ce-parser-before-pop.js", null, .{ .report = report });
    defer before_end.release();
    expectScriptBoolean(realm, before_end.value, "parser before pop") catch {
        ordering_failed = true;
    };
    parser_scope.end();
    parser_ended = true;
    const after_end = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\JSON.stringify(events) === JSON.stringify([
        \\  ['attr', 'watch', null, 'parser', null, true],
        \\  ['counter', 'InvalidStateError']
        \\]);
    }, "ce-parser-after-pop.js", null, .{ .report = report });
    defer after_end.release();
    expectScriptBoolean(realm, after_end.value, "parser after pop") catch {
        ordering_failed = true;
    };
    try testing.expectEqual(@as(usize, 0), host.custom_elements.queues.depth);
    if (ordering_failed) return error.TestUnexpectedResult;
}

test "CE mutations: attributes, connection and adoption invoke ordered callbacks through IDL" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                std.debug.print("CE mutation fixture failed: {s}\n", .{@errorName(err)});
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
