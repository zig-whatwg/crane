//! Typed OM property maps and reification; liaison Q57/Q58/Q60/Q62/Q64.
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
        std.debug.print("om1 property map script: {s}\n", .{info.message});
    }
};

fn script(realm: runtime.Context, source: []const u8) !engine.Owned {
    return engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, .{ .report = Host.report, .host = null });
}

fn check(source: []const u8, inspect_snapshot: bool) !void {
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
    if (inspect_snapshot) {
        if (comptime !@hasDecl(dom.style, "typed_om")) return std.testing.expect(false);
        if (comptime !@hasDecl(dom.style.typed_om, "mapEntries")) return std.testing.expect(false);
        const held_map = try script(realm, "m");
        var map_owned = true;
        defer if (map_owned) held_map.release();
        const map = engine.convertToPlatformObject(realm, held_map.value) orelse return error.NoMap;
        var snapshot = try dom.style.typed_om.mapEntries(map);
        defer snapshot.deinit();
        try std.testing.expectEqual(@as(usize, 3), snapshot.entries.items.len);
        const clear = try script(realm, "m.clear(); globalThis.m = null; el.remove(); globalThis.el = null;");
        clear.release();
        held_map.release();
        map_owned = false;
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try engine.runInRealm(realm, Collect.steps, agent);
        try engine.runInRealm(realm, Collect.steps, agent);
        const names = [_][]const u8{ "--A", "width", "transition-duration" };
        const values = [_][]const []const u8{ &.{"A"}, &.{"10px"}, &.{ "1s", "2s" } };
        for (snapshot.entries.items, names, values) |entry, name, expected| {
            try std.testing.expectEqualStrings(name, entry.name);
            try std.testing.expectEqual(expected.len, entry.value.len);
            for (entry.value, expected) |value, text| {
                const serialized = try interfaces.CSSStyleValue.serialize(value);
                defer value.ctx.allocator.free(serialized);
                try std.testing.expectEqualStrings(text, serialized);
            }
        }
    }
}

fn run(source: []const u8) !void {
    return runWithSnapshot(source, false);
}

fn runWithSnapshot(source: []const u8, inspect_snapshot: bool) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void, text: []const u8, inspect: bool) void {
            out.* = check(text, inspect);
        }
    }.body, .{ &result, source, inspect_snapshot });
    thread.join();
    try result;
}

test "Typed OM property names reject bare dashes but accept nonempty custom names with spaces" {
    try run(
        \\(() => {
        \\const m = el.attributeStyleMap;
        \\for (const name of ['--', 'not-a-property']) {
        \\  typeError(() => CSSStyleValue.parse(name, 'x'), 'parse ' + name);
        \\  typeError(() => CSSStyleValue.parseAll(name, 'x'), 'parseAll ' + name);
        \\  typeError(() => m.set(name, 'x'), 'set ' + name);
        \\  for (const method of ['get', 'getAll', 'has', 'delete']) typeError(() => m[method](name), method + ' ' + name);
        \\}
        \\for (const name of ['--x y', '-- ']) {
        \\  const parsed = CSSStyleValue.parse(name, 'x');
        \\  check(parsed instanceof CSSUnparsedValue && String(parsed) === 'x', 'custom parse ' + name);
        \\  m.set(name, parsed);
        \\  check(String(m.get(name)) === 'x' && m.getAll(name).length === 1 && m.has(name), 'custom map ' + name);
        \\  check(el.style.getPropertyValue(name) === 'x', 'CSSOM custom spelling ' + name);
        \\  m.delete(name); check(!m.has(name), 'custom delete ' + name);
        \\}
        \\check(el.computedStyleMap().get('--unset') === undefined, 'unset computed custom');
        \\return 'ok'; })()
    );
}

