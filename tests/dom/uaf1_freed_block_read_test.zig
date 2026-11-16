//! A liveness test of a FREED node block (lane uaf1; the HIGH safety item
//! lane wb1 found, 2026-11-16).
//!
//! A node's NodeBase is the first field of its State block. Node's teardown
//! RELEASES it (Node's releaseNodeBase: the owner word 0, the rest poisoned
//! in the builds that poison); later the block is FREED to the arena
//! (runtime.gc.releaseStorage), which hands it to the next node of its size.
//! A raw NodeBase pointer kept past the free then reads, through
//! `registeredInstance()`: 0 in production until the block is reissued, and
//! after that the NEW node's Instance - "registered", as another node. In a
//! poisoning build it read the poison, whose low bit happened to say "no
//! Instance": the same quiet answer as for a released node, so no gate saw
//! the read.
//!
//! The rule now, pinned here:
//! - a RELEASED node's owner word is 0 in every build (the release keeps it
//!   across its poison, as it keeps `live`): the block is still the node's
//!   own, and a holder of the address may ask;
//! - a FREED block's owner word is the arena's poison in a build that
//!   poisons freed state (every Debug build, the bug-finding WPT runner),
//!   and stays so while the block waits in the arena's quarantine;
//! - a liveness test that reads that word panics in a Debug build
//!   (`NodeBase.freedBlockReadPanics`, which `registeredInstance` and
//!   `stands` ask first). The panic ends the process, so the tests pin the
//!   question the accessors ask and the word a real freed block holds; the
//!   panic itself was shown once on the pool (the lane's merge report).
//!   Production compiles the question out.
//!
//! RED at 7fd36b074a9 (lane wb1's tip merged, before the instrument): no
//! `freedBlockReadPanics`; a released NodeBase's owner word is the poison.
const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const dom = @import("dom");
const runtime = @import("runtime");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;
const Instance = runtime.Instance;
const baseOf = real_nodes.baseOf;

const instrumented = @hasDecl(NodeBase, "freedBlockReadPanics");

test "the rule: a liveness test of the arena's poison panics in a Debug build, and only there" {
    if (comptime !instrumented) return error.NoFreedBlockCheck;
    const panics = NodeBase.freedBlockReadPanics;
    // The poison byte in every byte of the word.
    var word: usize = undefined;
    @memset(std.mem.asBytes(&word), runtime.ArenaAllocator.poison_byte);
    try testing.expectEqual(word, NodeBase.freed_owner_word);

    try testing.expect(panics(.debug, NodeBase.freed_owner_word));
    // Released, or not yet registered: the block is the node's own.
    try testing.expect(!panics(.debug, 0));
    // No release build asks: the comparison is compiled out of the DOM's
    // hot paths, and a release build that poisons reads the word as "no
    // Instance" by its low bit, never as an address.
    inline for (.{ std.builtin.OptimizeMode.safe, .fast, .small }) |mode| {
        try testing.expect(!panics(mode, NodeBase.freed_owner_word));
        try testing.expect(!panics(mode, 0));
    }
    try testing.expectEqual(@as(usize, 1), NodeBase.freed_owner_word & 1);
}

test "a registered node's owner word is its Instance: no liveness test of a live node panics" {
    if (comptime !instrumented) return error.NoFreedBlockCheck;
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const div = try nodes.element(doc, "div");
    const base = baseOf(div);
    try testing.expectEqual(@intFromPtr(div), base.owner);
    try testing.expect(!NodeBase.freedBlockReadPanics(builtin.mode, base.owner));
    try testing.expectEqual(@as(?*Instance, div), base.registeredInstance());
    try testing.expect(base.stands());
}

test "released, then freed: the owner word is 0 while the block is the node's own, and the poison once the arena has it" {
    if (comptime !instrumented) return error.NoFreedBlockCheck;
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    // A Debug build's scope poisons freed state by default; said here, so
    // the test reads the same in any mode.
    nodes.scope.arena.poison_freed = true;
    const doc = try nodes.document();
    const div = try nodes.element(doc, "div");
    const base = baseOf(div);
    const generation = runtime.SlabAllocator.generationOf(div);

    // The two halves of the collector's free (runtime.gc.onObjectFreed),
    // apart. First the node's teardown: its creator's reference ends, its
    // destructor chain runs, Node's part releases the NodeBase.
    dom.refcount.releaseCreatorReference(base);
    div.vtable.deinit.?(div);

    // RELEASED. The block is still this node's: the reads are no reads
    // after a free, and every liveness test answers "gone" - with no panic.
    try testing.expectEqual(@as(usize, 0), base.owner);
    try testing.expect(!NodeBase.freedBlockReadPanics(builtin.mode, base.owner));
    try testing.expectEqual(@as(?*Instance, null), base.registeredInstance());
    try testing.expectEqual(@as(?*anyopaque, null), dom.instance_bridge.getInstance(base));
    try testing.expect(!base.stands());
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(div));
    // The rest of the NodeBase is poison, where the scope poisons released
    // nodes: the 0 was kept across it, not left by a missing poison.
    if (nodes.scope.poisonsReleasedNodes()) {
        var poison: usize = undefined;
        @memset(std.mem.asBytes(&poison), runtime.ArenaAllocator.poison_byte);
        try testing.expectEqual(poison, base.document_word);
    }

    // Then the storage: the State block goes back to the arena, the slot to
    // the slab.
    runtime.gc.releaseStorage(div);

    // FREED. The correct liveness test says so without touching the block:
    // the slot's generation moved.
    try testing.expect(runtime.SlabAllocator.generationOf(div) != generation);
    // And the block says so too, for a holder that kept the raw address:
    // the owner word is the arena's poison. Read here as a FIELD, on
    // purpose - the arena keeps a freed block mapped and, in its
    // quarantine, out of reuse; the accessors (`registeredInstance`,
    // `stands`) would panic on this word, which is the instrument.
    try testing.expectEqual(NodeBase.freed_owner_word, base.owner);
    try testing.expect(NodeBase.freedBlockReadPanics(.debug, base.owner));
    try testing.expectEqual(builtin.mode == .debug, NodeBase.freedBlockReadPanics(builtin.mode, base.owner));

    // It stays so while other nodes of its size are made: the arena does
    // not hand a poisoned block to the next request (its quarantine), so
    // the stale read finds the poison, not the next div.
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        const other = try nodes.element(doc, "div");
        try testing.expect(baseOf(other) != base);
    }
    try testing.expectEqual(NodeBase.freed_owner_word, base.owner);
}
