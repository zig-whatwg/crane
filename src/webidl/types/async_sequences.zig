//! WebIDL Async Sequence Type
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-async-sequence
//!
//! Async sequences represent asynchronous iterables that yield values over time.
//! Unlike Promise<sequence<T>> which loads all values into memory, async sequences
//! stream values one at a time.
//!
//! # Usage
//!
//! ```zig
//! const async_sequences = @import("async_sequences.zig");
//!
//! // Define an async sequence of chunks
//! var seq = AsyncSequence(Chunk).init(iterator);
//!
//! // In JavaScript, this becomes an async iterable:
//! // for await (const chunk of asyncSequence) {
//! //   processChunk(chunk);
//! // }
//! ```
//!
//! # Use Cases
//!
//! - Fetch Streams API - Stream response body chunks
//! - File System Access API - Stream directory entries
//! - WebGPU - Stream large buffer reads
//! - Any API that produces data over time without loading everything into memory

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

/// AsyncSequence<T> represents a WebIDL async_sequence<T> type.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-async-sequence
///
/// An async sequence is an asynchronous iterable that yields values of type T.
/// Values are produced on demand, not all at once.
///
/// Example:
/// ```zig
/// // WebIDL: Promise<async_sequence<Entry>> getAllEntries();
/// fn getAllEntries() AsyncSequence(Entry) {
///     return AsyncSequence(Entry).init(entryIterator);
/// }
/// ```
pub fn AsyncSequence(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Async iterator that produces values of type T
        iterator: AsyncIterator,

        /// AsyncIterator provides the mechanism to produce values asynchronously
        pub const AsyncIterator = struct {
            /// Function pointer to get the next value
            /// Returns null when iteration is complete
            /// Returns error if iteration fails
            next_fn: *const fn (ctx: *anyopaque) anyerror!?T,

            /// Opaque context pointer passed to next_fn
            context: *anyopaque,

            /// Get the next value from the iterator
            ///
            /// Returns:
            /// - `T` if a value is available
            /// - `null` if iteration is complete
            /// - `error` if iteration fails
            pub fn next(self: *AsyncIterator) anyerror!?T {
                return self.next_fn(self.context);
            }
        };

        /// Creates an async sequence from an async iterator
        pub fn init(iterator: AsyncIterator) Self {
            return .{ .iterator = iterator };
        }

        /// Creates an async sequence from a slice (for testing/simple cases)
        pub fn fromSlice(allocator: Allocator, items: []const T) !Self {
            const Context = struct {
                items: []const T,
                index: usize,

                fn nextFn(ctx: *anyopaque) anyerror!?T {
                    const self: *@This() = @ptrCast(@alignCast(ctx));
                    if (self.index >= self.items.len) {
                        return null;
                    }
                    const item = self.items[self.index];
                    self.index += 1;
                    return item;
                }
            };

            const context = try allocator.create(Context);
            context.* = .{
                .items = items,
                .index = 0,
            };

            return Self{
                .iterator = .{
                    .next_fn = Context.nextFn,
                    .context = context,
                },
            };
        }

        /// Helper to collect all values into a sequence (defeats the purpose but useful for testing)
        pub fn collect(self: *Self, allocator: Allocator) ![]T {
            var list = infra.List(T).init(allocator);
            errdefer list.deinit();

            while (try self.iterator.next()) |item| {
                try list.append(item);
            }

            return try list.toOwnedSlice();
        }
    };
}

/// BufferedAsyncSequence<T> provides async iteration with buffering using infra.Queue.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-async-iterable
///
/// This implementation allows producers to push values into a buffer (queue) and
/// consumers to pull values asynchronously. This enables backpressure handling
/// and decouples producer/consumer execution.
///
/// Use Cases:
/// - Fetch Streams API - Buffer response body chunks
/// - ReadableStream - Buffer data chunks
/// - File System Access API - Buffer directory entries
///
/// Example:
/// ```zig
/// var seq = BufferedAsyncSequence([]const u8).init(allocator);
/// defer seq.deinit();
///
/// // Producer: Push chunks as they arrive
/// try seq.push("chunk1");
/// try seq.push("chunk2");
/// seq.close(); // Signal end of stream
///
/// // Consumer: Read chunks
/// while (try seq.next()) |chunk| {
///     processChunk(chunk);
/// }
/// ```
pub fn BufferedAsyncSequence(comptime T: type) type {
    return struct {
        const Self = @This();

        queue: infra.Queue(T),
        allocator: Allocator,
        closed: bool,

        /// Initialize buffered async sequence
        pub fn init(allocator: Allocator) Self {
            return .{
                .queue = infra.Queue(T).init(allocator),
                .allocator = allocator,
                .closed = false,
            };
        }

        /// Clean up resources
        pub fn deinit(self: *Self) void {
            self.queue.deinit();
        }

        /// Producer: Push value into buffer
        ///
        /// Returns error.SequenceClosed if sequence was already closed.
        pub fn push(self: *Self, value: T) !void {
            if (self.closed) return error.SequenceClosed;
            try self.queue.enqueue(value);
        }

        /// Consumer: Get next value from buffer
        ///
        /// Returns:
        /// - `T` if a value is available in buffer
        /// - `null` if sequence is closed and buffer is empty (end of iteration)
        /// - Waits if sequence is open but buffer is empty (in real async impl)
        pub fn next(self: *Self) !?T {
            if (self.queue.isEmpty() and self.closed) {
                return null;
            }
            return self.queue.dequeue();
        }

        /// Producer: Signal end of sequence
        ///
        /// After calling close(), no more values can be pushed.
        /// Consumer will receive null after draining the buffer.
        pub fn close(self: *Self) void {
            self.closed = true;
        }

        /// Check if sequence is closed (no more values will be produced)
        pub fn isClosed(self: Self) bool {
            return self.closed;
        }

        /// Get number of buffered values waiting to be consumed
        pub fn bufferedCount(self: Self) usize {
            return self.queue.items_list.size();
        }

        /// Check if buffer is empty
        pub fn isEmpty(self: Self) bool {
            return self.queue.isEmpty();
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;






// ============================================================================
// BufferedAsyncSequence Tests
// ============================================================================










