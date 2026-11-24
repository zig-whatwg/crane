//! Allocator hardening, batch A (lane hard1; tmp/plans/allocator-hardening-
//! design.md section 7, red tests A1-A12): a Browser's State blocks and
//! Instance slots live in its heap's span engine (runtime.heap), and each
//! of these held for the state arena and the slab they replace only as a
//! failure - every test here FAILS on the arena's inline LIFO free lists
//! and the slab's free-list link.
//!
//! The allocator's own checks are tested through its hook
//! (`checks = .report`): the violation is recorded where production panics.
//! A use after free here is a read of memory the test knows is mapped - a
//! block the heap holds or has freed - never a stale read that passes on
//! bytes left behind (lesson testing-a-use-after-free-that-reads-stale-
//! bytes-passes-unmap-on-free.md): what such a read finds is the assertion.

const std = @import("std");
const runtime = @import("runtime");
const testing = std.testing;
const BrowserScope = runtime.BrowserScope;
const heap = runtime.heap;

/// A div's State, as the heap sees it: a node (it embeds an InternalState
/// declaring `counted_node`, as Node's does), an element (`heap_kind`), and
/// 112 bytes (tests/dom/node_block_sizes_test.zig).
const DivInternal = struct {
    pub const counted_node = true;
    pub const heap_kind: heap.NodeKind = .element;
    words: [14]u64 = @splat(0),
};
const DivState = struct { _embedded: DivInternal };

/// A Text's: a node of the character-data kind, also 112 bytes.
const TextInternal = struct {
    pub const counted_node = true;
    pub const heap_kind: heap.NodeKind = .character_data;
    words: [14]u64 = @splat(0),
};
const TextState = struct { _embedded: TextInternal };

/// An Event's: no node, 112 bytes.
const EventState = struct { words: [14]u64 = @splat(0) };

/// The largest class: one block per span.
const BigState = struct { words: [2048]u64 = @splat(0) };

comptime {
    std.debug.assert(@sizeOf(DivState) == 112 and @sizeOf(TextState) == 112 and @sizeOf(EventState) == 112);
}

const no_methods = .{};
const slot_vtable: runtime.VTable = .{ .name = "Hard1", .deinit = null, .methods_ptr = &no_methods };

fn engineOf(scope: *BrowserScope) !*heap.Engine {
    return scope.heapEngine();
}

/// A scope whose heap runs the production configuration (zero on free), in
/// this Debug binary: "production zeroes, bug-finding poisons" is tested in
/// one binary (design 7).
fn productionScope(scope: *BrowserScope) !*heap.Engine {
    const engine = try engineOf(scope);
    engine.configureForTest(heap.Config.production);
    return engine;
}

test "A1: a node block freed inside a task is not reissued in that task" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);

    engine.beginTask();
    const first = try scope.arena.create(DivState);
    const address = @intFromPtr(first);
    scope.arena.destroy(DivState, first);
    var made: std.ArrayListUnmanaged(*DivState) = .empty;
    defer made.deinit(testing.allocator);
    for (0..20_000) |_| {
        const div = try scope.arena.create(DivState);
        try made.append(testing.allocator, div);
        try testing.expect(@intFromPtr(div) != address);
    }
    engine.endTask();
    // After the task, the block is free again: the lowest slot first.
    const again = try scope.arena.create(DivState);
    try testing.expectEqual(address, @intFromPtr(again));
    scope.arena.destroy(DivState, again);
    for (made.items) |div| scope.arena.destroy(DivState, div);
}

