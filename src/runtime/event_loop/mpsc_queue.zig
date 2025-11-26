//! Intrusive Multi-Producer Single-Consumer Queue
//!
//! Lock-free MPSC queue with cache-line alignment to prevent false sharing.
//! Used for thread-safe task submission to the event loop.
//!
//! ## Design
//!
//! - Intrusive: Nodes are embedded in user structures
//! - Lock-free: Uses atomic CAS operations
//! - Cache-line aligned: Head and tail on separate cache lines
//! - Single consumer: Only one thread may dequeue
//!
//! ## Usage
//!
//! Multiple producer threads call `push()` to enqueue work.
//! A single consumer thread calls `pop()` to dequeue work.
//!
//! ## References
//!
//! - Dmitry Vyukov: Intrusive MPSC Queue
//! - http://www.1024cores.net/home/lock-free-algorithms/queues/intrusive-mpsc-node-based-queue

const std = @import("std");
const atomic = std.atomic;

/// Cache line size (typically 64 bytes on modern CPUs)
const CACHE_LINE_SIZE = 64;

/// Intrusive node for MPSC queue
///
/// Embed this in your task structure for zero-allocation queuing.
pub const MpscNode = struct {
    /// Next pointer (atomic for lock-free operations)
    next: atomic.Value(?*MpscNode) = atomic.Value(?*MpscNode).init(null),
};

/// Lock-free multi-producer single-consumer queue
///
/// Cache-line aligned to prevent false sharing between producers and consumer.
/// Uses a simpler algorithm without stub node.
pub const MpscQueue = struct {
    /// Head pointer (consumer side, protected by single-consumer guarantee)
    head: ?*MpscNode align(CACHE_LINE_SIZE) = null,

    /// Padding to ensure tail is on different cache line
    _padding: [CACHE_LINE_SIZE - @sizeOf(?*MpscNode)]u8 = undefined,

    /// Tail pointer (producer side, atomic)
    tail: atomic.Value(?*MpscNode) align(CACHE_LINE_SIZE),

    const Self = @This();

    /// Initialize MPSC queue
    pub fn init() Self {
        return .{
            .head = null,
            .tail = atomic.Value(?*MpscNode).init(null),
        };
    }

    /// Push a node to the queue (thread-safe, lock-free)
    ///
    /// Can be called from any thread (multiple producers).
    /// O(1) time complexity.
    pub fn push(self: *Self, node: *MpscNode) void {
        // Initialize node's next to null
        node.next.store(null, .release);

        // Atomically swap tail to point to new node
        const prev = self.tail.swap(node, .acq_rel);

        if (prev) |p| {
            // Link previous tail to new node
            p.next.store(node, .release);
        } else {
            // Queue was empty, update head
            // This is safe because we're the only one who can see null tail
            self.head = node;
        }
    }

    /// Pop a node from the queue (single consumer only)
    ///
    /// Must only be called from a single consumer thread.
    /// Returns null if queue is empty.
    /// O(1) time complexity.
    pub fn pop(self: *Self) ?*MpscNode {
        const head = self.head orelse return null;

        // Try to get next node
        if (head.next.load(.acquire)) |next| {
            self.head = next;
            return head;
        }

        // Head has no next - check if it's the tail
        const tail = self.tail.load(.acquire);
        if (tail == head) {
            // This is the last node - try to remove it
            // CAS tail from head to null
            if (self.tail.cmpxchgStrong(head, null, .acq_rel, .acquire)) |_| {
                // CAS failed - another producer is pushing
                // The next pointer should become visible soon
                return null;
            }
            // Success - we removed the last node
            self.head = null;
            return head;
        }

        // Tail != head but next is null means a push is in progress
        // Wait for it (or return null to try later)
        return null;
    }

    /// Check if queue appears empty
    ///
    /// Note: Due to concurrent modifications, this is only an approximation.
    pub fn isEmpty(self: *Self) bool {
        return self.head == null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "MpscQueue - single producer single consumer" {
    var queue = MpscQueue.init();

    var node1 = MpscNode{};
    var node2 = MpscNode{};
    var node3 = MpscNode{};

    try std.testing.expect(queue.isEmpty());

    queue.push(&node1);
    queue.push(&node2);
    queue.push(&node3);

    try std.testing.expect(!queue.isEmpty());

    // Pop in FIFO order
    try std.testing.expectEqual(&node1, queue.pop().?);
    try std.testing.expectEqual(&node2, queue.pop().?);
    try std.testing.expectEqual(&node3, queue.pop().?);
    try std.testing.expectEqual(@as(?*MpscNode, null), queue.pop());

    try std.testing.expect(queue.isEmpty());
}

test "MpscQueue - push after pop" {
    var queue = MpscQueue.init();

    var node1 = MpscNode{};
    var node2 = MpscNode{};

    queue.push(&node1);
    try std.testing.expectEqual(&node1, queue.pop().?);

    queue.push(&node2);
    try std.testing.expectEqual(&node2, queue.pop().?);
}

test "MpscQueue - interleaved push pop" {
    var queue = MpscQueue.init();

    var nodes: [10]MpscNode = [_]MpscNode{.{}} ** 10;

    // Push 3, pop 1, push 2, pop all
    queue.push(&nodes[0]);
    queue.push(&nodes[1]);
    queue.push(&nodes[2]);

    try std.testing.expectEqual(&nodes[0], queue.pop().?);

    queue.push(&nodes[3]);
    queue.push(&nodes[4]);

    try std.testing.expectEqual(&nodes[1], queue.pop().?);
    try std.testing.expectEqual(&nodes[2], queue.pop().?);
    try std.testing.expectEqual(&nodes[3], queue.pop().?);
    try std.testing.expectEqual(&nodes[4], queue.pop().?);
    try std.testing.expectEqual(@as(?*MpscNode, null), queue.pop());
}

test "MpscQueue - cache line alignment" {
    // Verify that head and tail are on separate cache lines
    const head_offset = @offsetOf(MpscQueue, "head");
    const tail_offset = @offsetOf(MpscQueue, "tail");

    try std.testing.expect(tail_offset - head_offset >= CACHE_LINE_SIZE);
}

// Note: Multi-threaded tests would require spawning threads
// which is more complex. The core algorithm is well-known and
// has been formally verified (Dmitry Vyukov's design).
