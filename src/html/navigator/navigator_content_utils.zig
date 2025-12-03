//! NavigatorContentUtils Mixin
//!
//! HTML Standard § 8.8.1.5 - NavigatorContentUtils
//! https://html.spec.whatwg.org/#navigatorcontentutils
//!
//! This mixin provides protocol handler registration.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Error type for protocol handler operations
pub const ProtocolHandlerError = error{
    /// The scheme is not allowed
    SecurityError,
    /// The scheme is invalid
    SyntaxError,
    /// Out of memory
    OutOfMemory,
};

/// A registered protocol handler
pub const ProtocolHandler = struct {
    scheme: []const u8,
    url: []const u8,
};

/// NavigatorContentUtils mixin implementation
/// Spec: HTML Standard § 8.8.1.5
///
/// Note: This is only exposed in Window context, not workers.
/// [SecureContext] required for both methods.
pub const NavigatorContentUtils = struct {
    allocator: Allocator,

    /// Registered protocol handlers (dynamically sized)
    handlers: []ProtocolHandler,
    capacity: usize,

    const Self = @This();

    /// Allowed safelisted schemes that can be registered
    const SAFELISTED_SCHEMES = [_][]const u8{
        "bitcoin",
        "cabal",
        "dat",
        "did",
        "dweb",
        "ethereum",
        "geo",
        "hyper",
        "im",
        "ipfs",
        "ipns",
        "irc",
        "ircs",
        "magnet",
        "mailto",
        "matrix",
        "mms",
        "news",
        "nntp",
        "openpgp4fpr",
        "sftp",
        "sip",
        "sms",
        "smsto",
        "ssh",
        "tel",
        "urn",
        "webcal",
        "wtai",
        "xmpp",
    };

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .handlers = &[_]ProtocolHandler{},
            .capacity = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.handlers) |handler| {
            self.allocator.free(handler.scheme);
            self.allocator.free(handler.url);
        }
        if (self.capacity > 0) {
            self.allocator.free(self.handlers.ptr[0..self.capacity]);
        }
    }

    /// Ensure capacity for at least one more handler
    fn ensureCapacity(self: *Self) !void {
        if (self.handlers.len < self.capacity) return;

        const new_capacity = if (self.capacity == 0) 4 else self.capacity * 2;
        const new_handlers = try self.allocator.alloc(ProtocolHandler, new_capacity);

        // Copy existing handlers
        @memcpy(new_handlers[0..self.handlers.len], self.handlers);

        // Free old storage
        if (self.capacity > 0) {
            self.allocator.free(self.handlers.ptr[0..self.capacity]);
        }

        self.handlers.ptr = new_handlers.ptr;
        self.capacity = new_capacity;
    }

    // ========================================================================
    // NavigatorContentUtils Methods
    // ========================================================================

    /// Register a protocol handler.
    /// Spec: HTML Standard § 8.8.1.5
    ///
    /// The scheme must be either:
    /// - A safelisted scheme from the spec
    /// - A custom scheme starting with "web+"
    ///
    /// The URL must contain a %s placeholder.
    pub fn registerProtocolHandler(
        self: *Self,
        scheme: []const u8,
        url: []const u8,
    ) ProtocolHandlerError!void {
        // Validate scheme
        if (!self.isValidScheme(scheme)) {
            return ProtocolHandlerError.SecurityError;
        }

        // URL must contain %s placeholder
        if (std.mem.indexOf(u8, url, "%s") == null) {
            return ProtocolHandlerError.SyntaxError;
        }

        // Check if already registered
        for (self.handlers, 0..) |handler, i| {
            if (std.ascii.eqlIgnoreCase(handler.scheme, scheme)) {
                // Update existing handler
                self.allocator.free(self.handlers[i].url);
                self.handlers[i].url = try self.allocator.dupe(u8, url);
                return;
            }
        }

        // Add new handler
        try self.ensureCapacity();
        const new_scheme = try self.allocator.dupe(u8, scheme);
        errdefer self.allocator.free(new_scheme);
        const new_url = try self.allocator.dupe(u8, url);

        self.handlers.len += 1;
        self.handlers[self.handlers.len - 1] = .{
            .scheme = new_scheme,
            .url = new_url,
        };
    }

    /// Unregister a protocol handler.
    /// Spec: HTML Standard § 8.8.1.5
    pub fn unregisterProtocolHandler(
        self: *Self,
        scheme: []const u8,
        url: []const u8,
    ) ProtocolHandlerError!void {
        // Validate scheme
        if (!self.isValidScheme(scheme)) {
            return ProtocolHandlerError.SecurityError;
        }

        // Find and remove the handler
        for (self.handlers, 0..) |handler, i| {
            if (std.ascii.eqlIgnoreCase(handler.scheme, scheme) and
                std.mem.eql(u8, handler.url, url))
            {
                // Free the handler data
                self.allocator.free(handler.scheme);
                self.allocator.free(handler.url);

                // Shift remaining handlers down
                if (i + 1 < self.handlers.len) {
                    std.mem.copyForwards(
                        ProtocolHandler,
                        self.handlers[i .. self.handlers.len - 1],
                        self.handlers[i + 1 .. self.handlers.len],
                    );
                }
                self.handlers.len -= 1;
                return;
            }
        }
    }

    /// Check if a scheme is valid for registration
    fn isValidScheme(self: *const Self, scheme: []const u8) bool {
        _ = self;

        // Check safelisted schemes
        for (SAFELISTED_SCHEMES) |safelisted| {
            if (std.ascii.eqlIgnoreCase(scheme, safelisted)) {
                return true;
            }
        }

        // Check for web+ prefix (must be at least 5 chars: web+x)
        if (scheme.len >= 5 and
            std.ascii.startsWithIgnoreCase(scheme, "web+"))
        {
            // The part after web+ must be one or more ASCII lower alpha
            const suffix = scheme[4..];
            for (suffix) |c| {
                if (c < 'a' or c > 'z') {
                    return false;
                }
            }
            return suffix.len >= 1;
        }

        return false;
    }

    /// Get number of registered handlers
    pub fn getHandlerCount(self: *const Self) usize {
        return self.handlers.len;
    }

    /// Get handler for a specific scheme
    pub fn getHandler(self: *const Self, scheme: []const u8) ?ProtocolHandler {
        for (self.handlers) |handler| {
            if (std.ascii.eqlIgnoreCase(handler.scheme, scheme)) {
                return handler;
            }
        }
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "NavigatorContentUtils - registerProtocolHandler" {
    const allocator = std.testing.allocator;

    var utils = NavigatorContentUtils.init(allocator);
    defer utils.deinit();

    // Register a safelisted scheme
    try utils.registerProtocolHandler("mailto", "https://mail.example.com/?to=%s");

    try std.testing.expectEqual(@as(usize, 1), utils.getHandlerCount());
    const handler = utils.getHandler("mailto");
    try std.testing.expect(handler != null);
    try std.testing.expectEqualStrings("mailto", handler.?.scheme);
}

test "NavigatorContentUtils - web+ scheme" {
    const allocator = std.testing.allocator;

    var utils = NavigatorContentUtils.init(allocator);
    defer utils.deinit();

    // Register a custom web+ scheme
    try utils.registerProtocolHandler("web+custom", "https://example.com/?uri=%s");

    const handler = utils.getHandler("web+custom");
    try std.testing.expect(handler != null);
}

test "NavigatorContentUtils - invalid scheme" {
    const allocator = std.testing.allocator;

    var utils = NavigatorContentUtils.init(allocator);
    defer utils.deinit();

    // Try to register an invalid scheme
    const result = utils.registerProtocolHandler("http", "https://example.com/?uri=%s");
    try std.testing.expectError(ProtocolHandlerError.SecurityError, result);
}

test "NavigatorContentUtils - missing placeholder" {
    const allocator = std.testing.allocator;

    var utils = NavigatorContentUtils.init(allocator);
    defer utils.deinit();

    // URL without %s placeholder
    const result = utils.registerProtocolHandler("mailto", "https://mail.example.com/");
    try std.testing.expectError(ProtocolHandlerError.SyntaxError, result);
}

test "NavigatorContentUtils - unregisterProtocolHandler" {
    const allocator = std.testing.allocator;

    var utils = NavigatorContentUtils.init(allocator);
    defer utils.deinit();

    try utils.registerProtocolHandler("mailto", "https://mail.example.com/?to=%s");
    try std.testing.expectEqual(@as(usize, 1), utils.getHandlerCount());

    try utils.unregisterProtocolHandler("mailto", "https://mail.example.com/?to=%s");
    try std.testing.expectEqual(@as(usize, 0), utils.getHandlerCount());
}