test "A2: a freed node block is never reissued as a non-node State, nor as another node kind" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    _ = try engineOf(&scope);

    const div = try scope.arena.create(DivState);
    const address = @intFromPtr(div);
    scope.arena.destroy(DivState, div);
    // Enough 112-byte Events and Texts to fill a fresh span of each.
    const per_span = heap.span_bytes / 112 + 1;
    var events: std.ArrayListUnmanaged(*EventState) = .empty;
    defer events.deinit(testing.allocator);
    var texts: std.ArrayListUnmanaged(*TextState) = .empty;
    defer texts.deinit(testing.allocator);
    for (0..per_span) |_| {
        const event = try scope.arena.create(EventState);
        try events.append(testing.allocator, event);
        try testing.expect(@intFromPtr(event) != address);
        const text = try scope.arena.create(TextState);
        try texts.append(testing.allocator, text);
        try testing.expect(@intFromPtr(text) != address);
    }
    const engine = try engineOf(&scope);
    try testing.expectEqual(heap.PartitionId.objects, engine.partitionOf(events.items[0]).?);
    try testing.expectEqual(heap.PartitionId.node, engine.partitionOf(texts.items[0]).?);
    try testing.expectEqual(heap.NodeKind.character_data, engine.nodeKindOf(texts.items[0]).?);
    // The div's own kind takes it back.
    const again = try scope.arena.create(DivState);
    try testing.expectEqual(address, @intFromPtr(again));
    try testing.expectEqual(heap.NodeKind.element, engine.nodeKindOf(again).?);
    scope.arena.destroy(DivState, again);
    for (events.items) |event| scope.arena.destroy(EventState, event);
    for (texts.items) |text| scope.arena.destroy(TextState, text);
}

test "A3: under the production configuration a freed block reads zero - no link, no old bytes" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    _ = try productionScope(&scope);

    const a = try scope.arena.create(EventState);
    const b = try scope.arena.create(EventState);
    a.words = @splat(0x4141_4141_4141_4141);
    b.words = @splat(0x4242_4242_4242_4242);
    scope.arena.destroy(EventState, a);
    scope.arena.destroy(EventState, b);
    // Both freed blocks are still the heap's, mapped: every byte reads 0.
    for (std.mem.asBytes(a)) |byte| try testing.expectEqual(@as(u8, 0), byte);
    for (std.mem.asBytes(b)) |byte| try testing.expectEqual(@as(u8, 0), byte);
}

test "A4: a write after free is caught when the block is issued again" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    engine.checks = .report;

    const event = try scope.arena.create(EventState);
    scope.arena.destroy(EventState, event);
    try testing.expectEqual(@as(?heap.Violation, null), engine.takeViolation());
    // A pointer kept past the free writes through it.
    event.words[3] = 0xdead_beef;
    // Lowest slot first: the next Event is that block.
    const again = try scope.arena.create(EventState);
    try testing.expectEqual(@intFromPtr(event), @intFromPtr(again));
    try testing.expectEqual(@as(?heap.Violation, .write_after_free), engine.takeViolation());
    // Issued zeroed all the same.
    try testing.expectEqual(@as(u64, 0), again.words[3]);
    scope.arena.destroy(EventState, again);
}

test "A5: a double free is caught, and the block never gets two owners" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);
    engine.checks = .report;

    const event = try scope.arena.create(EventState);
    scope.arena.destroy(EventState, event);
    scope.arena.destroy(EventState, event);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    const one = try scope.arena.create(EventState);
    const two = try scope.arena.create(EventState);
    try testing.expect(one != two);
    scope.arena.destroy(EventState, one);
    scope.arena.destroy(EventState, two);
    // A double free of a block the quarantine holds is caught too.
    engine.beginTask();
    const held = try scope.arena.create(EventState);
    scope.arena.destroy(EventState, held);
    scope.arena.destroy(EventState, held);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    engine.endTask();
}

test "A6: an interior, a wrong-size and another Browser's free are caught" {
    var a = BrowserScope.init(testing.allocator);
    defer a.deinit();
    var b = BrowserScope.init(testing.allocator);
    defer b.deinit();
    const engine_a = try engineOf(&a);
    const engine_b = try engineOf(&b);
    engine_a.checks = .report;
    engine_b.checks = .report;

    const event = try a.arena.create(EventState);
    const bytes: [*]u8 = @ptrCast(event);
    // Interior: 16 bytes in.
    a.arena.destroyRaw(bytes + 16, 96, 8);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), engine_a.takeViolation());
    // The block's start, another class's size.
    a.arena.destroyRaw(bytes, 64, 8);
    try testing.expectEqual(@as(?heap.Violation, .wrong_size), engine_a.takeViolation());
    // Through another Browser's arena.
    b.arena.destroy(EventState, event);
    try testing.expectEqual(@as(?heap.Violation, .other_heap), engine_b.takeViolation());
    // None of them freed it: its own free still works, once.
    a.arena.destroy(EventState, event);
    try testing.expectEqual(@as(?heap.Violation, null), engine_a.takeViolation());
}

