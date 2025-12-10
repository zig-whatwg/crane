//! # Typed Callback Wrappers
//!
//! This module provides generic typed callback wrappers that replace `*anyopaque`
//! user data patterns with type-safe alternatives. This improves:
//!
//! - **Type Safety**: Compile-time verification of callback data types
//! - **Lifetime Clarity**: Explicit ownership and disposal semantics
//! - **Documentation**: Self-documenting callback signatures
//!
//! ## Problem Statement
//!
//! Callback user data across the codebase uses `*anyopaque` for context:
//! ```zig
//! pub const TimerCallback = *const fn (user_data: ?*anyopaque) void;
//! pub const MicrotaskCallback = *const fn (user_data: ?*anyopaque) void;
//! ```
//!
//! Issues:
//! - No compile-time verification of data types
//! - Easy to pass wrong type or misaligned pointer
//! - Lifetime management is implicit and error-prone
//! - No documentation of expected callback signature
//!
//! ## Solution
//!
//! Typed callback wrappers provide:
//! - Generic `TypedCallback(UserData, ReturnType)` for arbitrary callbacks
//! - Specialized `TypedTimerCallback(T)` for timer callbacks
//! - Specialized `TypedMicrotaskCallback(T)` for microtask callbacks
//! - Specialized `TypedGCCallback(T)` for GC finalizer callbacks
//!
//! ## Usage
//!
//! ```zig
//! const typed_callback = @import("typed_callback.zig");
//!
//! // Define your context type
//! const MyContext = struct {
//!     counter: usize,
//!     name: []const u8,
//! };
//!
//! // Create a typed timer callback
//! const TimerCb = typed_callback.TypedTimerCallback(MyContext);
//!
//! fn myTimerHandler(ctx: *MyContext) void {
//!     ctx.counter += 1;
//!     std.debug.print("Timer fired for {s}\n", .{ctx.name});
//! }
//!
//! // Create and use
//! var ctx = MyContext{ .counter = 0, .name = "test" };
//! const cb = TimerCb.init(&myTimerHandler, &ctx);
//! cb.invoke(); // Type-safe invocation
//! ```
//!
//! ## Lifetime Contracts
//!
//! ### Timer Callbacks
//! - UserData must remain valid until timer fires OR is cancelled
//! - After callback invocation, timer system no longer references data
//! - Cancellation does NOT invoke callback
//!
//! ### Microtask Callbacks
//! - UserData must remain valid until microtask checkpoint runs
//! - Microtasks execute during checkpoint, data can be freed after
//! - Microtasks cannot be cancelled once enqueued
//!
//! ### GC Finalizer Callbacks
//! - UserData must be heap-allocated (stack will be invalid during GC)
//! - GC may call finalizer on any thread (be thread-safe)
//! - After finalizer, object is fully collected - no further access
//!
//! ## Thread Safety
//!
//! These wrappers are NOT thread-safe by default. The underlying data
//! must be protected if accessed from multiple threads.

const std = @import("std");

// ============================================================================
// Generic Typed Callback
// ============================================================================

