//! A hook slot: one process-wide value - a function table an owner installs
//! so that code which may not name the owner can reach a step - written while
//! the process starts and frozen after (docs/instances.md, "Hooks";
//! tmp/plans/hookfreeze-design.md).
//!
//!     var implementation: Hook(?Implementation) = .init(null);
//!
//!     pub fn install(impl: Implementation) void {   // the owner's installHooks
//!         implementation.install(impl);
//!     }
//!     const impl = implementation.get() orelse return error.NotSupported;
//!
//!     // a test
//!     const override = implementation.overrideForTest(null);
//!     defer override.restore();
//!
//! - Readers (`get`, `read`) take no lock and make no check: nothing writes a
//!   slot after start outside tests, so the read is the plain load a `var`
//!   was.
//! - Every write (`install`, `installing`) asks `process_start.writer`:
//!   while the process starts and never after, in every build mode (WebKit
//!   freezes its process-wide WTF::Config after start-up - permanentlyFreeze
//!   - and RELEASE_ASSERTs in AssertNotFrozenScope; Blink's CoreInitializer
//!   installs core's hooks once, before any frame). A test installs through
//!   the sanctioned test start (`process_start.installForTest`) or writes
//!   into its own override.
//! - A test swaps a slot with `overrideForTest`, a scoped guard whose
//!   `restore()` puts back what was there, nested ones in reverse order
//!   (Chromium's base::test::ScopedFeatureList). Each live override counts in
//!   `process_start.outstandingOverrides()`, which the test runner's digest
//!   checks is 0 after every test (base::TestSuite's check that a test left
//!   the FeatureList as it found it). While a slot is overridden, the process
//!   start's own install lands UNDER the override and is what `restore()`
//!   brings back - so a swap made before the start can no longer put "no
//!   hooks" back over the real ones (lesson
//!   testing-a-test-may-assume-only-what-the-process-start-makes.md,
//!   mechanism 4).
//!
//! A registration list is a `Hook(List(T, capacity))`, appended to through
//! `installing()` at start and read through `read().slice()`.

const std = @import("std");
const builtin = @import("builtin");
const process_start = @import("process_start.zig");

pub fn Hook(comptime T: type) type {
    return struct {
        const Self = @This();

        /// What readers see. Never written but through `install`,
        /// `installing` and `overrideForTest`.
        value: T,
        /// A test build's override bookkeeping; nothing outside tests.
        overrides: if (builtin.is_test) Overrides else void,

        const Overrides = struct {
            /// Overrides of this slot not yet restored.
            depth: u32 = 0,
            /// The installed value under them: what the outermost
            /// `restore()` puts back, and where the start's own installs
            /// land meanwhile. Meaningful only while `depth > 0`.
            installed: T = undefined,
        };

        /// A slot holding `initial` until the process start installs.
        pub fn init(initial: T) Self {
            return .{ .value = initial, .overrides = if (builtin.is_test) .{} else {} };
        }

        /// The installed value.
        pub inline fn get(self: *const Self) T {
            return self.value;
        }

        /// The installed value, borrowed: for a registry or a table, read
        /// in place.
        pub inline fn read(self: *const Self) *const T {
            return &self.value;
        }

        /// Install `value`: only while the process starts (`installing`).
        pub fn install(self: *Self, value: T) void {
            self.installing().* = value;
        }

        /// The value to change in place while installing - a registry's
        /// append, a table whose parts several owners fill. Panics outside
        /// the process start (`process_start.writerOf`).
        pub fn installing(self: *Self) *T {
            const overridden = if (builtin.is_test) self.overrides.depth > 0 else false;
            return switch (process_start.writer(overridden)) {
                // The start installs under a test's override, which the
                // outermost restore() then brings back.
                .start => if (builtin.is_test and overridden) &self.overrides.installed else &self.value,
                .test_override => &self.value,
                .refused => process_start.refuseWrite(@typeName(T)),
            };
        }

        /// A test's swap of this slot: `value` until the returned guard's
        /// `restore()`, which every test calls before it ends (the digest
        /// counts overrides left behind). Nested overrides are restored in
        /// reverse order. While overridden, the test may `install` into the
        /// slot - into its override.
        pub fn overrideForTest(self: *Self, value: T) Override {
            if (!builtin.is_test) @compileError("overrideForTest is for tests: a hook is installed once, by crane.Process");
            const previous = self.value;
            if (self.overrides.depth == 0) self.overrides.installed = self.value;
            self.overrides.depth += 1;
            self.value = value;
            process_start.overrideMade();
            return .{ .slot = self, .previous = previous, .depth = self.overrides.depth };
        }

        /// A live override (`overrideForTest`).
        pub const Override = struct {
            slot: *Self,
            /// What the slot showed before this override (an outer
            /// override's value, when nested).
            previous: T,
            /// The slot's depth with this override made.
            depth: u32,

            /// Put back what the slot held before the override: the
            /// installed value (with whatever the start installed meanwhile)
            /// for the outermost, the outer override's value for a nested
            /// one.
            pub fn restore(self: Override) void {
                const overrides = &self.slot.overrides;
                if (overrides.depth != self.depth) std.debug.panic(
                    "a hook override ({s}) restored out of order or twice: depth {d}, this override's {d} (restore nested overrides in reverse order)",
                    .{ @typeName(T), overrides.depth, self.depth },
                );
                overrides.depth -= 1;
                self.slot.value = if (overrides.depth == 0) overrides.installed else self.previous;
                if (overrides.depth == 0) overrides.installed = undefined;
                process_start.overrideRestored();
            }
        };
    };
}

