//! A navigation without an available parser still owns normal completion.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");

test "parserless completion releases the post-load readiness predicate" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    try std.testing.expect(!dom.document_lifecycle.isReadyForPostLoadTasks(document));
    dom.document_lifecycle.finishWithoutParser(document);
    try std.testing.expect(dom.document_lifecycle.isReadyForPostLoadTasks(document));
}

test "parserless completion cannot finish an associated suspended HTML parser" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>pending", .{});
    defer parser.release();
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    dom.document_lifecycle.finishWithoutParser(document);
    try std.testing.expect(!dom.document_lifecycle.isReadyForPostLoadTasks(document));
    try std.testing.expect(!parser.input_stream.eof_processed);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == parser);
}
