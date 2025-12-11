//! V8 Promise Wrapper for Zig
//!
//! Provides high-level Zig interface to V8 Promises, enabling async operations
//! in WHATWG Streams and other async APIs.
//!
//! ## Usage
//!
//! ```zig
//! const Promise = @import("promise.zig").Promise;
//!
//! // Create a Promise
//! var promise = try Promise(u32).init(isolate, context);
//! defer promise.deinit();
//!
//! // Resolve it
//! try promise.resolve(42);
//!
//! // Get the V8 Promise to return to JavaScript
//! const v8_promise = promise.getPromise();
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");
const webidl = @import("webidl");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

/// V8 Promise wrapper for Zig
///
/// Provides type-safe Promise creation and manipulation.
/// Handles conversion between Zig values and V8 Values.
pub fn Promise(comptime T: type) type {
    return struct {
        resolver: *v8.PromiseResolver,
        promise: *v8.Promise,
        isolate: *v8.Isolate,
        context: *v8.Context,

        const Self = @This();

        /// Create a new Promise
        ///
        /// The Promise is initially in the "pending" state.
        /// Call resolve() or reject() to settle it.
        ///
        /// Example:
        /// ```zig
        /// var promise = try Promise(i32).init(isolate, context);
        /// defer promise.deinit();
        /// ```
        pub fn init(isolate: *v8.Isolate, context: *v8.Context) !Self {
            const resolver = v8.v8_PromiseResolver_New(context) orelse
                return error.PromiseCreationFailed;
            errdefer v8.v8_PromiseResolver_Dispose(resolver);

            const promise = v8.v8_PromiseResolver_GetPromise(resolver) orelse
                return error.PromiseCreationFailed;

            return Self{
                .resolver = resolver,
                .promise = promise,
                .isolate = isolate,
                .context = context,
            };
        }

        /// Resolve the Promise with a value
        ///
        /// Transitions the Promise to the "fulfilled" state.
        /// The Promise can only be settled once.
        ///
        /// Example:
        /// ```zig
        /// try promise.resolve(42);
        /// ```
        pub fn resolve(self: *Self, value: T) !void {
            const v8_value = try conv.toV8(T, self.isolate, self.context, value);
            // NOTE: Do NOT dispose v8_value here!
            // The value is passed to V8's Promise resolver and will be delivered
            // to .then() handlers via V8's microtask queue. V8/JS GC manages
            // the value's lifetime from this point on.
            //
            // Disposing here causes use-after-free when V8 tries to deliver
            // the value to Promise reaction handlers.

            if (!v8.v8_PromiseResolver_Resolve(self.resolver, self.context, v8_value)) {
                return error.PromiseResolveFailed;
            }
        }

        /// Reject the Promise with a reason
        ///
        /// Transitions the Promise to the "rejected" state.
        /// The Promise can only be settled once.
        ///
        /// Example:
        /// ```zig
        /// try promise.reject("something went wrong");
        /// ```
        pub fn reject(self: *Self, reason: anytype) !void {
            const v8_reason = try conv.toV8(@TypeOf(reason), self.isolate, self.context, reason);
            // NOTE: Do NOT dispose v8_reason here!
            // Same as resolve() - the reason is passed to V8's Promise resolver
            // and delivered via microtask queue to .catch() handlers.

            if (!v8.v8_PromiseResolver_Reject(self.resolver, self.context, v8_reason)) {
                return error.PromiseRejectFailed;
            }
        }

        /// Chain a .then() handler
        ///
        /// Returns a new Promise that will be resolved/rejected based on
        /// the result of calling the appropriate handler.
        ///
        /// Example:
        /// ```zig
        /// const chained = try promise.then(onFulfilled, onRejected);
        /// defer v8.v8_Promise_Dispose(chained);
        /// ```
        pub fn then(
            self: *Self,
            on_fulfilled: ?*v8.Function,
            on_rejected: ?*v8.Function,
        ) !*v8.Promise {
            return v8.v8_Promise_Then(
                self.promise,
                self.context,
                on_fulfilled,
                on_rejected,
            ) orelse error.PromiseThenFailed;
        }

        /// Chain a .catch() handler
        ///
        /// Equivalent to promise.then(undefined, onRejected).
        ///
        /// Example:
        /// ```zig
        /// const caught = try promise.catch(onRejected);
        /// defer v8.v8_Promise_Dispose(caught);
        /// ```
        pub fn catch_(
            self: *Self,
            on_rejected: *v8.Function,
        ) !*v8.Promise {
            return v8.v8_Promise_Catch(
                self.promise,
                self.context,
                on_rejected,
            ) orelse error.PromiseCatchFailed;
        }

        /// Get the underlying V8 Promise
        ///
        /// Use this to return the Promise to JavaScript.
        ///
        /// Example:
        /// ```zig
        /// const v8_promise = promise.getPromise();
        /// // Return v8_promise to JavaScript
        /// ```
        pub fn getPromise(self: *Self) *v8.Promise {
            return self.promise;
        }

        /// Clean up the Promise
        ///
        /// Disposes both the Promise and PromiseResolver.
        /// After calling deinit(), the Promise cannot be used.
        ///
        /// **IMPORTANT**: Do NOT call this if the Promise was returned to JavaScript!
        ///
        /// When you call `getPromise()` and return that to JavaScript (e.g., from
        /// an async iterator's `next()` method), JavaScript now owns the Promise.
        /// V8's garbage collector will manage its lifetime. Calling deinit() in
        /// that case causes use-after-free crashes when V8 tries to deliver the
        /// resolved/rejected value to JavaScript `.then()` handlers.
        ///
        /// **When to call deinit():**
        /// - Promise was created but never returned to JavaScript
        /// - Promise is only used internally in Zig code
        /// - Error paths where Promise creation failed and it was never exposed
        ///
        /// **When NOT to call deinit():**
        /// - Promise was returned to JavaScript via getPromise()
        /// - Promise is being resolved/rejected and JS handlers will receive it
        pub fn deinit(self: *Self) void {
            v8.v8_Promise_Dispose(self.promise);
            v8.v8_PromiseResolver_Dispose(self.resolver);
        }
    };
}