test "Typed OM list writes preserve order and priority on failure and clear priority on success" {
    try run(
        \\(() => {
        \\const m = el.attributeStyleMap;
        \\el.style.cssText = 'color: red; animation-duration: 4s !important; width: 5px';
        \\const before = el.style.cssText;
        \\typeError(() => m.set('animation-duration'), 'zero set');
        \\check(el.style.cssText === before, 'zero set mutation');
        \\m.append('animation-duration'); check(el.style.cssText === before, 'zero append mutation');
        \\typeError(() => m.set('animation-duration', CSS.px(3)), 'invalid unit');
        \\check(el.style.cssText === before, 'invalid set mutation');
        \\m.set('animation-duration', '1s, 2s', CSS.s(3));
        \\check(el.style.getPropertyValue('animation-duration') === '1s, 2s, 3s', 'all string list items');
        \\check(el.style.getPropertyPriority('animation-duration') === '', 'set clears priority');
        \\check(el.style.item(0) === 'color' && el.style.item(1) === 'animation-duration' && el.style.item(2) === 'width', 'set order');
        \\el.style.setProperty('animation-duration', '1s', 'important');
        \\m.append('animation-duration', '2s, 3s');
        \\check(el.style.getPropertyValue('animation-duration') === '1s, 2s, 3s', 'append all string list items');
        \\check(el.style.getPropertyPriority('animation-duration') === '', 'append clears priority');
        \\check(el.style.item(1) === 'animation-duration', 'append order');
        \\const valid = el.style.cssText;
        \\typeError(() => m.set('animation-duration', 'inherit', CSS.s(2)), 'mixed CSS-wide');
        \\typeError(() => m.append('animation-duration', 'inherit'), 'append CSS-wide');
        \\check(el.style.cssText === valid, 'CSS-wide rollback');
        \\m.set('animation-duration', 'inherit');
        \\check(String(m.get('animation-duration')) === 'inherit', 'single CSS-wide');
        \\return 'ok'; })()
    );
}

test "Typed OM parse and map agree on Q60 singleton matrix with Q62 background size amendment" {
    try run(
        \\(() => {
        \\const cases = [
        \\ ['align-content','space-between','CSSKeywordValue','space-between'],
        \\ ['align-items','first baseline','CSSKeywordValue','baseline'],
        \\ ['align-items','safe center','CSSStyleValue','safe center'],
        \\ ['display','inline flow-root','CSSKeywordValue','inline-block'],
        \\ ['display','block ruby','CSSStyleValue','block ruby'],
        \\ ['display','flex','CSSKeywordValue','flex'],
        \\ ['background-size','10px','CSSStyleValue','10px auto'],
        \\ ['background-size','10px auto','CSSStyleValue','10px auto'],
        \\ ['background-size','10px 20px','CSSStyleValue','10px 20px'],
        \\ ['border-top-left-radius','10px','CSSUnitValue','10px'],
        \\ ['border-top-left-radius','10px 10px','CSSUnitValue','10px'],
        \\ ['border-top-left-radius','10px 20px','CSSStyleValue','10px 20px'],
        \\ ['grid-row-start','foo','CSSKeywordValue','foo'],
        \\ ['grid-row-start','2','CSSStyleValue','2'],
        \\ ['grid-row-start','span 2','CSSStyleValue','span 2'],
        \\ ['grid-auto-flow','row','CSSKeywordValue','row'],
        \\ ['grid-auto-flow','row dense','CSSKeywordValue','dense'],
        \\ ['contain','layout','CSSKeywordValue','layout'],
        \\ ['contain','strict','CSSKeywordValue','strict'],
        \\ ['contain','layout paint','CSSStyleValue','layout paint'],
        \\ ['font-family','serif','CSSStyleValue','serif'],
        \\ ['text-transform','uppercase','CSSKeywordValue','uppercase'],
        \\ ['text-transform','uppercase full-width','CSSStyleValue','uppercase full-width'],
        \\ ['color','currentcolor','CSSKeywordValue','currentcolor'],
        \\ ['color','red','CSSStyleValue','red'],
        \\ ['font-weight','normal','CSSKeywordValue','normal'],
        \\ ['font-weight','700','CSSUnitValue','700']
        \\];
        \\for (const [p, input, className, text] of cases) {
        \\  el.style.cssText = ''; el.style.setProperty(p, input);
        \\  for (const value of [CSSStyleValue.parse(p, input), el.attributeStyleMap.get(p)]) {
        \\    check(value.constructor === globalThis[className], p + ':' + input + ' class');
        \\    check(String(value) === text, p + ':' + input + ' text ' + String(value));
        \\  }
        \\}
        \\return 'ok'; })()
    );
}

