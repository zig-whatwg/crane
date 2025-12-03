//! Web Storage API Implementation
//!
//! HTML Standard - Web storage
//! https://html.spec.whatwg.org/multipage/webstorage.html
//!
//! This module implements the Storage interface for localStorage and sessionStorage.
//!
//! ## Features
//!
//! - **Storage interface**: length, key(), getItem(), setItem(), removeItem(), clear()
//! - **localStorage**: Persistent storage keyed by origin
//! - **sessionStorage**: Session-scoped storage keyed by (browsing_context_id, origin)
//! - **StorageEvent**: Cross-window notification of storage changes
//! - **Quota enforcement**: 5 MiB per origin per storage type
//!
//! ## Usage
//!
//! ```zig
//! const storage = @import("html").storage;
//!
//! // Get localStorage for an origin
//! var local = try storage.getLocalStorage(allocator, "https://example.com");
//! defer local.deinit();
//!
//! // Store and retrieve values
//! try local.setItem("key", "value");
//! const value = local.getItem("key"); // "value"
//!
//! // Get sessionStorage for a browsing context
//! var session = try storage.getSessionStorage(allocator, context_id, "https://example.com");
//! defer session.deinit();
//! ```
//!
//! ## Specification References
//!
//! - HTML Standard § 12.2.1: The Storage interface
//! - HTML Standard § 12.2.2: The sessionStorage getter
//! - HTML Standard § 12.2.3: The localStorage getter
//! - Storage Standard: https://storage.spec.whatwg.org/

const std = @import("std");
const storage_standard = @import("storage");

/// Error types for Storage operations
pub const StorageError = error{
    /// The operation would exceed the storage quota
    QuotaExceededError,
    /// Access to storage was denied (opaque origin or policy violation)
    SecurityError,
    /// Out of memory
    OutOfMemory,
    /// Invalid key (null not allowed in some contexts)
    InvalidKey,
};

/// Storage type: local or session
pub const StorageType = enum {
    local,
    session,
};

