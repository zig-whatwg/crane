//! Q189/Q190: preserve the existing non-throwing default for routed stubs.
//! KNOWN-INCOMPLETE: the placeholder is legacy behavior, not CSS serialization.
//! These native regressions deliberately do not add placeholder WPT expectations.
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
        std.debug.print("om1 style value default: {s}\n", .{info.message});
    }
};

fn check(comptime Interface: type, source: ?[]const u8) !void {
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
    if (source) |text| {
        // Match the existing map harness: a stylesheet needs its window's
        // associated document before the test reaches the value operation.
        const held_document = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis.d = new Document().implementation.createHTMLDocument('om1'); d" }, "", null, .{ .report = Host.report, .host = null });
        defer held_document.release();
        const document = engine.convertToPlatformObject(realm, held_document.value) orelse return error.NoDocument;
        const held_window = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "", null, .{ .report = Host.report, .host = null });
        defer held_window.release();
        const window = engine.convertToPlatformObject(realm, held_window.value) orelse return error.NoWindow;
        dom.document_browsing_context.setWindow(document, window);
        dom.window_globals.setDocument(window, document);
        const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = text }, "", null, a, .{ .report = Host.report, .host = null });
        defer a.free(result);
        try std.testing.expectEqualStrings("ok", result);
    } else {
        const instance = try Interface.init(a, realm);
        defer Interface.deinit(instance);
        const result = try interfaces.CSSStyleValue.serialize(instance);
        defer a.free(result);
        try std.testing.expectEqualStrings("[object]", result);
    }
}

fn run(comptime Interface: type, source: ?[]const u8) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void, text: ?[]const u8) void {
            out.* = check(Interface, text);
        }
    }.body, .{ &result, source });
    thread.join();
    try result;
}

fn constructed(comptime expression: []const u8) !void {
    try run(interfaces.CSSStyleValue, "(() => { const value = " ++ expression ++ "; if (String(value) !== '[object]') throw new Error('legacy default'); return 'ok'; })()");
}

test "Q189 default CSSStyleValue owns a non-throwing placeholder copy" {
    try run(interfaces.CSSStyleValue, null);
}

test "Q190 CSSImageValue without native payload retains the default" {
    try run(interfaces.CSSImageValue, null);
}

test "Q190 abstract CSSColorValue retains the default" {
    try run(interfaces.CSSColorValue, null);
}

test "Q190 direct CSSTransformValue stringification does not abort registration" {
    try constructed("new CSSTransformValue([new CSSTranslate(CSS.px(1), CSS.px(2))])");
}

test "Q190 native CSSRGB retains its routed default" {
    // Nested color-union construction is a routed binding dependency.
    try run(interfaces.CSSRGB, null);
}

test "Q190 native CSSHSL retains its routed default" {
    // Nested color-union construction is a routed binding dependency.
    try run(interfaces.CSSHSL, null);
}

test "Q190 direct CSSHWB retains its routed default" {
    try constructed("new CSSHWB(CSS.deg(0), CSS.percent(0), CSS.percent(0))");
}

test "Q190 native CSSLab retains its routed default" {
    // Nested color-union construction is a routed binding dependency.
    try run(interfaces.CSSLab, null);
}

test "Q190 native CSSLCH retains its routed default" {
    // Nested color-union construction is a routed binding dependency.
    try run(interfaces.CSSLCH, null);
}

test "Q190 native CSSOKLab retains its routed default" {
    // Nested color-union construction is a routed binding dependency.
    try run(interfaces.CSSOKLab, null);
}

test "Q190 native CSSOKLCH retains its routed default" {
    // Nested color-union construction is a routed binding dependency.
    try run(interfaces.CSSOKLCH, null);
}

test "Q190 direct CSSColor retains its routed default" {
    try constructed("new CSSColor('srgb', [0, 0, 0])");
}

