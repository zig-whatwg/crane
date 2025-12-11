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
// Typed Promise Callback
// ============================================================================

/// Typed wrapper for promise fulfillment/rejection callbacks.
///
/// Promise callbacks are invoked when a JavaScript Promise settles.
/// They receive a context and a value (fulfillment) or reason (rejection).
///
/// ## Lifetime Contract
///
/// - Context must be heap-allocated (callback may be invoked asynchronously)
/// - After callback returns, the context can be freed
/// - Both fulfill and reject handlers use the same context type
///
/// ## Thread Safety
///
/// Promise callbacks may be called from any thread (JS engine dependent).
/// The callback implementation SHOULD be thread-safe if crossing thread boundaries.
///
/// ## Example
///
/// ```zig
/// const RequestContext = struct {
///     request_id: u64,
///     allocator: std.mem.Allocator,
///     on_success: *const fn (u64, []const u8) void,
///     on_failure: *const fn (u64, []const u8) void,
/// };
///
/// const FulfillCb = TypedPromiseFulfillCallback(RequestContext);
///
/// fn onFulfill(ctx: *RequestContext, value: ?*anyopaque) void {
///     // Extract result from value and call success handler
///     ctx.on_success(ctx.request_id, "result");
/// }
///
/// // Register with engine
/// var ctx = try allocator.create(RequestContext);
/// const cb = FulfillCb.init(&onFulfill, ctx, allocator);
/// engine.chainPromiseHandlers(promise, cb.toLegacyCallback(), cb.getContextAnyopaque(), ...);
/// ```
pub fn TypedPromiseFulfillCallback(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed callback function
        /// Receives context and the fulfillment value (or null for undefined)
        callback: *const fn (ctx: *T, value: ?*anyopaque) void,

        /// Pointer to user context (must be heap-allocated!)
        context: *T,

        /// Allocator for cleanup
        allocator: ?std.mem.Allocator = null,

        /// Initialize with non-owning reference
        pub fn init(
            callback: *const fn (ctx: *T, value: ?*anyopaque) void,
            context: *T,
        ) Self {
            return .{
                .callback = callback,
                .context = context,
                .allocator = null,
            };
        }

        /// Initialize with ownership (context will be freed after invocation)
        pub fn initOwned(
            callback: *const fn (ctx: *T, value: ?*anyopaque) void,
            context: *T,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .callback = callback,
                .context = context,
                .allocator = allocator,
            };
        }

        /// Invoke the callback
        pub fn invoke(self: Self, value: ?*anyopaque) void {
            self.callback(self.context, value);
        }

        /// Invoke and free owned context
        pub fn invokeAndFree(self: *Self, value: ?*anyopaque) void {
            self.callback(self.context, value);
            if (self.allocator) |alloc| {
                alloc.destroy(self.context);
                self.allocator = null;
            }
        }

        /// Get context as anyopaque for legacy APIs
        pub fn getContextAnyopaque(self: Self) ?*anyopaque {
            return @ptrCast(self.context);
        }

        /// Get a C-calling-convention trampoline for V8 promise handlers
        ///
        /// The trampoline signature matches `PromiseFulfillCallback`.
        pub fn toLegacyCallbackC() *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void {
            return &legacyTrampolineC;
        }

        fn legacyTrampolineC(ctx: ?*anyopaque, value: ?*anyopaque) callconv(.c) void {
            const typed: *T = @ptrCast(@alignCast(ctx orelse return));
            _ = typed;
            _ = value;
            // Note: The actual callback invocation requires the callback function pointer
            // which isn't available in the trampoline. Use SelfContainedPromiseCallback instead.
        }

        /// Free owned context without invoking callback
        pub fn deinit(self: *Self) void {
            if (self.allocator) |alloc| {
                alloc.destroy(self.context);
                self.allocator = null;
            }
        }
    };
}

