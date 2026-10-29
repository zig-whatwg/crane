//! Typed OM §§4.3.1 and6.4; Q81 Chrome156/Safari27 probe,2026-10-27.
//! Both preserve arithmetic overflow; 1-1 splits use the complete spec.
//! Probe: tmp/probe-q81/RULING.md, q81-{chrome,safari}.json; grantQ82.
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
        std.debug.print("om1 nonfinite map script: {s}\n", .{info.message});
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

test "Q81 px multiplication overflow sets width as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.px(1e308).mul(2);
        \\el.attributeStyleMap.set('width', v);
        \\check(el.style.getPropertyValue('width') === 'calc(infinity * 1px)', 'specified: ' + el.style.getPropertyValue('width'));
        \\const read = el.attributeStyleMap.get('width');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinitypx)', 'math reification: ' + String(read));
        \\const control = d.createElement('div'); d.body.appendChild(control);
        \\control.style.width = 'calc(infinity * 1px)';
        \\check(getComputedStyle(el).width === getComputedStyle(control).width, 'existing CSS computation');
        \\const a = el.computedStyleMap().get('width'), b = control.computedStyleMap().get('width');
        \\check(a.constructor === b.constructor && String(a) === String(b), 'existing computed reification');
        \\control.remove();
        \\return 'ok'; })()
    );
}

test "Q81 number addition overflow sets z-index as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(1e308).add(1e308);
        \\el.attributeStyleMap.set('z-index', v);
        \\check(el.style.getPropertyValue('z-index') === 'calc(infinity)', 'specified: ' + el.style.getPropertyValue('z-index'));
        \\const read = el.attributeStyleMap.get('z-index');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('z-index');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 2147483647, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('z-index') === '2147483647', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 number addition overflow sets opacity as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(1e308).add(1e308);
        \\el.attributeStyleMap.set('opacity', v);
        \\check(el.style.getPropertyValue('opacity') === 'calc(infinity)', 'specified: ' + el.style.getPropertyValue('opacity'));
        \\const read = el.attributeStyleMap.get('opacity');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('opacity');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 1, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('opacity') === '1', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 number multiplication overflow sets z-index as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(1e308).mul(2);
        \\el.attributeStyleMap.set('z-index', v);
        \\check(el.style.getPropertyValue('z-index') === 'calc(infinity)', 'specified: ' + el.style.getPropertyValue('z-index'));
        \\const read = el.attributeStyleMap.get('z-index');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('z-index');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 2147483647, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('z-index') === '2147483647', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 number multiplication overflow sets opacity as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(1e308).mul(2);
        \\el.attributeStyleMap.set('opacity', v);
        \\check(el.style.getPropertyValue('opacity') === 'calc(infinity)', 'specified: ' + el.style.getPropertyValue('opacity'));
        \\const read = el.attributeStyleMap.get('opacity');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('opacity');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 1, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('opacity') === '1', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 zero times overflow sets z-index as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(0).mul(CSS.number(1e308).mul(2));
        \\el.attributeStyleMap.set('z-index', v);
        \\check(el.style.getPropertyValue('z-index') === 'calc(NaN)', 'specified: ' + el.style.getPropertyValue('z-index'));
        \\const read = el.attributeStyleMap.get('z-index');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(NaN)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('z-index');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 0, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('z-index') === '0', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 zero times overflow sets opacity as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(0).mul(CSS.number(1e308).mul(2));
        \\el.attributeStyleMap.set('opacity', v);
        \\check(el.style.getPropertyValue('opacity') === 'calc(NaN)', 'specified: ' + el.style.getPropertyValue('opacity'));
        \\const read = el.attributeStyleMap.get('opacity');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(NaN)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('opacity');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 0, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('opacity') === '0', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 absolute conversion overflow sets width as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.cm(1e308).to('px');
        \\el.attributeStyleMap.set('width', v);
        \\check(el.style.getPropertyValue('width') === 'calc(infinity * 1px)', 'specified: ' + el.style.getPropertyValue('width'));
        \\const read = el.attributeStyleMap.get('width');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinitypx)', 'math reification: ' + String(read));
        \\const control = d.createElement('div'); d.body.appendChild(control);
        \\control.style.width = 'calc(infinity * 1px)';
        \\check(getComputedStyle(el).width === getComputedStyle(control).width, 'existing CSS computation');
        \\const a = el.computedStyleMap().get('width'), b = control.computedStyleMap().get('width');
        \\check(a.constructor === b.constructor && String(a) === String(b), 'existing computed reification');
        \\control.remove();
        \\return 'ok'; })()
    );
}

