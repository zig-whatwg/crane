//! Typed OM §5.2 and Q95 Chrome156/Safari27 probe,2026-10-27.
//! Unsupported valid math keeps its native property-associated value.
//! Each body owns a fresh thread, realm and leak-checking allocator.
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
        std.debug.print("om1 residual math script: {s}\n", .{info.message});
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

test "Q95 round(1em, 1px) retains an opaque associated value" {
    try run(
        \\(() => {
        \\function checkWidth(source, opaque, number) {
        \\  check(CSS.supports('width', source), 'valid CSS');
        \\  el.style.width = source;
        \\  const expected = el.style.width;
        \\  check(expected !== '', 'specified value stored');
        \\  const parsed = CSSStyleValue.parse('width', source);
        \\  const got = el.attributeStyleMap.get('width');
        \\  const all = CSSStyleValue.parseAll('width', source);
        \\  check(all.length === 1, 'one parsed value');
        \\  for (const value of [parsed, got, all[0]]) {
        \\    check(value.constructor === (opaque ? CSSStyleValue : CSSUnitValue), 'concrete class');
        \\    if (opaque) check(String(value) === expected, 'CSSOM serialization: ' + String(value) + ' != ' + expected);
        \\    else check(value.value === number && value.unit === 'px' && String(value) === number + 'px', 'simplified numeric');
        \\    const target = d.createElement('div');
        \\    target.attributeStyleMap.set('width', value);
        \\    check(target.style.width === (opaque ? expected : number + 'px'), 'same-property set');
        \\    if (opaque) {
        \\      target.style.height = '3px';
        \\      typeError(() => target.attributeStyleMap.set('height', value), 'associated property');
        \\      check(target.style.height === '3px', 'failed cross-property set is atomic');
        \\    }
        \\  }
        \\  el.style.removeProperty('width');
        \\  check(String(got) === (opaque ? expected : number + 'px'), 'value outlives source declaration');
        \\}
        \\checkWidth("round(1em, 1px)", true, null);
        \\return "ok"; })()
    );
}

test "Q95 calc(round(1em, 1px) + 2px) retains an opaque associated value" {
    try run(
        \\(() => {
        \\function checkWidth(source, opaque, number) {
        \\  check(CSS.supports('width', source), 'valid CSS');
        \\  el.style.width = source;
        \\  const expected = el.style.width;
        \\  check(expected !== '', 'specified value stored');
        \\  const parsed = CSSStyleValue.parse('width', source);
        \\  const got = el.attributeStyleMap.get('width');
        \\  const all = CSSStyleValue.parseAll('width', source);
        \\  check(all.length === 1, 'one parsed value');
        \\  for (const value of [parsed, got, all[0]]) {
        \\    check(value.constructor === (opaque ? CSSStyleValue : CSSUnitValue), 'concrete class');
        \\    if (opaque) check(String(value) === expected, 'CSSOM serialization: ' + String(value) + ' != ' + expected);
        \\    else check(value.value === number && value.unit === 'px' && String(value) === number + 'px', 'simplified numeric');
        \\    const target = d.createElement('div');
        \\    target.attributeStyleMap.set('width', value);
        \\    check(target.style.width === (opaque ? expected : number + 'px'), 'same-property set');
        \\    if (opaque) {
        \\      target.style.height = '3px';
        \\      typeError(() => target.attributeStyleMap.set('height', value), 'associated property');
        \\      check(target.style.height === '3px', 'failed cross-property set is atomic');
        \\    }
        \\  }
        \\  el.style.removeProperty('width');
        \\  check(String(got) === (opaque ? expected : number + 'px'), 'value outlives source declaration');
        \\}
        \\checkWidth("calc(round(1em, 1px) + 2px)", true, null);
        \\return "ok"; })()
    );
}

test "Q95 mod(1em, 1px) retains an opaque associated value" {
    try run(
        \\(() => {
        \\function checkWidth(source, opaque, number) {
        \\  check(CSS.supports('width', source), 'valid CSS');
        \\  el.style.width = source;
        \\  const expected = el.style.width;
        \\  check(expected !== '', 'specified value stored');
        \\  const parsed = CSSStyleValue.parse('width', source);
        \\  const got = el.attributeStyleMap.get('width');
        \\  const all = CSSStyleValue.parseAll('width', source);
        \\  check(all.length === 1, 'one parsed value');
        \\  for (const value of [parsed, got, all[0]]) {
        \\    check(value.constructor === (opaque ? CSSStyleValue : CSSUnitValue), 'concrete class');
        \\    if (opaque) check(String(value) === expected, 'CSSOM serialization: ' + String(value) + ' != ' + expected);
        \\    else check(value.value === number && value.unit === 'px' && String(value) === number + 'px', 'simplified numeric');
        \\    const target = d.createElement('div');
        \\    target.attributeStyleMap.set('width', value);
        \\    check(target.style.width === (opaque ? expected : number + 'px'), 'same-property set');
        \\    if (opaque) {
        \\      target.style.height = '3px';
        \\      typeError(() => target.attributeStyleMap.set('height', value), 'associated property');
        \\      check(target.style.height === '3px', 'failed cross-property set is atomic');
        \\    }
        \\  }
        \\  el.style.removeProperty('width');
        \\  check(String(got) === (opaque ? expected : number + 'px'), 'value outlives source declaration');
        \\}
        \\checkWidth("mod(1em, 1px)", true, null);
        \\return "ok"; })()
    );
}

