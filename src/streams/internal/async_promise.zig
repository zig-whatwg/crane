//! Async Promise Implementation for Streams
//!
//! This module provides true asynchronous promise behavior that integrates
//! with an event loop. Promises are settled asynchronously via microtasks,
//! and then/catch/finally handlers execute asynchronously.
//!
//! ## ECMAScript Promise Semantics
//!
//! This implementation follows the ECMAScript Promise specification:
//! - **Spec**: https://tc39.es/ecma262/#sec-promise-objects
//! - **WebIDL**: https://webidl.spec.whatwg.org/#idl-promise
//!
//! Key behaviors:
//! 1. Promises start in "pending" state
//! 2. Can transition to "fulfilled" (with value) or "rejected" (with reason)
//! 3. State transitions are one-way and permanent
//! 4. Settlement (fulfill/reject) queues microtasks for reactions
//! 5. Then/catch/finally handlers execute asynchronously
//!
//! ## Usage
//!
//! ```zig
//! const allocator = std.testing.allocator;
//! var loop = TestEventLoop.init(allocator);
//! defer loop.deinit();
//!
//! // Create a pending promise
//! const promise = try AsyncPromise(u32).init(allocator, loop.eventLoop());
//! defer promise.deinit();
//!
//! // Attach a reaction
//! var result: ?u32 = null;
//! _ = try promise.then(struct {
//!     fn onFulfilled(value: u32) !u32 {
//!         result = value;
//!         return value * 2;
//!     }
//! }.onFulfilled, null);
//!
//! // Fulfill the promise
//! promise.fulfill(21);
//!
//! // Run microtasks to execute reactions
//! loop.eventLoop().runMicrotasks();
//!
//! // Result is now set
//! try testing.expectEqual(@as(?u32, 21), result);
//! ```
//!
//! ## Memory Management
//!
//! Promises are heap-allocated and must be deinitialized:
//! ```zig
//! const promise = try AsyncPromise(T).init(allocator, loop);
//! defer promise.deinit();
//! ```
//!
//! ### Promise Ownership Model
//!
//! **IMPORTANT**: Promise chaining creates new promises that must be managed:
//!
//! ```zig
//! // ❌ MEMORY LEAK - chained promise is never deinitialized
//! _ = try promise.then(handler, null);
//!
//! // ✅ CORRECT - keep reference and deinit
//! const chained = try promise.then(handler, null);
//! defer chained.deinit();
//!
//! // ✅ BEST - use onSettleCtx when you don't need a chain
//! try promise.onSettleCtx(handler, null, &context);
//! // No chained promise created, nothing to leak!
//! ```
//!
//! **Guidelines**:
//! - Use `then()` or `thenCtx()` when you need promise chaining
//!   - Caller MUST keep the returned promise and call deinit()
//! - Use `onSettleCtx()` for fire-and-forget handlers
//!   - No chained promise, no leak risk
//!   - Perfect for callbacks that don't return values
//!
//! ## Thread Safety
//!
//! This implementation is **NOT thread-safe**. It's designed for single-threaded
//! event loop environments, matching JavaScript's execution model.

const std = @import("std");
const Allocator = std.mem.Allocator;
const event_loop = @import("event_loop");
const common = @import("common");
const webidl = @import("webidl");
const infra = @import("infra");
const JSValue = common.JSValue;