test "Q81 invert zero to unit sets z-index as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = new CSSMathInvert(CSS.number(0)).to('number');
        \\el.attributeStyleMap.set('z-index', v);
        \\check(el.style.getPropertyValue('z-index') === 'calc(infinity)', 'specified: ' + el.style.getPropertyValue('z-index'));
        \\const read = el.attributeStyleMap.get('z-index');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('z-index');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 2147483647, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('z-index') === '2147483647', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 invert zero to unit sets opacity as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = new CSSMathInvert(CSS.number(0)).to('number');
        \\el.attributeStyleMap.set('opacity', v);
        \\check(el.style.getPropertyValue('opacity') === 'calc(infinity)', 'specified: ' + el.style.getPropertyValue('opacity'));
        \\const read = el.attributeStyleMap.get('opacity');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('opacity');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 1, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('opacity') === '1', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 negative dimension overflow sets width as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.px(-1e308).mul(2);
        \\el.attributeStyleMap.set('width', v);
        \\check(el.style.getPropertyValue('width') === 'calc(-infinity * 1px)', 'specified: ' + el.style.getPropertyValue('width'));
        \\const read = el.attributeStyleMap.get('width');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(-infinitypx)', 'math reification: ' + String(read));
        \\const control = d.createElement('div'); d.body.appendChild(control);
        \\control.style.width = 'calc(-infinity * 1px)';
        \\check(getComputedStyle(el).width === getComputedStyle(control).width, 'existing CSS computation');
        \\const a = el.computedStyleMap().get('width'), b = control.computedStyleMap().get('width');
        \\check(a.constructor === b.constructor && String(a) === String(b), 'existing computed reification');
        \\control.remove();
        \\return 'ok'; })()
    );
}

test "Q81 negative number overflow sets z-index as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(-1e308).mul(2);
        \\el.attributeStyleMap.set('z-index', v);
        \\check(el.style.getPropertyValue('z-index') === 'calc(-infinity)', 'specified: ' + el.style.getPropertyValue('z-index'));
        \\const read = el.attributeStyleMap.get('z-index');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(-infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('z-index');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === -2147483648, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('z-index') === '-2147483648', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q81 negative number overflow sets opacity as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.number(-1e308).mul(2);
        \\el.attributeStyleMap.set('opacity', v);
        \\check(el.style.getPropertyValue('opacity') === 'calc(-infinity)', 'specified: ' + el.style.getPropertyValue('opacity'));
        \\const read = el.attributeStyleMap.get('opacity');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(-infinity)', 'math reification: ' + String(read));
        \\const computed = el.computedStyleMap().get('opacity');
        \\check(computed instanceof CSSUnitValue && computed.unit === 'number' && computed.value === 0, 'computed unit');
        \\check(getComputedStyle(el).getPropertyValue('opacity') === '0', 'computed CSSOM');
        \\return 'ok'; })()
    );
}