test "Q95 hypot(1em, 1px) retains an opaque associated value" {
    try run(
        \\(() => {
        \\function checkWidth(source, opaque, number) {
        \\  check(CSS.supports('width', source), 'valid CSS');
        \\  el.style.width = source;
        \\  const expected = el.style.width;
        \\  check(expected !== '', 'specified value stored');
        \\  const parsed = CSSStyleValue.parse('width', source);
        \\  const got = el.attributeStyleMap.get('width');
        \\  const all = CSSStyleValue.parseAll('width', source);
        \\  check(all.length === 1, 'one parsed value');
        \\  for (const value of [parsed, got, all[0]]) {
        \\    check(value.constructor === (opaque ? CSSStyleValue : CSSUnitValue), 'concrete class');
        \\    if (opaque) check(String(value) === expected, 'CSSOM serialization: ' + String(value) + ' != ' + expected);
        \\    else check(value.value === number && value.unit === 'px' && String(value) === number + 'px', 'simplified numeric');
        \\    const target = d.createElement('div');
        \\    target.attributeStyleMap.set('width', value);
        \\    check(target.style.width === (opaque ? expected : number + 'px'), 'same-property set');
        \\    if (opaque) {
        \\      target.style.height = '3px';
        \\      typeError(() => target.attributeStyleMap.set('height', value), 'associated property');
        \\      check(target.style.height === '3px', 'failed cross-property set is atomic');
        \\    }
        \\  }
        \\  el.style.removeProperty('width');
        \\  check(String(got) === (opaque ? expected : number + 'px'), 'value outlives source declaration');
        \\}
        \\checkWidth("hypot(1em, 1px)", true, null);
        \\return "ok"; })()
    );
}

test "Q95 round(2px, 1px) simplifies to a unit value" {
    try run(
        \\(() => {
        \\function checkWidth(source, opaque, number) {
        \\  check(CSS.supports('width', source), 'valid CSS');
        \\  el.style.width = source;
        \\  const expected = el.style.width;
        \\  check(expected !== '', 'specified value stored');
        \\  const parsed = CSSStyleValue.parse('width', source);
        \\  const got = el.attributeStyleMap.get('width');
        \\  const all = CSSStyleValue.parseAll('width', source);
        \\  check(all.length === 1, 'one parsed value');
        \\  for (const value of [parsed, got, all[0]]) {
        \\    check(value.constructor === (opaque ? CSSStyleValue : CSSUnitValue), 'concrete class');
        \\    if (opaque) check(String(value) === expected, 'CSSOM serialization: ' + String(value) + ' != ' + expected);
        \\    else check(value.value === number && value.unit === 'px' && String(value) === number + 'px', 'simplified numeric');
        \\    const target = d.createElement('div');
        \\    target.attributeStyleMap.set('width', value);
        \\    check(target.style.width === (opaque ? expected : number + 'px'), 'same-property set');
        \\    if (opaque) {
        \\      target.style.height = '3px';
        \\      typeError(() => target.attributeStyleMap.set('height', value), 'associated property');
        \\      check(target.style.height === '3px', 'failed cross-property set is atomic');
        \\    }
        \\  }
        \\  el.style.removeProperty('width');
        \\  check(String(got) === (opaque ? expected : number + 'px'), 'value outlives source declaration');
        \\}
        \\checkWidth("round(2px, 1px)", false, 2);
        \\return "ok"; })()
    );
}

test "Q95 calc(sin(90deg) * 1px) simplifies to a unit value" {
    try run(
        \\(() => {
        \\function checkWidth(source, opaque, number) {
        \\  check(CSS.supports('width', source), 'valid CSS');
        \\  el.style.width = source;
        \\  const expected = el.style.width;
        \\  check(expected !== '', 'specified value stored');
        \\  const parsed = CSSStyleValue.parse('width', source);
        \\  const got = el.attributeStyleMap.get('width');
        \\  const all = CSSStyleValue.parseAll('width', source);
        \\  check(all.length === 1, 'one parsed value');
        \\  for (const value of [parsed, got, all[0]]) {
        \\    check(value.constructor === (opaque ? CSSStyleValue : CSSUnitValue), 'concrete class');
        \\    if (opaque) check(String(value) === expected, 'CSSOM serialization: ' + String(value) + ' != ' + expected);
        \\    else check(value.value === number && value.unit === 'px' && String(value) === number + 'px', 'simplified numeric');
        \\    const target = d.createElement('div');
        \\    target.attributeStyleMap.set('width', value);
        \\    check(target.style.width === (opaque ? expected : number + 'px'), 'same-property set');
        \\    if (opaque) {
        \\      target.style.height = '3px';
        \\      typeError(() => target.attributeStyleMap.set('height', value), 'associated property');
        \\      check(target.style.height === '3px', 'failed cross-property set is atomic');
        \\    }
        \\  }
        \\  el.style.removeProperty('width');
        \\  check(String(got) === (opaque ? expected : number + 'px'), 'value outlives source declaration');
        \\}
        \\checkWidth("calc(sin(90deg) * 1px)", false, 1);
        \\return "ok"; })()
    );
}

test "Q95 numeric parse rejects the residual newer function with SyntaxError" {
    try run(
        \\(() => { let thrown; try { CSSNumericValue.parse('calc(round(1em, 1px) + 2px)'); } catch (e) { thrown = e; }
        \\check(thrown instanceof DOMException && thrown.name === 'SyntaxError', 'numeric parse boundary'); return 'ok'; })()
    );
}
