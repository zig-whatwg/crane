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
            defer v8.v8_Value_Dispose(v8_value);

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
            defer v8.v8_Value_Dispose(v8_reason);

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