/// Call a JavaScript callback and get Promise result
///
/// Helper for invoking callbacks that return Promises.
/// Used by Streams API for write_algorithm, pull_algorithm, etc.
///
/// This properly chains the callback's returned Promise to the wrapper Promise,
/// so that when the callback's Promise settles, our wrapper Promise settles too.
///
/// Example:
/// ```zig
/// const promise = try invokeCallback(
///     void,
///     isolate,
///     context,
///     write_algorithm,
///     null,  // no 'this'
///     &[_]*v8.Value{chunk, controller},
/// );
/// defer promise.deinit();
/// ```
pub fn invokeCallback(
    comptime ReturnType: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    callback: *v8.Function,
    this_arg: ?*v8.Object,
    args: []const *v8.Value,
) !Promise(ReturnType) {
    // Call the function
    const this_val = if (this_arg) |obj|
        @as(*v8.Value, @ptrCast(obj))
    else
        v8.v8_Undefined(isolate) orelse return error.UndefinedCreationFailed;

    const result = v8.v8_Function_Call(
        callback,
        context,
        this_val,
        @intCast(args.len),
        @constCast(args.ptr),
    ) orelse return error.CallbackInvocationFailed;
    defer v8.v8_Value_Dispose(result);

    // Result should be a Promise
    // TODO: Add runtime type check with v8_Value_IsPromise
    // For now, we assume the callback returns a Promise as per spec

    // Create a wrapper Promise to return to Zig
    var wrapper = try Promise(ReturnType).init(isolate, context);
    errdefer wrapper.deinit();

    // Create resolve/reject handlers that will settle our wrapper Promise
    const resolve_handler = v8.v8_PromiseResolver_CreateResolveHandler(
        context,
        wrapper.resolver,
    ) orelse return error.HandlerCreationFailed;
    defer v8.v8_Function_Dispose(resolve_handler);

    const reject_handler = v8.v8_PromiseResolver_CreateRejectHandler(
        context,
        wrapper.resolver,
    ) orelse return error.HandlerCreationFailed;
    defer v8.v8_Function_Dispose(reject_handler);

    // Chain the callback's returned Promise to our wrapper
    // Cast result to Promise (we assume it's a Promise per spec)
    const source_promise = @as(*v8.Promise, @ptrCast(result));

    // source_promise.then(resolve_handler, reject_handler)
    // This chains: when source settles → our wrapper settles with same value/reason
    const chained = v8.v8_Promise_Then(
        source_promise,
        context,
        resolve_handler,
        reject_handler,
    ) orelse return error.PromiseChainingFailed;
    defer v8.v8_Promise_Dispose(chained);

    return wrapper;
}

// ============================================================================
// AsyncPromise to V8 Promise Bridge
// ============================================================================