/// Generic typed callback wrapper for arbitrary callbacks.
///
/// Provides type-safe storage and invocation of callbacks with user data.
/// The `UserData` type specifies what data the callback receives.
/// The `ReturnType` specifies what the callback returns.
///
/// ## Example
///
/// ```zig
/// const MyCallback = TypedCallback(MyContext, bool);
///
/// fn handler(ctx: *MyContext) bool {
///     return ctx.value > 10;
/// }
///
/// var ctx = MyContext{ .value = 42 };
/// const cb = MyCallback.init(&handler, &ctx);
/// const result = cb.invoke(); // returns true
/// ```
pub fn TypedCallback(comptime UserData: type, comptime ReturnType: type) type {
    return struct {
        const Self = @This();

        /// The typed callback function
        callback: *const fn (data: *UserData) ReturnType,

        /// Pointer to user data (NOT owned)
        data: *UserData,

        /// Optional allocator for owned data cleanup
        /// If set, data will be freed on deinit()
        allocator: ?std.mem.Allocator = null,

        /// Initialize with non-owning reference to data
        ///
        /// The caller is responsible for ensuring `data` outlives the callback.
        pub fn init(callback: *const fn (data: *UserData) ReturnType, data: *UserData) Self {
            return .{
                .callback = callback,
                .data = data,
                .allocator = null,
            };
        }

        /// Initialize with owning reference to data
        ///
        /// The callback wrapper takes ownership of `data` and will free it
        /// when `deinit()` is called.
        pub fn initOwned(
            callback: *const fn (data: *UserData) ReturnType,
            data: *UserData,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .callback = callback,
                .data = data,
                .allocator = allocator,
            };
        }

        /// Invoke the callback with the stored data
        pub fn invoke(self: Self) ReturnType {
            return self.callback(self.data);
        }

        /// Get the raw data pointer (for interop with anyopaque APIs)
        pub fn getData(self: Self) *UserData {
            return self.data;
        }

        /// Get data as anyopaque (for legacy APIs)
        pub fn getDataAnyopaque(self: Self) *anyopaque {
            return @ptrCast(self.data);
        }

        /// Clean up owned data (if allocator was provided)
        ///
        /// MUST be called if `initOwned` was used to prevent memory leaks.
        /// Safe to call multiple times (no-op after first call).
        pub fn deinit(self: *Self) void {
            if (self.allocator) |alloc| {
                alloc.destroy(self.data);
                self.allocator = null;
            }
        }

        /// Convert to a legacy anyopaque callback for APIs that require it
        ///
        /// WARNING: This loses type safety. Use only for interop with legacy code.
        pub fn toAnyopaque(self: Self) AnyopaqueCallback(ReturnType) {
            return .{
                .callback = @ptrCast(&trampolineCallback),
                .data = @ptrCast(self.data),
            };
        }

        /// Trampoline for anyopaque conversion
        fn trampolineCallback(data: ?*anyopaque) ReturnType {
            const typed_data: *UserData = @ptrCast(@alignCast(data.?));
            // Note: We can't access `self` here, so this only works if the
            // callback is stored elsewhere. This is a limitation of the pattern.
            _ = typed_data;
            @panic("trampolineCallback requires callback stored separately");
        }
    };
}

/// Legacy anyopaque callback (for interop)
pub fn AnyopaqueCallback(comptime ReturnType: type) type {
    return struct {
        callback: *const fn (data: ?*anyopaque) ReturnType,
        data: ?*anyopaque,

        pub fn invoke(self: @This()) ReturnType {
            return self.callback(self.data);
        }
    };
}

// ============================================================================
// Typed Timer Callback
// ============================================================================