test "A7: a freed Instance slot's vtable, state and ctx words read zero, its generation dead" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    _ = try productionScope(&scope);

    const first = try scope.slab.alloc(&slot_vtable);
    const second = try scope.slab.alloc(&slot_vtable);
    first.state = @ptrFromInt(0x1000);
    second.state = @ptrFromInt(0x2000);
    scope.slab.free(first);
    scope.slab.free(second);
    for ([_]*runtime.Instance{ first, second }) |freed| {
        const words: *const [3]usize = @ptrCast(freed);
        try testing.expectEqual([3]usize{ 0, 0, 0 }, words.*);
        try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(freed));
    }
}

test "A8: after a churn the emptied spans are decommitted once idle, back to within a span per class of the start" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);
    engine.setNow(1_000);
    const start = engine.stats();

    const count = 50_000;
    const divs = try testing.allocator.alloc(*DivState, count);
    defer testing.allocator.free(divs);
    for (divs) |*div| div.* = try scope.arena.create(DivState);
    const peak = engine.stats();
    try testing.expect(peak.node.committed_span_bytes >= count * 112);
    for (divs) |div| scope.arena.destroy(DivState, div);

    // Not yet old enough: nothing goes.
    engine.setNow(1_500);
    const early = engine.decommitAged(1_500, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expectEqual(@as(usize, 0), early.decommitted);
    try testing.expect(early.next_due_ms != null);
    // 1.5 s after the churn: every empty span goes.
    const late = engine.decommitAged(2_500, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expect(late.decommitted > 0);
    const after = engine.stats();
    try testing.expect(after.node.committed_span_bytes <= start.node.committed_span_bytes + heap.span_bytes);
    try testing.expect(after.node.spans_decommitted > 0);
    // And a decommitted span serves its class again, zeroed.
    const again = try scope.arena.create(DivState);
    try testing.expectEqual(@as(u64, 0), again._embedded.words[0]);
    scope.arena.destroy(DivState, again);
}

test "A9: a task that frees twice the cap still holds a chosen block often (random eviction), and a held block reads zero" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);
    var config = heap.Config.production;
    config.quarantine_cap = 64 * 1024;
    engine.configureForTest(config);

    const per_trial = 2 * config.quarantine_cap / 112;
    const blocks = try testing.allocator.alloc(*EventState, per_trial);
    defer testing.allocator.free(blocks);
    const trials = 200;
    var held: usize = 0;
    for (0..trials) |_| {
        const target = try scope.arena.create(EventState);
        target.words = @splat(0x5a5a_5a5a_5a5a_5a5a);
        for (blocks) |*block| block.* = try scope.arena.create(EventState);
        engine.beginTask();
        scope.arena.destroy(EventState, target);
        for (blocks) |block| scope.arena.destroy(EventState, block);
        if (engine.isQuarantined(target)) {
            held += 1;
            // Held, zeroed, out of reuse: a stale read finds nothing.
            for (std.mem.asBytes(target)) |byte| try testing.expectEqual(@as(u8, 0), byte);
        }
        engine.endTask();
    }
    // A block survives each later eviction with probability 1 - 1/n for a
    // quarantine of n blocks: after n more frees, e^-1, 37% ([B1] F1's
    // arithmetic): about 74 of 200. A FIFO would hold it in none. At least
    // half the expectation (5 standard deviations below it).
    try testing.expect(held >= 37);
    try testing.expect(held < trials);
}