/// Storage interface implementation
/// HTML Standard § 12.2.1
///
/// A Storage object provides access to a list of key/value pairs, which are
/// sometimes called items. Keys are strings. Any string (including the empty
/// string) is a valid key. Values are similarly strings.
pub const Storage = struct {
    /// Allocator for this storage instance
    allocator: std.mem.Allocator,

    /// The storage proxy map backing this storage
    map: storage_standard.StorageProxyMap,

    /// Storage type (local or session)
    storage_type: StorageType,

    /// Origin string for this storage
    origin: []const u8,

    /// Whether we own the origin string
    origin_owned: bool,

    /// Optional event broadcaster for cross-window notifications
    broadcaster: ?*StorageEventBroadcaster,

    /// Quota limit in bytes (default: 5 MiB)
    quota: u64,

    const Self = @This();

    /// Default quota per storage type (5 MiB per spec)
    pub const DEFAULT_QUOTA: u64 = 5 * 1024 * 1024;

    /// Create a new Storage object with the given backing map
    pub fn init(
        allocator: std.mem.Allocator,
        map: storage_standard.StorageProxyMap,
        storage_type: StorageType,
        origin: []const u8,
    ) !Self {
        const origin_copy = try allocator.dupe(u8, origin);
        return Self{
            .allocator = allocator,
            .map = map,
            .storage_type = storage_type,
            .origin = origin_copy,
            .origin_owned = true,
            .broadcaster = null,
            .quota = DEFAULT_QUOTA,
        };
    }

    /// Create with borrowed origin (caller maintains ownership)
    pub fn initBorrowed(
        allocator: std.mem.Allocator,
        map: storage_standard.StorageProxyMap,
        storage_type: StorageType,
        origin: []const u8,
    ) Self {
        return Self{
            .allocator = allocator,
            .map = map,
            .storage_type = storage_type,
            .origin = origin,
            .origin_owned = false,
            .broadcaster = null,
            .quota = DEFAULT_QUOTA,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.origin_owned) {
            self.allocator.free(self.origin);
        }
    }

    /// Set the event broadcaster for cross-window notifications
    pub fn setBroadcaster(self: *Self, broadcaster: *StorageEventBroadcaster) void {
        self.broadcaster = broadcaster;
    }

    // ========================================================================
    // Storage interface methods (HTML Standard § 12.2.1)
    // ========================================================================

    /// Returns the number of key/value pairs.
    /// HTML Standard § 12.2.1 - length getter
    pub fn length(self: *const Self) usize {
        return self.map.count();
    }

    /// Returns the name of the nth key, or null if n is greater than or
    /// equal to the number of key/value pairs.
    /// HTML Standard § 12.2.1 - key(index) method
    pub fn key(self: *const Self, index: usize) ?[]const u8 {
        // Step 1: If index is >= size, return null
        if (index >= self.map.count()) {
            return null;
        }

        // Step 2-3: Get keys and return the one at index
        // Note: This requires iteration since we don't maintain insertion order
        var iter = self.map.backing_map.iterator();
        var i: usize = 0;
        while (iter.next()) |entry| : (i += 1) {
            if (i == index) {
                return entry.key_ptr.*;
            }
        }
        return null;
    }

    /// Returns the current value associated with the given key, or null
    /// if the given key does not exist.
    /// HTML Standard § 12.2.1 - getItem(key) method
    pub fn getItem(self: *const Self, key_name: []const u8) ?[]const u8 {
        // Step 1-2: Return value if exists, null otherwise
        return self.map.get(key_name);
    }

    /// Sets the value of the pair identified by key to value, creating a
    /// new key/value pair if none existed for key previously.
    /// HTML Standard § 12.2.1 - setItem(key, value) method
    ///
    /// Throws QuotaExceededError if the new value couldn't be set.
    /// Dispatches a storage event on Window objects with equivalent Storage.
    pub fn setItem(self: *Self, key_name: []const u8, value: []const u8) StorageError!void {
        // Step 1: Let oldValue be null
        const old_value = self.map.get(key_name);

        // Step 2: Let reorder be true
        var should_reorder = true;

        // Step 3: If key exists
        if (old_value) |old| {
            // Step 3.1: Set oldValue to existing value (already done)
            // Step 3.2: If oldValue is value, return
            if (std.mem.eql(u8, old, value)) {
                return;
            }
            // Step 3.3: Set reorder to false
            should_reorder = false;
        }

        // Step 4: Check quota
        try self.checkQuota(key_name, value, old_value);

        // Step 5: Set map[key] to value
        self.map.set(key_name, value) catch return error.OutOfMemory;

        // Step 6: If reorder is true, reorder this
        if (should_reorder) {
            self.reorder();
        }

        // Step 7: Broadcast with key, oldValue, and value
        self.broadcast(key_name, old_value, value);
    }

    /// Removes the key/value pair with the given key, if one exists.
    /// HTML Standard § 12.2.1 - removeItem(key) method
    ///
    /// Dispatches a storage event on Window objects with equivalent Storage.
    pub fn removeItem(self: *Self, key_name: []const u8) void {
        // Step 1: If key does not exist, return
        const old_value = self.map.get(key_name) orelse return;

        // Step 2: Set oldValue (already done)
        // We need to copy the old value before deletion for broadcast
        var old_value_copy: ?[]u8 = null;
        if (self.broadcaster != null) {
            old_value_copy = self.allocator.dupe(u8, old_value) catch null;
        }
        defer if (old_value_copy) |v| self.allocator.free(v);

        // Step 3: Remove map[key]
        _ = self.map.delete(key_name);

        // Step 4: Reorder this
        self.reorder();

        // Step 5: Broadcast with key, oldValue, and null
        if (old_value_copy) |old| {
            self.broadcast(key_name, old, null);
        } else {
            self.broadcast(key_name, null, null);
        }
    }

    /// Removes all key/value pairs, if there are any.
    /// HTML Standard § 12.2.1 - clear() method
    ///
    /// Dispatches a storage event on Window objects with equivalent Storage.
    pub fn clear(self: *Self) void {
        // Step 1: Clear map
        self.map.clear();

        // Step 2: Broadcast with null, null, and null
        self.broadcast(null, null, null);
    }

    // ========================================================================
    // Internal helper methods
    // ========================================================================

    /// Check if the new value would exceed the quota
    fn checkQuota(self: *const Self, key_name: []const u8, new_value: []const u8, old_value: ?[]const u8) StorageError!void {
        // Calculate current usage
        var current_usage: u64 = 0;
        var iter = self.map.backing_map.iterator();
        while (iter.next()) |entry| {
            current_usage += entry.key_ptr.len;
            current_usage += entry.value_ptr.len;
        }

        // Calculate the change in storage
        var new_usage = current_usage;

        // Remove old value contribution if replacing
        if (old_value) |old| {
            new_usage -= key_name.len;
            new_usage -= old.len;
        }

        // Add new value contribution
        new_usage += key_name.len;
        new_usage += new_value.len;

        // Check quota
        if (new_usage > self.quota) {
            return error.QuotaExceededError;
        }
    }

    /// Reorder the storage entries (implementation-defined)
    /// HTML Standard § 12.2.1 - reorder algorithm
    fn reorder(self: *Self) void {
        // The spec says reorder is implementation-defined.
        // We keep insertion order, so this is a no-op.
        _ = self;
    }

    /// Broadcast a storage event to other windows
    /// HTML Standard § 12.2.1 - broadcast algorithm
    fn broadcast(self: *Self, key_name: ?[]const u8, old_value: ?[]const u8, new_value: ?[]const u8) void {
        if (self.broadcaster) |b| {
            b.broadcast(StorageEventData{
                .key = key_name,
                .old_value = old_value,
                .new_value = new_value,
                .storage_type = self.storage_type,
                .origin = self.origin,
            });
        }
    }

    /// Get all keys (for supported property names)
    pub fn keys(self: *const Self, allocator: std.mem.Allocator) ![][]const u8 {
        const count = self.map.count();
        if (count == 0) return &[_][]const u8{};

        var result = try allocator.alloc([]const u8, count);
        errdefer allocator.free(result);

        var iter = self.map.backing_map.iterator();
        var i: usize = 0;
        while (iter.next()) |entry| : (i += 1) {
            result[i] = try allocator.dupe(u8, entry.key_ptr.*);
        }

        return result;
    }

    /// Free keys array allocated by keys()
    pub fn freeKeys(allocator: std.mem.Allocator, key_list: [][]const u8) void {
        for (key_list) |k| {
            allocator.free(k);
        }
        allocator.free(key_list);
    }
};