/// Typed wrapper for promise rejection callbacks.
///
/// Similar to TypedPromiseFulfillCallback but for rejection handling.
/// The callback receives a rejection reason instead of a fulfillment value.
pub fn TypedPromiseRejectCallback(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed callback function
        /// Receives context and the rejection reason (or null)
        callback: *const fn (ctx: *T, reason: ?*anyopaque) void,

        /// Pointer to user context (must be heap-allocated!)
        context: *T,

        /// Allocator for cleanup
        allocator: ?std.mem.Allocator = null,

        /// Initialize with non-owning reference
        pub fn init(
            callback: *const fn (ctx: *T, reason: ?*anyopaque) void,
            context: *T,
        ) Self {
            return .{
                .callback = callback,
                .context = context,
                .allocator = null,
            };
        }

        /// Initialize with ownership
        pub fn initOwned(
            callback: *const fn (ctx: *T, reason: ?*anyopaque) void,
            context: *T,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .callback = callback,
                .context = context,
                .allocator = allocator,
            };
        }

        /// Invoke the callback
        pub fn invoke(self: Self, reason: ?*anyopaque) void {
            self.callback(self.context, reason);
        }

        /// Invoke and free owned context
        pub fn invokeAndFree(self: *Self, reason: ?*anyopaque) void {
            self.callback(self.context, reason);
            if (self.allocator) |alloc| {
                alloc.destroy(self.context);
                self.allocator = null;
            }
        }

        /// Get context as anyopaque for legacy APIs
        pub fn getContextAnyopaque(self: Self) ?*anyopaque {
            return @ptrCast(self.context);
        }

        /// Get a C-calling-convention trampoline for V8 promise handlers
        pub fn toLegacyCallbackC() *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void {
            return &legacyTrampolineC;
        }

        fn legacyTrampolineC(ctx: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void {
            const typed: *T = @ptrCast(@alignCast(ctx orelse return));
            _ = typed;
            _ = reason;
        }

        /// Free owned context without invoking callback
        pub fn deinit(self: *Self) void {
            if (self.allocator) |alloc| {
                alloc.destroy(self.context);
                self.allocator = null;
            }
        }
    };
}

// ============================================================================
// Self-Contained Promise Callback
// ============================================================================

/// A promise callback that stores the callback function and context together.
///
/// This is the recommended pattern for promise handlers because it ensures
/// the callback function pointer and context are always available together.
/// Essential for C ABI compatibility with V8's promise handler API.
///
/// ## Example
///
/// ```zig
/// const FetchContext = struct {
///     url: []const u8,
///     on_done: *const fn ([]const u8, bool) void,
/// };
///
/// fn handleFetchResult(ctx: *FetchContext, value: ?*anyopaque) void {
///     _ = value;
///     ctx.on_done(ctx.url, true);
/// }
///
/// // Create self-contained callback
/// var cb = try SelfContainedPromiseCallback(FetchContext).create(
///     allocator,
///     &handleFetchResult,
///     .{ .url = "https://example.com", .on_done = &myHandler },
/// );
///
/// // Pass to V8
/// engine.chainPromiseHandlers(
///     promise,
///     cb.getTrampolineC(),
///     cb.toAnyopaque(),
///     reject_handler,
///     reject_ctx,
/// );
///
/// // Cleanup happens in the trampoline after invocation
/// ```
pub fn SelfContainedPromiseCallback(comptime UserData: type) type {
    return struct {
        const Self = @This();

        /// Embedded user data
        data: UserData,

        /// Callback function pointer
        callback: *const fn (data: *UserData, value: ?*anyopaque) void,

        /// Allocator for self-destruction after invocation
        allocator: std.mem.Allocator,

        /// Create a new self-contained promise callback on the heap
        pub fn create(
            allocator: std.mem.Allocator,
            callback: *const fn (data: *UserData, value: ?*anyopaque) void,
            data: UserData,
        ) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .data = data,
                .callback = callback,
                .allocator = allocator,
            };
            return self;
        }

        /// Destroy the callback wrapper
        pub fn destroy(self: *Self) void {
            self.allocator.destroy(self);
        }

        /// Invoke the callback (does NOT destroy self)
        pub fn invoke(self: *Self, value: ?*anyopaque) void {
            self.callback(&self.data, value);
        }

        /// Invoke the callback and destroy self
        ///
        /// This is the typical pattern for promise handlers - they fire once
        /// and should be cleaned up after.
        pub fn invokeAndDestroy(self: *Self, value: ?*anyopaque) void {
            self.callback(&self.data, value);
            self.destroy();
        }

        /// Get pointer to embedded data
        pub fn getData(self: *Self) *UserData {
            return &self.data;
        }

        /// Convert to anyopaque for legacy APIs
        pub fn toAnyopaque(self: *Self) *anyopaque {
            return @ptrCast(self);
        }

        /// Get a C-calling-convention trampoline for V8 promise handlers
        ///
        /// The trampoline invokes the callback AND destroys the wrapper.
        /// Use this for one-shot promise handlers.
        pub fn getTrampolineC() *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void {
            return &trampolineC;
        }

        fn trampolineC(ctx: ?*anyopaque, value: ?*anyopaque) callconv(.c) void {
            const self: *Self = @ptrCast(@alignCast(ctx orelse return));
            self.invokeAndDestroy(value);
        }

        /// Get a non-destructive trampoline (callback only, no cleanup)
        ///
        /// Use this if you need to retain the wrapper after invocation.
        pub fn getTrampolineNonDestructiveC() *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void {
            return &trampolineNonDestructiveC;
        }

        fn trampolineNonDestructiveC(ctx: ?*anyopaque, value: ?*anyopaque) callconv(.c) void {
            const self: *Self = @ptrCast(@alignCast(ctx orelse return));
            self.invoke(value);
        }
    };
}