test "A10: a node block made off the window agent's thread is refused" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);
    engine.checks = .report;
    // This thread makes the first node block: it is the owner.
    const div = try scope.arena.create(DivState);
    defer scope.arena.destroy(DivState, div);

    const Worker = struct {
        fn run(s: *BrowserScope, result: *?anyerror) void {
            const made = s.arena.create(DivState) catch |err| {
                result.* = err;
                return;
            };
            _ = made;
            result.* = null;
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Worker.run, .{ &scope, &result });
    thread.join();
    try testing.expectEqual(@as(?anyerror, error.OutOfMemory), result);
    try testing.expectEqual(@as(?heap.Violation, .wrong_thread), engine.takeViolation());
    // An objects-partition block is any thread's.
    const Objects = struct {
        fn run(s: *BrowserScope, ok: *bool) void {
            const event = s.arena.create(EventState) catch return;
            s.arena.destroy(EventState, event);
            ok.* = true;
        }
    };
    var ok = false;
    const other = try std.Thread.spawn(.{}, Objects.run, .{ &scope, &ok });
    other.join();
    try testing.expect(ok);
}

test "A11: a block left alive is named in the leak report, by type" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);
    engine.configureForTest(heap.Config.debug_default);

    const kept = try scope.arena.create(EventState);
    const freed = try scope.arena.create(DivState);
    scope.arena.destroy(DivState, freed);

    const Collect = struct {
        found: usize = 0,
        div_lines: usize = 0,
        fn line(self: *@This(), l: heap.LeakLine) void {
            const name = l.type_name orelse return;
            if (std.mem.indexOf(u8, name, "EventState") != null) self.found += l.count;
            if (std.mem.indexOf(u8, name, "DivState") != null) self.div_lines += 1;
        }
    };
    var collect: Collect = .{};
    const total = engine.leakReport(&collect, Collect.line);
    try testing.expectEqual(@as(usize, 1), total);
    try testing.expectEqual(@as(usize, 1), collect.found);
    try testing.expectEqual(@as(usize, 0), collect.div_lines);
    scope.arena.destroy(EventState, kept);
}

test "A12: the address space a class takes is counted, and pressure is raised at 90% of a partition" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);

    const Pressure = struct {
        raised: usize = 0,
        fn call(context: *anyopaque, partition: heap.PartitionId) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (partition == .objects) self.raised += 1;
        }
    };
    var pressure: Pressure = .{};
    engine.pressure_hook = .{ .context = &pressure, .call = Pressure.call };
    engine.limitForTest(.objects, 4 * 1024 * 1024);

    try testing.expectEqual(@as(usize, 0), engine.bucketSpans(.objects, @sizeOf(BigState), @alignOf(BigState)));
    var made: std.ArrayListUnmanaged(*BigState) = .empty;
    defer made.deinit(testing.allocator);
    // One 16 KiB block per span: past 90% of 4 MiB (bounded: a heap that
    // counts nothing would never get there).
    for (0..1024) |_| {
        if (engine.stats().objects.va_assigned * 10 >= 4 * 1024 * 1024 * 9) break;
        try made.append(testing.allocator, try scope.arena.create(BigState));
    }
    try testing.expect(engine.stats().objects.va_assigned * 10 >= 4 * 1024 * 1024 * 9);
    try testing.expectEqual(made.items.len, engine.bucketSpans(.objects, @sizeOf(BigState), @alignOf(BigState)));
    try testing.expectEqual(@as(usize, 1), pressure.raised);
    try testing.expect(engine.stats().objects.pressure_raised);
    // Past the limit, a clean OutOfMemory - never a crash.
    const refused: ?anyerror = for (0..1024) |_| {
        const big = scope.arena.create(BigState) catch |err| break err;
        try made.append(testing.allocator, big);
    } else null;
    try testing.expectEqual(@as(?anyerror, error.OutOfMemory), refused);
    for (made.items) |big| scope.arena.destroy(BigState, big);
}

