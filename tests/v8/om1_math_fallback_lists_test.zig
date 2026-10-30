//! Typed OM §5.2 and Q124/Q126 Chrome156/Safari27 probe,2026-10-28.
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
        std.debug.print("om1 compound math script: {s}\n", .{info.message});
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

test "Q126 named range with unsupported math retains the whole specified list" {
    try run(
        \\(() => {
        \\const property = "animation-range-start";
        \\const source = "cover round(1em, 1px), 10px";
        \\check(CSS.supports(property, source), 'valid CSS');
        \\el.style.setProperty(property, source);
        \\const expected = el.style.getPropertyValue(property);
        \\check(expected !== '', 'declaration stored');
        \\const parsed = CSSStyleValue.parse(property, source);
        \\const got = el.attributeStyleMap.get(property);
        \\const parsedAll = CSSStyleValue.parseAll(property, source);
        \\const gotAll = el.attributeStyleMap.getAll(property);
        \\check(parsedAll.length === 1, 'parseAll retains whole property');
        \\check(gotAll.length === 1, 'getAll retains whole property');
        \\for (const value of [parsed, got, parsedAll[0], gotAll[0]]) {
        \\  check(value.constructor === CSSStyleValue, 'opaque class');
        \\  check(String(value) === expected, 'existing CSSOM serialization');
        \\  const target = d.createElement('div');
        \\  target.attributeStyleMap.set(property, value);
        \\  check(target.style.getPropertyValue(property) === expected, 'same property round trip');
        \\}
        \\el.style.removeProperty(property);
        \\check(String(got) === expected, 'retained native value after removal');
        \\el.attributeStyleMap.set(property, got);
        \\check(el.style.getPropertyValue(property) === expected, 'set after source removal');
        \\return 'ok';
        \\})()
    );
}

test "Q126 registered residual math retains the whole computed list" {
    try run(
        \\(() => {
        \\const property = '--om1-math-list';
        \\const source = 'round(10%, 1px), 2px';
        \\CSS.registerProperty({name: property, syntax: '<length-percentage>#', inherits: false, initialValue: '0px'});
        \\el.style.setProperty(property, source);
        \\check(CSSStyleValue.parse(property, source).constructor === CSSUnparsedValue, 'specified parse remains unparsed');
        \\check(el.attributeStyleMap.get(property).constructor === CSSUnparsedValue, 'specified get remains unparsed');
        \\const expected = getComputedStyle(el).getPropertyValue(property);
        \\check(expected === source, 'computed unresolved list serialization');
        \\const got = el.computedStyleMap().get(property);
        \\const all = el.computedStyleMap().getAll(property);
        \\check(all.length === 1, 'whole registered list is one value');
        \\for (const value of [got, all[0]]) {
        \\  check(value.constructor === CSSStyleValue, 'opaque registered list class');
        \\  check(String(value) === expected, 'whole registered list serialization');
        \\}
        \\el.style.removeProperty(property);
        \\check(String(got) === expected, 'whole list outlives declaration');
        \\// Q126: neither browser gives valid set evidence; Typed OM §5.2 decides.
        \\el.attributeStyleMap.set(property, got);
        \\check(el.style.getPropertyValue(property) === expected, 'same-property set restores entire list');
        \\return 'ok';
        \\})()
    );
}

test "Q126 registered reifiable control 3px, 2px keeps two units" {
    try run(
        \\(() => {
        \\const property = '--om1-math-list';
        \\CSS.registerProperty({name: property, syntax: '<length-percentage>#', inherits: false, initialValue: '0px'});
        \\el.style.fontSize = '16px';
        \\el.style.setProperty(property, "3px, 2px");
        \\check(el.attributeStyleMap.get(property).constructor === CSSUnparsedValue, 'specified control remains unparsed');
        \\const got = el.computedStyleMap().get(property);
        \\const all = el.computedStyleMap().getAll(property);
        \\check(got.constructor === CSSUnitValue && got.unit === 'px' && got.value === 3, 'first computed unit');
        \\check(all.length === 2, 'reifiable list keeps both items');
        \\check(all[0].constructor === CSSUnitValue && all[0].value === 3 && all[0].unit === 'px', 'first list unit');
        \\check(all[1].constructor === CSSUnitValue && all[1].value === 2 && all[1].unit === 'px', 'second list unit');
        \\return 'ok';
        \\})()
    );
}

test "Q126 registered reifiable control round(1em, 1px), 2px keeps two units" {
    try run(
        \\(() => {
        \\const property = '--om1-math-list';
        \\CSS.registerProperty({name: property, syntax: '<length-percentage>#', inherits: false, initialValue: '0px'});
        \\el.style.fontSize = '16px';
        \\el.style.setProperty(property, "round(1em, 1px), 2px");
        \\check(el.attributeStyleMap.get(property).constructor === CSSUnparsedValue, 'specified control remains unparsed');
        \\const got = el.computedStyleMap().get(property);
        \\const all = el.computedStyleMap().getAll(property);
        \\check(got.constructor === CSSUnitValue && got.unit === 'px' && got.value === 16, 'first computed unit');
        \\check(all.length === 2, 'reifiable list keeps both items');
        \\check(all[0].constructor === CSSUnitValue && all[0].value === 16 && all[0].unit === 'px', 'first list unit');
        \\check(all[1].constructor === CSSUnitValue && all[1].value === 2 && all[1].unit === 'px', 'second list unit');
        \\return 'ok';
        \\})()
    );
}