test "Q190 a native transform payload keeps its owning serializer" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const rule = new CSSStyleSheet();
        \\rule.replaceSync('div { translate: 2px 3px; }');
        \\const expected = rule.cssRules[0].style.getPropertyValue('translate');
        \\const value = CSSStyleValue.parse('translate', '2px 3px');
        \\if (value.constructor !== CSSStyleValue || String(value) !== expected || expected === '[object]') throw new Error('native serializer');
        \\return 'ok'; })()
    );
}

// Q192 native-only positive integer evidence: Blink b5548ca1190d2e89df6d7c7500799b19b15f81a2
// third_party/blink/renderer/core/css/css_properties.json5, Keyword-only grid lines.
test "Q192 grid-row-start rejects every tested numeric form before mutation" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div { grid-row-start: 2 !important; color: red; }');
        \\const rule = sheet.cssRules[0]; const map = rule.styleMap;
        \\const before = rule.style.cssText;
        \\for (const input of [CSS.number(-3.14), CSS.number(0), CSS.number(3.14), new CSSMathSum(2, 3)]) {
        \\  let error; try { map.set('grid-row-start', input); } catch (e) { error = e; }
        \\  if (!(error instanceof TypeError)) throw new Error('expected TypeError for ' + String(input));
        \\  if (rule.style.cssText !== before) throw new Error('failed set mutated declaration');
        \\}
        \\return 'ok'; })()
    );
}

test "Q192 grid-row-end rejects every tested numeric form before mutation" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div { grid-row-end: 2 !important; color: red; }');
        \\const rule = sheet.cssRules[0]; const map = rule.styleMap;
        \\const before = rule.style.cssText;
        \\for (const input of [CSS.number(-3.14), CSS.number(0), CSS.number(3.14), new CSSMathSum(2, 3)]) {
        \\  let error; try { map.set('grid-row-end', input); } catch (e) { error = e; }
        \\  if (!(error instanceof TypeError)) throw new Error('expected TypeError for ' + String(input));
        \\  if (rule.style.cssText !== before) throw new Error('failed set mutated declaration');
        \\}
        \\return 'ok'; })()
    );
}

test "Q192 grid-column-start rejects every tested numeric form before mutation" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div { grid-column-start: 2 !important; color: red; }');
        \\const rule = sheet.cssRules[0]; const map = rule.styleMap;
        \\const before = rule.style.cssText;
        \\for (const input of [CSS.number(-3.14), CSS.number(0), CSS.number(3.14), new CSSMathSum(2, 3)]) {
        \\  let error; try { map.set('grid-column-start', input); } catch (e) { error = e; }
        \\  if (!(error instanceof TypeError)) throw new Error('expected TypeError for ' + String(input));
        \\  if (rule.style.cssText !== before) throw new Error('failed set mutated declaration');
        \\}
        \\return 'ok'; })()
    );
}

test "Q192 grid-column-end rejects every tested numeric form before mutation" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div { grid-column-end: 2 !important; color: red; }');
        \\const rule = sheet.cssRules[0]; const map = rule.styleMap;
        \\const before = rule.style.cssText;
        \\for (const input of [CSS.number(-3.14), CSS.number(0), CSS.number(3.14), new CSSMathSum(2, 3)]) {
        \\  let error; try { map.set('grid-column-end', input); } catch (e) { error = e; }
        \\  if (!(error instanceof TypeError)) throw new Error('expected TypeError for ' + String(input));
        \\  if (rule.style.cssText !== before) throw new Error('failed set mutated declaration');
        \\}
        \\return 'ok'; })()
    );
}

test "Q192 positive integer follows the pinned Blink Keyword-only types" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\for (const property of ['grid-row-start', 'grid-row-end', 'grid-column-start', 'grid-column-end']) {
        \\  const sheet = new CSSStyleSheet(); sheet.replaceSync('div { ' + property + ': 2; }');
        \\  const map = sheet.cssRules[0].styleMap;
        \\  let error; try { map.set(property, CSS.number(3)); } catch (e) { error = e; }
        \\  if (!(error instanceof TypeError)) throw new Error('Keyword-only native positive integer: ' + property);
        \\}
        \\return 'ok'; })()
    );
}