/// A fixed-capacity registration list - a hook several owners append to at
/// start (`Hook(List(T, capacity))`). What start-up installs is bounded and
/// known; an append past the capacity panics, naming it (a hook dropped
/// silently is a feature lost silently).
pub fn List(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        len: usize = 0,

        pub const empty: Self = .{};

        pub fn slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        /// The entries, to change in place - reached only through the
        /// slot's `installing()` (or a test's override).
        pub fn mutableSlice(self: *Self) []T {
            return self.items[0..self.len];
        }

        pub fn append(self: *Self, item: T) void {
            if (self.len == capacity) std.debug.panic("hook list of {s}: more than {d} entries", .{ @typeName(T), capacity });
            self.items[self.len] = item;
            self.len += 1;
        }

        /// Whether an entry equal to `item` (every field) is in the list.
        pub fn contains(self: *const Self, item: T) bool {
            for (self.slice()) |existing| {
                if (std.meta.eql(existing, item)) return true;
            }
            return false;
        }
    };
}

const testing = std.testing;

fn testSlotStep(x: u32) u32 {
    return x + 1;
}

fn otherSlotStep(x: u32) u32 {
    return x + 2;
}

const TestTable = struct { step: *const fn (u32) u32 };

test "an override restores the installed value and is counted until then" {
    var slot: Hook(?TestTable) = .init(.{ .step = &testSlotStep });
    const before = process_start.outstandingOverrides();
    {
        const override = slot.overrideForTest(.{ .step = &otherSlotStep });
        try testing.expectEqual(before + 1, process_start.outstandingOverrides());
        try testing.expectEqual(@as(u32, 3), slot.get().?.step(1));
        override.restore();
    }
    try testing.expectEqual(before, process_start.outstandingOverrides());
    try testing.expectEqual(@as(u32, 2), slot.get().?.step(1));
}

test "an override left unrestored stays counted: what the test runner's digest reports" {
    var slot: Hook(?TestTable) = .init(null);
    const before = process_start.outstandingOverrides();
    const override = slot.overrideForTest(.{ .step = &testSlotStep });
    // The test "forgot" its restore: the count says so, by one.
    try testing.expectEqual(before + 1, process_start.outstandingOverrides());
    // (This test gives it back, so as not to be the test that leaves one.)
    override.restore();
    try testing.expectEqual(before, process_start.outstandingOverrides());
}

test "nested overrides restore in reverse order, each to what it covered" {
    var slot: Hook(u32) = .init(1);
    const outer = slot.overrideForTest(2);
    const inner = slot.overrideForTest(3);
    try testing.expectEqual(@as(u32, 3), slot.get());
    inner.restore();
    try testing.expectEqual(@as(u32, 2), slot.get());
    outer.restore();
    try testing.expectEqual(@as(u32, 1), slot.get());
}

test "a test installs into the slot it overrides, and the restore takes the install away" {
    var slot: Hook(?TestTable) = .init(null);
    const override = slot.overrideForTest(null);
    // Outside a start, the only writer is the test, into its override.
    if (process_start.get().phase != .starting) {
        try testing.expectEqual(process_start.Writer.test_override, process_start.writer(true));
        slot.install(.{ .step = &testSlotStep });
        try testing.expectEqual(@as(u32, 2), slot.get().?.step(1));
    }
    override.restore();
    try testing.expect(slot.get() == null);
}

test "the start installs under a test's override, and the restore brings the install back" {
    const Slots = struct {
        var slot: Hook(?TestTable) = .init(null);
        fn install() void {
            slot.install(.{ .step = &testSlotStep });
        }
    };
    const override = Slots.slot.overrideForTest(.{ .step = &otherSlotStep });
    // A helper's startHooksForTest() - or a Browser's start - runs inside
    // the test's override: the test still sees its own value...
    process_start.installForTest(Slots.install);
    try testing.expectEqual(@as(u32, 3), Slots.slot.get().?.step(1));
    // ...and its restore puts back what the start installed, not the
    // empty slot the override covered.
    override.restore();
    try testing.expectEqual(@as(u32, 2), Slots.slot.get().?.step(1));
}

test "a test start installs into an empty slot" {
    const Slots = struct {
        var slot: Hook(u32) = .init(0);
        fn install() void {
            slot.install(7);
        }
    };
    process_start.installForTest(Slots.install);
    try testing.expectEqual(@as(u32, 7), Slots.slot.get());
}

test "a registration list appends in order and reads in place" {
    var registry: Hook(List(u32, 4)) = .init(.empty);
    const override = registry.overrideForTest(.empty);
    defer override.restore();
    if (process_start.get().phase != .starting) {
        registry.installing().append(5);
        registry.installing().append(6);
        try testing.expectEqualSlices(u32, &.{ 5, 6 }, registry.read().slice());
        try testing.expect(registry.read().contains(6));
        try testing.expect(!registry.read().contains(7));
    }
}