test "the configuration is a function of the build and the Browser's request: production zeroes, Debug and bug-finding poison" {
    try testing.expectEqual(heap.Fill.zero, heap.Config.of(false, false).fill);
    try testing.expect(!heap.Config.of(false, false).retire_freed_spans);
    try testing.expectEqual(heap.Fill.poison, heap.Config.of(true, false).fill);
    try testing.expectEqual(heap.Config.production_quarantine_cap, heap.Config.of(true, false).quarantine_cap);
    try testing.expectEqual(heap.Fill.poison, heap.Config.of(true, true).fill);
    try testing.expectEqual(heap.Config.bug_finding_quarantine_cap, heap.Config.of(true, true).quarantine_cap);
    try testing.expect(heap.Config.of(true, true).retire_freed_spans);
    // A Debug build's scope poisons by default; a release build's does not.
    try testing.expect(BrowserScope.poisonsFreedStateByDefault(.debug));
    try testing.expect(!BrowserScope.poisonsFreedStateByDefault(.safe));
}

// ---------------------------------------------------------------------------
// The Browser's end gives back what the arena used to free wholesale (the
// integrator's classes A, 2026-11-23): a registry's owned blocks, and the
// final sweep's nodes.
// ---------------------------------------------------------------------------

const SideState = struct {
    words: [6]u64 = @splat(0),
    deinits: *usize,
    pub fn deinit(self: *SideState) void {
        self.deinits.* += 1;
    }
};

test "a registry's sweep gives the blocks it owns back to the heap, as its end does" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const Registry = runtime.InstanceRegistry(.html_output_element, SideState);
    var deinits: usize = 0;
    const before = scope.arena.stats().live_blocks;
    var made: [3]*runtime.Instance = undefined;
    for (&made) |*instance| {
        instance.* = try scope.slab.alloc(&slot_vtable);
        const state = try Registry.createIn(instance.*, &scope.arena);
        state.* = .{ .deinits = &deinits };
    }
    try testing.expectEqual(before + 3, scope.arena.stats().live_blocks);
    Registry.deinitAllAndClear(&scope);
    try testing.expectEqual(@as(usize, 3), deinits);
    try testing.expectEqual(before, scope.arena.stats().live_blocks);
    for (made) |instance| scope.slab.free(instance);
}

test "the final sweep's nodes are released by the scope's end: State block and slot" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try engineOf(&scope);
    const node_vtable: runtime.VTable = .{
        .name = "Hard1Node",
        .deinit = null,
        .methods_ptr = &no_methods,
        .state_size = @sizeOf(DivState),
        .state_align = @alignOf(DivState),
        .counted = &runtime.lifetime.node,
    };
    // A node held past every realm's end, and an object that is not a node.
    const node = try scope.slab.alloc(&node_vtable);
    node.state = try scope.arena.create(DivState);
    const other = try scope.slab.alloc(&slot_vtable);
    try testing.expectEqual(@as(usize, 1), scope.releaseSweptNodes(engine));
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(node));
    try testing.expect(runtime.SlabAllocator.generationOf(other) != runtime.SlabAllocator.dead_generation);
    try testing.expectEqual(@as(usize, 0), scope.arena.stats().live_blocks);
    scope.slab.free(other);
}

// The magazine (heap.magazine_depth; lane hard1's P1, the integrator's
// 9:24 AM ET call): a bucket's blocks released last are reissued first, with
// no span search, past the quarantine as before.

test "M1: a block released outside a task is the next one issued, from its bucket's magazine, ahead of a lower free slot" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    const low = try scope.arena.create(EventState);
    const mid = try scope.arena.create(EventState);
    const high = try scope.arena.create(EventState);
    try testing.expect(@intFromPtr(low) < @intFromPtr(high));
    scope.arena.destroy(EventState, low);
    scope.arena.destroy(EventState, high);
    try testing.expect(engine.inMagazine(high));
    // Last released, first reissued: the lower free slot waits.
    const again = try scope.arena.create(EventState);
    try testing.expectEqual(@intFromPtr(high), @intFromPtr(again));
    try testing.expect(!engine.inMagazine(again));
    scope.arena.destroy(EventState, again);
    scope.arena.destroy(EventState, mid);
}

