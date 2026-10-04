//! Platform objects made and freed on two threads at once.
//!
//! Every worker runs on a thread of its own (docs/instances.md, "Decisions"),
//! and every platform object any thread makes comes from the runtime's
//! process-wide allocators: `Instance.init` takes its handle from
//! `SlabAllocator.global` and its state from `ArenaAllocator.global`, and an
//! impl records its internal state in `internal_state`'s registry. All three
//! were single-threaded - a free list popped by two threads at once hands one
//! slot to both, and a hash map written by two threads loses entries or
//! corrupts its buckets.
//!
//! Each thread here keeps a window of live objects, stamps each one's state
//! with its own id and a serial, registers it in the internal-state registry,
//! and checks all of that before it frees the object - so a slot or a state
//! block handed to both threads, or a registry entry another thread clobbered,
//! shows up as a mismatch (or, with the free list corrupted, as a crash).

const std = @import("std");
const runtime = @import("runtime");

const Marked = struct {
    owner: u64,
    serial: u64,
    /// Enough bytes that the arena's size classes are exercised, not only
    /// the smallest.
    pad: [6]u64 = @splat(0),
};

const Internal = struct {
    owner: u64,
    serial: u64,
};

const no_methods = .{};
const vtable: runtime.VTable = .{
    .name = "Marked",
    .deinit = null,
    .methods_ptr = &no_methods,
    .state_size = @sizeOf(Marked),
    .state_align = @alignOf(Marked),
};

const window = 64;
const iterations = 200_000;

const Live = struct {
    instance: *runtime.Instance,
    generation: u64,
    serial: u64,
    internal: *Internal,
};

const Churn = struct {
    id: u64,
    ctx: runtime.Context,
    mismatches: u32 = 0,

    fn run(self: *Churn) void {
        // The lifecycle registry is per thread; this thread's goes with it.
        defer runtime.instance_lifecycle.deinit();
        var live: [window]?Live = @splat(null);
        var serial: u64 = 0;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const slot = i % window;
            if (live[slot]) |held| {
                self.check(held);
                runtime.internal_state.removeInternal(held.instance);
                std.heap.page_allocator.destroy(held.internal);
                runtime.Instance.deinit(held.instance);
                live[slot] = null;
            }
            serial += 1;
            const instance = runtime.Instance.init(std.heap.page_allocator, Marked, &vtable, self.ctx) catch {
                self.mismatches += 1;
                continue;
            };
            const state: *Marked = @ptrCast(@alignCast(instance.state));
            state.* = .{ .owner = self.id, .serial = serial };
            const internal = std.heap.page_allocator.create(Internal) catch {
                self.mismatches += 1;
                runtime.Instance.deinit(instance);
                continue;
            };
            internal.* = .{ .owner = self.id, .serial = serial };
            runtime.internal_state.setInternal(instance, internal) catch {
                self.mismatches += 1;
                std.heap.page_allocator.destroy(internal);
                runtime.Instance.deinit(instance);
                continue;
            };
            live[slot] = .{
                .instance = instance,
                .generation = runtime.SlabAllocator.generationOf(instance),
                .serial = serial,
                .internal = internal,
            };
        }
        for (live) |maybe| {
            const held = maybe orelse continue;
            self.check(held);
            runtime.internal_state.removeInternal(held.instance);
            std.heap.page_allocator.destroy(held.internal);
            runtime.Instance.deinit(held.instance);
        }
    }

    /// Everything this thread recorded about `held` still reads back.
    fn check(self: *Churn, held: Live) void {
        if (runtime.SlabAllocator.generationOf(held.instance) != held.generation) {
            self.mismatches += 1;
            return;
        }
        if (held.instance.ctx != self.ctx) self.mismatches += 1;
        const state: *Marked = @ptrCast(@alignCast(held.instance.state));
        if (state.owner != self.id or state.serial != held.serial) self.mismatches += 1;
        const internal = runtime.internal_state.getInternal(Internal, held.instance) orelse {
            self.mismatches += 1;
            return;
        };
        if (internal != held.internal or internal.owner != self.id or internal.serial != held.serial) self.mismatches += 1;
    }
};

test "two threads make and free platform objects at once, and neither sees the other's" {
    runtime.initializeRuntime(std.heap.page_allocator);
    defer runtime.deinitializeRuntime();

    var contexts: [2]runtime.ContextData = undefined;
    for (&contexts) |*ctx| ctx.* = try runtime.ContextData.init(std.heap.page_allocator, .{});
    defer for (&contexts) |*ctx| ctx.deinit();

    var churns = [_]Churn{
        .{ .id = 1, .ctx = &contexts[0] },
        .{ .id = 2, .ctx = &contexts[1] },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &churns) |*thread, *churn| thread.* = try std.Thread.spawn(.{}, Churn.run, .{churn});
    for (threads) |thread| thread.join();

    try std.testing.expectEqual(@as(u32, 0), churns[0].mismatches);
    try std.testing.expectEqual(@as(u32, 0), churns[1].mismatches);
    // Every object made was freed: the slab's count balances.
    const stats = runtime.SlabAllocator.get().stats();
    try std.testing.expectEqual(@as(usize, 0), stats.currently_allocated);
}
