//! The style system through the real binding (lane style1): an element's
//! `style` (CSSStyleProperties) and getComputedStyle()'s object, whose
//! camel-cased and dashed CSS attributes are the V8 adapter's named
//! interceptor for BOTH CSSStyleDeclaration and CSSStyleProperties; the
//! interceptor declines a name that is no CSS property, so `cssText`,
//! `length` and an expando reach the ordinary [[Set]] and [[Get]]. And the
//! style engine (dom.style) over documents script builds: the UA sheet, a
//! <style> element's rules and the style attribute cascade into each
//! element's computed style, cached and resolved again when an input moves.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(r.allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        return openWith(std.heap.c_allocator);
    }

    fn openWith(allocator: std.mem.Allocator) !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn eval(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn answer(self: Page, source: []const u8) ![]u8 {
        var reports: Reports = .{};
        return protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    }

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try self.answer(source);
        defer testing.allocator.free(got);
        testing.expectEqualStrings(expected, got) catch |err| {
            std.debug.print("{s}\n", .{source});
            return err;
        };
    }
};

/// `source` evaluates to an element; its computed `property`, resolved.
fn expectComputed(page: Page, source: []const u8, property: []const u8, expected: []const u8) !void {
    const element = try page.instance(source);
    const style = (try dom.style.computedStyle(element, null)) orelse return error.NoComputedStyle;
    const l = switch (dom.style.css.properties.lookup(property) orelse return error.UnknownProperty) {
        .longhand => |x| x,
        .shorthand => return error.Shorthand,
    };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s} {s}\n", .{ source, property });
        return err;
    };
}

const html_page =
    \\globalThis.d = new Document().implementation.createHTMLDocument('t');
    \\globalThis.div = d.createElement('div');
    \\d.body.appendChild(div);
;

test "element.style: camel-cased and dashed attributes, cssText through the setter, expandos fall through" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    try page.eval("globalThis.s = div.style; s.color = 'RED'; s['margin-left'] = '2px';");
    try page.expect("s.color", "red");
    try page.expect("s.marginLeft", "2px");
    try page.expect("div.getAttribute('style')", "color: red; margin-left: 2px;");
    try page.eval("s.cssText = 'margin: 1px; float: left'");
    try page.expect("s.marginLeft + '|' + s.cssFloat + '|' + s.length", "1px|left|5");
    try page.expect("s.cssText", "margin: 1px; float: left;");
    try page.eval("s.myExpando = 7");
    try page.expect("String(s.myExpando)", "7");
    try page.expect("String(div.getAttribute('style').includes('Expando'))", "false");
    try page.expect("String(s instanceof CSSStyleProperties) + String(s instanceof CSSStyleDeclaration)", "truetrue");
    try page.expect("String(div.style === s)", "true");
}

test "getComputedStyle: the same interceptor, read-only, empty without a browsing context" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    try page.eval("globalThis.cs = getComputedStyle(div);");
    try page.expect("String(cs instanceof CSSStyleProperties)", "true");
    try page.expect("cs.length + '|' + cs.color + '|' + cs.cssText", "0||");
    try page.expect("(() => { try { cs.cssText = 'color: red'; return 'no'; } catch (e) { return e.name; } })()", "NoModificationAllowedError");
    try page.expect("(() => { try { cs.setProperty('color', 'red'); return 'no'; } catch (e) { return e.name; } })()", "NoModificationAllowedError");
    try page.eval("cs.anotherExpando = 1");
    try page.expect("String(cs.anotherExpando)", "1");
}

test "the cascade: the UA sheet, the style attribute, inheritance" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    // A <style> element's sheet is tested through the WPT runner
    // (crane/style1-cascade.html): its load needs an event loop this
    // harness's document has not.
    try page.eval(
        \\globalThis.span = d.createElement('span'); div.appendChild(span);
        \\div.setAttribute('style', 'color: rgb(1, 2, 3); margin-left: 2px');
    );
    try expectComputed(page, "d.documentElement", "display", "block");
    try expectComputed(page, "d.head", "display", "none");
    try expectComputed(page, "div", "display", "block");
    try expectComputed(page, "span", "display", "inline");
    try expectComputed(page, "div", "margin-left", "2px");
    try expectComputed(page, "div", "color", "rgb(1, 2, 3)");
    try expectComputed(page, "span", "color", "rgb(1, 2, 3)");
    try expectComputed(page, "span", "margin-left", "0px");
    try page.eval("span.hidden = true");
    try expectComputed(page, "span", "display", "none");
    try page.eval("div.style.color = 'navy'");
    try expectComputed(page, "span", "color", "rgb(0, 0, 128)");
    try page.eval("div.removeAttribute('style')");
    try expectComputed(page, "span", "color", "rgb(0, 0, 0)");
}