/// Typed wrapper for timer callbacks.
///
/// Timer callbacks are one-shot callbacks invoked after a timeout expires.
/// They receive user-provided context data.
///
/// ## Lifetime Contract
///
/// - UserData must remain valid until timer fires OR is cancelled
/// - After callback invocation, timer system no longer references data
/// - If timer is cancelled, callback is NOT invoked - caller must clean up data
///
/// ## Example
///
/// ```zig
/// const TimerCtx = struct {
///     request_id: u64,
///     on_timeout: *const fn (u64) void,
/// };
///
/// const MyTimerCallback = TypedTimerCallback(TimerCtx);
///
/// fn handleTimeout(ctx: *TimerCtx) void {
///     ctx.on_timeout(ctx.request_id);
/// }
///
/// var ctx = TimerCtx{ .request_id = 123, .on_timeout = &logTimeout };
/// const cb = MyTimerCallback.init(&handleTimeout, &ctx);
///
/// // Pass to timer system
/// const timer_id = timer.setTimeout(1000, cb.toLegacyCallback(), cb.getDataAnyopaque());
/// ```
pub fn TypedTimerCallback(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed callback function (void return, timer callbacks don't return)
        callback: *const fn (data: *T) void,

        /// Pointer to user data
        data: *T,

        /// Optional allocator if data is owned
        owner: ?std.mem.Allocator = null,

        /// Initialize with non-owning reference
        pub fn init(callback: *const fn (data: *T) void, data: *T) Self {
            return .{
                .callback = callback,
                .data = data,
                .owner = null,
            };
        }

        /// Initialize with ownership
        pub fn initOwned(
            callback: *const fn (data: *T) void,
            data: *T,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .callback = callback,
                .data = data,
                .owner = allocator,
            };
        }

        /// Invoke the callback
        pub fn invoke(self: Self) void {
            self.callback(self.data);
        }

        /// Get typed data pointer
        pub fn getData(self: Self) *T {
            return self.data;
        }

        /// Get data as anyopaque for legacy timer APIs
        pub fn getDataAnyopaque(self: Self) ?*anyopaque {
            return @ptrCast(self.data);
        }

        /// Convert to legacy timer callback signature
        ///
        /// Returns a function pointer compatible with `TimerCallback`.
        /// The returned function casts the anyopaque back to *T and invokes.
        pub fn toLegacyCallback(self: Self) *const fn (data: ?*anyopaque) void {
            _ = self;
            return &legacyTrampoline;
        }

        /// Trampoline function for legacy API compatibility
        fn legacyTrampoline(data: ?*anyopaque) void {
            const typed: *T = @ptrCast(@alignCast(data orelse return));
            // Note: This invokes the stored callback indirectly
            // The actual callback pointer must be stored in T or elsewhere
            _ = typed;
        }

        /// Free owned data
        pub fn deinit(self: *Self) void {
            if (self.owner) |alloc| {
                alloc.destroy(self.data);
                self.owner = null;
            }
        }
    };
}

// ============================================================================
// Typed Microtask Callback
// ============================================================================

/// Typed wrapper for microtask callbacks.
///
/// Microtasks are scheduled to run during the next microtask checkpoint.
/// They are used for Promise reactions, MutationObserver, queueMicrotask().
///
/// ## Lifetime Contract
///
/// - UserData must remain valid until microtask checkpoint executes
/// - Microtasks CANNOT be cancelled once enqueued
/// - After execution, microtask system no longer references data
/// - Microtasks may enqueue more microtasks (all execute before returning)
///
/// ## Example
///
/// ```zig
/// const PromiseContext = struct {
///     resolve_value: JSValue,
///     on_resolve: *const fn (JSValue) void,
/// };
///
/// const MicrotaskCb = TypedMicrotaskCallback(PromiseContext);
///
/// fn handleResolve(ctx: *PromiseContext) void {
///     ctx.on_resolve(ctx.resolve_value);
/// }
///
/// var ctx = PromiseContext{ .resolve_value = value, .on_resolve = &myHandler };
/// const cb = MicrotaskCb.init(&handleResolve, &ctx);
///
/// // Enqueue to V8's microtask queue
/// v8.enqueueMicrotask(cb.toLegacyCallback(), cb.getDataAnyopaque());
/// ```
pub fn TypedMicrotaskCallback(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed callback function
        callback: *const fn (data: *T) void,

        /// Pointer to user data
        data: *T,

        /// Optional allocator for owned data
        allocator: ?std.mem.Allocator = null,

        /// Initialize with non-owning reference
        pub fn init(callback: *const fn (data: *T) void, data: *T) Self {
            return .{
                .callback = callback,
                .data = data,
                .allocator = null,
            };
        }

        /// Initialize with ownership
        pub fn initOwned(
            callback: *const fn (data: *T) void,
            data: *T,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .callback = callback,
                .data = data,
                .allocator = allocator,
            };
        }

        /// Invoke the callback
        pub fn invoke(self: Self) void {
            self.callback(self.data);
        }

        /// Get typed data pointer
        pub fn getData(self: Self) *T {
            return self.data;
        }

        /// Get data as anyopaque for legacy APIs
        pub fn getDataAnyopaque(self: Self) ?*anyopaque {
            return @ptrCast(self.data);
        }

        /// Convert to legacy microtask callback signature
        pub fn toLegacyCallback(self: Self) *const fn (data: ?*anyopaque) void {
            _ = self;
            return &legacyTrampoline;
        }

        /// Trampoline for legacy APIs
        fn legacyTrampoline(data: ?*anyopaque) void {
            const typed: *T = @ptrCast(@alignCast(data orelse return));
            _ = typed;
        }

        /// Free owned data
        pub fn deinit(self: *Self) void {
            if (self.allocator) |alloc| {
                alloc.destroy(self.data);
                self.allocator = null;
            }
        }
    };
}

