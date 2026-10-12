//! Tests for the navigation's WindowProxy record (html_core.WindowProxy): its
//! browsing context and the recorded origin of its active document. It runs
//! no access check - HTML 7.2.1's cross-origin checks are the engine's
//! [cross_origin_objects] (tests/v8/xo2_cross_origin_objects_test.zig).

const std = @import("std");
const html = @import("html");
const BrowsingContext = html.window.BrowsingContext;
const Navigables = html.window.Navigables;
const WindowProxy = html.window.WindowProxy;
const Origin = html.window.Origin;

test "Origin - same origin comparison" {
    const origin1 = Origin.init("https", "example.com", 443);
    const origin2 = Origin.init("https", "example.com", 443);
    const origin3 = Origin.init("https", "example.com", 8443);
    const origin4 = Origin.init("http", "example.com", 443);
    const origin5 = Origin.init("https", "other.com", 443);

    try std.testing.expect(origin1.isSameOrigin(origin2));
    try std.testing.expect(!origin1.isSameOrigin(origin3)); // Different port
    try std.testing.expect(!origin1.isSameOrigin(origin4)); // Different scheme
    try std.testing.expect(!origin1.isSameOrigin(origin5)); // Different host
}

test "Origin - opaque origins are never same-origin" {
    const opaque1 = Origin.createOpaque();
    const opaque2 = Origin.createOpaque();
    const tuple = Origin.init("https", "example.com", 443);

    // Opaque origins are never same-origin
    try std.testing.expect(!opaque1.isSameOrigin(opaque2));
    try std.testing.expect(!opaque1.isSameOrigin(tuple));
    try std.testing.expect(!tuple.isSameOrigin(opaque1));
}

test "Origin - null port handling" {
    const with_port = Origin.init("https", "example.com", 443);
    const without_port = Origin.init("https", "example.com", null);

    try std.testing.expect(!with_port.isSameOrigin(without_port));

    const both_null = Origin.init("https", "example.com", null);
    try std.testing.expect(without_port.isSameOrigin(both_null));
}

test "WindowProxy - init and basic properties" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);

    // Initial state
    try std.testing.expect(!proxy.getClosed());
    try std.testing.expectEqual(@as(u32, 0), proxy.getLength());
}

test "WindowProxy - getClosed reflects browsing context state" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);

    try std.testing.expect(!proxy.getClosed());

    ctx.close();

    try std.testing.expect(proxy.getClosed());
}

test "WindowProxy - getLength reflects child count" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const parent = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer parent.deinit();

    const proxy = WindowProxy.init(allocator, parent);

    try std.testing.expectEqual(@as(u32, 0), proxy.getLength());

    // Add children - save references for cleanup
    const child1 = try BrowsingContext.initChild(allocator, parent);
    defer child1.deinit();
    try std.testing.expectEqual(@as(u32, 1), proxy.getLength());

    const child2 = try BrowsingContext.initChild(allocator, parent);
    defer child2.deinit();
    try std.testing.expectEqual(@as(u32, 2), proxy.getLength());
}

test "WindowProxy - getWindow returns self" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);
    const window_ref = proxy.getWindow();

    try std.testing.expect(window_ref == &proxy);
}

test "WindowProxy - the recorded origin of another scheme is not the same origin" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    // http vs https is cross-origin
    const http_origin = Origin.init("http", "example.com", 443);
    try std.testing.expect(!proxy.document_origin.isSameOrigin(http_origin));
}

test "WindowProxy - the recorded origin of another port is not the same origin" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const different_port = Origin.init("https", "example.com", 8443);
    try std.testing.expect(!proxy.document_origin.isSameOrigin(different_port));
}