/// Data for a storage event
pub const StorageEventData = struct {
    /// The key that was changed (null for clear())
    key: ?[]const u8,
    /// The old value (null if new or clear)
    old_value: ?[]const u8,
    /// The new value (null if removed or clear)
    new_value: ?[]const u8,
    /// The storage type
    storage_type: StorageType,
    /// The origin
    origin: []const u8,
};

/// Interface for broadcasting storage events across windows
pub const StorageEventBroadcaster = struct {
    /// Context pointer for the broadcaster implementation
    context: *anyopaque,

    /// Function to broadcast an event
    broadcastFn: *const fn (context: *anyopaque, data: StorageEventData) void,

    /// Broadcast a storage event
    pub fn broadcast(self: *StorageEventBroadcaster, data: StorageEventData) void {
        self.broadcastFn(self.context, data);
    }
};

/// StorageEvent interface
/// HTML Standard § 12.2.4
///
/// The StorageEvent interface represents storage change events.
pub const StorageEvent = struct {
    /// The key of the storage item being changed
    key: ?[]const u8,
    /// The old value of the key
    old_value: ?[]const u8,
    /// The new value of the key
    new_value: ?[]const u8,
    /// The URL of the document whose storage changed
    url: []const u8,
    /// The Storage object that was affected (optional, as we can't always provide it)
    storage_area_type: ?StorageType,

    // Event base properties
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,

    allocator: ?std.mem.Allocator,

    const Self = @This();

    /// Create a new StorageEvent
    pub fn init(allocator: std.mem.Allocator, data: StorageEventData, url: []const u8) !Self {
        return Self{
            .key = if (data.key) |k| try allocator.dupe(u8, k) else null,
            .old_value = if (data.old_value) |v| try allocator.dupe(u8, v) else null,
            .new_value = if (data.new_value) |v| try allocator.dupe(u8, v) else null,
            .url = try allocator.dupe(u8, url),
            .storage_area_type = data.storage_type,
            .event_type = "storage",
            .bubbles = false,
            .cancelable = false,
            .allocator = allocator,
        };
    }

    /// Create with borrowed strings (no allocation)
    pub fn initBorrowed(data: StorageEventData, url: []const u8) Self {
        return Self{
            .key = data.key,
            .old_value = data.old_value,
            .new_value = data.new_value,
            .url = url,
            .storage_area_type = data.storage_type,
            .event_type = "storage",
            .bubbles = false,
            .cancelable = false,
            .allocator = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            if (self.key) |k| alloc.free(k);
            if (self.old_value) |v| alloc.free(v);
            if (self.new_value) |v| alloc.free(v);
            alloc.free(self.url);
        }
    }

    /// Legacy initStorageEvent method
    /// HTML Standard § 12.2.4
    pub fn initStorageEvent(
        self: *Self,
        event_type: []const u8,
        bubbles: bool,
        cancelable: bool,
        key: ?[]const u8,
        old_value: ?[]const u8,
        new_value: ?[]const u8,
        url: []const u8,
        storage_type: ?StorageType,
    ) void {
        self.event_type = event_type;
        self.bubbles = bubbles;
        self.cancelable = cancelable;
        self.key = key;
        self.old_value = old_value;
        self.new_value = new_value;
        self.url = url;
        self.storage_area_type = storage_type;
    }
};

