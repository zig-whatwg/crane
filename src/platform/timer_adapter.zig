//! Timer Backend Adapter
//!
//! Provides adapters between the old TimerBackend interface and the new
//! unified TimerVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `TimerBackend` (Zig-native VTable)
//! 2. New embedders implement `TimerVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces
//!
//! ## Usage
//!
//! ```zig
//! // Wrap old TimerBackend for new unified system
//! const adapter = TimerVTableAdapter.init(allocator, old_backend);
//! const vtable = TimerVTableAdapter.getVTable();
//!
//! // Wrap new TimerVTable for existing code
//! const backend = TimerBackendAdapter.fromVTable(vtable, user_context);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const TimerVTable = vtables.TimerVTable;
const OpaquePtr = vtables.OpaquePtr;

const timer_backend = @import("timer_backend.zig");
const TimerBackend = timer_backend.TimerBackend;

// =============================================================================
// TimerVTable -> TimerBackend Adapter
// =============================================================================

/// Adapter that wraps a TimerVTable and provides a TimerBackend interface.
///
/// This allows new C ABI embedder implementations to be used with existing
/// Zig code that expects a TimerBackend.
pub const TimerBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const TimerVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter from a TimerVTable.
    pub fn init(
        allocator: Allocator,
        vtable: *const TimerVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = vtable,
            .user_context = user_context,
            .allocator = allocator,
        };
        return self;
    }

    /// Get a TimerBackend interface.
    pub fn backend(self: *Self) TimerBackend {
        return TimerBackend{
            .ptr = self,
            .vtable = &backend_vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    const backend_vtable = TimerBackend.VTable{
        .getCurrentTime = getCurrentTimeImpl,
        .getHighResTime = getHighResTimeImpl,
        .scheduleWakeup = scheduleWakeupImpl,
        .cancelWakeup = cancelWakeupImpl,
        .sleepUntilWakeup = sleepUntilWakeupImpl,
        .deinit = deinitImpl,
    };

    fn getCurrentTimeImpl(ptr: *anyopaque) i64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.getCurrentTime(self.user_context);
    }

    fn getHighResTimeImpl(ptr: *anyopaque) i64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.getHighResTime(self.user_context);
    }

    fn scheduleWakeupImpl(ptr: *anyopaque, time_ms: i64) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.vtable.scheduleWakeup(self.user_context, time_ms);
    }

    fn cancelWakeupImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.vtable.cancelWakeup(self.user_context);
    }

    fn sleepUntilWakeupImpl(ptr: *anyopaque, timeout_ms: ?i64) i64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.sleepUntilWakeup(self.user_context, timeout_ms orelse -1);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// =============================================================================
// TimerBackend -> TimerVTable Adapter
// =============================================================================

/// Context for TimerVTable that wraps a TimerBackend.
///
/// This allows existing Zig TimerBackend implementations (like MockTimerBackend)
/// to be used with the new unified PlatformBackend system.
pub const TimerVTableAdapter = struct {
    /// The wrapped backend
    backend: TimerBackend,
    /// Allocator for cleanup
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter context.
    pub fn init(allocator: Allocator, backend: TimerBackend) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .backend = backend,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Get a pointer to the static VTable.
    pub fn getVTable() *const TimerVTable {
        return &vtable;
    }

    /// Get the user context pointer (pass this to PlatformBackend.user_context).
    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    const vtable = TimerVTable{
        .getCurrentTime = getCurrentTimeImpl,
        .getHighResTime = getHighResTimeImpl,
        .scheduleWakeup = scheduleWakeupImpl,
        .cancelWakeup = cancelWakeupImpl,
        .sleepUntilWakeup = sleepUntilWakeupImpl,
    };

    fn getCurrentTimeImpl(user_context: OpaquePtr) callconv(.c) i64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.getCurrentTime();
    }

    fn getHighResTimeImpl(user_context: OpaquePtr) callconv(.c) i64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.getHighResTime();
    }

    fn scheduleWakeupImpl(user_context: OpaquePtr, time_ms: i64) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.backend.scheduleWakeup(time_ms);
    }

    fn cancelWakeupImpl(user_context: OpaquePtr) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.backend.cancelWakeup();
    }

    fn sleepUntilWakeupImpl(user_context: OpaquePtr, timeout_ms: i64) callconv(.c) i64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const timeout: ?i64 = if (timeout_ms < 0) null else timeout_ms;
        return self.backend.sleepUntilWakeup(timeout);
    }
};

