//! HTML 3.1.6 render blocking: membership is Document state, not a timer.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const rendering = dom.document_rendering;

test "render blockers form an ordered set and timeout leaves membership intact" {
    var set = rendering.ElementSet.init(std.testing.allocator);
    defer set.deinit();
    // The set compares identities; it never dereferences its elements.
    var a: runtime.Instance = undefined;
    var b: runtime.Instance = undefined;
    var c: runtime.Instance = undefined;
    try set.add(&a);
    try set.add(&b);
    try set.add(&a);
    try std.testing.expectEqualSlices(*runtime.Instance, &.{ &a, &b }, set.elements.items);
    set.remove(&c);
    set.remove(&a);
    try std.testing.expect(set.contains(&b));
    try std.testing.expect(set.isBlocked(false, rendering.timeout_ms));
    try std.testing.expect(!set.isBlocked(false, rendering.timeout_ms + 1));
    try std.testing.expect(set.contains(&b));
    set.remove(&b);
    try std.testing.expect(!set.isBlocked(false, 0));
    try std.testing.expect(set.isBlocked(true, 0));
    set.deinit();
    try std.testing.expect(!set.contains(&b));
    try std.testing.expectEqual(@as(usize, 0), set.elements.items.len);
}

test "a failed render-set insertion changes no membership" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var set = rendering.ElementSet.init(failing.allocator());
    defer set.deinit();
    var element: runtime.Instance = undefined;
    try std.testing.expectError(error.OutOfMemory, set.add(&element));
    try std.testing.expectEqual(@as(usize, 0), set.elements.items.len);
}

test "blocking tokens use ASCII whitespace and case-insensitive render" {
    try std.testing.expect(rendering.hasRenderToken("\tREnDer\nunknown\r\x0c"));
    try std.testing.expect(!rendering.hasRenderToken("rendering"));
    try std.testing.expect(!rendering.hasRenderToken("render\x0bother"));
    try std.testing.expect(!rendering.hasRenderToken(""));
    try std.testing.expect(rendering.allowsAdding("text/html", false));
    try std.testing.expect(!rendering.allowsAdding("text/html", true));
    try std.testing.expect(!rendering.allowsAdding("application/xhtml+xml", false));
}

test "Document owns blockers before body and removal and token writes erase them" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(std.testing.allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &ctx);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const html = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("html"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(document, html);
    const script = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("script"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(html, script);
    try rendering.block(script);
    try rendering.block(script);
    try std.testing.expect(rendering.contains(document, script));
    const body = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("body"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(html, body);
    // Body arrival closes additions but does not erase existing blockers.
    const second = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("script"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(body, second);
    try rendering.block(second);
    try std.testing.expect(!rendering.contains(document, second));
    try std.testing.expect(rendering.contains(document, script));
    try interfaces.Element.call_setAttribute(script, runtime.DOMString.initInterned("blocking"), .{ .domstring = runtime.DOMString.initInterned("render") });
    const tokens = try interfaces.HTMLScriptElement.get_blocking(script);
    defer interfaces.DOMTokenList.deinit(tokens);
    try std.testing.expect(tokens == try interfaces.HTMLScriptElement.get_blocking(script));
    try std.testing.expect(try interfaces.DOMTokenList.call_supports(tokens, runtime.DOMString.initInterned("RENDER")));
    try std.testing.expect(!(try interfaces.DOMTokenList.call_supports(tokens, runtime.DOMString.initInterned("unknown"))));
    try interfaces.DOMTokenList.set_value(tokens, runtime.DOMString.initInterned(""));
    try std.testing.expect(!rendering.contains(document, script));
    // Removing a subtree invokes removing steps for the script descendant.
    _ = try interfaces.Node.call_removeChild(html, body);
    try rendering.block(script);
    try std.testing.expect(rendering.contains(document, script));
    _ = try interfaces.Node.call_removeChild(document, html);
    try std.testing.expect(!rendering.contains(document, script));
    try rendering.block(script);
    dom.document_browsing_context.clearWindow(document);
    try std.testing.expect(!rendering.contains(document, script));
    try dom.document_internals.setContentType(document, "application/xhtml+xml");
    try rendering.block(script);
    try std.testing.expect(!rendering.contains(document, script));
    try dom.document_internals.setContentType(document, "text/html");
    _ = try interfaces.Node.call_appendChild(document, html);
    const frameset = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("frameset"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(html, frameset);
    try rendering.block(script);
    try std.testing.expect(!rendering.contains(document, script));
    _ = try interfaces.Node.call_removeChild(html, frameset);
    interfaces.HTMLFrameSetElement.deinit(frameset);
    _ = try interfaces.Node.call_removeChild(document, html);
    _ = try interfaces.Node.call_removeChild(body, second);
    _ = try interfaces.Node.call_removeChild(html, script);
    interfaces.HTMLBodyElement.deinit(body);
    interfaces.HTMLScriptElement.deinit(second);
    interfaces.HTMLScriptElement.deinit(script);
    interfaces.HTMLHtmlElement.deinit(html);
}
