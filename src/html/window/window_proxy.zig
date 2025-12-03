//! WindowProxy - HTML Standard §7.4
//!
//! A WindowProxy is the interface through which cross-origin access to a Window
//! is controlled. It acts as a security wrapper around the Window object.
//!
//! Spec: https://html.spec.whatwg.org/multipage/window-object.html#the-windowproxy-exotic-object
//!
//! ## Cross-Origin Restrictions
//!
//! Per the HTML Standard, only certain properties are accessible cross-origin:
//! - window, self (returns WindowProxy)
//! - location (limited access)
//! - close, closed, focus, blur (methods/properties)
//! - frames, length (frame access)
//! - top, opener, parent (navigation)
//! - postMessage (messaging)
//!
//! All other properties (document, localStorage, etc.) throw SecurityError cross-origin.
//!
//! ## Architecture
//!
//! WindowProxy wraps a Window and BrowsingContext, checking origin before
//! allowing property access. The accessor origin is tracked for security checks.

const std = @import("std");
const Allocator = std.mem.Allocator;
const BrowsingContext = @import("browsing_context.zig").BrowsingContext;

/// Origin representation for security checks
/// Per URL Standard and HTML Standard
pub const Origin = struct {
    /// Tuple origin: (scheme, host, port)
    scheme: []const u8,
    host: []const u8,
    port: ?u16,

    /// Opaque origin (unique, never same-origin with anything)
    is_opaque: bool = false,

    /// Create a tuple origin
    pub fn init(scheme: []const u8, host: []const u8, port: ?u16) Origin {
        return .{
            .scheme = scheme,
            .host = host,
            .port = port,
            .is_opaque = false,
        };
    }

    /// Create an opaque origin
    pub fn createOpaque() Origin {
        return .{
            .scheme = "",
            .host = "",
            .port = null,
            .is_opaque = true,
        };
    }

    /// Check if two origins are same-origin
    /// Per HTML Standard §7.5
    pub fn isSameOrigin(self: Origin, other: Origin) bool {
        // Opaque origins are never same-origin (even with themselves conceptually)
        // But for comparison purposes, an opaque origin created in the same way
        // would be the same pointer - so we treat is_opaque as always different
        if (self.is_opaque or other.is_opaque) {
            return false;
        }

        // Tuple origins: same if scheme, host, and port all match
        if (!std.mem.eql(u8, self.scheme, other.scheme)) {
            return false;
        }
        if (!std.mem.eql(u8, self.host, other.host)) {
            return false;
        }
        if (self.port != other.port) {
            return false;
        }

        return true;
    }

    /// Check if same-origin-domain (relaxed for document.domain)
    /// Per HTML Standard §7.5.2
    pub fn isSameOriginDomain(self: Origin, other: Origin) bool {
        // For now, same as same-origin (document.domain is deprecated)
        return self.isSameOrigin(other);
    }
};

/// Properties allowed for cross-origin access
/// Per HTML Standard §7.4.6
pub const CrossOriginProperty = enum {
    // WindowProxy/Window self-references
    window,
    self_,
    frames,

    // Navigation
    top,
    opener,
    parent,

    // State
    closed,
    length,

    // Methods
    close,
    focus,
    blur,
    postMessage,

    // Location (special handling)
    location,
};

/// Error types for WindowProxy operations
pub const WindowProxyError = error{
    /// Cross-origin access to restricted property
    SecurityError,
    /// The browsing context has been discarded
    InvalidStateError,
    /// Property or method not found
    NotFound,
    /// General operation failure
    OperationFailed,
    /// Out of memory
    OutOfMemory,
};