/// Bridge for converting Zig AsyncPromise(T) to V8 Promise.
///
/// This is critical for correct promise handling: Zig AsyncPromise pointers
/// are NOT V8 handles and cannot be passed to JavaScript directly. This bridge
/// creates a proper V8 Promise and wires up callbacks so that when the Zig
/// promise settles, the V8 Promise settles too.
///
/// ## Example
///
/// ```zig
/// // WRONG - passing Zig pointer to JS!
/// const zig_promise = try AsyncPromise(void).init(allocator, event_loop);
/// return runtime.JSValue.fromAnyopaque(@ptrCast(zig_promise)); // CRASH!
///
/// // CORRECT - bridge to V8 Promise
/// const zig_promise = try AsyncPromise(void).init(allocator, event_loop);
/// const v8_promise = try asyncPromiseToV8(void, allocator, isolate, context, zig_promise);
/// return runtime.JSValue.fromHandle(@ptrCast(v8_promise));
/// ```
pub fn AsyncPromiseBridge(comptime T: type) type {
    return struct {
        v8_promise: Promise(T),
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context) !*Self {
            const bridge = try allocator.create(Self);
            errdefer allocator.destroy(bridge);

            bridge.* = .{
                .v8_promise = try Promise(T).init(isolate, context),
                .allocator = allocator,
                .isolate = isolate,
                .context = context,
            };

            return bridge;
        }

        fn deinit(self: *Self) void {
            // NOTE: Do NOT call self.v8_promise.deinit() here!
            // The V8 Promise was returned to JavaScript via getPromise().
            // JavaScript owns it now and V8's GC will manage its lifetime.
            // Disposing here causes use-after-free when V8 tries to deliver
            // the resolved value to JavaScript .then() handlers.
            //
            // We only free the bridge wrapper struct itself.
            self.allocator.destroy(self);
        }

        pub fn onFulfilled(ctx: *anyopaque, value: T) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.v8_promise.resolve(value) catch {};
            self.deinit();
        }

        pub fn onRejected(ctx: *anyopaque, err_value: webidl.errors.Exception) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.v8_promise.reject(err_value) catch {};
            self.deinit();
        }
    };
}

/// Convert a Zig AsyncPromise(T) to a V8 Promise.
///
/// Creates a V8 Promise and registers callbacks on the Zig promise.
/// When the Zig promise settles, the V8 promise is resolved/rejected
/// with the same value/error.
///
/// The returned V8 Promise pointer can be safely returned to JavaScript.
///
/// ## Arguments
/// - `T`: The type the AsyncPromise resolves to
/// - `allocator`: Allocator for the bridge (use c_allocator for safety)
/// - `isolate`: V8 isolate
/// - `context`: V8 context
/// - `zig_promise`: The Zig AsyncPromise to bridge
///
/// ## Returns
/// A V8 Promise pointer that can be returned to JavaScript
///
/// ## Example
///
/// ```zig
/// const zig_promise = try AsyncPromise(void).init(allocator, event_loop);
/// zig_promise.reject(exception); // Will settle the V8 promise too
/// const v8_promise = try asyncPromiseToV8(void, c_allocator, isolate, context, zig_promise);
/// // Return v8_promise to JavaScript
/// ```
pub fn asyncPromiseToV8(
    comptime T: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    zig_promise: *AsyncPromise(T),
) !*v8.Promise {
    const Bridge = AsyncPromiseBridge(T);

    // Create bridge that will resolve V8 promise when Zig promise settles
    const bridge = try Bridge.init(allocator, isolate, context);
    errdefer bridge.deinit();

    // Register callbacks on Zig promise
    // When it settles, bridge will settle the V8 promise
    try zig_promise.onSettleCtx(
        Bridge.onFulfilled,
        Bridge.onRejected,
        bridge,
    );

    // Return the V8 promise (bridge will be cleaned up when promise settles)
    return bridge.v8_promise.getPromise();
}

/// Create a rejected V8 Promise with the given exception.
///
/// This is a convenience function for error paths where you need to
/// return a rejected promise without creating an AsyncPromise first.
///
/// ## Example
///
/// ```zig
/// if (stream_is_locked) {
///     return createRejectedV8Promise(allocator, isolate, context,
///         try webidl.errors.Exception.typeError(allocator, "Stream is locked"));
/// }
/// ```
pub fn createRejectedV8Promise(
    isolate: *v8.Isolate,
    context: *v8.Context,
    exception: webidl.errors.Exception,
) !*v8.Promise {
    var promise = try Promise(void).init(isolate, context);
    // Don't defer deinit - the promise is being returned to JS
    try promise.reject(exception);
    return promise.getPromise();
}

/// Create a resolved V8 Promise with the given value.
///
/// This is a convenience function for success paths where you need to
/// return a resolved promise without creating an AsyncPromise first.
pub fn createResolvedV8Promise(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: T,
) !*v8.Promise {
    var promise = try Promise(T).init(isolate, context);
    // Don't defer deinit - the promise is being returned to JS
    try promise.resolve(value);
    return promise.getPromise();
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "Promise - creation and disposal" {
    // Skip until we have V8 test infrastructure
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create isolate and context
    // 2. Create Promise(i32)
    // 3. Verify it doesn't crash
    // 4. Call deinit()
}

test "Promise - resolve" {
    // Skip until we have V8 test infrastructure
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create Promise(i32)
    // 2. Resolve with 42
    // 3. Verify Promise state is fulfilled
    // 4. Verify value is 42
}

test "Promise - reject" {
    // Skip until we have V8 test infrastructure
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create Promise(i32)
    // 2. Reject with "error"
    // 3. Verify Promise state is rejected
    // 4. Verify reason is "error"
}

test "invokeCallback - basic call" {
    // Skip until we have V8 test infrastructure
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create a JS function that returns a Promise
    // 2. Invoke it with invokeCallback
    // 3. Verify Promise is returned
    // 4. Verify Promise resolves correctly
}