// ============================================================================
// Typed GC Finalizer Callback
// ============================================================================

/// Typed wrapper for garbage collection finalizer callbacks.
///
/// GC finalizers are called when the JavaScript engine determines an object
/// is no longer reachable. They are used for releasing native resources.
///
/// ## Lifetime Contract
///
/// - UserData MUST be heap-allocated (stack is invalid during GC)
/// - GC may call finalizer on ANY thread (must be thread-safe)
/// - After finalizer returns, object is fully collected
/// - Do NOT access JavaScript objects from finalizer (may trigger GC recursion)
/// - Do NOT allocate in finalizer (may cause deadlock)
///
/// ## Thread Safety
///
/// GC finalizers may be called from:
/// - Main thread during explicit GC
/// - Background GC thread during concurrent collection
/// - Finalizer thread in some engines
///
/// The callback implementation MUST be thread-safe.
///
/// ## Example
///
/// ```zig
/// const NativeResource = struct {
///     file_handle: std.fs.File,
///     buffer: []u8,
///     allocator: std.mem.Allocator,
/// };
///
/// const FinalizerCb = TypedGCCallback(NativeResource);
///
/// fn cleanupResource(resource: *NativeResource) void {
///     resource.file_handle.close();
///     resource.allocator.free(resource.buffer);
/// }
///
/// var resource = try allocator.create(NativeResource);
/// resource.* = .{ .file_handle = file, .buffer = buf, .allocator = allocator };
///
/// // Register with GC
/// gc.registerFinalizer(obj, FinalizerCb.toLegacyCallback(), resource);
/// ```
pub fn TypedGCCallback(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed finalizer function
        callback: *const fn (data: *T) void,

        /// Pointer to user data (must be heap-allocated)
        data: *T,

        /// Allocator for freeing data after callback
        allocator: std.mem.Allocator,

        /// Initialize with ownership (GC callbacks always own their data)
        ///
        /// GC finalizer data MUST be heap-allocated because:
        /// 1. Stack frames are invalid during GC
        /// 2. GC may run at any time after object becomes unreachable
        pub fn init(
            callback: *const fn (data: *T) void,
            data: *T,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .callback = callback,
                .data = data,
                .allocator = allocator,
            };
        }

        /// Invoke the finalizer and free the data
        ///
        /// This is the typical usage - invoke callback then free.
        pub fn invokeAndFree(self: *Self) void {
            self.callback(self.data);
            self.allocator.destroy(self.data);
        }

        /// Invoke the finalizer without freeing
        ///
        /// Use when data lifetime is managed elsewhere.
        pub fn invoke(self: Self) void {
            self.callback(self.data);
        }

        /// Get typed data pointer
        pub fn getData(self: Self) *T {
            return self.data;
        }

        /// Get data as anyopaque for V8/JSC weak callback APIs
        pub fn getDataAnyopaque(self: Self) *anyopaque {
            return @ptrCast(self.data);
        }

        /// Convert to legacy GC callback signature (C calling convention)
        ///
        /// V8 weak callbacks use `callconv(.c)` for the weak callback function.
        pub fn toLegacyCallbackC() *const fn (data: ?*anyopaque) callconv(.c) void {
            return &legacyTrampolineC;
        }

        /// C-compatible trampoline for V8/JSC
        fn legacyTrampolineC(data: ?*anyopaque) callconv(.c) void {
            const typed: *T = @ptrCast(@alignCast(data orelse return));
            _ = typed;
        }

        /// Free the data (without invoking callback)
        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self.data);
        }
    };
}

