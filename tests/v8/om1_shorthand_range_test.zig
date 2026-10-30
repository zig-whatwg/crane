//! Q198: shorthand numeric admission uses the matched component's range.
//! Chrome 156 and Safari 27 both throw for negative logical border widths.
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
        std.debug.print("om1 shorthand range: {s}\n", .{info.message});
    }
};

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
    const held_document = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis.d = new Document().implementation.createHTMLDocument('om1'); d" }, "", null, .{ .report = Host.report, .host = null });
    defer held_document.release();
    const document = engine.convertToPlatformObject(realm, held_document.value) orelse return error.NoDocument;
    const held_window = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "", null, .{ .report = Host.report, .host = null });
    defer held_window.release();
    const window = engine.convertToPlatformObject(realm, held_window.value) orelse return error.NoWindow;
    dom.document_browsing_context.setWindow(document, window);
    dom.window_globals.setDocument(window, document);
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

fn negativeBorder(comptime property: []const u8) !void {
    try run(
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div { color: red; }');
        \\const rule = sheet.cssRules[0]; const before = rule.style.cssText;
        \\let caught;
    ++ "try { rule.styleMap.set('" ++ property ++ "', CSS.em(-3.14)); } catch (e) { caught = e; }" ++
        \\if (!(caught instanceof TypeError)) throw new Error('negative shorthand unit must throw TypeError');
        \\if (rule.style.cssText !== before) throw new Error('rejected set mutated the declaration');
        \\return 'ok'; })()
    );
}

test "Q198 border-block rejects negative length before mutation" {
    try negativeBorder("border-block");
}
test "Q198 border-block-start rejects negative length before mutation" {
    try negativeBorder("border-block-start");
}
test "Q198 border-block-end rejects negative length before mutation" {
    try negativeBorder("border-block-end");
}
test "Q198 border-inline rejects negative length before mutation" {
    try negativeBorder("border-inline");
}
test "Q198 border-inline-start rejects negative length before mutation" {
    try negativeBorder("border-inline-start");
}
test "Q198 border-inline-end rejects negative length before mutation" {
    try negativeBorder("border-inline-end");
}

test "Q198 margin still accepts a negative length" {
    try run(
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div {}'); const rule = sheet.cssRules[0];
        \\rule.styleMap.set('margin', CSS.em(-3.14));
        \\if (rule.style.getPropertyValue('margin') !== '-3.14em') throw new Error('margin negative length changed');
        \\return 'ok'; })()
    );
}

test "Q198 background still accepts a negative length" {
    try run(
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div {}'); const rule = sheet.cssRules[0];
        \\rule.styleMap.set('background', CSS.em(-3.14));
        \\if (!rule.style.getPropertyValue('background').includes('-3.14em')) throw new Error('background negative length changed');
        \\return 'ok'; })()
    );
}

test "Q198 negative width longhand keeps calculation wrapping" {
    try run(
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div {}'); const rule = sheet.cssRules[0];
        \\rule.styleMap.set('width', CSS.px(-2));
        \\if (rule.style.getPropertyValue('width') !== 'calc(-2px)') throw new Error('longhand wrapping changed');
        \\return 'ok'; })()
    );
}

test "Q200 negative math on a border shorthand keeps calculation semantics" {
    try run(
        \\(() => {
        \\const sheet = new CSSStyleSheet(); sheet.replaceSync('div {}'); const rule = sheet.cssRules[0];
        \\rule.styleMap.set('border-block', new CSSMathSum(CSS.em(-3.14)));
        \\if (rule.style.getPropertyValue('border-block-start-width') !== 'calc(-3.14em)') throw new Error('existing math semantics changed');
        \\return 'ok'; })()
    );
}
