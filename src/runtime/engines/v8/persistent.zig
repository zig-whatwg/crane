//! V8 Persistent Handle Wrapper
//!
//! Provides Persistent handle management for V8 objects that need to survive
//! beyond HandleScope lifetime. Used for:
//! - EventListener callbacks
//! - Promise callbacks
//! - Long-lived object references
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## V8 Handle Lifecycle
//!
//! **Local Handles:**
//! - Created in HandleScope
//! - Destroyed when HandleScope exits
//! - Used for temporary operations
//!
//! **Persistent Handles:**
//! - Survive beyond HandleScope
//! - Manually managed (create/destroy)
//! - Used for callbacks and long-lived refs
//!
//! ## Architecture
//!
//! ```
//! V8 HandleScope
//!   ├─ Local<Object> (temporary) ───┐
//!   └─ ...                           │
//!                                    │
//! Persistent<Object> ←───────────────┘
//!   │                 (survives GC)
//!   └─ Used in EventListener, Promise, etc.
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const v8_persistent = @import("runtime").v8_persistent;
//!
//! // Create persistent handle
//! var persistent = try v8_persistent.PersistentHandle.init(allocator, v8_obj_handle);
//! defer persistent.deinit();
//!
//! // Get current value
//! const current = persistent.get();
//!
//! // Reset to new value
//! try persistent.reset(new_v8_obj_handle);
//!
//! // Clear handle
//! persistent.clear();
//! ```

const std = @import("std");

/// Persistent handle for V8 objects
///
/// In real V8:
/// ```c++
/// template<typename T>
/// class v8::Persistent {
///     Persistent(Isolate* isolate, Local<T> handle);
///     Local<T> Get(Isolate* isolate);
///     void Reset();
///     void Reset(Isolate* isolate, Local<T> handle);
/// };
/// ```
///
/// Prevents GC from collecting the referenced object until explicitly cleared.
pub const PersistentHandle = struct {
    allocator: std.mem.Allocator,
    handle: ?usize, // In real V8: v8::Persistent<v8::Object> handle
    is_weak: bool,

    /// Initialize persistent handle with V8 object
    ///
    /// In real V8:
    /// ```c++
    /// v8::Persistent<v8::Object> pers(isolate, local_handle);
    /// ```
    pub fn init(allocator: std.mem.Allocator, v8_obj_handle: usize) !*PersistentHandle {
        const self = try allocator.create(PersistentHandle);
        self.* = .{
            .allocator = allocator,
            .handle = v8_obj_handle,
            .is_weak = false,
        };
        return self;
    }

    /// Deinitialize persistent handle
    ///
    /// In real V8:
    /// ```c++
    /// persistent.Reset();  // Clear handle
    /// ```
    pub fn deinit(self: *PersistentHandle) void {
        self.clear();
        self.allocator.destroy(self);
    }

    /// Get current V8 object handle
    ///
    /// In real V8:
    /// ```c++
    /// v8::Local<v8::Object> obj = persistent.Get(isolate);
    /// ```
    pub fn get(self: *const PersistentHandle) ?usize {
        return self.handle;
    }

    /// Reset to new V8 object handle
    ///
    /// In real V8:
    /// ```c++
    /// persistent.Reset(isolate, new_local_handle);
    /// ```
    pub fn reset(self: *PersistentHandle, v8_obj_handle: usize) void {
        self.handle = v8_obj_handle;
    }

    /// Clear persistent handle
    ///
    /// Releases reference, allowing GC to collect the object.
    ///
    /// In real V8:
    /// ```c++
    /// persistent.Reset();  // Clears handle
    /// ```
    pub fn clear(self: *PersistentHandle) void {
        self.handle = null;
    }

    /// Check if handle is empty
    pub fn isEmpty(self: *const PersistentHandle) bool {
        return self.handle == null;
    }

    /// Make handle weak
    ///
    /// Weak handles allow GC to collect the object, but notify via callback.
    /// Used for cleanup when object is collected.
    ///
    /// In real V8:
    /// ```c++
    /// persistent.SetWeak(parameter, WeakCallback, v8::WeakCallbackType::kParameter);
    /// ```
    pub fn makeWeak(self: *PersistentHandle) void {
        self.is_weak = true;
    }

    /// Make handle strong
    ///
    /// Strong handles prevent GC from collecting the object.
    ///
    /// In real V8:
    /// ```c++
    /// persistent.ClearWeak();
    /// ```
    pub fn makeStrong(self: *PersistentHandle) void {
        self.is_weak = false;
    }

    /// Check if handle is weak
    pub fn isWeak(self: *const PersistentHandle) bool {
        return self.is_weak;
    }
};