test "a cached style is reused until an input moves" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    const element = try page.instance("div");
    const first = (try dom.style.computedStyle(element, null)).?;
    const again = (try dom.style.computedStyle(element, null)).?;
    try testing.expect(first == again);
    try page.eval("div.setAttribute('data-x', '1')");
    const after = (try dom.style.computedStyle(element, null)).?;
    try testing.expect(after != again);
}

test "a style read marks its document's engine resolving only while it runs (Codex row 61 Q16)" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    const element = try page.instance("div");
    const document = try page.instance("d");
    const engine = dom.style.engine.engineOf(document) orelse return error.NoEngine;
    try testing.expect(!engine.resolving);
    _ = try dom.style.computedStyle(element, null);
    try testing.expect(!engine.resolving);
    _ = try dom.style.computedStyle(element, "before");
    try testing.expect(!engine.resolving);
    _ = try dom.style.isBeingRendered(element);
    try testing.expect(!engine.resolving);
}

test "a sheet script holds outlives its style element's removal and a collection, rules and all" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    try page.eval(
        \\globalThis.style = d.createElement('style');
        \\style.textContent = 'a { color: red } @supports (display: block) { b { color: blue } }';
        \\d.head.appendChild(style);
        \\globalThis.sheet = style.sheet;
        \\globalThis.rules = sheet.cssRules;
        \\globalThis.group = rules[1];
        \\globalThis.inner = group.cssRules[0];
        \\globalThis.decl = rules[0].style;
    );
    try page.expect("String(sheet instanceof CSSStyleSheet) + '|' + String(sheet.ownerNode === style)", "true|true");
    try page.expect("String(d.styleSheets[0] === sheet) + '|' + d.styleSheets.length", "true|1");
    try page.eval("style.remove(); globalThis.style = null;");
    try page.collect();
    try page.expect("String(sheet.ownerNode) + '|' + d.styleSheets.length", "null|0");
    try page.expect("rules.length + '|' + rules[0].cssText", "2|a { color: red; }");
    try page.expect("String(rules[1] === group) + '|' + String(inner.parentRule === group)", "true|true");
    try page.expect("String(inner.parentStyleSheet === sheet) + '|' + inner.cssText", "true|b { color: blue; }");
    try page.expect("decl.color + '|' + String(decl.parentRule === rules[0])", "red|true");
    // Dropping every script reference lets the sheet, its rules and their
    // objects go (the counts are std.testing.allocator's, checked at the
    // end of the test, and leaks --atExit for the C++ side).
    try page.eval("globalThis.sheet = globalThis.rules = globalThis.group = globalThis.inner = globalThis.decl = null;");
    try page.collect();
}

test "a removed rule keeps its data and loses its parents; deleteRule and insertRule edit the list" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    try page.eval(
        \\globalThis.style = d.createElement('style');
        \\style.textContent = 'a { color: red } b { color: blue }';
        \\d.head.appendChild(style);
        \\globalThis.sheet = style.sheet;
        \\globalThis.first = sheet.cssRules[0];
        \\sheet.deleteRule(0);
    );
    try page.collect();
    try page.expect("sheet.cssRules.length + '|' + String(first.parentStyleSheet) + '|' + first.cssText", "1|null|a { color: red; }");
    try page.expect("sheet.insertRule('i { color: green }', 1) + '|' + sheet.cssRules[1].selectorText", "1|i");
    try page.expect("(() => { try { sheet.insertRule('@import url(x.css)', 2); return 'no'; } catch (e) { return e.name; } })()", "HierarchyRequestError");
    try page.expect("(() => { try { sheet.insertRule('{{', 0); return 'no'; } catch (e) { return e.name; } })()", "SyntaxError");
    try page.expect("(() => { try { sheet.deleteRule(9); return 'no'; } catch (e) { return e.name; } })()", "IndexSizeError");
}

/// What an ObservableArray<HTMLDivElement>'s owner steps saw.
const ArraySteps = struct {
    var sets: usize = 0;
    var deletes: usize = 0;
    var last_changed: usize = 0;

    fn isDiv(instance: *runtime.Instance) bool {
        return instance.vtable == &interfaces.HTMLDivElement.vtable;
    }
    fn set(owner: *runtime.Instance, index: usize, value: *runtime.Instance) anyerror!void {
        _ = owner;
        _ = value;
        sets += 1;
        if (index >= 2) return error.NotAllowedError;
    }
    fn delete(owner: *runtime.Instance, index: usize, value: *runtime.Instance) void {
        _ = owner;
        _ = index;
        _ = value;
        deletes += 1;
    }
    fn changed(owner: *runtime.Instance, values: []const *runtime.Instance) void {
        _ = owner;
        last_changed = values.len;
    }
    const hooks: protocol.ObservableArrayHooks = .{ .set_indexed_value = &set, .delete_indexed_value = &delete, .changed = &changed };
};