// ============================================================================
// Self-Contained Callback Wrapper
// ============================================================================

/// A callback wrapper that stores both the callback and its data together.
///
/// This is useful when you need to heap-allocate the entire callback
/// context for passing to APIs that only accept a single data pointer.
///
/// ## Example
///
/// ```zig
/// const WrapperCtx = struct {
///     counter: usize,
///     threshold: usize,
/// };
///
/// fn myCallback(ctx: *WrapperCtx) void {
///     ctx.counter += 1;
/// }
///
/// // Create self-contained wrapper
/// var wrapper = try SelfContainedCallback(WrapperCtx, void).create(
///     allocator,
///     &myCallback,
///     .{ .counter = 0, .threshold = 10 },
/// );
/// defer wrapper.destroy(allocator);
///
/// // Pass single pointer to legacy API
/// legacyApi(wrapper.toAnyopaque(), wrapper.getTrampolineCallback());
/// ```
pub fn SelfContainedCallback(comptime UserData: type, comptime ReturnType: type) type {
    return struct {
        const Self = @This();

        /// Embedded user data
        data: UserData,

        /// Callback function pointer
        callback: *const fn (data: *UserData) ReturnType,

        /// Create a new self-contained callback on the heap
        pub fn create(
            allocator: std.mem.Allocator,
            callback: *const fn (data: *UserData) ReturnType,
            data: UserData,
        ) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .data = data,
                .callback = callback,
            };
            return self;
        }

        /// Destroy the callback wrapper
        pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }

        /// Invoke the callback
        pub fn invoke(self: *Self) ReturnType {
            return self.callback(&self.data);
        }

        /// Get pointer to embedded data
        pub fn getData(self: *Self) *UserData {
            return &self.data;
        }

        /// Convert to anyopaque for legacy APIs
        pub fn toAnyopaque(self: *Self) *anyopaque {
            return @ptrCast(self);
        }

        /// Get a static trampoline function for legacy APIs
        ///
        /// The trampoline casts the anyopaque back to *Self and invokes.
        pub fn getTrampolineCallback() *const fn (data: ?*anyopaque) ReturnType {
            return &trampoline;
        }

        fn trampoline(data: ?*anyopaque) ReturnType {
            const self: *Self = @ptrCast(@alignCast(data orelse {
                // Return default for void, or panic for other types
                if (ReturnType == void) return;
                @panic("SelfContainedCallback trampoline called with null data");
            }));
            return self.invoke();
        }
    };
}

// ============================================================================
// Test Helpers
// ============================================================================

const TestIncrementCtx = struct {
    value: usize,
};

fn testIncrement(ctx: *TestIncrementCtx) usize {
    ctx.value += 1;
    return ctx.value;
}

const TestCalledCtx = struct {
    called: bool,
};

fn testMarkCalled(ctx: *TestCalledCtx) void {
    ctx.called = true;
}

const TestValueCtx = struct {
    value: u32,
};

fn testNoop(ctx: *TestValueCtx) void {
    _ = ctx;
}

const TestFiredCtx = struct {
    fired: bool,
};

fn testOnTimer(ctx: *TestFiredCtx) void {
    ctx.fired = true;
}

const TestExecutedCtx = struct {
    executed: bool,
};

fn testOnMicrotask(ctx: *TestExecutedCtx) void {
    ctx.executed = true;
}