// ============================================================================
// Storage getters (HTML Standard § 12.2.2, 12.2.3)
// ============================================================================

/// Get localStorage for an origin
/// HTML Standard § 12.2.3 - localStorage getter
pub fn getLocalStorage(
    allocator: std.mem.Allocator,
    origin: []const u8,
) StorageError!Storage {
    // Step 1-2: Check for opaque origin
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) {
        return error.SecurityError;
    }

    // Step 3: Obtain local storage bottle map
    const proxy_map_result = storage_standard.obtainLocalStorageBottleMap(
        allocator,
        origin,
        .localStorage,
    ) catch return error.OutOfMemory;

    const proxy_map = proxy_map_result orelse return error.SecurityError;

    // Step 4-5: Create and return Storage object
    return Storage.init(allocator, proxy_map, .local, origin);
}

/// Get sessionStorage for an origin and browsing context
/// HTML Standard § 12.2.2 - sessionStorage getter
///
/// Note: browsing_context_id is used to scope session storage.
/// Each top-level browsing context gets its own session storage.
pub fn getSessionStorage(
    allocator: std.mem.Allocator,
    browsing_context_id: u64,
    origin: []const u8,
) StorageError!Storage {
    // Step 1-2: Check for opaque origin
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) {
        return error.SecurityError;
    }

    // Create a unique key combining browsing context and origin
    const session_key = std.fmt.allocPrint(
        allocator,
        "{d}:{s}",
        .{ browsing_context_id, origin },
    ) catch return error.OutOfMemory;
    defer allocator.free(session_key);

    // For session storage, we use the session storage bottle map
    // Note: The spec says session storage is tied to traversable navigable
    // Here we approximate this with browsing_context_id
    const proxy_map_result = storage_standard.obtainSessionStorageBottleMap(
        allocator,
        session_key,
        .sessionStorage,
    ) catch return error.OutOfMemory;

    const proxy_map = proxy_map_result orelse return error.SecurityError;

    // Create Storage object with the original origin (not session_key)
    return Storage.init(allocator, proxy_map, .session, origin);
}

// ============================================================================
// Tests
// ============================================================================

test "Storage - basic operations" {
    const allocator = std.testing.allocator;

    // Clean up any existing global state
    storage_standard.deinitGlobalStorageShed(allocator);
    defer storage_standard.deinitGlobalStorageShed(allocator);

    // Get localStorage
    var storage = try getLocalStorage(allocator, "https://example.com");
    defer storage.deinit();

    // Initially empty
    try std.testing.expectEqual(@as(usize, 0), storage.length());

    // setItem
    try storage.setItem("key1", "value1");
    try std.testing.expectEqual(@as(usize, 1), storage.length());

    // getItem
    try std.testing.expectEqualStrings("value1", storage.getItem("key1").?);
    try std.testing.expect(storage.getItem("nonexistent") == null);

    // key
    try std.testing.expectEqualStrings("key1", storage.key(0).?);
    try std.testing.expect(storage.key(1) == null);

    // removeItem
    storage.removeItem("key1");
    try std.testing.expectEqual(@as(usize, 0), storage.length());
    try std.testing.expect(storage.getItem("key1") == null);
}

