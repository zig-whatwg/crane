//! IndexedDB Version Change Event Implementation
//!
//! Implements IDBVersionChangeEvent per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbversionchangeevent
//!
//! ## Properties
//!
//! - `oldVersion` - Previous database version
//! - `newVersion` - New database version (null for deletion)
//!
//! ## Usage
//!
//! Version change events are fired when:
//! - A database is being upgraded (new version > old version)
//! - A database is being deleted (newVersion is null)
//! - Another connection requests a version change
//!
//! ## Spec Reference
//!
//! Algorithm: "fire a version change event"
//! Location: specs/algorithms/IndexedDB-3.json lines 359-388

const std = @import("std");

/// Event initialization options
pub const IDBVersionChangeEventInit = struct {
    /// Previous database version
    old_version: u64 = 0,
    /// New database version (null for deletion)
    new_version: ?u64 = null,
    /// Whether event bubbles
    bubbles: bool = false,
    /// Whether event is cancelable
    cancelable: bool = false,
};

/// IDBVersionChangeEvent interface
/// https://w3c.github.io/IndexedDB/#idbversionchangeevent
///
/// Event fired when database version changes.
pub const IDBVersionChangeEvent = struct {
    const Self = @This();

    /// Event type
    event_type: EventType,

    /// Previous database version
    old_version: u64,

    /// New database version (null for deletion)
    new_version: ?u64,

    /// Whether event bubbles (always false per spec)
    bubbles: bool,

    /// Whether event is cancelable (always false per spec)
    cancelable: bool,

    /// Whether default was prevented
    default_prevented: bool,

    /// Event phase
    event_phase: EventPhase,

    /// Target
    target: ?*anyopaque,

    /// Current target
    current_target: ?*anyopaque,

    /// Whether propagation was stopped
    propagation_stopped: bool,

    /// Whether immediate propagation was stopped
    immediate_propagation_stopped: bool,

    /// Event types for IDBVersionChangeEvent
    pub const EventType = enum {
        /// Fired when an upgrade is needed
        upgradeneeded,
        /// Fired on successful operation
        success,
        /// Fired when database is blocked
        blocked,
        /// Fired when version change is requested on other connections
        versionchange,
    };

    /// Event phase
    pub const EventPhase = enum(u8) {
        none = 0,
        capturing_phase = 1,
        at_target = 2,
        bubbling_phase = 3,
    };

    /// Create a new version change event
    /// https://w3c.github.io/IndexedDB/#fire-a-version-change-event
    ///
    /// Steps from spec:
    /// 1. Create event using IDBVersionChangeEvent
    /// 2. Set event's type attribute
    /// 3. Set bubbles and cancelable to false
    /// 4. Set oldVersion and newVersion
    /// 5. Dispatch event
    pub fn init(event_type: EventType, options: IDBVersionChangeEventInit) Self {
        return Self{
            .event_type = event_type,
            .old_version = options.old_version,
            .new_version = options.new_version,
            .bubbles = false, // Always false per spec
            .cancelable = false, // Always false per spec
            .default_prevented = false,
            .event_phase = .none,
            .target = null,
            .current_target = null,
            .propagation_stopped = false,
            .immediate_propagation_stopped = false,
        };
    }

    /// Create an upgradeneeded event
    pub fn upgradeneeded(old_version: u64, new_version: u64) Self {
        return init(.upgradeneeded, .{
            .old_version = old_version,
            .new_version = new_version,
        });
    }

    /// Create a blocked event
    pub fn blocked(old_version: u64, new_version: ?u64) Self {
        return init(.blocked, .{
            .old_version = old_version,
            .new_version = new_version,
        });
    }

    /// Create a versionchange event
    pub fn versionchange(old_version: u64, new_version: ?u64) Self {
        return init(.versionchange, .{
            .old_version = old_version,
            .new_version = new_version,
        });
    }

    /// Create a success event (for delete operations)
    pub fn success(old_version: u64) Self {
        return init(.success, .{
            .old_version = old_version,
            .new_version = null,
        });
    }

    /// Prevent default action
    pub fn preventDefault(self: *Self) void {
        if (self.cancelable) {
            self.default_prevented = true;
        }
    }

    /// Stop propagation
    pub fn stopPropagation(self: *Self) void {
        self.propagation_stopped = true;
    }

    /// Stop immediate propagation
    pub fn stopImmediatePropagation(self: *Self) void {
        self.propagation_stopped = true;
        self.immediate_propagation_stopped = true;
    }

    /// Get event type as string
    pub fn getType(self: *const Self) []const u8 {
        return switch (self.event_type) {
            .upgradeneeded => "upgradeneeded",
            .success => "success",
            .blocked => "blocked",
            .versionchange => "versionchange",
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBVersionChangeEvent - upgradeneeded" {
    const event = IDBVersionChangeEvent.upgradeneeded(1, 2);

    try std.testing.expectEqual(IDBVersionChangeEvent.EventType.upgradeneeded, event.event_type);
    try std.testing.expectEqual(@as(u64, 1), event.old_version);
    try std.testing.expectEqual(@as(?u64, 2), event.new_version);
    try std.testing.expect(!event.bubbles);
    try std.testing.expect(!event.cancelable);
}

test "IDBVersionChangeEvent - blocked" {
    const event = IDBVersionChangeEvent.blocked(1, 2);

    try std.testing.expectEqual(IDBVersionChangeEvent.EventType.blocked, event.event_type);
    try std.testing.expectEqual(@as(u64, 1), event.old_version);
    try std.testing.expectEqual(@as(?u64, 2), event.new_version);
}

test "IDBVersionChangeEvent - versionchange" {
    const event = IDBVersionChangeEvent.versionchange(1, null);

    try std.testing.expectEqual(IDBVersionChangeEvent.EventType.versionchange, event.event_type);
    try std.testing.expectEqual(@as(u64, 1), event.old_version);
    try std.testing.expect(event.new_version == null);
}

test "IDBVersionChangeEvent - success" {
    const event = IDBVersionChangeEvent.success(1);

    try std.testing.expectEqual(IDBVersionChangeEvent.EventType.success, event.event_type);
    try std.testing.expectEqual(@as(u64, 1), event.old_version);
    try std.testing.expect(event.new_version == null);
}

test "IDBVersionChangeEvent - getType" {
    const event1 = IDBVersionChangeEvent.upgradeneeded(1, 2);
    try std.testing.expectEqualStrings("upgradeneeded", event1.getType());

    const event2 = IDBVersionChangeEvent.blocked(1, 2);
    try std.testing.expectEqualStrings("blocked", event2.getType());

    const event3 = IDBVersionChangeEvent.versionchange(1, null);
    try std.testing.expectEqualStrings("versionchange", event3.getType());

    const event4 = IDBVersionChangeEvent.success(1);
    try std.testing.expectEqualStrings("success", event4.getType());
}

test "IDBVersionChangeEvent - stopPropagation" {
    var event = IDBVersionChangeEvent.upgradeneeded(1, 2);

    try std.testing.expect(!event.propagation_stopped);
    event.stopPropagation();
    try std.testing.expect(event.propagation_stopped);
}

test "IDBVersionChangeEvent - stopImmediatePropagation" {
    var event = IDBVersionChangeEvent.upgradeneeded(1, 2);

    try std.testing.expect(!event.propagation_stopped);
    try std.testing.expect(!event.immediate_propagation_stopped);
    event.stopImmediatePropagation();
    try std.testing.expect(event.propagation_stopped);
    try std.testing.expect(event.immediate_propagation_stopped);
}
