//! Keeping a long-lived std hash map fast when its entries come and go.
//!
//! Crane keeps process-wide side tables keyed by an object's address - the
//! InstanceRegistry of each interface's internal state, EventTarget's
//! registry, the DOM's instance-to-NodeBase bridge. Every node a page makes is
//! put into them and taken out again when the page ends, so a runner that
//! loads page after page puts and removes millions of keys it never sees
//! again.
//!
//! std.HashMap deletes by tombstone and hands the slot back to `available`
//! (lib/std/hash_map.zig, `removeByIndex`). A map whose puts and removes
//! balance therefore never grows, and growing is the only thing that clears
//! tombstones on its own. An insert of a new key - and a lookup of a key that
//! is not there - probes until it meets a FREE slot; a tombstone does not stop
//! it. So every page's nodes left their tombstones behind, the free slots ran
//! out, and each insert walked most of the table: in one runner process the
//! big5-decode variants took 2.2 s for the first page and 46 s by the
//! thirteenth, 70% of it in these probes.
//!
//! std's own answer is `rehash` ("a long-lived HashMap with repeated inserts
//! and deletes"): in place, no allocation, no tombstones after it.
//! `TombstoneGuard` decides when to call it.

const std = @import("std");

/// When to rehash a long-lived managed `std.HashMap` (`std.AutoHashMap` and
/// friends) that entries keep entering and leaving.
///
/// Its invariant: at every insert, at least half of the slots not in use are
/// FREE, so a probe for a new key stops about as soon as in a map that never
/// removed anything. It counts removals - an upper bound on the tombstones,
/// since only a removal makes one - and rehashes before an insert once they
/// could take half the unused slots. A rehash costs a pass over the table,
/// and at least a tenth of the table's removals come between two (the map is
/// at most 80% full), so it is a few slots per removal.
///
/// It rehashes only before an insert, never on removal: a rehash moves
/// entries, and owners remove entries while they iterate (teardown sweeps);
/// an insert during an iteration is already invalid, since it can grow the
/// map.
pub const TombstoneGuard = struct {
    /// Removals since the map last had no tombstones: at most that many.
    removals: usize = 0,
    /// The map's capacity when `removals` started counting. A map that grew
    /// (or was freed and made again) was rebuilt, and has none.
    capacity: usize = 0,

    /// Count a removal `map` has just made.
    pub fn noteRemoval(self: *TombstoneGuard, map: anytype) void {
        self.sync(map);
        self.removals += 1;
    }

    /// Before an insert into `map`: rehash it, with std's in-place `rehash`,
    /// when the tombstones its removals may have left could take half of the
    /// slots not in use.
    pub fn beforeInsert(self: *TombstoneGuard, map: anytype) void {
        self.sync(map);
        if (self.removals == 0) return;
        const unused = self.capacity - map.count();
        if (self.removals * 2 < unused) return;
        map.rehash();
        self.removals = 0;
    }

    /// The map was emptied without a removal per entry
    /// (`clearRetainingCapacity`): it has no tombstones.
    pub fn reset(self: *TombstoneGuard) void {
        self.removals = 0;
    }

    fn sync(self: *TombstoneGuard, map: anytype) void {
        const capacity = map.capacity();
        if (capacity == self.capacity) return;
        self.capacity = capacity;
        self.removals = 0;
    }
};

/// A managed std hash map's slots by state: `free` slots are neither in use
/// nor a tombstone - the only slots at which a probe for an absent key stops.
pub const SlotCounts = struct {
    capacity: usize = 0,
    live: usize = 0,
    free: usize = 0,

    /// `TombstoneGuard`'s invariant: at least half of the slots not in use
    /// are free.
    pub fn halfOfUnusedFree(self: SlotCounts) bool {
        return self.free * 2 >= self.capacity - self.live;
    }
};

/// Count `map`'s slots by state - a diagnostic, for tests and measurements.
/// Reads std's slot metadata, one byte a slot (hash_map.zig asserts the size),
/// whose free state is all zero bits.
pub fn slotCounts(map: anytype) SlotCounts {
    const capacity = map.capacity();
    var counts: SlotCounts = .{ .capacity = capacity, .live = map.count() };
    if (capacity == 0) return counts;
    const metadata: [*]const u8 = @ptrCast(map.unmanaged.metadata.?);
    for (metadata[0..capacity]) |byte| counts.free += @intFromBool(byte == 0);
    return counts;
}
