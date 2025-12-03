//! NavigatorCookies Mixin
//!
//! HTML Standard § 8.8.1.6 - NavigatorCookies
//! https://html.spec.whatwg.org/#navigatorcookies
//!
//! This mixin provides cookie enabled status.

const std = @import("std");

/// NavigatorCookies mixin implementation
/// Spec: HTML Standard § 8.8.1.6
///
/// Note: This is only exposed in Window context, not workers.
pub const NavigatorCookies = struct {
    /// Whether cookies are enabled
    cookie_enabled: bool,

    /// Optional backend for actual cookie status detection
    backend: ?*CookieStatusBackend,

    const Self = @This();

    /// Initialize with default cookie status (true)
    pub fn init() Self {
        return .{
            .cookie_enabled = true,
            .backend = null,
        };
    }

    /// Initialize with custom backend
    pub fn initWithBackend(backend: *CookieStatusBackend) Self {
        return .{
            .cookie_enabled = backend.areCookiesEnabled(),
            .backend = backend,
        };
    }

    // ========================================================================
    // NavigatorCookies Properties
    // ========================================================================

    /// Check if cookies are enabled.
    /// Spec: "Must return true if the user agent attempts to handle cookies
    /// per the cookie specification, and false if it ignores cookie change
    /// requests."
    pub fn isCookieEnabled(self: *const Self) bool {
        if (self.backend) |backend| {
            return backend.areCookiesEnabled();
        }
        return self.cookie_enabled;
    }

    /// Set cookie enabled status (for testing/simulation)
    pub fn setCookieEnabled(self: *Self, enabled: bool) void {
        self.cookie_enabled = enabled;
    }
};

/// Backend interface for cookie status detection
/// Embedders can implement this to provide real cookie status
pub const CookieStatusBackend = struct {
    /// Implementation-specific context
    context: *anyopaque,

    /// VTable for backend operations
    vtable: *const VTable,

    const VTable = struct {
        /// Check if cookies are enabled
        areCookiesEnabled: *const fn (context: *anyopaque) bool,
    };

    pub fn areCookiesEnabled(self: *const CookieStatusBackend) bool {
        return self.vtable.areCookiesEnabled(self.context);
    }
};

/// Stub backend that always returns true (cookies enabled)
pub const StubCookieStatusBackend = struct {
    backend: CookieStatusBackend,

    const Self_ = @This();

    pub fn init() Self_ {
        return .{
            .backend = .{
                .context = undefined,
                .vtable = &vtable,
            },
        };
    }

    pub fn getBackend(self: *Self_) *CookieStatusBackend {
        self.backend.context = self;
        return &self.backend;
    }

    fn areCookiesEnabled(_: *anyopaque) bool {
        return true;
    }

    const vtable = CookieStatusBackend.VTable{
        .areCookiesEnabled = areCookiesEnabled,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "NavigatorCookies - default is enabled" {
    const cookies = NavigatorCookies.init();
    try std.testing.expect(cookies.isCookieEnabled());
}

test "NavigatorCookies - setCookieEnabled" {
    var cookies = NavigatorCookies.init();

    try std.testing.expect(cookies.isCookieEnabled());

    cookies.setCookieEnabled(false);
    try std.testing.expect(!cookies.isCookieEnabled());

    cookies.setCookieEnabled(true);
    try std.testing.expect(cookies.isCookieEnabled());
}

test "NavigatorCookies - with stub backend" {
    var stub = StubCookieStatusBackend.init();
    const cookies = NavigatorCookies.initWithBackend(stub.getBackend());

    try std.testing.expect(cookies.isCookieEnabled());
}
