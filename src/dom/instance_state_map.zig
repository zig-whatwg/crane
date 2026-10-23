//! One element type's state, inline, in its Browser's side table, keyed by
//! the instance's address: what HTMLOptionElement and HTMLTextAreaElement
//! keep there (each in its own BrowserScope table), so that a stale entry
//! can only give a wrong answer, never corrupt a neighbour (see
//! HTMLTextAreaElement.zig's StateMap).
//!
//! The table lives as long as its Browser - every page a runner loads - and
//! every element of the type that script writes to enters it and leaves it
//! at its teardown, at an address the table has usually never seen. Each
//! such element's init and deinit also look up its address and MISS.
//! std's map never grows while puts and removes balance and never clears
//! its tombstones, so its free slots ran out (a 1,069-file runner sample:
//! the option table at capacity 16 with none free in 23 of 35 samples) and
//! every option's construction, teardown and first write walked the whole
//! table (src/infra/tombstones.zig).

const std = @import("std");
const runtime = @import("runtime");
const tombstones = @import("infra").tombstones;

pub fn InstanceStateMap(comptime State: type) type {
    return struct {
        const Self = @This();

        map: std.AutoHashMap(usize, State),
        /// Rehashes `map` before an insert once its removals could take half
        /// the unused slots. A rehash moves the values, as growing does:
        /// a `*State` from `get` or `getOrPut` is borrowed only until the
        /// next insert, and the owners never iterate while inserting.
        guard: tombstones.TombstoneGuard = .{},

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = std.AutoHashMap(usize, State).init(allocator) };
        }

        /// With its Browser: each state's own `deinit`, if it has one, then
        /// the map.
        pub fn deinit(self: *Self) void {
            self.deinitValues();
            self.map.deinit();
        }

        pub fn put(self: *Self, instance: *const runtime.Instance, value: State) !void {
            self.guard.beforeInsert(&self.map);
            try self.map.put(@intFromPtr(instance), value);
        }

        /// `instance`'s state, BORROWED until the next `put` or `getOrPut`
        /// into this table, which may move every value.
        pub fn get(self: *Self, instance: *const runtime.Instance) ?*State {
            return self.map.getPtr(@intFromPtr(instance));
        }

        /// `instance`'s state, a default one made if this is the first
        /// write; BORROWED as `get`'s is.
        pub fn getOrPut(self: *Self, instance: *const runtime.Instance) !*State {
            self.guard.beforeInsert(&self.map);
            const entry = try self.map.getOrPut(@intFromPtr(instance));
            if (!entry.found_existing) entry.value_ptr.* = .{};
            return entry.value_ptr;
        }

        /// Take `instance`'s state out, if it has one; the caller owns it.
        pub fn remove(self: *Self, instance: *const runtime.Instance) ?State {
            const kv = self.map.fetchRemove(@intFromPtr(instance)) orelse return null;
            self.guard.noteRemoval(&self.map);
            return kv.value;
        }

        /// Forget every entry, each state's own `deinit` run first.
        pub fn clear(self: *Self) void {
            self.deinitValues();
            self.map.clearRetainingCapacity();
            self.guard.reset();
        }

        fn deinitValues(self: *Self) void {
            if (!@hasDecl(State, "deinit")) return;
            var values = self.map.valueIterator();
            while (values.next()) |state| state.deinit();
        }
    };
}
