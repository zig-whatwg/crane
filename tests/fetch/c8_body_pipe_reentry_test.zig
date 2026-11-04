//! A body's source and a reader that goes inside its own notification
//! (lane crashes8).
//!
//! A reader of a body still arriving (fetch/internal/body_pipe.zig) is told
//! of new bytes, and of the body's end, from inside the source's delivery -
//! `push`, `finish`, `fail` - and may let its pipe go right there: a service
//! worker's opaque-body pump (service_worker/fetch_event.zig
//! InternalBodyPump) does, when the page's reader went or the body ended.
//! When it is the LAST reader, the source has no reader left and is freed -
//! and the delivery that called the reader went on reading the freed
//! source: the rest of its copy of the readers, its own allocator for the
//! copy, and, for `finish` and `fail`, the source once more to free it.
//!
//! Each source allocates from `Pages` (every allocation its own mapping,
//! unmapped when freed), so a read of the freed source faults at once
//! instead of reading the bytes it left behind
//! (docs/lessons/testing-a-use-after-free-that-reads-stale-bytes-passes-unmap-on-free.md).
//! The count of live allocations stands in for std.testing.allocator's leak
//! check.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const body_pipe = fetch.internal.body_pipe;
const PipeSource = body_pipe.PipeSource;
const BodyPipe = body_pipe.BodyPipe;

/// The page allocator, counting what is live: free unmaps.
const Pages = struct {
    live: isize = 0,

    fn allocator(self: *Pages) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    const inner = std.heap.page_allocator;

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Pages = @ptrCast(@alignCast(ctx));
        const made = inner.vtable.alloc(inner.ptr, len, alignment, ret) orelse return null;
        self.live += 1;
        return made;
    }
    fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) bool {
        return inner.vtable.resize(inner.ptr, memory, alignment, new_len, ret);
    }
    fn remap(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) ?[*]u8 {
        return inner.vtable.remap(inner.ptr, memory, alignment, new_len, ret);
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Pages = @ptrCast(@alignCast(ctx));
        inner.vtable.free(inner.ptr, memory, alignment, ret);
        self.live -= 1;
    }
};

/// The network end: counts its cancels.
const Producer = struct {
    cancelled: usize = 0,

    fn producer(self: *Producer) body_pipe.Producer {
        return .{ .context = self, .cancel = cancel };
    }

    fn cancel(context: *anyopaque) void {
        const self: *Producer = @ptrCast(@alignCast(context));
        self.cancelled += 1;
    }
};

/// A reader that lets its pipe go the first time it is told anything - and,
/// with `also`, another reader's pipe first.
const Leaver = struct {
    pipe: ?*BodyPipe = null,
    also: ?*Leaver = null,
    notified: usize = 0,

    fn attach(self: *Leaver, pipe: *BodyPipe) void {
        self.pipe = pipe;
        pipe.consumer = .{ .context = self, .notify = notify };
    }

    fn notify(context: *anyopaque) void {
        const self: *Leaver = @ptrCast(@alignCast(context));
        self.notified += 1;
        if (self.also) |other| other.leave();
        self.leave();
    }

    fn leave(self: *Leaver) void {
        const pipe = self.pipe orelse return;
        self.pipe = null;
        pipe.consumer = null;
        pipe.release();
    }
};

test "the last reader going inside push's notification: the source outlives the delivery, then the transfer is cancelled and the source freed" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    {
        const source = try PipeSource.create(pages.allocator());
        source.producer = producer.producer();
        var reader: Leaver = .{};
        reader.attach(try source.branch());

        source.push("abc");

        try testing.expectEqual(@as(usize, 1), reader.notified);
        try testing.expect(reader.pipe == null);
    }
    // Nobody reads: the network stopped, once, and nothing is left.
    try testing.expectEqual(@as(usize, 1), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live);
}

test "the last reader going inside finish's notification: the source is freed once, after the delivery" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    {
        const source = try PipeSource.create(pages.allocator());
        source.producer = producer.producer();
        var reader: Leaver = .{};
        reader.attach(try source.branch());

        source.finish();

        try testing.expectEqual(@as(usize, 1), reader.notified);
    }
    // The body ended on its own: nothing to cancel.
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live);
}

test "the last reader going inside fail's notification: the source is freed once, with the failure's reason" {
    const Reason = struct {
        released: usize = 0,
        fn release(context: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.released += 1;
        }
    };
    var pages: Pages = .{};
    var producer: Producer = .{};
    var reason: Reason = .{};
    {
        const source = try PipeSource.create(pages.allocator());
        source.producer = producer.producer();
        var reader: Leaver = .{};
        reader.attach(try source.branch());

        source.fail(.{ .kind = .aborted, .reason = &reason, .release_reason = Reason.release });

        try testing.expectEqual(@as(usize, 1), reader.notified);
    }
    try testing.expectEqual(@as(usize, 1), reason.released);
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live);
}

test "a reader that lets the other reader go, then itself, inside one notification: neither is told again, and the source goes after the delivery" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    var first: Leaver = .{};
    var second: Leaver = .{};
    {
        const source = try PipeSource.create(pages.allocator());
        source.producer = producer.producer();
        first.attach(try source.branch());
        second.attach(try first.pipe.?.tee());
        first.also = &second;

        source.push("abc");
    }
    try testing.expectEqual(@as(usize, 1), first.notified);
    // Released before its turn came: never told.
    try testing.expectEqual(@as(usize, 0), second.notified);
    try testing.expectEqual(@as(usize, 1), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live);
}

test "a reader going inside its notification while another stays: the source and the other reader carry on" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    const source = try PipeSource.create(pages.allocator());
    source.producer = producer.producer();
    var leaver: Leaver = .{};
    leaver.attach(try source.branch());
    const stayer = try leaver.pipe.?.tee();

    source.push("ab");
    try testing.expect(leaver.pipe == null);
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
    source.push("cd");
    try testing.expectEqualStrings("abcd", stayer.buffered.items);

    stayer.release();
    try testing.expectEqual(@as(usize, 1), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live);
}
