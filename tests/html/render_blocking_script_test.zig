//! HTML script potential blocking and execution step 3, without an engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");

test "token removal retains implicit parser classic blocking and uses prepared type" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const script = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("script"), .{ .was_passed = false, .value = undefined });
    defer interfaces.HTMLScriptElement.deinit(script);
    try dom.node_document.set(script, document);
    const state = html.script_element.of(script).?;
    state.parser_document = document;
    state.script_type = .classic;
    state.force_async = true;
    try interfaces.Element.call_setAttribute(script, runtime.DOMString.initInterned("blocking"), .{ .domstring = runtime.DOMString.initInterned("render") });
    try dom.document_rendering.block(script);
    try interfaces.Element.call_removeAttribute(script, runtime.DOMString.initInterned("blocking"));
    try std.testing.expect(html.script_execution.isPotentiallyRenderBlocking(script));
    try std.testing.expect(dom.document_rendering.contains(document, script));
    try interfaces.HTMLScriptElement.set_type(script, runtime.DOMString.initInterned("module"));
    try std.testing.expect(html.script_execution.isPotentiallyRenderBlocking(script));
    try interfaces.HTMLScriptElement.set_async(script, true);
    try std.testing.expect(!html.script_execution.isPotentiallyRenderBlocking(script));
    // Only a change to blocking runs blocking-attribute unblocking steps.
    try std.testing.expect(dom.document_rendering.contains(document, script));
    try interfaces.Element.call_setAttribute(script, runtime.DOMString.initInterned("blocking"), .{ .domstring = runtime.DOMString.initInterned("unknown") });
    try std.testing.expect(!dom.document_rendering.contains(document, script));
    try interfaces.Element.call_setAttribute(script, runtime.DOMString.initInterned("blocking"), .{ .domstring = runtime.DOMString.initInterned("render") });
    // Adding a token does not retroactively acquire membership.
    try std.testing.expect(!dom.document_rendering.contains(document, script));
}

test "execution unblocks even a null result before reporting load failure" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const script = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("script"), .{ .was_passed = false, .value = undefined });
    defer interfaces.HTMLScriptElement.deinit(script);
    try dom.node_document.set(script, document);
    const state = html.script_element.of(script).?;
    state.preparation_time_document = document;
    state.result = .null;
    try dom.document_rendering.block(script);
    try html.script_execution.executeScriptElement(allocator, script);
    try std.testing.expect(!dom.document_rendering.contains(document, script));
}

test "module and classic descendant options retain render blocking" {
    const module: html.module_script.ModuleScript = .{
        .allocator = std.testing.allocator,
        .base_url = "https://example.test/module.js",
        .render_blocking = true,
    };
    const classic: html.module_script.ClassicScript = .{
        .base_url = "https://example.test/classic.js",
        .render_blocking = true,
    };
    try std.testing.expect(module.descendantFetchOptions().render_blocking);
    try std.testing.expect(classic.descendantFetchOptions().render_blocking);
    try std.testing.expect(!(html.module_script.FetchOptions{}).render_blocking);
}

test "navigation parser initialization allows render blockers before body" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    // The browser creates the document singleton without a content type.
    // Exercise the real persistent parser initializer before its first pump.
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<!doctype html><body>", .{});
    defer parser.release();
    try std.testing.expectEqualStrings("text/html", dom.document_internals.getContentType(document).?);
    try std.testing.expect(dom.document_rendering.isBlocked(document));
    const script = try interfaces.HTMLScriptElement.init(allocator, &ctx);
    defer interfaces.HTMLScriptElement.deinit(script);
    try dom.node_document.set(script, document);
    try dom.document_rendering.block(script);
    try std.testing.expect(dom.document_rendering.contains(document, script));
}

test "the complete HTML parsing entry point initializes content type" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try html.scripted_parser.parseHTMLWithScripting(allocator, &ctx, "<!doctype html><p>parsed", .{});
    defer interfaces.Document.deinit(document);
    try std.testing.expectEqualStrings("text/html", dom.document_internals.getContentType(document).?);
    try std.testing.expect(!dom.document_rendering.isBlocked(document));
}

test "HTML parser initialization preserves caller content types" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    for ([_][]const u8{ "application/xml", "application/xhtml+xml", "text/plain", "text/html" }) |content_type| {
        const document = try interfaces.Document.init(allocator, &ctx);
        defer interfaces.Document.deinit(document);
        try dom.document_internals.setContentType(document, content_type);
        const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<!doctype html><body>", .{});
        defer parser.release();
        try std.testing.expectEqualStrings(content_type, dom.document_internals.getContentType(document).?);
        const parsed = try html.scripted_parser.parseHTMLWithScripting(allocator, &ctx, "<!doctype html><p>parsed", .{ .document = document });
        try std.testing.expect(parsed == document);
        try std.testing.expectEqualStrings(content_type, dom.document_internals.getContentType(document).?);
        try std.testing.expect(!dom.document_rendering.isBlocked(document));
    }
}
