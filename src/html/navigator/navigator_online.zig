//! NavigatorOnLine Mixin
//!
//! HTML Standard § 8.8.1.3 - NavigatorOnLine
//! https://html.spec.whatwg.org/#navigatoronline
//!
//! This mixin provides online/offline status information.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Callback for online status change events
pub const OnlineChangeCallback = *const fn (online: bool) void;

/// NavigatorOnLine mixin implementation
/// Spec: HTML Standard § 8.8.1.3
pub const NavigatorOnLine = struct {
    /// Whether the browser is online
    on_line: bool,

    /// Optional backend for actual network status detection
    backend: ?*NetworkStatusBackend,

    const Self = @This();

    /// Initialize with default online status (true)
    pub fn init() Self {
        return .{
            .on_line = true,
            .backend = null,
        };
    }

    /// Initialize with custom backend for network status detection
    pub fn initWithBackend(backend: *NetworkStatusBackend) Self {
        return .{
            .on_line = backend.isOnline(),
            .backend = backend,
        };
    }

    // ========================================================================
    // NavigatorOnLine Properties
    // ========================================================================

    /// Check if online.
    /// Spec: "Must return false if the user agent is definitely offline
    /// (disconnected from the network). Must return true if the user
    /// agent might be online."
    pub fn isOnLine(self: *const Self) bool {
        if (self.backend) |backend| {
            return backend.isOnline();
        }
        return self.on_line;
    }

    /// Set online status (for testing/simulation or when no backend)
    pub fn setOnLine(self: *Self, online: bool) void {
        self.on_line = online;
    }

    /// Update online status from backend (if available)
    pub fn refresh(self: *Self) void {
        if (self.backend) |backend| {
            self.on_line = backend.isOnline();
        }
    }
};

/// Backend interface for network status detection
/// Embedders can implement this to provide real network status
pub const NetworkStatusBackend = struct {
    /// Implementation-specific context
    context: *anyopaque,

    /// VTable for backend operations
    vtable: *const VTable,

    const VTable = struct {
        /// Check if the network is currently online
        isOnline: *const fn (context: *anyopaque) bool,

        /// Register for online status change notifications
        addChangeListener: ?*const fn (context: *anyopaque, callback: OnlineChangeCallback) void,

        /// Remove a previously registered listener
        removeChangeListener: ?*const fn (context: *anyopaque, callback: OnlineChangeCallback) void,
    };

    pub fn isOnline(self: *const NetworkStatusBackend) bool {
        return self.vtable.isOnline(self.context);
    }

    pub fn addChangeListener(self: *NetworkStatusBackend, callback: OnlineChangeCallback) void {
        if (self.vtable.addChangeListener) |add| {
            add(self.context, callback);
        }
    }

    pub fn removeChangeListener(self: *NetworkStatusBackend, callback: OnlineChangeCallback) void {
        if (self.vtable.removeChangeListener) |remove| {
            remove(self.context, callback);
        }
    }
};

/// Stub backend that always returns true (online)
pub const StubNetworkStatusBackend = struct {
    backend: NetworkStatusBackend,

    const Self = @This();

    pub fn init() Self {
        return .{
            .backend = .{
                .context = undefined,
                .vtable = &vtable,
            },
        };
    }

    pub fn getBackend(self: *Self) *NetworkStatusBackend {
        self.backend.context = self;
        return &self.backend;
    }

    fn isOnline(_: *anyopaque) bool {
        return true;
    }

    const vtable = NetworkStatusBackend.VTable{
        .isOnline = isOnline,
        .addChangeListener = null,
        .removeChangeListener = null,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "NavigatorOnLine - default is online" {
    const online = NavigatorOnLine.init();
    try std.testing.expect(online.isOnLine());
}

test "NavigatorOnLine - setOnLine" {
    var online = NavigatorOnLine.init();

    try std.testing.expect(online.isOnLine());

    online.setOnLine(false);
    try std.testing.expect(!online.isOnLine());

    online.setOnLine(true);
    try std.testing.expect(online.isOnLine());
}

test "NavigatorOnLine - with stub backend" {
    var stub = StubNetworkStatusBackend.init();
    const online = NavigatorOnLine.initWithBackend(stub.getBackend());

    try std.testing.expect(online.isOnLine());
}