/// Async Promise type
///
/// This provides asynchronous promise behavior with event loop integration.
/// Promises settle asynchronously by queuing microtasks.
///
/// Type parameter T is the fulfilled value type.
pub fn AsyncPromise(comptime T: type) type {
    return struct {
        allocator: Allocator,
        event_loop: event_loop.EventLoop,
        state: State,
        reactions: infra.List(Reaction),

        const Self = @This();

        /// Promise state
        ///
        /// Promises start as pending and transition to fulfilled or rejected.
        /// State transitions are one-way and permanent.
        ///
        /// Error Handling:
        /// - Rejected state now uses proper WebIDL exceptions instead of JSValue
        /// - This enables correct error propagation to JavaScript runtimes
        pub const State = union(enum) {
            /// Pending - not yet settled
            pending: void,

            /// Fulfilled - resolved with a value
            fulfilled: T,

            /// Rejected - rejected with a proper exception
            rejected: webidl.errors.Exception,
        };

        /// Reaction - A then/catch/finally handler
        ///
        /// When a promise settles, all pending reactions are queued as microtasks.
        ///
        /// Supports both context-aware and context-free handlers for flexibility.
        ///
        /// Error Handling:
        /// - Rejection handlers now receive proper WebIDL exceptions
        pub const Reaction = struct {
            /// Called when promise fulfills (may be null)
            /// Legacy signature: fn(T) anyerror!T
            on_fulfilled: ?*const fn (T) anyerror!T,

            /// Called when promise rejects (may be null)
            /// Now receives proper Exception instead of JSValue
            on_rejected: ?*const fn (webidl.errors.Exception) anyerror!T,

            /// Context-aware fulfillment handler (may be null)
            /// New signature: fn(*anyopaque, T) anyerror!T
            on_fulfilled_ctx: ?*const fn (*anyopaque, T) anyerror!T,

            /// Context-aware rejection handler (may be null)
            /// Now receives proper Exception instead of JSValue
            on_rejected_ctx: ?*const fn (*anyopaque, webidl.errors.Exception) anyerror!T,

            /// Context pointer for context-aware handlers
            context: ?*anyopaque,

            /// Promise to settle with the handler result (null for onSettleCtx reactions)
            target_promise: ?*Self,
        };

        /// Initialize a new pending promise
        ///
        /// The promise starts in pending state. You must call fulfill() or
        /// reject() to settle it.
        ///
        /// The promise itself is allocated from the event loop's arena allocator,
        /// matching browser semantics where the JavaScript execution context
        /// (event loop) manages promise lifetime via garbage collection.
        ///
        /// The reactions list uses the provided allocator for internal bookkeeping.
        ///
        /// Example:
        /// ```zig
        /// const promise = try AsyncPromise(u32).init(allocator, loop);
        /// defer promise.deinit();  // Only cleans up reactions, arena frees promise
        /// ```
        pub fn init(allocator: Allocator, loop: event_loop.EventLoop) !*Self {
            // Allocate promise from event loop's arena
            const promise_alloc = loop.promiseAllocator();
            const self = try promise_alloc.create(Self);

            self.* = .{
                .allocator = allocator, // For reactions list
                .event_loop = loop,
                .state = .pending,
                .reactions = infra.List(Reaction).init(allocator),
            };
            return self;
        }

        /// Free the promise's resources
        ///
        /// This clears the reactions list but does NOT free the promise itself.
        /// The promise memory is owned by the event loop's arena and will be
        /// freed when the event loop is destroyed.
        ///
        /// This matches browser semantics where promises are garbage collected
        /// when the execution context is destroyed, not manually freed.
        ///
        /// After calling deinit(), the promise memory remains valid but should
        /// not be used (all operations will fail or panic).
        pub fn deinit(self: *Self) void {
            self.reactions.deinit();
            // NOTE: Don't free self - arena owns it
        }

        /// Fulfill the promise with a value
        ///
        /// This settles the promise to fulfilled state and queues microtasks
        /// for all pending reactions.
        ///
        /// If the promise is already settled, this is a no-op.
        ///
        /// Example:
        /// ```zig
        /// promise.fulfill(42);
        /// loop.runMicrotasks(); // Execute reactions
        /// ```
        pub fn fulfill(self: *Self, value: T) void {
            if (self.state != .pending) return; // Already settled

            self.state = .{ .fulfilled = value };

            // Queue microtask for each reaction
            for (self.reactions.toSlice()) |reaction| {
                self.queueReaction(reaction, self.state);
            }

            self.reactions.clear();
        }

        /// Reject the promise with an error
        ///
        /// This settles the promise to rejected state and queues microtasks
        /// for all pending reactions.
        ///
        /// If the promise is already settled, this is a no-op.
        ///
        /// Example:
        /// ```zig
        /// const exception = webidl.errors.Exception{
        ///     .simple = .{ .type = .TypeError, .message = "Something went wrong" }
        /// };
        /// promise.reject(exception);
        /// loop.runMicrotasks(); // Execute reactions
        /// ```
        pub fn reject(self: *Self, error_value: webidl.errors.Exception) void {
            if (self.state != .pending) return; // Already settled

            self.state = .{ .rejected = error_value };

            // Queue microtask for each reaction
            for (self.reactions.toSlice()) |reaction| {
                self.queueReaction(reaction, self.state);
            }

            self.reactions.clear();
        }

        /// Execute close steps for ReadResult promises
        ///
        /// Spec: Used when closing a stream with pending read requests.
        /// Fulfills the promise with { value: null, done: true }
        ///
        /// Only available for AsyncPromise(ReadResult)
        pub fn executeCloseSteps(self: *Self) void {
            // This method is only meaningful for ReadResult promises
            const ReadResult = @import("common").ReadResult;
            if (T == ReadResult) {
                self.fulfill(.{ .value = null, .done = true });
            } else {
                @compileError("executeCloseSteps is only available for AsyncPromise(ReadResult)");
            }
        }

        /// Execute chunk steps for ReadResult promises
        ///
        /// Spec: Used when fulfilling a read request with a chunk.
        /// Fulfills the promise with { value: chunk, done: false }
        ///
        /// Only available for AsyncPromise(ReadResult)
        pub fn executeChunkSteps(self: *Self, chunk: anytype) void {
            // This method is only meaningful for ReadResult promises
            const ReadResult = @import("common").ReadResult;
            if (T == ReadResult) {
                // Convert ArrayBufferView chunk to JSValue bytes
                // chunk has: data ([]u8), offset (usize), length (usize)
                const bytes_slice = chunk.data[chunk.offset..][0..chunk.length];
                const value = JSValue{ .bytes = bytes_slice };
                self.fulfill(.{ .value = value, .done = false });
            } else {
                @compileError("executeChunkSteps is only available for AsyncPromise(ReadResult)");
            }
        }

        /// Attach fulfillment and rejection handlers
        ///
        /// Returns a new promise that resolves/rejects based on the handler
        /// results. Handlers execute asynchronously as microtasks.
        ///
        /// - `on_fulfilled`: Called if this promise fulfills (may be null)
        /// - `on_rejected`: Called if this promise rejects (may be null)
        ///
        /// Example:
        /// ```zig
        /// const chained = try promise.then(
        ///     struct {
        ///         fn onFulfilled(value: u32) !u32 {
        ///             return value * 2;
        ///         }
        ///     }.onFulfilled,
        ///     null
        /// );
        /// defer chained.deinit();
        /// ```
        pub fn then(
            self: *Self,
            on_fulfilled: ?*const fn (T) anyerror!T,
            on_rejected: ?*const fn (webidl.errors.Exception) anyerror!T,
        ) !*Self {
            const new_promise = try Self.init(self.allocator, self.event_loop);

            const reaction = Reaction{
                .on_fulfilled = on_fulfilled,
                .on_rejected = on_rejected,
                .on_fulfilled_ctx = null,
                .on_rejected_ctx = null,
                .context = null,
                .target_promise = new_promise,
            };

            switch (self.state) {
                .pending => {
                    // Add to reaction list
                    try self.reactions.append(reaction);
                },
                .fulfilled, .rejected => {
                    // Already settled - queue immediately
                    self.queueReaction(reaction, self.state);
                },
            }

            return new_promise;
        }

        /// Attach fulfillment and rejection handlers with context
        ///
        /// This is the context-aware version of then(), allowing handlers to
        /// access state through a context pointer. This is essential for
        /// complex async patterns like pipeTo shuttling loops.
        ///
        /// Returns a new promise that resolves/rejects based on the handler
        /// results. Handlers execute asynchronously as microtasks.
        ///
        /// - `on_fulfilled`: Called if this promise fulfills (may be null)
        /// - `on_rejected`: Called if this promise rejects (may be null)
        /// - `context`: Context pointer passed to handlers
        ///
        /// Example:
        /// ```zig
        /// const Context = struct { multiplier: u32 };
        /// var ctx = Context{ .multiplier = 3 };
        ///
        /// const chained = try promise.thenCtx(
        ///     struct {
        ///         fn onFulfilled(c: *anyopaque, value: u32) !u32 {
        ///             const context: *Context = @ptrCast(@alignCast(c));
        ///             return value * context.multiplier;
        ///         }
        ///     }.onFulfilled,
        ///     null,
        ///     &ctx,
        /// );
        /// defer chained.deinit();
        /// ```
        pub fn thenCtx(
            self: *Self,
            on_fulfilled: ?*const fn (*anyopaque, T) anyerror!T,
            on_rejected: ?*const fn (*anyopaque, webidl.errors.Exception) anyerror!T,
            context: *anyopaque,
        ) !*Self {
            const new_promise = try Self.init(self.allocator, self.event_loop);

            const reaction = Reaction{
                .on_fulfilled = null,
                .on_rejected = null,
                .on_fulfilled_ctx = on_fulfilled,
                .on_rejected_ctx = on_rejected,
                .context = context,
                .target_promise = new_promise,
            };

            switch (self.state) {
                .pending => {
                    // Add to reaction list
                    try self.reactions.append(reaction);
                },
                .fulfilled, .rejected => {
                    // Already settled - queue immediately
                    self.queueReaction(reaction, self.state);
                },
            }

            return new_promise;
        }

        /// Attach handlers with context without creating a chained promise
        ///
        /// This is useful when you just want to execute a callback when the promise
        /// settles, but don't care about chaining another promise. This avoids
        /// memory leaks from unreferenced chained promises.
        ///
        /// Example:
        /// ```zig
        /// try promise.onSettleCtx(myOnFulfilled, myOnRejected, &my_context);
        /// ```
        pub fn onSettleCtx(
            self: *Self,
            on_fulfilled: ?*const fn (*anyopaque, T) anyerror!void,
            on_rejected: ?*const fn (*anyopaque, webidl.errors.Exception) anyerror!void,
            context: *anyopaque,
        ) !void {
            const reaction = Reaction{
                .on_fulfilled = null,
                .on_rejected = null,
                .on_fulfilled_ctx = if (on_fulfilled) |f| @ptrCast(f) else null,
                .on_rejected_ctx = if (on_rejected) |r| @ptrCast(r) else null,
                .context = context,
                .target_promise = null, // No chained promise
            };

            switch (self.state) {
                .pending => {
                    // Add to reaction list
                    try self.reactions.append(reaction);
                },
                .fulfilled, .rejected => {
                    // Already settled - queue immediately
                    self.queueReaction(reaction, self.state);
                },
            }
        }

        /// Attach a rejection handler only
        ///
        /// Equivalent to `then(null, on_rejected)`.
        ///
        /// Example:
        /// ```zig
        /// _ = try promise.catch(struct {
        ///     fn onRejected(error_value: webidl.errors.Exception) !u32 {
        ///         return 0; // Default value on error
        ///     }
        /// }.onRejected);
        /// ```
        pub fn catch_(
            self: *Self,
            on_rejected: *const fn (webidl.errors.Exception) anyerror!T,
        ) !*Self {
            return self.then(null, on_rejected);
        }

        /// Check if the promise is pending
        pub fn isPending(self: *const Self) bool {
            return self.state == .pending;
        }

        /// Check if the promise is fulfilled
        pub fn isFulfilled(self: *const Self) bool {
            return self.state == .fulfilled;
        }

        /// Check if the promise is rejected
        pub fn isRejected(self: *const Self) bool {
            return self.state == .rejected;
        }

        // ====================================================================
        // Internal Implementation
        // ====================================================================

        /// Queue a reaction as a microtask
        fn queueReaction(self: *Self, reaction: Reaction, state: State) void {
            // Create context for microtask
            // IMPORTANT: Allocate from event loop's promise arena, not regular allocator.
            // This ensures that if microtasks are not run during cleanup, the context
            // is automatically freed when the event loop's arena is destroyed.
            const promise_alloc = self.event_loop.promiseAllocator();
            const ctx = promise_alloc.create(ReactionContext) catch @panic("AsyncPromise: OOM in queueReaction");
            ctx.* = .{
                .promise_alloc = promise_alloc,
                .reaction = reaction,
                .state = state,
            };

            self.event_loop.queueMicrotask(.{
                .callback = executeReaction,
                .context = ctx,
            });
        }

        /// Context passed to microtask
        const ReactionContext = struct {
            promise_alloc: Allocator,
            reaction: Reaction,
            state: State,
        };

        /// Execute a reaction (called as microtask)
        fn executeReaction(ctx_ptr: ?*anyopaque) void {
            const ctx: *ReactionContext = @ptrCast(@alignCast(ctx_ptr.?));
            const promise_alloc = ctx.promise_alloc;
            defer promise_alloc.destroy(ctx);

            const reaction = ctx.reaction;
            const state = ctx.state;

            switch (state) {
                .fulfilled => |value| {
                    // Check for context-aware handler first
                    if (reaction.on_fulfilled_ctx) |handler| {
                        if (reaction.target_promise) |target| {
                            // Chained promise - capture result and forward it
                            const result = handler(reaction.context.?, value) catch |err| {
                                const exception = webidl.errors.Exception.typeError(target.allocator, @errorName(err)) catch return;
                                target.reject(exception);
                                return;
                            };
                            target.fulfill(result);
                        } else {
                            // No chained promise - just execute handler and discard result
                            _ = handler(reaction.context.?, value) catch {};
                        }
                    } else if (reaction.on_fulfilled) |handler| {
                        if (reaction.target_promise) |target| {
                            // Chained promise - capture result and forward it
                            const result = handler(value) catch |err| {
                                const exception = webidl.errors.Exception.typeError(target.allocator, @errorName(err)) catch return;
                                target.reject(exception);
                                return;
                            };
                            target.fulfill(result);
                        } else {
                            // No chained promise - just execute handler and discard result
                            _ = handler(value) catch {};
                        }
                    } else {
                        // No handler - forward fulfillment if target exists
                        if (reaction.target_promise) |target| {
                            target.fulfill(value);
                        }
                    }
                },
                .rejected => |error_value| {
                    // Check for context-aware handler first
                    if (reaction.on_rejected_ctx) |handler| {
                        if (reaction.target_promise) |target| {
                            // Chained promise - capture result and forward it
                            const result = handler(reaction.context.?, error_value) catch |err| {
                                const exception = webidl.errors.Exception.typeError(target.allocator, @errorName(err)) catch return;
                                target.reject(exception);
                                return;
                            };
                            target.fulfill(result);
                        } else {
                            // No chained promise - just execute handler and discard result
                            _ = handler(reaction.context.?, error_value) catch {};
                        }
                    } else if (reaction.on_rejected) |handler| {
                        if (reaction.target_promise) |target| {
                            // Chained promise - capture result and forward it
                            const result = handler(error_value) catch |err| {
                                const exception = webidl.errors.Exception.typeError(target.allocator, @errorName(err)) catch return;
                                target.reject(exception);
                                return;
                            };
                            target.fulfill(result);
                        } else {
                            // No chained promise - just execute handler and discard result
                            _ = handler(error_value) catch {};
                        }
                    } else {
                        // No handler - forward rejection if target exists
                        if (reaction.target_promise) |target| {
                            target.reject(error_value);
                        }
                    }
                },
                .pending => unreachable, // Should never queue a reaction for pending state
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const TestEventLoop = @import("test_event_loop").TestEventLoop;
