test "Q83 NaN dimension sets width as math and follows its computed range" {
    try run(
        \\(() => {
        \\const v = CSS.px(0).mul(CSS.number(1e308).mul(2));
        \\el.attributeStyleMap.set('width', v);
        \\check(el.style.getPropertyValue('width') === 'calc(NaN * 1px)', 'specified: ' + el.style.getPropertyValue('width'));
        \\const read = el.attributeStyleMap.get('width');
        \\check(read instanceof CSSMathSum && String(read) === 'calc(NaNpx)', 'math reification: ' + String(read));
        \\const control = d.createElement('div'); d.body.appendChild(control);
        \\control.style.width = 'calc(NaN * 1px)';
        \\check(getComputedStyle(el).width === getComputedStyle(control).width, 'existing CSS computation');
        \\const a = el.computedStyleMap().get('width'), b = control.computedStyleMap().get('width');
        \\check(a.constructor === b.constructor && String(a) === String(b), 'existing computed reification');
        \\control.remove();
        \\return 'ok'; })()
    );
}

test "Q85 property accepts32 unresolved levels" {
    try run(
        \\(() => {
        \\el.style.cssText = 'width: 5px !important; z-index: 7';
        \\const before = el.style.cssText;
        \\let value = CSS.em(1);
        \\for (let i = 0; i < 32; ++i) value = i % 2 ? new CSSMathMax(value, CSS.vw(1)) : new CSSMathMin(value, CSS.vw(1));
        \\el.attributeStyleMap.set('width', value);
        \\check(el.style.getPropertyValue('width').startsWith('max('), 'native graph assigned');
        \\check(el.style.getPropertyPriority('width') === '', 'priority reset');
        \\check(el.style.getPropertyValue('z-index') === '7', 'unrelated property');
        \\return 'ok'; })()
    );
}

test "Q85 property accepts128 unresolved levels" {
    try run(
        \\(() => {
        \\el.style.cssText = 'width: 5px !important; z-index: 7';
        \\const before = el.style.cssText;
        \\let value = CSS.em(1);
        \\for (let i = 0; i < 128; ++i) value = i % 2 ? new CSSMathMax(value, CSS.vw(1)) : new CSSMathMin(value, CSS.vw(1));
        \\el.attributeStyleMap.set('width', value);
        \\check(el.style.getPropertyValue('width').startsWith('max('), 'native graph assigned');
        \\check(el.style.getPropertyPriority('width') === '', 'priority reset');
        \\check(el.style.getPropertyValue('z-index') === '7', 'unrelated property');
        \\return 'ok'; })()
    );
}

test "Q85 property rejects129 unresolved levels atomically" {
    try run(
        \\(() => {
        \\el.style.cssText = 'width: 5px !important; z-index: 7';
        \\const before = el.style.cssText;
        \\let value = CSS.em(1);
        \\for (let i = 0; i < 129; ++i) value = i % 2 ? new CSSMathMax(value, CSS.vw(1)) : new CSSMathMin(value, CSS.vw(1));
        \\typeError(() => el.attributeStyleMap.set('width', value), 'over-limit TypeError');
        \\check(el.style.cssText === before, 'atomic declaration rollback');
        \\const read = el.attributeStyleMap.get('width');
        \\check(read instanceof CSSUnitValue && read.value === 5 && read.unit === 'px', 'old typed value');
        \\check(el.style.getPropertyPriority('width') === 'important', 'old priority');
        \\return 'ok'; })()
    );
}

test "Q85 property rejects5000 unresolved levels atomically" {
    try run(
        \\(() => {
        \\el.style.cssText = 'width: 5px !important; z-index: 7';
        \\const before = el.style.cssText;
        \\let value = CSS.em(1);
        \\for (let i = 0; i < 5000; ++i) value = i % 2 ? new CSSMathMax(value, CSS.vw(1)) : new CSSMathMin(value, CSS.vw(1));
        \\typeError(() => el.attributeStyleMap.set('width', value), 'over-limit TypeError');
        \\check(el.style.cssText === before, 'atomic declaration rollback');
        \\const read = el.attributeStyleMap.get('width');
        \\check(read instanceof CSSUnitValue && read.value === 5 && read.unit === 'px', 'old typed value');
        \\check(el.style.getPropertyPriority('width') === 'important', 'old priority');
        \\return 'ok'; })()
    );
}