/// WindowProxy exotic object per HTML Standard §7.4
///
/// This is the object through which all Window access is mediated.
/// It checks origin before allowing access to Window properties.
pub const WindowProxy = struct {
    /// The associated browsing context
    browsing_context: *BrowsingContext,

    /// The origin of this window's document
    document_origin: Origin,

    /// Allocator for dynamic operations
    allocator: Allocator,

    /// Create a new WindowProxy for a browsing context
    pub fn init(allocator: Allocator, browsing_context: *BrowsingContext) WindowProxy {
        return .{
            .browsing_context = browsing_context,
            .document_origin = Origin.createOpaque(), // Default to opaque until document loads
            .allocator = allocator,
        };
    }

    /// Set the document origin (called when document loads)
    pub fn setDocumentOrigin(self: *WindowProxy, origin: Origin) void {
        self.document_origin = origin;
    }

    /// Check if an accessor origin can access a property
    /// Returns true if access is allowed, false if SecurityError should be thrown
    pub fn canAccess(self: *const WindowProxy, accessor_origin: Origin, property: CrossOriginProperty) bool {
        // Same-origin always allowed
        if (self.document_origin.isSameOrigin(accessor_origin)) {
            return true;
        }

        // Cross-origin: only specific properties allowed
        return switch (property) {
            .window, .self_, .frames => true,
            .top, .opener, .parent => true,
            .closed, .length => true,
            .close, .focus, .blur, .postMessage => true,
            .location => true, // Location has its own restrictions
        };
    }

    /// Check if an accessor can access any property (unrestricted)
    /// This is used for same-origin checks before accessing arbitrary properties
    pub fn isSameOriginAccess(self: *const WindowProxy, accessor_origin: Origin) bool {
        return self.document_origin.isSameOrigin(accessor_origin);
    }

    /// Get the WindowProxy itself (always allowed)
    pub fn getWindow(self: *const WindowProxy) *const WindowProxy {
        return self;
    }

    /// Get the closed state (always allowed)
    pub fn getClosed(self: *const WindowProxy) bool {
        return self.browsing_context.is_closed;
    }

    /// Get the number of child browsing contexts (always allowed)
    pub fn getLength(self: *const WindowProxy) u32 {
        return self.browsing_context.getChildCount();
    }

    /// Get the top WindowProxy (always allowed, but may return different proxy cross-origin)
    pub fn getTop(self: *WindowProxy) *WindowProxy {
        // Navigate to top browsing context
        var ctx = self.browsing_context;
        while (ctx.parent) |parent| {
            ctx = parent;
        }
        // In a full implementation, we'd look up the WindowProxy for that context
        // For now, if we're already at top, return self
        if (ctx == self.browsing_context) {
            return self;
        }
        // TODO: Look up WindowProxy for top context from a registry
        return self;
    }

    /// Get the parent WindowProxy (always allowed)
    pub fn getParent(self: *WindowProxy) ?*WindowProxy {
        if (self.browsing_context.parent) |_| {
            // TODO: Look up WindowProxy for parent context
            return self; // Placeholder
        }
        // If no parent, return self per spec
        return self;
    }

    /// Get the opener WindowProxy (always allowed, but may be null if disowned)
    pub fn getOpener(self: *const WindowProxy) ?*WindowProxy {
        if (self.browsing_context.disowned) {
            return null;
        }
        if (self.browsing_context.opener) |_| {
            // TODO: Look up WindowProxy for opener context
            return null; // Placeholder until we have a registry
        }
        return null;
    }

    /// Close the window (allowed if script-closable)
    pub fn close(self: *WindowProxy) WindowProxyError!void {
        if (!self.browsing_context.isScriptClosable()) {
            // Per spec, close() on non-script-closable window does nothing
            return;
        }
        self.browsing_context.close();
    }

    /// Focus the window (always allowed cross-origin)
    pub fn focus(self: *WindowProxy) void {
        // TODO: Implement focus behavior
        _ = self;
    }

    /// Blur the window (always allowed cross-origin)
    pub fn blur(self: *WindowProxy) void {
        // TODO: Implement blur behavior
        _ = self;
    }

    /// Post a message to this window (always allowed cross-origin)
    /// This is the core cross-origin communication mechanism
    pub fn postMessage(
        self: *WindowProxy,
        message: []const u8,
        target_origin: []const u8,
        source_origin: Origin,
    ) WindowProxyError!void {
        _ = message;
        _ = source_origin;

        // Check target origin if not "*"
        if (!std.mem.eql(u8, target_origin, "*")) {
            // Parse target_origin and compare
            // For now, simplified check
            if (!std.mem.eql(u8, target_origin, "/")) {
                // Would need to parse and compare origins
                // If target doesn't match, silently fail per spec
            }
        }

        // TODO: Create MessageEvent and dispatch to the window
        // This requires integration with the event system
        _ = self;
    }

    /// Check if a property name is a cross-origin allowed property
    pub fn isCrossOriginAllowedProperty(property_name: []const u8) ?CrossOriginProperty {
        const map = std.StaticStringMap(CrossOriginProperty).initComptime(.{
            .{ "window", .window },
            .{ "self", .self_ },
            .{ "frames", .frames },
            .{ "top", .top },
            .{ "opener", .opener },
            .{ "parent", .parent },
            .{ "closed", .closed },
            .{ "length", .length },
            .{ "close", .close },
            .{ "focus", .focus },
            .{ "blur", .blur },
            .{ "postMessage", .postMessage },
            .{ "location", .location },
        });
        return map.get(property_name);
    }

    /// Attempt to access a property by name
    /// Returns error.SecurityError if cross-origin access to restricted property
    pub fn accessProperty(
        self: *const WindowProxy,
        accessor_origin: Origin,
        property_name: []const u8,
    ) WindowProxyError!void {
        // Same-origin access always allowed
        if (self.document_origin.isSameOrigin(accessor_origin)) {
            return;
        }

        // Cross-origin: check if property is in allowed list
        if (isCrossOriginAllowedProperty(property_name)) |_| {
            return; // Allowed
        }

        // Not in allowed list - SecurityError
        return WindowProxyError.SecurityError;
    }
};