test "Typed OM computed maps are live and same object with computed native reification" {
    try run(
        \\(() => {
        \\const map = el.computedStyleMap();
        \\check(map === el.computedStyleMap(), 'SameObject');
        \\el.style.fontWeight = 'normal'; el.style.color = 'currentcolor';
        \\const weight = map.get('font-weight');
        \\check(weight instanceof CSSUnitValue && weight.unit === 'number' && weight.value === 400, 'computed font weight');
        \\const color = map.get('color');
        \\check(color.constructor === CSSStyleValue && String(color) === 'rgb(0, 0, 0)', 'computed color');
        \\el.style.width = '19px'; check(map.get('width').value === 19, 'live width');
        \\el.remove(); check(map.get('width') === undefined && map.size === 0, 'disconnected');
        \\d.body.appendChild(el); check(map.get('width').value === 19, 'reattached');
        \\return 'ok'; })()
    );
}

test "Typed OM opaque values own native data and pending values retain nested references" {
    try run(
        \\(() => {
        \\el.style.fontFamily = 'serif';
        \\const value = el.attributeStyleMap.get('font-family');
        \\el.style.cssText = ''; check(String(value) === 'serif', 'opaque owns native data');
        \\typeError(() => el.attributeStyleMap.set('color', value), 'opaque cross property');
        \\el.attributeStyleMap.set('font-family', value); check(el.style.fontFamily === 'serif', 'opaque original property');
        \\const pending = CSSStyleValue.parse('width', 'var(--x, var(--y, 2px))');
        \\check(pending instanceof CSSUnparsedValue, 'pending class');
        \\check(pending[0] instanceof CSSVariableReferenceValue && pending[0].variable === '--x', 'outer var');
        \\check(Array.from(pending[0].fallback).some(x => x instanceof CSSVariableReferenceValue && x.variable === '--y'), 'inner var');
        \\el.attributeStyleMap.set('width', pending);
        \\check(String(el.attributeStyleMap.get('width')) === String(pending), 'pending round trip');
        \\return 'ok'; })()
    );
}

test "KNOWN-INCOMPLETE Q32 transform and position subclasses retain an explicit base-value fallback" {
    try run(
        \\(() => {
        \\for (const [p, text] of [['transform','translateX(2px)'], ['object-position','10px 20px']]) {
        \\  const value = CSSStyleValue.parse(p, text);
        \\  check(value.constructor === CSSStyleValue && String(value) === text, p + ' routed fallback');
        \\}
        \\return 'ok'; })()
    );
}

test "Typed OM rejects empty strings but accepts empty custom values with zero segments Q65" {
    try run(
        \\(() => {
        \\const m = el.attributeStyleMap;
        \\for (const text of ['', ' ', '\t\n ']) {
        \\  typeError(() => CSSStyleValue.parse('--foo', text), 'empty parse');
        \\  typeError(() => CSSStyleValue.parseAll('--foo', text), 'empty parseAll');
        \\  typeError(() => m.set('--foo', text), 'empty string set');
        \\  check(!m.has('--foo'), 'empty string mutation');
        \\}
        \\el.setAttribute('style', '--foo:');
        \\check(m.has('--foo') && m.get('--foo').length === 0 && String(m.get('--foo')) === '', 'empty declaration');
        \\for (const segments of [[], ['']]) {
        \\  const input = new CSSUnparsedValue(segments);
        \\  check(input.length === segments.length, 'constructor does not normalize');
        \\  m.set('--foo', input);
        \\  check(m.has('--foo') && m.getAll('--foo').length === 1, 'empty value exists');
        \\  check(m.get('--foo').length === 0 && String(m.get('--foo')) === '', 'empty value normalization');
        \\  check(el.getAttribute('style') === '--foo: ;', 'empty attribute serialization');
        \\  check(el.style.getPropertyValue('--foo') === ' ', 'Q67 current spec empty CSSOM value');
        \\}
        \\el.style.setProperty('--foo', '');
        \\check(!m.has('--foo') && m.get('--foo') === undefined, 'CSSOM empty string removes');
        \\return 'ok'; })()
    );
}

