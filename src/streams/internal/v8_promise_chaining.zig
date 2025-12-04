//! V8 Promise Chaining Utility
//!
//! This module provides a reusable utility for chaining handlers onto V8 Promises
//! and bridging them to Zig's AsyncPromise. This enables proper async/await semantics
//! when JavaScript callbacks return Promises.
//!
//! ## Overview
//!
//! When JS callbacks (start, pull, cancel, write, close, abort, flush, transform)
//! return Promises, we need to:
//! 1. Detect that the return value is a Promise (using v8_Value_IsPromise)
//! 2. Chain .then() and .catch() handlers onto it (using v8_Promise_Then)
//! 3. Bridge settlement to an AsyncPromise for Zig-side async handling
//!
//! ## Usage
//!
//! ```zig
//! const v8_chain = @import("v8_promise_chaining");
//!
//! // After calling a JS function that may return a Promise:
//! const result = v8.v8_Function_Call(func, ctx, recv, argc, argv);
//! if (result) |value| {
//!     if (v8_chain.chainIfPromise(allocator, context, value, .{
//!         .on_fulfill = myFulfillFn,
//!         .on_reject = myRejectFn,
//!         .user_context = myCtx,
//!     })) {
//!         // Was a promise, handlers are chained
//!         return;
//!     }
//!     // Not a promise, handle synchronously
//! }
//! ```
//!
//! ## WHATWG Streams Spec References
//!
//! - § 4.9.3 SetUpReadableStreamDefaultController Step 10-12 (start promise handling)
//! - § 4.9.4 ReadableStreamDefaultControllerCallPullIfNeeded (pull promise handling)
//! - § 4.9.14 SetUpWritableStreamDefaultController Step 10-12 (start promise handling)
//! - § 5.4.10 TransformStreamDefaultControllerPerformTransform (transform promise handling)
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const AsyncPromise = @import("async_promise").AsyncPromise;
const webidl = @import("webidl");
const runtime = @import("runtime");

/// V8 FFI bindings
const v8 = @import("v8").ffi;

