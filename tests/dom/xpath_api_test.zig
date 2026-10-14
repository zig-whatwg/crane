//! XPath is tested through the generated interfaces, without a JavaScript engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const a = std.testing.allocator;

test "XPath compiled grammar releases native allocations on success and syntax errors" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const evaluator = try interfaces.XPathEvaluator.init(a, &ctx);
    defer interfaces.XPathEvaluator.deinit(evaluator);
    for ([_][]const u8{ "1 + 2 * 3", "//div[@id='x'][1]", "preceding-sibling::*[last()]", "substring('12345', 1.5, 2.6)", "(//x | //y)[1]", "processing-instruction('target')" }) |text| {
        const expression = try interfaces.XPathEvaluator.call_createExpression(evaluator, runtime.DOMString.initInterned(text), webidl.Opt(??*runtime.CallbackWrapper).notPassed());
        runtime.Instance.deinit(expression);
    }
    for ([_][]const u8{ "(", "///x", "a[", "1e2", "unknown()", "last(1)", "$v", "p :", "p : : item", "child : : item" }) |text| {
        try std.testing.expectError(error.SyntaxError, interfaces.XPathEvaluator.call_createExpression(evaluator, runtime.DOMString.initInterned(text), webidl.Opt(??*runtime.CallbackWrapper).notPassed()));
    }
    // Browser lexers admit XML whitespace around the QName colon. A missing
    // resolver must therefore be a namespace error, not malformed syntax.
    for ([_][]const u8{ "p : item", "p: item", "p :item", "@p : *", "child :: p : item", "p\t:\ritem" }) |text| {
        try std.testing.expectError(error.NamespaceError, interfaces.XPathEvaluator.call_createExpression(evaluator, runtime.DOMString.initInterned(text), webidl.Opt(??*runtime.CallbackWrapper).notPassed()));
    }
}

test "XPath scalar evaluation through interfaces releases all native allocations" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(a, &ctx);
    defer interfaces.Document.deinit(document);
    const result = try interfaces.Document.call_evaluate(document, runtime.DOMString.initInterned("1 + 2 * 3"), document, webidl.Opt(??*runtime.CallbackWrapper).notPassed(), webidl.Opt(u16).notPassed(), webidl.Opt(?*runtime.Instance).notPassed());
    defer runtime.Instance.deinit(result);
    try std.testing.expectEqual(@as(u16, 1), try interfaces.XPathResult.get_resultType(result));
    try std.testing.expectEqual(@as(f64, 7), try interfaces.XPathResult.get_numberValue(result));
}

test "XPath parser and evaluation arenas unwind every allocation failure" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(a, &ctx);
    defer interfaces.Document.deinit(document);
    try std.testing.checkAllAllocationFailures(a, compileAndEvaluate, .{document});
}

fn compileAndEvaluate(allocator: std.mem.Allocator, document: *runtime.Instance) !void {
    const compiled = try interfaces.XPathExpression.initWith(allocator, document.ctx, .{
        .expression = runtime.DOMString.initInterned("concat('a', substring('12345', 1.5, 2.6), string(4 div 2), translate('a😀a', '😀a', 'xy'))"),
    });
    defer runtime.Instance.deinit(compiled);
    const result = try interfaces.XPathExpression.call_evaluate(compiled, document, webidl.Opt(u16).notPassed(), webidl.Opt(?*runtime.Instance).notPassed());
    defer runtime.Instance.deinit(result);
    var text = try interfaces.XPathResult.get_stringValue(result);
    defer text.deinit(a);
    try std.testing.expectEqualStrings("a2342xy", text.asSlice());
}

test "XPath string operations preserve browser UTF-16 units and surrogate seams" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(a, &ctx);
    defer interfaces.Document.deinit(document);
    const cases = [_][2][]const u8{
        .{ "string-length('a😀b')", "4" },
        .{ "substring('a😀b', 2, 1)", "\xED\xA0\xBD" },
        .{ "substring('a😀b', 3, 1)", "\xED\xB8\x80" },
        .{ "translate('a😀a', '😀a', 'xy')", "xy" },
        .{ "contains('😀', '\xED\xB8\x80')", "true" },
        .{ "concat('\xED\xA0\xBD', '\xED\xB8\x80') = '😀'", "true" },
        .{ "sum(3)", "0" },
    };
    for (cases) |case| {
        const result = try interfaces.Document.call_evaluate(document, runtime.DOMString.initInterned(case[0]), document, webidl.Opt(??*runtime.CallbackWrapper).notPassed(), webidl.Opt(u16).passed(2), webidl.Opt(?*runtime.Instance).notPassed());
        defer runtime.Instance.deinit(result);
        var text = try interfaces.XPathResult.get_stringValue(result);
        defer text.deinit(a);
        try std.testing.expectEqualStrings(case[1], text.asSlice());
    }
}

test "XPathResult allocation failures release partial node holds and strings" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(a, &ctx);
    defer interfaces.Document.deinit(document);
    try std.testing.checkAllAllocationFailures(a, constructResults, .{document});
}

fn constructResults(allocator: std.mem.Allocator, document: *runtime.Instance) !void {
    const snapshot = try interfaces.XPathResult.initWith(allocator, document.ctx, .{
        .result_type = @as(u16, 7),
        .nodes = &[_]*runtime.Instance{document},
    });
    defer runtime.Instance.deinit(snapshot);
    try std.testing.expectEqual(document, (try interfaces.XPathResult.call_snapshotItem(snapshot, 0)).?);
    const scalar = try interfaces.XPathResult.initWith(allocator, document.ctx, .{
        .result_type = @as(u16, 2),
        .string_value = "an independently owned result string",
    });
    defer runtime.Instance.deinit(scalar);
    var text = try interfaces.XPathResult.get_stringValue(scalar);
    defer text.deinit(a);
    try std.testing.expectEqualStrings("an independently owned result string", text.asSlice());
}