test "Typed OM native iterable source owns ordered names and sequence values until conversion completes Q25" {
    try runWithSnapshot(
        \\(() => {
        \\el.style.cssText = '--A: A; width: 10px; transition-duration: 1s, 2s';
        \\globalThis.m = el.attributeStyleMap;
        \\return 'ok'; })()
    , true);
}

test "Typed OM shadows fallback lists and anchor name lists remain whole values Q68 Q69" {
    try run(
        \\(() => {
        \\for (const [p, input] of [
        \\ ['box-shadow', '1px 1px red, 2px 2px blue'],
        \\ ['text-shadow', '1px 1px red, 2px 2px blue'],
        \\ ['position-try-fallbacks', '--a, --b'],
        \\ ['anchor-name', '--a, --b'],
        \\ ['anchor-scope', '--a, --b']]) {
        \\  el.style.cssText = ''; el.style.setProperty(p, input);
        \\  for (const values of [CSSStyleValue.parseAll(p, input), el.attributeStyleMap.getAll(p), el.computedStyleMap().getAll(p)]) {
        \\    check(values.length === 1 && values[0].constructor === CSSStyleValue, p + ' whole value');
        \\  }
        \\  typeError(() => el.attributeStyleMap.append(p, input), p + ' append');
        \\}
        \\for (const p of ['anchor-name', 'anchor-scope']) {
        \\  for (const input of ['--AbC', '--a\\ b']) {
        \\    const value = CSSStyleValue.parse(p, input);
        \\    check(value instanceof CSSKeywordValue && String(value) === input, p + ' singleton');
        \\  }
        \\  check(CSSStyleValue.parse(p, 'none') instanceof CSSKeywordValue, p + ' none');
        \\}
        \\check(CSSStyleValue.parse('anchor-scope', 'all') instanceof CSSKeywordValue, 'scope all');
        \\return 'ok'; })()
    );
}

// Append to granted tests/v8/om1_typed_maps_test.zig after its measured cases.
// Q86 Chrome156/Firefox158/Safari27 probe,2026-10-27. UNMEASURED.

test "Q86 page child absent computes auto" {
    try run(
        \\(() => {
        \\const parent = d.createElement('div'); d.body.appendChild(parent); parent.appendChild(el);
        \\parent.style.setProperty('page', 'Foo');
        \\el.style.setProperty('page', "");
        \\check(getComputedStyle(el).getPropertyValue('page') === "auto", 'computed page');
        \\const read = el.computedStyleMap().get('page');
        \\check(read instanceof CSSKeywordValue && read.value === "auto", 'computed typed keyword');
        \\return 'ok'; })()
    );
}

test "Q86 page child auto computes auto" {
    try run(
        \\(() => {
        \\const parent = d.createElement('div'); d.body.appendChild(parent); parent.appendChild(el);
        \\parent.style.setProperty('page', 'Foo');
        \\el.style.setProperty('page', "auto");
        \\check(getComputedStyle(el).getPropertyValue('page') === "auto", 'computed page');
        \\const read = el.computedStyleMap().get('page');
        \\check(read instanceof CSSKeywordValue && read.value === "auto", 'computed typed keyword');
        \\return 'ok'; })()
    );
}

test "Q86 page child inherit computes Foo" {
    try run(
        \\(() => {
        \\const parent = d.createElement('div'); d.body.appendChild(parent); parent.appendChild(el);
        \\parent.style.setProperty('page', 'Foo');
        \\el.style.setProperty('page', "inherit");
        \\check(getComputedStyle(el).getPropertyValue('page') === "Foo", 'computed page');
        \\const read = el.computedStyleMap().get('page');
        \\check(read instanceof CSSKeywordValue && read.value === "Foo", 'computed typed keyword');
        \\return 'ok'; })()
    );
}

