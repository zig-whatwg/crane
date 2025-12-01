//! InstallEvent
//!
//! Event fired during service worker installation.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#installevent-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=ServiceWorker]
//! interface InstallEvent : ExtendableEvent {
//!   Promise<undefined> addRoutes(sequence<RouterRule> rules);
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const ExtendableEvent = @import("extendable_event.zig").ExtendableEvent;
const ExtendableEventInit = @import("extendable_event.zig").ExtendableEventInit;

const router = @import("router.zig");
const RouterRule = router.RouterRule;

const iface_types = @import("../interfaces/types.zig");
const VoidPromise = iface_types.VoidPromise;

/// InstallEvent.
///
/// Fired during service worker installation phase.
/// Can register static router rules via addRoutes().
///
/// Spec: https://w3c.github.io/ServiceWorker/#installevent-interface
pub const InstallEvent = struct {
    allocator: Allocator,

    /// Base ExtendableEvent.
    base: *ExtendableEvent,
    owns_base: bool = false,

    /// Router rules added via addRoutes().
    added_routes: std.ArrayListUnmanaged(RouterRule),

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new InstallEvent.
    pub fn init(allocator: Allocator, options: ExtendableEventInit) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const base = try ExtendableEvent.init(allocator, "install", options);
        errdefer base.deinit();

        self.* = .{
            .allocator = allocator,
            .base = base,
            .owns_base = true,
            .added_routes = .{},
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.added_routes.deinit(self.allocator);

        if (self.owns_base) {
            self.base.deinit();
        }

        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Add static router rules during installation.
    ///
    /// These rules are evaluated before the fetch event is dispatched,
    /// allowing certain requests to bypass the service worker entirely.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#install-event-addroutes
    pub fn addRoutes(self: *Self, rules: []const RouterRule) !VoidPromise {
        var promise = VoidPromise.init();

        // Check if we can still extend
        if (!self.base.extensions_allowed) {
            promise.reject(error.InvalidStateError);
            return promise;
        }

        // Add rules
        for (rules) |rule| {
            try self.added_routes.append(self.allocator, rule);
        }

        promise.resolve({});
        return promise;
    }

    /// Get added routes.
    pub fn getAddedRoutes(self: *const Self) []const RouterRule {
        return self.added_routes.items;
    }

    // =========================================================================
    // Delegated to ExtendableEvent
    // =========================================================================

    pub fn waitUntil(self: *Self) !u64 {
        return self.base.waitUntil();
    }

    pub fn resolvePromise(self: *Self, promise_id: u64) void {
        self.base.resolvePromise(promise_id);
    }

    pub fn rejectPromise(self: *Self, promise_id: u64, msg: ?[]const u8) void {
        self.base.rejectPromise(promise_id, msg);
    }

    pub fn startDispatch(self: *Self, target_ptr: *anyopaque) void {
        self.base.startDispatch(target_ptr);
    }

    pub fn endDispatch(self: *Self) void {
        self.base.endDispatch();
    }

    pub fn isComplete(self: *const Self) bool {
        return self.base.isComplete();
    }

    pub fn hasRejection(self: *const Self) bool {
        return self.base.hasRejection();
    }

    pub fn canExtend(self: *const Self) bool {
        return self.base.canExtend();
    }

    pub fn getType(self: *const Self) []const u8 {
        return self.base.getType();
    }

    pub fn setTimeout(self: *Self) void {
        self.base.setTimeout();
    }

    pub fn isTimedOut(self: *const Self) bool {
        return self.base.isTimedOut();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "InstallEvent.init and deinit" {
    const allocator = std.testing.allocator;

    const event = try InstallEvent.init(allocator, .{});
    defer event.deinit();

    try std.testing.expectEqualStrings("install", event.getType());
    try std.testing.expect(event.canExtend());
}

test "InstallEvent.addRoutes" {
    const allocator = std.testing.allocator;

    const event = try InstallEvent.init(allocator, .{});
    defer event.deinit();

    const rules = [_]RouterRule{
        .{
            .condition = .{ .url_pattern = .{ .pathname = "/static/*" } },
            .source = .network,
        },
        .{
            .condition = .{ .url_pattern = .{ .pathname = "/api/*" } },
            .source = .fetch_event,
        },
    };

    const promise = try event.addRoutes(&rules);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expectEqual(@as(usize, 2), event.getAddedRoutes().len);
}

test "InstallEvent.addRoutes after dispatch ends" {
    const allocator = std.testing.allocator;

    const event = try InstallEvent.init(allocator, .{});
    defer event.deinit();

    // End dispatch
    var dummy: u8 = 0;
    event.startDispatch(&dummy);
    event.endDispatch();

    // addRoutes should fail
    const rules = [_]RouterRule{};
    const promise = try event.addRoutes(&rules);
    try std.testing.expect(promise.isRejected());
}

test "InstallEvent.waitUntil" {
    const allocator = std.testing.allocator;

    const event = try InstallEvent.init(allocator, .{});
    defer event.deinit();

    const promise_id = try event.waitUntil();
    try std.testing.expect(!event.isComplete());

    event.resolvePromise(promise_id);
    try std.testing.expect(event.isComplete());
}