test "an observable array of platform objects: values converted, the owner's steps run, its backing list read and replaced" {
    dom.style.ua_sheet.build();
    const page = try Page.open();
    defer page.close();
    try page.eval(html_page);
    const owner = try page.instance("d");
    const array = try protocol.createObservableArray(page.realm, .{ .element = .{ .platform_object = &ArraySteps.isDiv }, .hooks = &ArraySteps.hooks, .owner = owner });
    var reports: Reports = .{};
    const global = try protocol.evaluateClassicScript(page.realm, .{ .utf8 = "globalThis" }, "", null, reports.reporter());
    defer global.release();
    try protocol.setProperty(page.realm, global.value, "arr", array);
    try page.eval("globalThis.x = d.createElement('div'); globalThis.y = d.createElement('div'); arr[0] = x; arr[1] = y;");
    try testing.expectEqual(@as(usize, 2), ArraySteps.sets);
    try testing.expectEqual(@as(usize, 2), ArraySteps.last_changed);
    // The element type's conversion: a TypeError, the owner's steps not run.
    try page.expect("(() => { try { arr[2] = d.createElement('span'); return 'no'; } catch (e) { return e.name; } })()", "TypeError");
    try page.expect("(() => { try { arr[2] = 1; return 'no'; } catch (e) { return e.name; } })()", "TypeError");
    try testing.expectEqual(@as(usize, 2), ArraySteps.sets);
    // A set step's error throws its DOMException and stores nothing.
    try page.expect("(() => { try { arr[2] = d.createElement('div'); return 'no'; } catch (e) { return e.name; } })() + '|' + arr.length", "NotAllowedError|2");
    // Replacing an index deletes the old value first.
    try page.eval("arr[0] = y;");
    try testing.expectEqual(@as(usize, 1), ArraySteps.deletes);

    var items: std.ArrayList(*runtime.Instance) = .empty;
    defer items.deinit(testing.allocator);
    try protocol.observableArrayItems(array, testing.allocator, &items);
    try testing.expectEqual(@as(usize, 2), items.items.len);
    try testing.expect(items.items[0] == try page.instance("y"));

    // Deleting: at the end only.
    try page.expect("String(Reflect.deleteProperty(arr, 0)) + '|' + String(delete arr[1]) + '|' + arr.length", "false|true|1");
    try testing.expectEqual(@as(usize, 1), ArraySteps.last_changed);
    // The attribute setter's replacement, with values the binding made.
    const x_value = try protocol.evaluateClassicScript(page.realm, .{ .utf8 = "x" }, "", null, reports.reporter());
    defer x_value.release();
    try protocol.replaceObservableArrayItems(array, &.{ x_value.value, x_value.value });
    try page.expect("arr.length + '|' + String(arr[1] === x)", "2|true");
    try testing.expectEqual(@as(usize, 2), ArraySteps.last_changed);
    try page.eval("arr.length = 0;");
    try testing.expectEqual(@as(usize, 0), ArraySteps.last_changed);
    try testing.expectEqual(@as(usize, 0), reports.count);
}

// Rendering and delegated rendering share one ancestor check. Each node
// remains rooted in script for this synchronous native observation.
fn renderingAndDelegation() !void {
    const page = try Page.openWith(testing.allocator);
    defer page.close();
    try page.eval(html_page);
    const document = try page.instance("d");
    const window = try page.instance("globalThis");
    dom.document_browsing_context.setWindow(document, window);
    try page.eval(
        \\div.innerHTML = '<div id="plain"></div>' +
        \\  '<div id="none" style="display:none"></div>' +
        \\  '<div style="display:none"><div id="ancestor"></div></div>' +
        \\  '<div id="contents" style="display:contents"><span></span></div>' +
        \\  '<div style="display:none"><div id="hidden-contents" style="display:contents"><span></span></div></div>';
    );
    const cases = [_]struct { id: []const u8, rendered: bool, delegating: bool }{
        .{ .id = "plain", .rendered = true, .delegating = true },
        .{ .id = "none", .rendered = false, .delegating = false },
        .{ .id = "ancestor", .rendered = false, .delegating = false },
        .{ .id = "contents", .rendered = false, .delegating = true },
        .{ .id = "hidden-contents", .rendered = false, .delegating = false },
    };
    for (cases) |case| {
        const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(case.id))).?;
        testing.expectEqual(case.rendered, try dom.style.isBeingRendered(element)) catch |err| {
            std.debug.print("rendered case: {s}\n", .{case.id});
            return err;
        };
        testing.expectEqual(case.delegating, try dom.style.engine.isBeingRenderedOrDelegating(element)) catch |err| {
            std.debug.print("delegating case: {s}\n", .{case.id});
            return err;
        };
    }
}

test "rendering and delegated rendering both reject a hidden flat-tree ancestor" {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            renderingAndDelegation() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
