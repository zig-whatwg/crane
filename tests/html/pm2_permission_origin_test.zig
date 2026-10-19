const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const settings = dom.global_settings;
const worker_host = @import("html").worker_host;

fn copyWorkerOrigin(allocator: std.mem.Allocator, realm: runtime.Context) !void {
    const copy = (try worker_host.creatorTopLevelOrigin(allocator, realm)) orelse return error.MissingTopLevelOrigin;
    defer allocator.free(copy);
    try std.testing.expectEqualStrings("https://top.example.test:8443", copy);
}

test "permission keys use the top-level origin for a top window and a cross-origin child" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();

    const top = try interfaces.Window.init(allocator, &realm);
    defer interfaces.Window.deinit(top);
    const top_document = blk: {
        const document = try interfaces.Document.init(allocator, &realm);
        errdefer interfaces.Document.deinit(document);
        try dom.document_internals.setURL(document, "https://top.example.test:8443/page");
        dom.window_globals.setDocument(top, document);
        break :blk document; // Window owns its associated document.
    };
    const navigables = dom.browser_state.navigablesOf(&realm).?;
    const top_bc = navigables.contexts()[0];
    top_bc.setActiveWindow(top);

    const child = try interfaces.Window.init(allocator, &realm);
    defer interfaces.Window.deinit(child);
    {
        const document = try interfaces.Document.init(allocator, &realm);
        errdefer interfaces.Document.deinit(document);
        try dom.document_internals.setURL(document, "https://cross.example.test/frame");
        dom.window_globals.setDocument(child, document);
    }
    const child_bc = navigables.contexts()[1];
    try top_bc.children.append(allocator, child_bc);
    child_bc.parent = top_bc;
    defer child_bc.removeFromParent();
    child_bc.setActiveWindow(child);

    for ([_]*runtime.Instance{ top, child }) |window| {
        const origin = (try settings.topLevelOriginOf(window)) orelse return error.MissingTopLevelOrigin;
        defer allocator.free(origin);
        try std.testing.expectEqualStrings("https://top.example.test:8443", origin);
    }
    const child_origin = try settings.of(child).?.origin(child);
    defer allocator.free(child_origin);
    try std.testing.expectEqualStrings("https://cross.example.test", child_origin);

    // Worker startup captures its owner's top-level origin on this thread,
    // then transfers only the independently owned bytes to the worker.
    const record = try runtime.Realm.init(allocator, .{ .context_type = .window, .global_object = child });
    defer record.deinit();
    realm.setRealm(record);
    defer realm.clearRealm();
    try copyWorkerOrigin(allocator, &realm);
    try std.testing.checkAllAllocationFailures(allocator, copyWorkerOrigin, .{&realm});

    // The current serialized-key hook cannot represent an opaque origin's
    // identity. It must return no key rather than share "null" across them.
    const opaque_origin = try dom.origin_record.OriginRecord.create(allocator, "null");
    defer opaque_origin.release();
    const opaque_document = try interfaces.Document.initWith(allocator, &realm, .{ .origin = opaque_origin });
    defer interfaces.Document.deinit(opaque_document);
    dom.window_globals.setDocument(top, opaque_document);
    defer dom.window_globals.setDocument(top, top_document);
    try std.testing.expectEqual(null, try settings.topLevelOriginOf(top));
    try std.testing.expectEqual(null, try settings.topLevelOriginOf(child));
}

test "a worker without a captured owner has no invented top-level permission origin" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const worker = try interfaces.DedicatedWorkerGlobalScope.initWith(allocator, &realm, .{ .url = "https://worker.example.test/script.js" });
    defer interfaces.DedicatedWorkerGlobalScope.deinit(worker);
    try std.testing.expectEqual(null, try settings.topLevelOriginOf(worker));
}