/// Persistent function handle for callbacks
///
/// Specialized persistent handle for JavaScript functions.
/// Used for EventListener, Promise callbacks, etc.
pub const PersistentFunction = struct {
    handle: *PersistentHandle,

    /// Initialize persistent function handle
    pub fn init(allocator: std.mem.Allocator, v8_func_handle: usize) !*PersistentFunction {
        const self = try allocator.create(PersistentFunction);
        self.* = .{
            .handle = try PersistentHandle.init(allocator, v8_func_handle),
        };
        return self;
    }

    /// Deinitialize persistent function handle
    pub fn deinit(self: *PersistentFunction) void {
        const allocator = self.handle.allocator;
        self.handle.deinit();
        allocator.destroy(self);
    }

    /// Get current function handle
    pub fn get(self: *const PersistentFunction) ?usize {
        return self.handle.get();
    }

    /// Reset to new function handle
    pub fn reset(self: *PersistentFunction, v8_func_handle: usize) void {
        self.handle.reset(v8_func_handle);
    }

    /// Clear function handle
    pub fn clear(self: *PersistentFunction) void {
        self.handle.clear();
    }

    /// Check if function handle is empty
    pub fn isEmpty(self: *const PersistentFunction) bool {
        return self.handle.isEmpty();
    }

    /// Call persistent function with arguments
    ///
    /// In real V8:
    /// ```c++
    /// v8::Local<v8::Function> func = persistent_func.Get(isolate);
    /// v8::Local<v8::Value> result = func->Call(context, receiver, argc, argv);
    /// ```
    pub fn call(
        self: *const PersistentFunction,
        this_handle: ?usize,
        args: []const usize,
    ) !?usize {
        const func_handle = self.get() orelse return error.EmptyHandle;

        // In real V8, would convert to v8::Function and call
        _ = this_handle;
        _ = args;

        // Mock: return success
        return func_handle;
    }
};

/// Persistent handle registry
///
/// Manages all persistent handles for cleanup and lifecycle management.
/// Useful for tracking all EventListeners, Promises, etc.
pub const PersistentRegistry = struct {
    allocator: std.mem.Allocator,
    handles: std.ArrayList(*PersistentHandle),
    functions: std.ArrayList(*PersistentFunction),

    /// Initialize registry
    pub fn init(allocator: std.mem.Allocator) PersistentRegistry {
        return .{
            .allocator = allocator,
            .handles = std.ArrayList(*PersistentHandle){},
            .functions = std.ArrayList(*PersistentFunction){},
        };
    }

    /// Deinitialize registry
    ///
    /// Clears and destroys all registered persistent handles.
    pub fn deinit(self: *PersistentRegistry) void {
        // Clear all functions
        for (self.functions.items) |func| {
            func.deinit();
        }
        self.functions.deinit(self.allocator);

        // Clear all handles
        for (self.handles.items) |handle| {
            handle.deinit();
        }
        self.handles.deinit(self.allocator);
    }

    /// Register persistent handle
    pub fn registerHandle(self: *PersistentRegistry, handle: *PersistentHandle) !void {
        try self.handles.append(handle);
    }

    /// Register persistent function
    pub fn registerFunction(self: *PersistentRegistry, func: *PersistentFunction) !void {
        try self.functions.append(func);
    }

    /// Unregister persistent handle
    pub fn unregisterHandle(self: *PersistentRegistry, handle: *const PersistentHandle) void {
        for (self.handles.items, 0..) |h, i| {
            if (h == handle) {
                _ = self.handles.swapRemove(i);
                break;
            }
        }
    }

    /// Unregister persistent function
    pub fn unregisterFunction(self: *PersistentRegistry, func: *const PersistentFunction) void {
        for (self.functions.items, 0..) |f, i| {
            if (f == func) {
                _ = self.functions.swapRemove(i);
                break;
            }
        }
    }

    /// Clear all weak handles
    ///
    /// Removes all weak persistent handles from registry.
    /// Useful during GC sweep.
    pub fn clearWeakHandles(self: *PersistentRegistry) void {
        var i: usize = 0;
        while (i < self.handles.items.len) {
            if (self.handles.items[i].isWeak()) {
                const handle = self.handles.swapRemove(i);
                handle.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Get statistics
    pub fn getStats(self: *const PersistentRegistry) Stats {
        var weak_count: u32 = 0;
        for (self.handles.items) |handle| {
            if (handle.isWeak()) weak_count += 1;
        }

        return .{
            .total_handles = @intCast(self.handles.items.len),
            .total_functions = @intCast(self.functions.items.len),
            .weak_handles = weak_count,
            .strong_handles = @intCast(self.handles.items.len - weak_count),
        };
    }

    pub const Stats = struct {
        total_handles: u32,
        total_functions: u32,
        weak_handles: u32,
        strong_handles: u32,
    };
};

// Unit tests

const testing = std.testing;

test "PersistentHandle init and deinit" {
    const handle = try PersistentHandle.init(testing.allocator, 0xDEADBEEF);
    defer handle.deinit();

    try testing.expectEqual(@as(?usize, 0xDEADBEEF), handle.get());
    try testing.expect(!handle.isEmpty());
}

test "PersistentHandle get returns correct value" {
    const handle = try PersistentHandle.init(testing.allocator, 0x12345678);
    defer handle.deinit();

    const value = handle.get().?;
    try testing.expectEqual(@as(usize, 0x12345678), value);
}

test "PersistentHandle reset changes value" {
    const handle = try PersistentHandle.init(testing.allocator, 0x1111);
    defer handle.deinit();

    handle.reset(0x2222);

    const value = handle.get().?;
    try testing.expectEqual(@as(usize, 0x2222), value);
}

test "PersistentHandle clear makes it empty" {
    const handle = try PersistentHandle.init(testing.allocator, 0xAAAA);
    defer handle.deinit();

    handle.clear();

    try testing.expect(handle.isEmpty());
    try testing.expectEqual(@as(?usize, null), handle.get());
}

test "PersistentHandle weak/strong transitions" {
    const handle = try PersistentHandle.init(testing.allocator, 0xBBBB);
    defer handle.deinit();

    // Initially strong
    try testing.expect(!handle.isWeak());

    // Make weak
    handle.makeWeak();
    try testing.expect(handle.isWeak());

    // Make strong again
    handle.makeStrong();
    try testing.expect(!handle.isWeak());
}

test "PersistentFunction init and deinit" {
    const func = try PersistentFunction.init(testing.allocator, 0xCCCC);
    defer func.deinit();

    try testing.expectEqual(@as(?usize, 0xCCCC), func.get());
    try testing.expect(!func.isEmpty());
}

test "PersistentFunction call with arguments" {
    const func = try PersistentFunction.init(testing.allocator, 0xDDDD);
    defer func.deinit();

    const args = [_]usize{ 0x1111, 0x2222 };
    const result = try func.call(0xEEEE, &args);

    try testing.expect(result != null);
}

test "PersistentFunction clear makes it empty" {
    const func = try PersistentFunction.init(testing.allocator, 0xFFFF);
    defer func.deinit();

    func.clear();

    try testing.expect(func.isEmpty());
}

test "PersistentFunction call on empty handle returns error" {
    const func = try PersistentFunction.init(testing.allocator, 0x0000);
    defer func.deinit();

    func.clear();

    const args = [_]usize{0x1111};
    const result = func.call(null, &args);
    try testing.expectError(error.EmptyHandle, result);
}

test "PersistentRegistry init and deinit" {
    var registry = PersistentRegistry.init(testing.allocator);
    defer registry.deinit();

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 0), stats.total_handles);
    try testing.expectEqual(@as(u32, 0), stats.total_functions);
}

test "PersistentRegistry registerHandle and unregisterHandle" {
    var registry = PersistentRegistry.init(testing.allocator);
    defer registry.deinit();

    const handle = try PersistentHandle.init(testing.allocator, 0x1234);

    try registry.registerHandle(handle);

    var stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.total_handles);

    registry.unregisterHandle(handle);

    stats = registry.getStats();
    try testing.expectEqual(@as(u32, 0), stats.total_handles);

    // Manual cleanup since we unregistered
    handle.deinit();
}