test "Q86 page child unset computes auto" {
    try run(
        \\(() => {
        \\const parent = d.createElement('div'); d.body.appendChild(parent); parent.appendChild(el);
        \\parent.style.setProperty('page', 'Foo');
        \\el.style.setProperty('page', "unset");
        \\check(getComputedStyle(el).getPropertyValue('page') === "auto", 'computed page');
        \\const read = el.computedStyleMap().get('page');
        \\check(read instanceof CSSKeywordValue && read.value === "auto", 'computed typed keyword');
        \\return 'ok'; })()
    );
}

test "Q86 page child initial computes auto" {
    try run(
        \\(() => {
        \\const parent = d.createElement('div'); d.body.appendChild(parent); parent.appendChild(el);
        \\parent.style.setProperty('page', 'Foo');
        \\el.style.setProperty('page', "initial");
        \\check(getComputedStyle(el).getPropertyValue('page') === "auto", 'computed page');
        \\const read = el.computedStyleMap().get('page');
        \\check(read instanceof CSSKeywordValue && read.value === "auto", 'computed typed keyword');
        \\return 'ok'; })()
    );
}

test "Q86 page child Bar computes Bar" {
    try run(
        \\(() => {
        \\const parent = d.createElement('div'); d.body.appendChild(parent); parent.appendChild(el);
        \\parent.style.setProperty('page', 'Foo');
        \\el.style.setProperty('page', "Bar");
        \\check(getComputedStyle(el).getPropertyValue('page') === "Bar", 'computed page');
        \\const read = el.computedStyleMap().get('page');
        \\check(read instanceof CSSKeywordValue && read.value === "Bar", 'computed typed keyword');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps auto" {
    try run(
        \\(() => {
        \\const source = "auto", specified = "auto", value = "auto";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps AUTO" {
    try run(
        \\(() => {
        \\const source = "AUTO", specified = "auto", value = "auto";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps Foo" {
    try run(
        \\(() => {
        \\const source = "Foo", specified = "Foo", value = "Foo";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps FOO" {
    try run(
        \\(() => {
        \\const source = "FOO", specified = "FOO", value = "FOO";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps f\\6f o" {
    try run(
        \\(() => {
        \\const source = "f\\6f o", specified = "foo", value = "foo";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps \\31 23" {
    try run(
        \\(() => {
        \\const source = "\\31 23", specified = "\\31 23", value = "123";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

test "Q86 page keyword parse and maps a\\ b" {
    try run(
        \\(() => {
        \\const source = "a\\ b", specified = "a\\ b", value = "a b";
        \\const parsed = CSSStyleValue.parse('page', source);
        \\check(parsed instanceof CSSKeywordValue && parsed.value === value && String(parsed) === specified, 'parsed keyword');
        \\el.attributeStyleMap.set('page', parsed);
        \\check(el.style.getPropertyValue('page') === specified, 'specified CSS');
        \\for (const read of [el.attributeStyleMap.get('page'), el.computedStyleMap().get('page')])
        \\  check(read instanceof CSSKeywordValue && read.value === value && String(read) === specified, 'reified keyword');
        \\check(getComputedStyle(el).getPropertyValue('page') === specified, 'computed CSS');
        \\return 'ok'; })()
    );
}

// Q87/Q88: append to the granted native map family. UNMEASURED.

test "Q87 image classes url(a.png)" {
    try run(
        \\(() => {
        \\const source = "url(a.png)";
        \\el.style.setProperty('color-scheme', 'light');
        \\el.style.setProperty('background-image', source);
        \\const specified = el.style.getPropertyValue('background-image');
        \\check(specified !== '', 'ordinary parser supports the image');
        \\const parsed = CSSStyleValue.parse('background-image', source);
        \\const read = el.attributeStyleMap.get('background-image');
        \\check(parsed.constructor === CSSImageValue && read.constructor === CSSImageValue, 'specified class');
        \\check(String(parsed) === specified && String(read) === specified, 'normalized owner serialization');
        \\const resolved = el.computedStyleMap().get('background-image');
        \\check(resolved.constructor === CSSImageValue, 'computed class');
        \\check(String(resolved) === getComputedStyle(el).getPropertyValue('background-image'), 'computed owner serialization');
        \\return 'ok'; })()
    );
}

test "Q87 image classes linear-gradient(red,blue)" {
    try run(
        \\(() => {
        \\const source = "linear-gradient(red,blue)";
        \\el.style.setProperty('color-scheme', 'light');
        \\el.style.setProperty('background-image', source);
        \\const specified = el.style.getPropertyValue('background-image');
        \\check(specified !== '', 'ordinary parser supports the image');
        \\const parsed = CSSStyleValue.parse('background-image', source);
        \\const read = el.attributeStyleMap.get('background-image');
        \\check(parsed.constructor === CSSStyleValue && read.constructor === CSSStyleValue, 'specified class');
        \\check(String(parsed) === specified && String(read) === specified, 'normalized owner serialization');
        \\const resolved = el.computedStyleMap().get('background-image');
        \\check(resolved.constructor === CSSStyleValue, 'computed class');
        \\check(String(resolved) === getComputedStyle(el).getPropertyValue('background-image'), 'computed owner serialization');
        \\return 'ok'; })()
    );
}

test "Q87 image classes image-set(url(a.png) 1x)" {
    try run(
        \\(() => {
        \\const source = "image-set(url(a.png) 1x)";
        \\el.style.setProperty('color-scheme', 'light');
        \\el.style.setProperty('background-image', source);
        \\const specified = el.style.getPropertyValue('background-image');
        \\check(specified !== '', 'ordinary parser supports the image');
        \\const parsed = CSSStyleValue.parse('background-image', source);
        \\const read = el.attributeStyleMap.get('background-image');
        \\check(parsed.constructor === CSSStyleValue && read.constructor === CSSStyleValue, 'specified class');
        \\check(String(parsed) === specified && String(read) === specified, 'normalized owner serialization');
        \\const resolved = el.computedStyleMap().get('background-image');
        \\check(resolved.constructor === CSSStyleValue, 'computed class');
        \\check(String(resolved) === getComputedStyle(el).getPropertyValue('background-image'), 'computed owner serialization');
        \\return 'ok'; })()
    );
}

test "Q87 image classes light-dark(url(a.png),url(b.png))" {
    try run(
        \\(() => {
        \\const source = "light-dark(url(a.png),url(b.png))";
        \\el.style.setProperty('color-scheme', 'light');
        \\el.style.setProperty('background-image', source);
        \\const specified = el.style.getPropertyValue('background-image');
        \\check(specified !== '', 'ordinary parser supports the image');
        \\const parsed = CSSStyleValue.parse('background-image', source);
        \\const read = el.attributeStyleMap.get('background-image');
        \\check(parsed.constructor === CSSStyleValue && read.constructor === CSSStyleValue, 'specified class');
        \\check(String(parsed) === specified && String(read) === specified, 'normalized owner serialization');
        \\const resolved = el.computedStyleMap().get('background-image');
        \\check(resolved.constructor === CSSImageValue, 'computed class');
        \\check(String(resolved) === getComputedStyle(el).getPropertyValue('background-image'), 'computed owner serialization');
        \\return 'ok'; })()
    );
}

test "Q87 image classes none" {
    try run(
        \\(() => {
        \\const source = "none";
        \\el.style.setProperty('color-scheme', 'light');
        \\el.style.setProperty('background-image', source);
        \\const specified = el.style.getPropertyValue('background-image');
        \\check(specified !== '', 'ordinary parser supports the image');
        \\const parsed = CSSStyleValue.parse('background-image', source);
        \\const read = el.attributeStyleMap.get('background-image');
        \\check(parsed.constructor === CSSKeywordValue && read.constructor === CSSKeywordValue, 'specified class');
        \\check(String(parsed) === specified && String(read) === specified, 'normalized owner serialization');
        \\const resolved = el.computedStyleMap().get('background-image');
        \\check(resolved.constructor === CSSKeywordValue, 'computed class');
        \\check(String(resolved) === getComputedStyle(el).getPropertyValue('background-image'), 'computed owner serialization');
        \\return 'ok'; })()
    );
}

test "Q87 URL image assignment to background-image" {
    try run(
        \\(() => {
        \\const value = CSSStyleValue.parse('background-image', 'url(a.png)');
        \\check(value instanceof CSSImageValue, 'URL image');
        \\el.style.cssText = 'width: 5px !important';
        \\const before = el.style.cssText;
        \\el.attributeStyleMap.set("background-image", value);
        \\check(el.style.getPropertyValue("background-image") === 'url("a.png")', 'specified URL');
        \\const read = el.attributeStyleMap.get("background-image");
        \\check(read instanceof CSSImageValue && String(read) === 'url("a.png")', 'reified URL');
        \\return 'ok'; })()
    );
}

test "Q87 URL image assignment to list-style-image" {
    try run(
        \\(() => {
        \\const value = CSSStyleValue.parse('background-image', 'url(a.png)');
        \\check(value instanceof CSSImageValue, 'URL image');
        \\el.style.cssText = 'width: 5px !important';
        \\const before = el.style.cssText;
        \\el.attributeStyleMap.set("list-style-image", value);
        \\check(el.style.getPropertyValue("list-style-image") === 'url("a.png")', 'specified URL');
        \\const read = el.attributeStyleMap.get("list-style-image");
        \\check(read instanceof CSSImageValue && String(read) === 'url("a.png")', 'reified URL');
        \\return 'ok'; })()
    );
}

test "Q87 URL image assignment to border-image-source" {
    try run(
        \\(() => {
        \\const value = CSSStyleValue.parse('background-image', 'url(a.png)');
        \\check(value instanceof CSSImageValue, 'URL image');
        \\el.style.cssText = 'width: 5px !important';
        \\const before = el.style.cssText;
        \\el.attributeStyleMap.set("border-image-source", value);
        \\check(el.style.getPropertyValue("border-image-source") === 'url("a.png")', 'specified URL');
        \\const read = el.attributeStyleMap.get("border-image-source");
        \\check(read instanceof CSSImageValue && String(read) === 'url("a.png")', 'reified URL');
        \\return 'ok'; })()
    );
}

test "Q87 URL image assignment to mask-image" {
    try run(
        \\(() => {
        \\const value = CSSStyleValue.parse('background-image', 'url(a.png)');
        \\check(value instanceof CSSImageValue, 'URL image');
        \\el.style.cssText = 'width: 5px !important';
        \\const before = el.style.cssText;
        \\el.attributeStyleMap.set("mask-image", value);
        \\check(el.style.getPropertyValue("mask-image") === 'url("a.png")', 'specified URL');
        \\const read = el.attributeStyleMap.get("mask-image");
        \\check(read instanceof CSSImageValue && String(read) === 'url("a.png")', 'reified URL');
        \\return 'ok'; })()
    );
}

test "Q87 URL image assignment to content" {
    try run(
        \\(() => {
        \\const value = CSSStyleValue.parse('background-image', 'url(a.png)');
        \\check(value instanceof CSSImageValue, 'URL image');
        \\el.style.cssText = 'width: 5px !important';
        \\const before = el.style.cssText;
        \\el.attributeStyleMap.set("content", value);
        \\check(el.style.getPropertyValue("content") === 'url("a.png")', 'specified URL');
        \\const read = el.attributeStyleMap.get("content");
        \\check(read instanceof CSSImageValue && String(read) === 'url("a.png")', 'reified URL');
        \\return 'ok'; })()
    );
}

test "Q87 URL image assignment to cursor" {
    try run(
        \\(() => {
        \\const value = CSSStyleValue.parse('background-image', 'url(a.png)');
        \\check(value instanceof CSSImageValue, 'URL image');
        \\el.style.cssText = 'width: 5px !important';
        \\const before = el.style.cssText;
        \\typeError(() => el.attributeStyleMap.set('cursor', value), 'cursor fallback required');
        \\check(el.style.cssText === before, 'rollback');
        \\return 'ok'; })()
    );
}

test "Q87 content URL image can be assigned back to an image property" {
    try run(
        \\(() => {
        \\el.attributeStyleMap.set('content', CSSStyleValue.parse('background-image', 'url(a.png)'));
        \\const value = el.attributeStyleMap.get('content');
        \\el.style.removeProperty('content');
        \\el.attributeStyleMap.set('border-image-source', value);
        \\check(el.style.getPropertyValue('border-image-source') === 'url("a.png")', 'retained native image');
        \\return 'ok'; })()
    );
}