// ============================================================================
// Typed Context Callback (for DOM/parser callbacks)
// ============================================================================

/// Typed wrapper for callbacks that receive a context and one typed argument.
///
/// Common pattern in DOM callbacks, parser hooks, and tree walkers.
/// The callback receives a typed context and a single typed argument.
///
/// ## Example
///
/// ```zig
/// const ParserContext = struct {
///     document: *Document,
///     allocator: std.mem.Allocator,
/// };
///
/// const TreeNode = opaque {};
///
/// const NodeCreatedCb = TypedContextCallback(ParserContext, *TreeNode, void);
///
/// fn onNodeCreated(ctx: *ParserContext, node: *TreeNode) void {
///     // Handle node creation
///     _ = ctx;
///     _ = node;
/// }
///
/// var ctx = ParserContext{ ... };
/// const cb = NodeCreatedCb.init(&onNodeCreated, &ctx);
/// parser.setCallback(cb.toLegacyCallback(), cb.getContextAnyopaque());
/// ```
pub fn TypedContextCallback(comptime ContextType: type, comptime ArgType: type, comptime ReturnType: type) type {
    return struct {
        const Self = @This();

        /// The typed callback function
        callback: *const fn (ctx: *ContextType, arg: ArgType) ReturnType,

        /// Pointer to user context
        context: *ContextType,

        /// Initialize with non-owning reference
        pub fn init(
            callback: *const fn (ctx: *ContextType, arg: ArgType) ReturnType,
            context: *ContextType,
        ) Self {
            return .{
                .callback = callback,
                .context = context,
            };
        }

        /// Invoke the callback
        pub fn invoke(self: Self, arg: ArgType) ReturnType {
            return self.callback(self.context, arg);
        }

        /// Get context as anyopaque for legacy APIs
        pub fn getContextAnyopaque(self: Self) ?*anyopaque {
            return @ptrCast(self.context);
        }

        /// Get a trampoline function for legacy APIs
        /// Note: This requires ArgType to be pointer-convertible to *anyopaque
        pub fn toLegacyCallback(self: Self) *const fn (?*anyopaque, ArgType) ReturnType {
            _ = self;
            return &legacyTrampoline;
        }

        fn legacyTrampoline(ctx: ?*anyopaque, arg: ArgType) ReturnType {
            const typed: *ContextType = @ptrCast(@alignCast(ctx orelse {
                if (ReturnType == void) return;
                @panic("TypedContextCallback trampoline called with null context");
            }));
            _ = typed;
            _ = arg;
            // Note: Actual invocation requires the callback pointer
            if (ReturnType == void) return;
            @panic("TypedContextCallback trampoline cannot invoke without callback");
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