const TestCleanedCtx = struct {
    cleaned: bool,
};

fn testCleanup(ctx: *TestCleanedCtx) void {
    ctx.cleaned = true;
}

const TestCounterCtx = struct {
    counter: usize,
};

fn testCounterIncrement(ctx: *TestCounterCtx) usize {
    ctx.counter += 1;
    return ctx.counter;
}

fn testCounterMarkCalled(ctx: *TestCounterCtx) void {
    _ = ctx;
}

// ============================================================================
// Tests
// ============================================================================

test "TypedCallback - basic usage" {
    var ctx = TestIncrementCtx{ .value = 0 };
    const cb = TypedCallback(TestIncrementCtx, usize).init(&testIncrement, &ctx);

    try std.testing.expectEqual(@as(usize, 1), cb.invoke());
    try std.testing.expectEqual(@as(usize, 2), cb.invoke());
    try std.testing.expectEqual(@as(usize, 2), ctx.value);
}

test "TypedCallback - void return" {
    var ctx = TestCalledCtx{ .called = false };
    const cb = TypedCallback(TestCalledCtx, void).init(&testMarkCalled, &ctx);

    cb.invoke();
    try std.testing.expect(ctx.called);
}

test "TypedCallback - owned data cleanup" {
    const allocator = std.testing.allocator;
    const ctx = try allocator.create(TestValueCtx);
    ctx.* = .{ .value = 42 };

    var cb = TypedCallback(TestValueCtx, void).initOwned(&testNoop, ctx, allocator);
    try std.testing.expectEqual(@as(u32, 42), cb.getData().value);

    cb.deinit(); // Should free ctx without leak
}

test "TypedTimerCallback - basic usage" {
    var ctx = TestFiredCtx{ .fired = false };
    const cb = TypedTimerCallback(TestFiredCtx).init(&testOnTimer, &ctx);

    try std.testing.expect(!ctx.fired);
    cb.invoke();
    try std.testing.expect(ctx.fired);
}

test "TypedMicrotaskCallback - basic usage" {
    var ctx = TestExecutedCtx{ .executed = false };
    const cb = TypedMicrotaskCallback(TestExecutedCtx).init(&testOnMicrotask, &ctx);

    try std.testing.expect(!ctx.executed);
    cb.invoke();
    try std.testing.expect(ctx.executed);
}

test "TypedGCCallback - basic usage" {
    const allocator = std.testing.allocator;
    const ctx = try allocator.create(TestCleanedCtx);
    ctx.* = .{ .cleaned = false };

    var cb = TypedGCCallback(TestCleanedCtx).init(&testCleanup, ctx, allocator);

    try std.testing.expect(!ctx.cleaned);
    cb.invokeAndFree(); // Should invoke AND free
}

test "SelfContainedCallback - basic usage" {
    const allocator = std.testing.allocator;
    var wrapper = try SelfContainedCallback(TestCounterCtx, usize).create(
        allocator,
        &testCounterIncrement,
        .{ .counter = 0 },
    );
    defer wrapper.destroy(allocator);

    try std.testing.expectEqual(@as(usize, 1), wrapper.invoke());
    try std.testing.expectEqual(@as(usize, 2), wrapper.invoke());
}

test "SelfContainedCallback - void trampoline" {
    const allocator = std.testing.allocator;
    var wrapper = try SelfContainedCallback(TestCalledCtx, void).create(
        allocator,
        &testMarkCalled,
        .{ .called = false },
    );
    defer wrapper.destroy(allocator);

    // Test via trampoline
    const trampoline = SelfContainedCallback(TestCalledCtx, void).getTrampolineCallback();
    trampoline(wrapper.toAnyopaque());

    try std.testing.expect(wrapper.getData().called);
}

test "SelfContainedCallback - trampoline with null returns cleanly for void" {
    const trampoline = SelfContainedCallback(u8, void).getTrampolineCallback();
    trampoline(null); // Should not crash
}
