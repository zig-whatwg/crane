//! HTML document.open steps 16-17 create a parser even after the document's
//! navigable was destroyed. Parser ownership and document activity differ.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const browser_mod = @import("browser");
const engine = @import("engine");

fn check(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn reopenAfterDestroy() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setDocumentType(document, .html);
    const internal = dom.document_internals.getInternal(document).?;
    dom.document_lifecycle.destroy(document);
    try std.testing.expect(internal.destroyed);
    _ = try interfaces.Document.call_open(document, .{ .was_passed = false, .value = undefined }, .{ .was_passed = false, .value = undefined });
    try std.testing.expect(internal.active_parser != null);
    try interfaces.Document.call_close(document);
    try std.testing.expect(internal.active_parser == null);
    try std.testing.expect(internal.destroyed);
}

fn retainedInactiveDocumentCanWrite() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const held = try browser.evaluateScript("globalThis.retired = document.implementation.createHTMLDocument('retired')");
    defer held.release();
    const document = engine.convertToPlatformObject(browser.getRealm().?, held.borrow()) orelse return error.NoDocument;
    dom.document_lifecycle.destroy(document);
    try page.runScript(
        \\retired.open();
        \\retired.write('<p id="written">retained document</p>');
        \\if (retired.getElementById('written')?.textContent !== 'retained document')
        \\  throw new Error('retained document did not parse the write');
        \\retired.close();
    );
}

fn destructionRevokesOldParser() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setDocumentType(document, .html);
    _ = try interfaces.Document.call_open(document, .{ .was_passed = false, .value = undefined }, .{ .was_passed = false, .value = undefined });
    const parser = dom.document_internals.getInternal(document).?.active_parser.?;
    parser.retain();
    defer parser.release();
    dom.document_lifecycle.destroy(document);
    try std.testing.expect(parser.detached);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    try std.testing.expectError(error.InvalidStateError, parser.protect());
}

test "document.close completes a newly opened parser after navigable destruction" {
    try check(reopenAfterDestroy);
}

test "a retained inactive document can open write and close" {
    try check(retainedInactiveDocumentCanWrite);
}

test "document destruction still revokes an existing parser" {
    try check(destructionRevokesOldParser);
}
