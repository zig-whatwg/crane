//! The navigable's WindowProxy record on the navigation side: its browsing
//! context, and the origin of its active document as the navigation recorded
//! it, for navigation's own same-origin decisions (reusing the initial
//! about:blank document's Window, the unload timing of a same-origin
//! predecessor).
//!
//! It runs no access check. The WindowProxy script sees is the engine's
//! global proxy, and HTML 7.2.1's cross-origin checks are the engine's
//! [cross_origin_objects]: it asks the host's IsPlatformObjectSameOrigin
//! (dom.cross_origin) on every access, over the documents' shared origin
//! records (dom.origin_record), whose domains document.domain sets.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-windowproxy-exotic-object

const std = @import("std");
const Allocator = std.mem.Allocator;
const BrowsingContext = @import("browsing_context.zig").BrowsingContext;
const Navigables = @import("browsing_context.zig").Navigables;

/// Origin representation for security checks
/// Per URL Standard and HTML Standard
pub const Origin = struct {
    /// Tuple origin: (scheme, host, port). No domain: the origin a document
    /// shares, domain included, is dom.origin_record's record.
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
};

/// HTML "same origin-domain" over canonical origin serializations and the
/// separately stored domains: dom.origin_record's, the one comparison.
pub const sameOriginDomainValues = @import("dom").origin_record.sameOriginDomainValues;

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

/// A navigable's WindowProxy record (see the module comment): no access
/// checks - those are the engine's.
pub const WindowProxy = struct {
    /// The associated browsing context
    browsing_context: *BrowsingContext,

    /// The origin of the navigable's active document, as the navigation
    /// recorded it: for navigation's same-origin decisions only. Its domain
    /// is not here - document.domain changes the document's origin record.
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

test "WindowProxy - getClosed" {
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

test "WindowProxy - getLength" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const parent = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer parent.deinit();

    const proxy = WindowProxy.init(allocator, parent);

    try std.testing.expectEqual(@as(u32, 0), proxy.getLength());

    // Add child
    _ = try BrowsingContext.initChild(allocator, parent);

    try std.testing.expectEqual(@as(u32, 1), proxy.getLength());
}