/// Callback function types for promise settlement
pub const FulfillCallback = *const fn (ctx: ?*anyopaque, value: ?*anyopaque) callconv(.c) void;
pub const RejectCallback = *const fn (ctx: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void;

/// Configuration for promise chaining
pub const ChainConfig = struct {
    /// Called when the promise fulfills
    on_fulfill: FulfillCallback,
    /// Called when the promise rejects
    on_reject: RejectCallback,
    /// User context passed to both callbacks
    user_context: ?*anyopaque = null,
    /// Allocator for the callback context (if user_context needs to be freed by callbacks)
    allocator: ?Allocator = null,
};

/// Result of attempting to chain handlers onto a V8 value
pub const ChainResult = enum {
    /// Value was a Promise and handlers were successfully chained
    chained,
    /// Value was a Promise but handler chaining failed
    chain_failed,
    /// Value was not a Promise
    not_promise,
};

/// Check if a V8 value is a Promise and chain handlers if so.
///
/// This is the primary entry point for the utility. It checks if the value is
/// a Promise, and if so, creates V8 Function handlers that invoke the provided
/// Zig callbacks when the promise settles.
///
/// Arguments:
/// - context: V8 Context for creating handlers
/// - value: V8 Value to check (may or may not be a Promise)
/// - config: Configuration specifying callbacks and context
///
/// Returns:
/// - .chained: The value was a Promise and handlers were successfully attached
/// - .chain_failed: The value was a Promise but we failed to attach handlers
/// - .not_promise: The value was not a Promise
///
/// Note: If chaining fails, the caller should handle the error (e.g., fall back
/// to immediate fulfillment or reject with an error).
pub fn chainIfPromise(
    context: *v8.Context,
    value: *v8.Value,
    config: ChainConfig,
) ChainResult {
    // Check if value is a Promise
    if (!v8.v8_Value_IsPromise(value)) {
        return .not_promise;
    }

    // Cast to Promise type
    const promise: *v8.Promise = @ptrCast(value);

    // Create fulfill handler
    const fulfill_handler = v8.v8_CreateZigFulfillHandler(
        context,
        config.on_fulfill,
        config.user_context,
    ) orelse {
        return .chain_failed;
    };

    // Create reject handler
    const reject_handler = v8.v8_CreateZigRejectHandler(
        context,
        config.on_reject,
        config.user_context,
    ) orelse {
        // Clean up fulfill handler before returning
        v8.v8_DisposeZigCallbackHandler(fulfill_handler);
        return .chain_failed;
    };

    // Chain handlers onto the promise
    const chained = v8.v8_Promise_Then(promise, context, fulfill_handler, reject_handler);
    if (chained == null) {
        // Failed to chain - clean up both handlers
        v8.v8_DisposeZigCallbackHandler(reject_handler);
        v8.v8_DisposeZigCallbackHandler(fulfill_handler);
        return .chain_failed;
    }

    // Successfully chained handlers
    return .chained;
}

/// Context structure for bridging V8 Promise to AsyncPromise
/// This is passed to the V8 promise handlers and freed after settlement
pub const PromiseBridgeContext = struct {
    promise: *AsyncPromise(void),
    allocator: Allocator,
};

/// Callback invoked when V8 Promise fulfills
/// Fulfills the corresponding AsyncPromise
fn promiseBridgeFulfillCallback(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const bridge_ctx: *PromiseBridgeContext = @ptrCast(@alignCast(ctx orelse return));
    defer bridge_ctx.allocator.destroy(bridge_ctx);

    // Fulfill the AsyncPromise
    bridge_ctx.promise.fulfill({});
}

/// Callback invoked when V8 Promise rejects
/// Rejects the corresponding AsyncPromise
fn promiseBridgeRejectCallback(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const bridge_ctx: *PromiseBridgeContext = @ptrCast(@alignCast(ctx orelse return));
    defer bridge_ctx.allocator.destroy(bridge_ctx);

    // Reject the AsyncPromise with a generic error
    // Note: We could extract the error message from the V8 value if needed
    bridge_ctx.promise.reject(webidl.errors.Exception{ .simple = .{
        .type = .TypeError,
        .message = "Promise rejected",
    } });
}

/// Bridge a V8 Promise to an AsyncPromise
///
/// Creates handlers that fulfill/reject the AsyncPromise when the V8 Promise settles.
/// This enables integration between V8's Promise system and Zig's AsyncPromise.
///
/// Arguments:
/// - allocator: Allocator for the bridge context
/// - context: V8 Context for creating handlers
/// - v8_promise_value: V8 Value that must be a Promise
/// - async_promise: The AsyncPromise to settle when the V8 Promise settles
///
/// Returns:
/// - true: Successfully bridged (handlers attached)
/// - false: Failed to bridge (handlers could not be attached)
///
/// On failure, the caller should settle the async_promise immediately (typically
/// by fulfilling it or rejecting with an error).
pub fn bridgeToAsyncPromise(
    allocator: Allocator,
    context: *v8.Context,
    v8_promise_value: *v8.Value,
    async_promise: *AsyncPromise(void),
) bool {
    // Create bridge context
    const bridge_ctx = allocator.create(PromiseBridgeContext) catch {
        return false;
    };
    bridge_ctx.* = .{
        .promise = async_promise,
        .allocator = allocator,
    };

    // Chain handlers onto the promise
    const result = chainIfPromise(context, v8_promise_value, .{
        .on_fulfill = promiseBridgeFulfillCallback,
        .on_reject = promiseBridgeRejectCallback,
        .user_context = bridge_ctx,
    });

    switch (result) {
        .chained => return true,
        .chain_failed, .not_promise => {
            // Failed or not a promise - clean up bridge context
            allocator.destroy(bridge_ctx);
            return false;
        },
    }
}

/// Check if a V8 value is a Promise, bridge to AsyncPromise if so, otherwise fulfill immediately.
///
/// This is a convenience function that combines promise checking, bridging, and
/// fallback handling into a single call. It's useful when you always want to
/// return an AsyncPromise regardless of whether the V8 callback returned a Promise.
///
/// Arguments:
/// - allocator: Allocator for the bridge context
/// - context: V8 Context for creating handlers
/// - value: V8 Value that may or may not be a Promise
/// - async_promise: The AsyncPromise to settle
///
/// Behavior:
/// - If value is a Promise: bridges it to async_promise (async settlement)
/// - If value is not a Promise: fulfills async_promise immediately
/// - If bridging fails: fulfills async_promise immediately (fallback)
pub fn bridgeOrFulfill(
    allocator: Allocator,
    context: *v8.Context,
    value: *v8.Value,
    async_promise: *AsyncPromise(void),
) void {
    if (!v8.v8_Value_IsPromise(value)) {
        // Not a promise - fulfill immediately
        async_promise.fulfill({});
        return;
    }

    // Try to bridge
    if (!bridgeToAsyncPromise(allocator, context, value, async_promise)) {
        // Bridge failed - fulfill immediately as fallback
        async_promise.fulfill({});
    }
    // If bridge succeeded, async_promise will be settled when V8 Promise settles
}

/// Check if a V8 value is a Promise
///
/// Simple wrapper around v8_Value_IsPromise for convenience.
pub fn isPromise(value: *v8.Value) bool {
    return v8.v8_Value_IsPromise(value);
}

// ============================================================================
// Tests
// ============================================================================

test "ChainConfig default values" {
    const noopFulfill = struct {
        fn cb(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {}
    }.cb;
    const noopReject = struct {
        fn cb(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {}
    }.cb;

    const config = ChainConfig{
        .on_fulfill = noopFulfill,
        .on_reject = noopReject,
    };

    try std.testing.expectEqual(@as(?*anyopaque, null), config.user_context);
    try std.testing.expectEqual(@as(?Allocator, null), config.allocator);
}

test "ChainResult enum values" {
    // Verify all enum variants exist
    _ = ChainResult.chained;
    _ = ChainResult.chain_failed;
    _ = ChainResult.not_promise;
}