test "PersistentRegistry registerFunction and unregisterFunction" {
    var registry = PersistentRegistry.init(testing.allocator);
    defer registry.deinit();

    const func = try PersistentFunction.init(testing.allocator, 0x5678);

    try registry.registerFunction(func);

    var stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.total_functions);

    registry.unregisterFunction(func);

    stats = registry.getStats();
    try testing.expectEqual(@as(u32, 0), stats.total_functions);

    // Manual cleanup since we unregistered
    func.deinit();
}

test "PersistentRegistry clearWeakHandles removes only weak handles" {
    var registry = PersistentRegistry.init(testing.allocator);
    defer registry.deinit();

    const strong_handle = try PersistentHandle.init(testing.allocator, 0x1111);
    const weak_handle = try PersistentHandle.init(testing.allocator, 0x2222);

    try registry.registerHandle(strong_handle);
    try registry.registerHandle(weak_handle);

    weak_handle.makeWeak();

    var stats = registry.getStats();
    try testing.expectEqual(@as(u32, 2), stats.total_handles);
    try testing.expectEqual(@as(u32, 1), stats.weak_handles);

    registry.clearWeakHandles();

    stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.total_handles);
    try testing.expectEqual(@as(u32, 0), stats.weak_handles);
}

test "PersistentRegistry deinit clears all handles" {
    var registry = PersistentRegistry.init(testing.allocator);

    const handle1 = try PersistentHandle.init(testing.allocator, 0x1111);
    const handle2 = try PersistentHandle.init(testing.allocator, 0x2222);
    const func = try PersistentFunction.init(testing.allocator, 0x3333);

    try registry.registerHandle(handle1);
    try registry.registerHandle(handle2);
    try registry.registerFunction(func);

    // Deinit will clean up all registered handles/functions
    registry.deinit();

    // No manual cleanup needed - registry owns the handles
}
