//! Typed OM §3 set step 10; Q178 Chrome156/Safari27 probe, 2026-10-29.
//! Equal successful sets serialize and notify; invalid sets and zero appends do not.
//! Shorthand serialization follows Chrome on the shipping-browser split, per
//! tmp/probes/q178/RESULT.md. Each test has a fresh thread and testing allocator.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const a = std.testing.allocator;

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("om1 same-value map script: {s}\n", .{info.message});
    }
};

fn script(realm: runtime.Context, source: []const u8) !engine.Owned {
    return engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, .{ .report = Host.report, .host = null });
}

fn check(source: []const u8) !void {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = a });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = a, .from_snapshot = false, .timer = null, .origin = "https://om1.test", .browser_scope = &scope, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(realm, .global_detached);
    // The existing style_engine_test.zig Page harness creates an HTMLDocument
    // and installs its window through this owner hook. Do not assume a prior
    // test initialized a document or a V8 isolate.
    const held_document = try script(realm, "globalThis.d = new Document().implementation.createHTMLDocument('om1'); d");
    defer held_document.release();
    const document = engine.convertToPlatformObject(realm, held_document.value) orelse return error.NoDocument;
    const held_window = try script(realm, "globalThis");
    defer held_window.release();
    const window = engine.convertToPlatformObject(realm, held_window.value) orelse return error.NoWindow;
    dom.document_browsing_context.setWindow(document, window);
    dom.window_globals.setDocument(window, document);
    const setup = try script(realm,
        \\globalThis.el = d.createElement('div'); d.body.appendChild(el);
        \\globalThis.check = (condition, message) => { if (!condition) throw new Error(message); };
        \\globalThis.typeError = (f, label) => { let thrown; try { f(); } catch (e) { thrown = e; } check(thrown instanceof TypeError, label); };
    );
    setup.release();
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = Host.report, .host = null });
    defer a.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

fn run(source: []const u8) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void, text: []const u8) void {
            out.* = check(text);
        }
    }.body, .{ &result, source });
    thread.join();
    try result;
}

test "Q178 Typed OM equal-value update - empty after raw declaration" {
    try run(
        \\(() => {
        \\const initial = "--foo:";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('--foo', new CSSUnparsedValue([]));
        \\  check(el.getAttribute('style') === "--foo: ;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - empty string segment after raw declaration" {
    try run(
        \\(() => {
        \\const initial = "--foo:";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('--foo', new CSSUnparsedValue(['']));
        \\  check(el.getAttribute('style') === "--foo: ;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - empty after canonical declaration" {
    try run(
        \\(() => {
        \\const initial = "--foo: ;";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('--foo', new CSSUnparsedValue([]));
        \\  check(el.getAttribute('style') === "--foo: ;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - nonempty custom same object" {
    try run(
        \\(() => {
        \\const initial = "--foo:one";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('--foo', new CSSUnparsedValue(['one']));
        \\  check(el.getAttribute('style') === "--foo: one;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - nonempty custom same string" {
    try run(
        \\(() => {
        \\const initial = "--foo:one";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('--foo', 'one');
        \\  check(el.getAttribute('style') === "--foo: one;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - unit same object" {
    try run(
        \\(() => {
        \\const initial = "width:1px";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('width', CSS.px(1));
        \\  check(el.getAttribute('style') === "width: 1px;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - unit same string" {
    try run(
        \\(() => {
        \\const initial = "width:1px";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('width', '1px');
        \\  check(el.getAttribute('style') === "width: 1px;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - keyword same" {
    try run(
        \\(() => {
        \\const initial = "display:block";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('display', new CSSKeywordValue('block'));
        \\  check(el.getAttribute('style') === "display: block;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - list same" {
    try run(
        \\(() => {
        \\const initial = "transition-duration:1s,2s";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('transition-duration', CSS.s(1), CSS.s(2));
        \\  check(el.getAttribute('style') === "transition-duration: 1s, 2s;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - wide same" {
    try run(
        \\(() => {
        \\const initial = "width:inherit";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('width', new CSSKeywordValue('inherit'));
        \\  check(el.getAttribute('style') === "width: inherit;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - shorthand same" {
    try run(
        \\(() => {
        \\const initial = "margin:1px";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.set('margin', '1px');
        \\  check(el.getAttribute('style') === "margin: 1px;", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 1, 'mutation count: ' + records.length);
        \\  check(records[0].type === 'attributes' && records[0].attributeName === 'style', 'mutation type/name');
        \\  check(records[0].target === el && records[0].attributeNamespace === null, 'mutation target/namespace');
        \\  check(records[0].oldValue === initial, 'mutation oldValue');
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - zero append" {
    try run(
        \\(() => {
        \\const initial = "transition-duration:1s";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  m.append('transition-duration');
        \\  check(el.getAttribute('style') === "transition-duration:1s", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 0, 'mutation count: ' + records.length);
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - invalid custom string" {
    try run(
        \\(() => {
        \\const initial = "--foo:";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  typeError(() => m.set('--foo', ''), 'invalid set');
        \\  check(el.getAttribute('style') === "--foo:", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 0, 'mutation count: ' + records.length);
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}

test "Q178 Typed OM equal-value update - invalid unit" {
    try run(
        \\(() => {
        \\const initial = "width:1px";
        \\el.setAttribute('style', initial);
        \\const m = el.attributeStyleMap;
        \\const observer = new MutationObserver(() => {});
        \\observer.observe(el, {attributes: true, attributeOldValue: true});
        \\try {
        \\  typeError(() => m.set('width', CSS.s(1)), 'invalid set');
        \\  check(el.getAttribute('style') === "width:1px", 'attribute: ' + el.getAttribute('style'));
        \\  const records = observer.takeRecords();
        \\  check(records.length === 0, 'mutation count: ' + records.length);
        \\} finally { observer.disconnect(); }
        \\return 'ok'; })()
    );
}