test "Storage - setItem update" {
    const allocator = std.testing.allocator;

    storage_standard.deinitGlobalStorageShed(allocator);
    defer storage_standard.deinitGlobalStorageShed(allocator);

    var storage = try getLocalStorage(allocator, "https://example.com");
    defer storage.deinit();

    // Set initial value
    try storage.setItem("key", "value1");
    try std.testing.expectEqualStrings("value1", storage.getItem("key").?);

    // Update value
    try storage.setItem("key", "value2");
    try std.testing.expectEqualStrings("value2", storage.getItem("key").?);
    try std.testing.expectEqual(@as(usize, 1), storage.length());
}

test "Storage - setItem same value no-op" {
    const allocator = std.testing.allocator;

    storage_standard.deinitGlobalStorageShed(allocator);
    defer storage_standard.deinitGlobalStorageShed(allocator);

    var storage = try getLocalStorage(allocator, "https://example.com");
    defer storage.deinit();

    try storage.setItem("key", "value");

    // Setting same value should be a no-op (per spec step 3.2)
    try storage.setItem("key", "value");
    try std.testing.expectEqual(@as(usize, 1), storage.length());
}

test "Storage - clear" {
    const allocator = std.testing.allocator;

    storage_standard.deinitGlobalStorageShed(allocator);
    defer storage_standard.deinitGlobalStorageShed(allocator);

    var storage = try getLocalStorage(allocator, "https://example.com");
    defer storage.deinit();

    try storage.setItem("key1", "value1");
    try storage.setItem("key2", "value2");
    try storage.setItem("key3", "value3");
    try std.testing.expectEqual(@as(usize, 3), storage.length());

    storage.clear();
    try std.testing.expectEqual(@as(usize, 0), storage.length());
}

test "Storage - quota enforcement" {
    const allocator = std.testing.allocator;

    storage_standard.deinitGlobalStorageShed(allocator);
    defer storage_standard.deinitGlobalStorageShed(allocator);

    var storage = try getLocalStorage(allocator, "https://example.com");
    defer storage.deinit();

    // Set a very small quota for testing
    storage.quota = 20;

    // This should fit (key1 + value1 = 10 bytes)
    try storage.setItem("key1", "value1");

    // This should exceed quota
    const result = storage.setItem("key2", "very_long_value_that_exceeds_quota");
    try std.testing.expectError(error.QuotaExceededError, result);
}

test "Storage - opaque origin security error" {
    const allocator = std.testing.allocator;

    storage_standard.deinitGlobalStorageShed(allocator);
    defer storage_standard.deinitGlobalStorageShed(allocator);

    // Empty origin should fail
    const result1 = getLocalStorage(allocator, "");
    try std.testing.expectError(error.SecurityError, result1);

    // "null" origin should fail
    const result2 = getLocalStorage(allocator, "null");
    try std.testing.expectError(error.SecurityError, result2);
}

test "StorageEvent - init and deinit" {
    const allocator = std.testing.allocator;

    const data = StorageEventData{
        .key = "testKey",
        .old_value = "oldVal",
        .new_value = "newVal",
        .storage_type = .local,
        .origin = "https://example.com",
    };

    var event = try StorageEvent.init(allocator, data, "https://example.com/page.html");
    defer event.deinit();

    try std.testing.expectEqualStrings("testKey", event.key.?);
    try std.testing.expectEqualStrings("oldVal", event.old_value.?);
    try std.testing.expectEqualStrings("newVal", event.new_value.?);
    try std.testing.expectEqualStrings("https://example.com/page.html", event.url);
    try std.testing.expectEqual(StorageType.local, event.storage_area_type.?);
    try std.testing.expectEqualStrings("storage", event.event_type);
    try std.testing.expect(!event.bubbles);
    try std.testing.expect(!event.cancelable);
}

test "StorageEvent - clear event" {
    const allocator = std.testing.allocator;

    // Clear events have null for key, oldValue, and newValue
    const data = StorageEventData{
        .key = null,
        .old_value = null,
        .new_value = null,
        .storage_type = .session,
        .origin = "https://example.com",
    };

    var event = try StorageEvent.init(allocator, data, "https://example.com/");
    defer event.deinit();

    try std.testing.expect(event.key == null);
    try std.testing.expect(event.old_value == null);
    try std.testing.expect(event.new_value == null);
}
