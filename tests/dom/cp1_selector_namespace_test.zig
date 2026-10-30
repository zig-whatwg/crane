//! CSS Namespaces 3: sheet-scoped parsing, ownership and real support checks.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = dom.style.css;
const rules = dom.style.rules;

fn retained(a: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(a, "@namespace svg 'http://www.w3.org/2000/svg'; @namespace 'urn:default'; svg|a[svg|href=x], .ordinary { color: red }", .{});
    var owns = true;
    defer if (owns) record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    try std.testing.expectEqual(@as(usize, 3), list.items.len);
    const rule = list.items[2];
    rule.ref();
    defer rule.unref();
    record.detach();
    record.unref();
    owns = false;
    try std.testing.expect(rule.parent_sheet == null);
    const ast = &rule.data.style.selectors;
    try std.testing.expectEqualStrings("http://www.w3.org/2000/svg", ast.selectors[0].compound.simple_selectors[1].NamespaceURI.uri);
    try std.testing.expectEqualStrings("http://www.w3.org/2000/svg", ast.selectors[0].compound.simple_selectors[2].NamespacedAttribute.uri);
    try std.testing.expectEqualStrings("urn:default", ast.selectors[1].compound.simple_selectors[0].NamespaceURI.uri);
}

test "a retained CSS rule owns its namespace URIs after sheet release" {
    try retained(std.testing.allocator);
}

test "namespaced stylesheet parsing and detachment unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, retained, .{});
}

test "real if supports selector uses its consuming declaration's namespace map" {
    const a = std.testing.allocator;
    for ([_][]const u8{
        "@namespace svg 'http://www.w3.org/2000/svg'; *|a { width: if(supports(selector(svg|a)): 10px; else: 20px) }",
        "*|a { width: if(supports(selector(svg|a)): 10px; else: 20px) }",
    }, 0..) |text, i| {
        const record = try dom.style.SheetRecord.create(a, text, .{});
        defer record.unref();
        const list = try record.rulesWith(.{ .allocator = a });
        const block = list.items[list.items.len - 1].block().?;
        const style = try css.cascade.cascade(.{ .allocator = a, .parent = null, .selector_check = &rules.selectorSupported }, &.{.{ .block = block, .source = .{ .origin = .author } }});
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(a);
        try style.serializeResolved(.width, &out, a);
        try std.testing.expectEqualStrings(if (i == 0) "10px" else "20px", out.items);
    }
}

fn featureless() !void {
    const a = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(a, &ctx);
    var shadow: ?*runtime.Instance = null;
    defer if (shadow) |root| interfaces.ShadowRoot.deinit(root);
    // The host severs its shadow link before the separately owned root dies.
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const host = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(document, host);
    shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    try dom.node_document.set(shadow.?, document);
    const map = try css.namespace_map.NamespaceMap.create(a, &.{}, "urn:not-html");
    defer map.release();
    var reads: dom.selector_matching.StateReads = .{};
    var matcher = dom.selector_matching.StyleMatcher.initForHost(host, shadow.?, &reads).?;
    // Regression pins: without namespace resolution the first two already
    // match. Adding an implicit URI constraint must not take that away.
    for ([_][]const u8{ ":host", ":is(:host)", "*:host", "div:host", "[id]:host" }, 0..) |text, i| {
        var ast = try rules.parseSelector(a, text, map);
        defer ast.deinit();
        try std.testing.expectEqual(i < 2, matcher.matchesHost(host, &ast.selectors[0], null));
    }
}

test "an implicit default namespace never excludes an otherwise matching featureless host" {
    const Run = struct {
        fn call(result: *?anyerror) void {
            featureless() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.call, .{&result});
    thread.join();
    if (result) |err| return err;
}
