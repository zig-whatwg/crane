//! XPath is tested through the generated interfaces, without a JavaScript engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const a = std.testing.allocator;

test "XPath compiled grammar releases native allocations on success and syntax errors" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const evaluator = try interfaces.XPathEvaluator.init(a, &ctx);
    defer interfaces.XPathEvaluator.deinit(evaluator);
    for ([_][]const u8{ "1 + 2 * 3", "//div[@id='x'][1]", "preceding-sibling::*[last()]", "substring('12345', 1.5, 2.6)", "(//x | //y)[1]", "processing-instruction('target')", "$v", "concat($p : v, 'b')" }) |text| {
        const expression = try interfaces.XPathEvaluator.call_createExpression(evaluator, runtime.DOMString.initInterned(text), webidl.Opt(??*runtime.CallbackWrapper).notPassed());
        runtime.Instance.deinit(expression);
    }
    for ([_][]const u8{ "(", "///x", "a[", "1e2", "unknown()", "last(1)", "$ v", "$p:*", "$1", "p :", "p : : item", "child : : item" }) |text| {
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
        // XPath §3.1: an unbound variable is an evaluation error; WebKit and
        // Blink evaluate it to "" (Gecko throws), so the browser majority wins.
        .{ "concat($unbound, 'b')", "b" },
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

test "XPath evaluates a 200,000-operator chain without native recursion" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(a, &ctx);
    defer interfaces.Document.deinit(document);
    // XPath §3.5: `+` is left-associative, so these terms make a left-deep tree
    // 200,000 levels high at nesting depth one. Evaluation used to recurse once
    // per level and overflowed the native stack (review M1).
    const terms = 200_000;
    const text = try a.alloc(u8, 1 + 2 * terms);
    defer a.free(text);
    text[0] = '1';
    for (0..terms) |i| @memcpy(text[1 + 2 * i ..][0..2], "+1");
    const result = try interfaces.Document.call_evaluate(document, runtime.DOMString.initInterned(text), document, webidl.Opt(??*runtime.CallbackWrapper).notPassed(), webidl.Opt(u16).notPassed(), webidl.Opt(?*runtime.Instance).notPassed());
    defer runtime.Instance.deinit(result);
    try std.testing.expectEqual(@as(f64, terms + 1), try interfaces.XPathResult.get_numberValue(result));
    // Folding reads the left value while building the next one: a comparison
    // must see its left operand intact. (1 = 1) = 1 = ... stays true.
    const comparisons = 1_000;
    const chain = try a.alloc(u8, 1 + 4 * comparisons);
    defer a.free(chain);
    chain[0] = '1';
    for (0..comparisons) |i| @memcpy(chain[1 + 4 * i ..][0..4], " = 1");
    for ([_][]const u8{ chain, "'ab' = concat('a', 'b')", "3 > 2 = true()" }) |expression| {
        const truth = try interfaces.Document.call_evaluate(document, runtime.DOMString.initInterned(expression), document, webidl.Opt(??*runtime.CallbackWrapper).notPassed(), webidl.Opt(u16).passed(3), webidl.Opt(?*runtime.Instance).notPassed());
        defer runtime.Instance.deinit(truth);
        try std.testing.expect(try interfaces.XPathResult.get_booleanValue(truth));
    }
}

/// A document with `<section><span>one</span><span>two</span></section>`,
/// the section in its tree, for the iterator tests below.
const IteratorFixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    section: *runtime.Instance,
    text: *runtime.Instance,

    fn init(self: *IteratorFixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(a);
        self.ctx = try runtime.ContextData.init(a, .{});
        self.document = try interfaces.Document.init(a, &self.ctx);
        self.section = try self.element("section");
        _ = try interfaces.Node.call_appendChild(self.document, self.section);
        for ([_][]const u8{ "one", "two" }) |data| {
            const span = try self.element("span");
            _ = try interfaces.Node.call_appendChild(self.section, span);
            self.text = try interfaces.Document.call_createTextNode(self.document, runtime.DOMString.initInterned(data));
            _ = try interfaces.Node.call_appendChild(span, self.text);
        }
    }

    fn deinit(self: *IteratorFixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(self: *IteratorFixture, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    /// `.//span` from the section, as an ORDERED_NODE_ITERATOR_TYPE result.
    fn iterator(self: *IteratorFixture) !*runtime.Instance {
        return interfaces.Document.call_evaluate(self.document, runtime.DOMString.initInterned(".//span"), self.section, webidl.Opt(??*runtime.CallbackWrapper).notPassed(), webidl.Opt(u16).passed(5), webidl.Opt(?*runtime.Instance).notPassed());
    }
};

test "an XPath iterator stays valid when an unrelated detached tree of its document is freed" {
    var f: IteratorFixture = undefined;
    try f.init();
    defer f.deinit();
    // A tree of the same document that was never in its tree, built BEFORE
    // the evaluation (building it mutates a detached tree of the document,
    // which browsers count too) and freed after it, as the collector frees
    // garbage (crane/xp2-result-gc.html: TestUtils.gc() between evaluate and
    // iterateNext). Its free mutates nothing: DOM Level 3 XPath invalidates
    // an iterator only when "the document has been mutated", and Blink and
    // WebKit move the version an iterator checks only on mutations.
    const garbage = try f.element("div");
    _ = try interfaces.Node.call_appendChild(garbage, try f.element("p"));
    const result = try f.iterator();
    defer runtime.Instance.deinit(result);
    dom.node_creation.destroyUninserted(garbage);
    try std.testing.expect(!try interfaces.XPathResult.get_invalidIteratorState(result));
    const first = (try interfaces.XPathResult.call_iterateNext(result)) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(interfaces.Node.get_firstChild(f.section) catch null, first);
    try std.testing.expect((try interfaces.XPathResult.call_iterateNext(result)) != null);
    try std.testing.expectEqual(null, try interfaces.XPathResult.call_iterateNext(result));
}

test "an XPath iterator is invalid after a character data change in its document" {
    var f: IteratorFixture = undefined;
    try f.init();
    defer f.deinit();
    const result = try f.iterator();
    defer runtime.Instance.deinit(result);
    try std.testing.expect((try interfaces.XPathResult.call_iterateNext(result)) != null);
    // Blink CharacterData::SetDataAndUpdate and WebKit
    // CharacterData::notifyParentAfterChange move the DOM tree version, and
    // Gecko's XPathResult::CharacterDataChanged invalidates the result.
    try interfaces.CharacterData.set_data(f.text, runtime.DOMString.initInterned("changed"));
    try std.testing.expect(try interfaces.XPathResult.get_invalidIteratorState(result));
    try std.testing.expectError(error.InvalidStateError, interfaces.XPathResult.call_iterateNext(result));
}

test "an XPath iterator is invalid after an insertion or an attribute change" {
    var f: IteratorFixture = undefined;
    try f.init();
    defer f.deinit();
    const inserted = try f.iterator();
    defer runtime.Instance.deinit(inserted);
    _ = try interfaces.Node.call_appendChild(f.section, try f.element("span"));
    try std.testing.expectError(error.InvalidStateError, interfaces.XPathResult.call_iterateNext(inserted));
    const attributed = try f.iterator();
    defer runtime.Instance.deinit(attributed);
    try interfaces.Element.call_setAttribute(f.section, runtime.DOMString.initInterned("data-x"), .{ .domstring = runtime.DOMString.initInterned("1") });
    try std.testing.expectError(error.InvalidStateError, interfaces.XPathResult.call_iterateNext(attributed));
}
