//! Tests for WindowProxy cross-origin access restrictions
//!
//! Per HTML Standard §7.4, WindowProxy controls cross-origin access to Window properties.

const std = @import("std");
const html = @import("html");
const BrowsingContext = html.window.BrowsingContext;
const WindowProxy = html.window.WindowProxy;
const Origin = html.window.Origin;
const WindowProxyError = html.window.WindowProxyError;

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

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);

    // Initial state
    try std.testing.expect(!proxy.getClosed());
    try std.testing.expectEqual(@as(u32, 0), proxy.getLength());
}

test "WindowProxy - same origin access allows everything" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const same_origin = Origin.init("https", "example.com", 443);

    // Same-origin can access restricted properties
    try std.testing.expect(proxy.isSameOriginAccess(same_origin));
    try proxy.accessProperty(same_origin, "document");
    try proxy.accessProperty(same_origin, "localStorage");
    try proxy.accessProperty(same_origin, "sessionStorage");
    try proxy.accessProperty(same_origin, "innerWidth");
}

test "WindowProxy - cross origin blocks restricted properties" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const cross_origin = Origin.init("https", "evil.com", 443);

    // Cross-origin cannot access restricted properties
    try std.testing.expect(!proxy.isSameOriginAccess(cross_origin));

    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin, "document"),
    );
    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin, "localStorage"),
    );
    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin, "sessionStorage"),
    );
    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin, "innerWidth"),
    );
}

test "WindowProxy - cross origin allows safe properties" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const cross_origin = Origin.init("https", "other.com", 443);

    // These properties ARE allowed cross-origin per HTML spec
    try proxy.accessProperty(cross_origin, "window");
    try proxy.accessProperty(cross_origin, "self");
    try proxy.accessProperty(cross_origin, "frames");
    try proxy.accessProperty(cross_origin, "top");
    try proxy.accessProperty(cross_origin, "opener");
    try proxy.accessProperty(cross_origin, "parent");
    try proxy.accessProperty(cross_origin, "closed");
    try proxy.accessProperty(cross_origin, "length");
    try proxy.accessProperty(cross_origin, "close");
    try proxy.accessProperty(cross_origin, "focus");
    try proxy.accessProperty(cross_origin, "blur");
    try proxy.accessProperty(cross_origin, "postMessage");
    try proxy.accessProperty(cross_origin, "location");
}

test "WindowProxy - getClosed reflects browsing context state" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);

    try std.testing.expect(!proxy.getClosed());

    ctx.close();

    try std.testing.expect(proxy.getClosed());
}

test "WindowProxy - getLength reflects child count" {
    const allocator = std.testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
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

test "WindowProxy - isCrossOriginAllowedProperty" {
    // Allowed properties should return non-null
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("window") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("self") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("frames") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("top") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("parent") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("opener") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("closed") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("length") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("close") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("focus") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("blur") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("postMessage") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("location") != null);

    // Not allowed properties should return null
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("document") == null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("localStorage") == null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("sessionStorage") == null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("alert") == null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("innerWidth") == null);
}

test "WindowProxy - getWindow returns self" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);
    const window_ref = proxy.getWindow();

    try std.testing.expect(window_ref == &proxy);
}

test "WindowProxy - different scheme is cross-origin" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    // http vs https is cross-origin
    const http_origin = Origin.init("http", "example.com", 443);
    try std.testing.expect(!proxy.isSameOriginAccess(http_origin));

    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(http_origin, "document"),
    );
}

test "WindowProxy - different port is cross-origin" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const different_port = Origin.init("https", "example.com", 8443);
    try std.testing.expect(!proxy.isSameOriginAccess(different_port));
}