// ============================================================================
// Tests
// ============================================================================

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

test "Origin - opaque origins" {
    const opaque1 = Origin.createOpaque();
    const opaque2 = Origin.createOpaque();
    const tuple = Origin.init("https", "example.com", 443);

    // Opaque origins are never same-origin
    try std.testing.expect(!opaque1.isSameOrigin(opaque2));
    try std.testing.expect(!opaque1.isSameOrigin(tuple));
    try std.testing.expect(!tuple.isSameOrigin(opaque1));
}

test "WindowProxy - same origin access" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const accessor = Origin.init("https", "example.com", 443);

    // Same-origin can access everything
    try std.testing.expect(proxy.isSameOriginAccess(accessor));
    try proxy.accessProperty(accessor, "document");
    try proxy.accessProperty(accessor, "localStorage");
}

test "WindowProxy - cross origin access restrictions" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const cross_origin_accessor = Origin.init("https", "other.com", 443);

    // Cross-origin cannot access restricted properties
    try std.testing.expect(!proxy.isSameOriginAccess(cross_origin_accessor));

    // Restricted properties throw SecurityError
    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin_accessor, "document"),
    );
    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin_accessor, "localStorage"),
    );
    try std.testing.expectError(
        WindowProxyError.SecurityError,
        proxy.accessProperty(cross_origin_accessor, "sessionStorage"),
    );
}

test "WindowProxy - cross origin allowed properties" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const cross_origin = Origin.init("https", "other.com", 443);

    // These properties ARE allowed cross-origin
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

test "WindowProxy - getClosed" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);

    try std.testing.expect(!proxy.getClosed());

    ctx.close();

    try std.testing.expect(proxy.getClosed());
}

test "WindowProxy - getLength" {
    const allocator = std.testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    const proxy = WindowProxy.init(allocator, parent);

    try std.testing.expectEqual(@as(u32, 0), proxy.getLength());

    // Add child
    _ = try BrowsingContext.initChild(allocator, parent);

    try std.testing.expectEqual(@as(u32, 1), proxy.getLength());
}

test "WindowProxy - isCrossOriginAllowedProperty" {
    // Allowed properties
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("window") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("self") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("postMessage") != null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("location") != null);

    // Not allowed
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("document") == null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("localStorage") == null);
    try std.testing.expect(WindowProxy.isCrossOriginAllowedProperty("alert") == null);
}
