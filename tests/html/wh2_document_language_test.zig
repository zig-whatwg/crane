//! Document language defaults, attribute precedence, persistence and ownership.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn attribute(target: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(target, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(testing.allocator, &ctx);
    defer dom.node_creation.destroyUninserted(document);
    const root = try element(document, "html");
    _ = try interfaces.Node.call_appendChild(document, root);
    const detached = try element(document, "div");
    defer dom.node_creation.destroyUninserted(detached);
    // The default is pinned before setting any pragma: no language is known.
    try testing.expect(!try dom.selector_matching.matches(root, ":lang(\"*\")"));
    try testing.expect(!try dom.selector_matching.matches(detached, ":lang(de)"));
    const meta = try element(document, "meta");
    try attribute(meta, "http-equiv", "content-language");
    try attribute(meta, "content", "de-DE");
    _ = try interfaces.Node.call_appendChild(root, meta);
    try testing.expect(try dom.selector_matching.matches(root, ":lang(de)"));
    _ = try interfaces.Node.call_removeChild(root, meta);
    dom.node_creation.destroyUninserted(meta);
    try testing.expect(try dom.selector_matching.matches(root, ":lang(de-DE)"));
    try testing.expect(try dom.selector_matching.matches(detached, ":lang(de)"));
    try attribute(root, "lang", "en");
    try testing.expect(try dom.selector_matching.matches(root, ":lang(en)"));
    try attribute(root, "lang", "");
    try testing.expect(!try dom.selector_matching.matches(root, ":lang(de)"));
    // testing.allocator verifies the Document releases its owned language.
}

fn exerciseOwnership() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var failing = testing.FailingAllocator.init(testing.allocator, .{});
    const allocator = failing.allocator();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer dom.node_creation.destroyUninserted(document);
    try testing.expect(dom.document_language.get(document) == null);
    const input = try allocator.dupe(u8, "fr");
    defer allocator.free(input);
    try dom.document_language.set(document, input);
    input[0] = 'x';
    try testing.expectEqualStrings("fr", dom.document_language.get(document).?);
    failing.fail_index = failing.alloc_index;
    try testing.expectError(error.OutOfMemory, dom.document_language.set(document, "replacement"));
    failing.fail_index = std.math.maxInt(usize);
    try testing.expectEqualStrings("fr", dom.document_language.get(document).?);
    try dom.document_language.set(document, "");
    try testing.expectEqualStrings("", dom.document_language.get(document).?);
}

fn exerciseMutations() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(testing.allocator, &ctx);
    defer dom.node_creation.destroyUninserted(document);
    const root = try element(document, "html");
    _ = try interfaces.Node.call_appendChild(document, root);
    const meta = try element(document, "meta");
    try attribute(meta, "http-equiv", "content-language");
    try attribute(meta, "content", "en");
    _ = try interfaces.Node.call_appendChild(root, meta);
    try testing.expectEqualStrings("en", dom.document_language.get(document).?);
    try attribute(meta, "content", "fr");
    try testing.expectEqualStrings("fr", dom.document_language.get(document).?);
    try attribute(meta, "http-equiv", "unrecognized");
    try attribute(meta, "content", "de");
    try testing.expectEqualStrings("fr", dom.document_language.get(document).?);
    try attribute(meta, "http-equiv", "CoNtEnT-LaNgUaGe");
    try testing.expectEqualStrings("de", dom.document_language.get(document).?);
    _ = try interfaces.Node.call_removeChild(root, meta);
    // Keep a cleanup for the detached node even if an assertion fails.
    defer if ((interfaces.Node.get_parentNode(meta) catch null) == null) dom.node_creation.destroyUninserted(meta);
    try attribute(meta, "content", "es");
    try testing.expectEqualStrings("de", dom.document_language.get(document).?);
    _ = try interfaces.Node.call_appendChild(root, meta);
    try testing.expectEqualStrings("es", dom.document_language.get(document).?);
}

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                std.debug.print("language regression failed: {s}\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "document default language is absent until a pragma and persists after removal" {
    try onFreshThread(exercise);
}

test "document default language owns its string and preserves it on allocation failure" {
    try onFreshThread(exerciseOwnership);
}

test "connected content-language mutations apply while detached changes wait for reinsertion" {
    try onFreshThread(exerciseMutations);
}