// =============================================================================
// Convenience Functions
// =============================================================================

/// Create a TimerVTable adapter from a MockTimerBackend.
///
/// This is a common use case for testing.
pub fn createMockVTableAdapter(
    allocator: Allocator,
    mock: *timer_backend.MockTimerBackend,
) !*TimerVTableAdapter {
    return TimerVTableAdapter.init(allocator, mock.backend());
}

// =============================================================================
// Tests
// =============================================================================

test "TimerVTableAdapter - wraps MockTimerBackend" {
    const allocator = std.testing.allocator;

    // Create mock backend
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(5000);

    // Create adapter
    const adapter = try TimerVTableAdapter.init(allocator, mock.backend());
    defer adapter.deinit();

    // Get VTable
    const vtable = TimerVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Test getCurrentTime
    const current_time = vtable.getCurrentTime(ctx);
    try std.testing.expectEqual(@as(i64, 5000), current_time);

    // Test getHighResTime
    const high_res = vtable.getHighResTime(ctx);
    try std.testing.expectEqual(@as(i64, 5000 * 1_000_000), high_res);

    // Test scheduleWakeup
    vtable.scheduleWakeup(ctx, 6000);
    try std.testing.expectEqual(@as(?i64, 6000), mock.scheduled_wakeup);

    // Test cancelWakeup
    vtable.cancelWakeup(ctx);
    try std.testing.expectEqual(@as(?i64, null), mock.scheduled_wakeup);
}

test "TimerBackendAdapter - wraps TimerVTable" {
    const allocator = std.testing.allocator;

    // Create mock backend first (to get a VTable)
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(10000);

    // Create VTable adapter
    const vtable_adapter = try TimerVTableAdapter.init(allocator, mock.backend());
    defer vtable_adapter.deinit();

    // Create backend adapter from VTable
    const backend_adapter = try TimerBackendAdapter.init(
        allocator,
        TimerVTableAdapter.getVTable(),
        vtable_adapter.getUserContext(),
    );
    defer backend_adapter.deinit();

    // Get TimerBackend interface
    const backend = backend_adapter.backend();

    // Test getCurrentTime
    try std.testing.expectEqual(@as(i64, 10000), backend.getCurrentTime());

    // Test getHighResTime
    try std.testing.expectEqual(@as(i64, 10000 * 1_000_000), backend.getHighResTime());

    // Test scheduleWakeup
    backend.scheduleWakeup(12000);
    try std.testing.expectEqual(@as(?i64, 12000), mock.scheduled_wakeup);

    // Test cancelWakeup
    backend.cancelWakeup();
    try std.testing.expectEqual(@as(?i64, null), mock.scheduled_wakeup);
}

test "TimerVTableAdapter - sleepUntilWakeup" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(1000);

    const adapter = try TimerVTableAdapter.init(allocator, mock.backend());
    defer adapter.deinit();

    const vtable = TimerVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Schedule wake-up at 1500
    vtable.scheduleWakeup(ctx, 1500);

    // Sleep until wake-up (no timeout)
    const slept = vtable.sleepUntilWakeup(ctx, -1);
    try std.testing.expectEqual(@as(i64, 500), slept);
    try std.testing.expectEqual(@as(i64, 1500), mock.current_time_ms);
}

test "TimerVTableAdapter - sleepUntilWakeup with timeout" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    mock.setCurrentTime(1000);

    const adapter = try TimerVTableAdapter.init(allocator, mock.backend());
    defer adapter.deinit();

    const vtable = TimerVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Schedule wake-up at 2000
    vtable.scheduleWakeup(ctx, 2000);

    // Sleep with timeout of 300ms (less than 1000ms to wake-up)
    const slept = vtable.sleepUntilWakeup(ctx, 300);
    try std.testing.expectEqual(@as(i64, 300), slept);
    try std.testing.expectEqual(@as(i64, 1300), mock.current_time_ms);
}