test "M2: a free of a block in the magazine is a double free, and the block never gets two owners" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    engine.checks = .report;
    const event = try scope.arena.create(EventState);
    scope.arena.destroy(EventState, event);
    try testing.expect(engine.inMagazine(event));
    scope.arena.destroy(EventState, event);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    const one = try scope.arena.create(EventState);
    const two = try scope.arena.create(EventState);
    try testing.expect(one != two);
    try testing.expect(!engine.inMagazine(one) and !engine.inMagazine(two));
    scope.arena.destroy(EventState, one);
    scope.arena.destroy(EventState, two);
}

test "M3: a block reissued from the magazine is verified: a write after its free is caught, and it is issued zeroed" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    engine.checks = .report;
    const event = try scope.arena.create(EventState);
    scope.arena.destroy(EventState, event);
    try testing.expect(engine.inMagazine(event));
    // A pointer kept past the free writes through it while the magazine holds it.
    event.words[5] = 0xdead_beef;
    const again = try scope.arena.create(EventState);
    try testing.expectEqual(@intFromPtr(event), @intFromPtr(again));
    try testing.expectEqual(@as(?heap.Violation, .write_after_free), engine.takeViolation());
    try testing.expectEqual(@as(u64, 0), again.words[5]);
    scope.arena.destroy(EventState, again);
}

test "M4: idle decommit drains the magazine first, so a span its blocks kept open goes back with the rest" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    engine.setNow(1_000);
    const start = engine.stats();
    // One block of the largest class has a span of its own.
    const big = try scope.arena.create(BigState);
    scope.arena.destroy(BigState, big);
    try testing.expect(engine.inMagazine(big));
    // The magazine keeps the span in use: nothing to age yet.
    try testing.expect(engine.stats().objects.spans_empty == start.objects.spans_empty);
    // Idle, past the age: drained, then decommitted in the same pass - aged
    // from the release, not from the drain.
    const r = engine.decommitAged(2_500, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expect(r.decommitted >= 1);
    try testing.expect(!engine.inMagazine(big));
    const after = engine.stats();
    try testing.expect(after.objects.committed_span_bytes <= start.objects.committed_span_bytes);
    try testing.expect(after.objects.spans_decommitted >= 1);
}

test "S1: the slab's peak is the most Instances live at once, not the slots the quarantine kept taken" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    const count = 2 * runtime.SlabAllocator.slots_per_span;
    const made = try testing.allocator.alloc(*runtime.Instance, count);
    defer testing.allocator.free(made);
    // In one task: two spans' worth made and freed (the quarantine holds their
    // slots to the task's end), then as many again.
    engine.beginTask();
    for (made) |*instance| instance.* = try scope.slab.alloc(&slot_vtable);
    for (made) |instance| scope.slab.free(instance);
    for (made) |*instance| instance.* = try scope.slab.alloc(&slot_vtable);
    const stats = scope.slab.stats();
    // Never more than `count` alive at once - though twice as many slots
    // were taken.
    try testing.expectEqual(@as(usize, count), stats.peak_allocated);
    try testing.expect(stats.total_capacity >= 2 * count);
    for (made) |instance| scope.slab.free(instance);
    engine.endTask();
    try testing.expectEqual(@as(usize, count), scope.slab.stats().peak_allocated);
}

test "M5: a span only the magazine keeps is aged from its own last release, not its bucket's latest" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try productionScope(&scope);
    // One block per span (the largest class): each in a span of its own.
    engine.setNow(1_000);
    const early = try scope.arena.create(BigState);
    const late = try scope.arena.create(BigState);
    const start = engine.stats().objects.spans_decommitted;
    scope.arena.destroy(BigState, early);
    // The bucket releases again 900 ms later.
    engine.setNow(1_900);
    scope.arena.destroy(BigState, late);
    try testing.expect(engine.inMagazine(early) and engine.inMagazine(late));
    // At 2.1 s the span released at 1 s is past the age, the other is not:
    // the first goes back now, as it would with no magazine.
    const r = engine.decommitAged(2_100, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expectEqual(@as(usize, 1), r.decommitted);
    try testing.expectEqual(start + 1, engine.stats().objects.spans_decommitted);
    try testing.expect(r.next_due_ms != null);
}