test "Q192 text opaque and keyword grid lines and other numeric inputs stay accepted" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div {}'); const rule = sheet.cssRules[0]; const map = rule.styleMap;
        \\for (const property of ['grid-row-start', 'grid-row-end', 'grid-column-start', 'grid-column-end']) {
        \\  rule.style.setProperty(property, '3');
        \\  if (rule.style.getPropertyValue(property) !== '3') throw new Error('CSS text integer changed');
        \\  const parsed = CSSStyleValue.parse(property, '3');
        \\  if (parsed.constructor !== CSSStyleValue || String(parsed) !== '3') throw new Error('opaque parsed integer changed');
        \\  map.set(property, parsed); map.set(property, new CSSKeywordValue('auto'));
        \\  if (rule.style.getPropertyValue(property) !== 'auto') throw new Error('keyword rejected');
        \\}
        \\map.set('width', CSS.px(2)); if (rule.style.width !== '2px') throw new Error('unrelated numeric rejected');
        \\map.set('margin', CSS.px(2)); if (rule.style.margin !== '2px') throw new Error('Q36 shorthand changed');
        \\return 'ok'; })()
    );
}

test "Q194 mask-position initial sentinel keeps parsed position shape and association" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const element = d.createElement('div'); d.body.appendChild(element);
        \\const initial = element.computedStyleMap().get('mask-position');
        \\const parsed = CSSStyleValue.parse('mask-position', '0% 0%');
        \\if (initial.constructor !== CSSStyleValue || parsed.constructor !== CSSStyleValue) throw new Error('position must stay opaque');
        \\if (String(initial) !== '0% 0%' || String(parsed) !== String(initial)) throw new Error('initial/parsed serialization differs');
        \\const target = d.createElement('div');
        \\let caught; try { target.attributeStyleMap.append('background-size', initial); } catch (e) { caught = e; }
        \\if (!(caught instanceof TypeError)) throw new Error('lost property association');
        \\target.attributeStyleMap.set('mask-position', initial);
        \\if (target.style.getPropertyValue('mask-position') !== String(initial)) throw new Error('same-property round trip');
        \\const pending = CSSStyleValue.parse('mask-position', 'var(--position)');
        \\if (!(pending instanceof CSSUnparsedValue)) throw new Error('pending priority changed');
        \\return 'ok'; })()
    );
}

test "Q194 object-position initial sentinel keeps parsed position shape and association" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const element = d.createElement('div'); d.body.appendChild(element);
        \\const initial = element.computedStyleMap().get('object-position');
        \\const parsed = CSSStyleValue.parse('object-position', '50% 50%');
        \\if (initial.constructor !== CSSStyleValue || parsed.constructor !== CSSStyleValue) throw new Error('position must stay opaque');
        \\if (String(initial) !== '50% 50%' || String(parsed) !== String(initial)) throw new Error('initial/parsed serialization differs');
        \\const target = d.createElement('div');
        \\let caught; try { target.attributeStyleMap.append('background-size', initial); } catch (e) { caught = e; }
        \\if (!(caught instanceof TypeError)) throw new Error('lost property association');
        \\target.attributeStyleMap.set('object-position', initial);
        \\if (target.style.getPropertyValue('object-position') !== String(initial)) throw new Error('same-property round trip');
        \\const pending = CSSStyleValue.parse('object-position', 'var(--position)');
        \\if (!(pending instanceof CSSUnparsedValue)) throw new Error('pending priority changed');
        \\return 'ok'; })()
    );
}

test "Q194 numeric initial remains a unit value" {
    try run(interfaces.CSSStyleValue,
        \\(() => {
        \\const element = d.createElement('div'); d.body.appendChild(element);
        \\const value = element.computedStyleMap().get('margin-left');
        \\if (!(value instanceof CSSUnitValue) || value.value !== 0 || value.unit !== 'px') throw new Error('numeric initial changed');
        \\return 'ok'; })()
    );
}
