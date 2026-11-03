//! A Browser's lists of its live objects of one kind - side tables of its
//! scope (runtime.BrowserScope, one tag each) - for the walks that must reach
//! every object of the kind the Browser has:
//!
//! - `.intersection_observers`: the IntersectionObservers that observe
//!   something, which a node's teardown tells it is gone
//!   (dom.intersection_targets);
//! - `.navigations`: the Navigation objects, which a Window's navigation
//!   hooks and a traversable's removed entries look up (dom.navigation_api);
//! - `.processing_instructions`: the ProcessingInstructions not yet
//!   deinit'd, which the Browser's end sweeps (dom.teardown_sweeps).
//!
//! A list is found from any object's address (`BrowserScope.ofInstance`),
//! so every walk reaches the same list whatever realm it starts from - a
//! frame's node and its parent's observer, a Window's hook, the Browser's end
//! after its realms are gone (docs/lessons/architecture-find-an-objects-browser-from-its-address-not-its-context.md).
//! The objects of these kinds are a Window's (a worker has no DOM), so a list
//! is read and written on its Browser's window agent thread only: no lock.
//!
//! They were one list per thread (`threadlocal`), shared by every Browser
//! the thread ran: one Browser's end swept the ProcessingInstruction list
//! empty under another's, and a node's teardown walked every Browser's
//! observers (lane gstate4; docs/instances.md - state has an owner, never a
//! thread).

const std = @import("std");
const runtime = @import("runtime");
const infra = @import("infra");

const BrowserScope = runtime.BrowserScope;

/// A list of objects, each once, in the order they joined (a removal moves
/// the last one into its place).
pub const ObjectList = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayListUnmanaged(*runtime.Instance) = .empty,

    pub fn init(allocator: std.mem.Allocator) ObjectList {
        return .{ .allocator = allocator };
    }

    /// With the Browser's scope: the objects are not touched.
    pub fn deinit(self: *ObjectList) void {
        self.items.deinit(self.allocator);
    }

    /// Add `object`, unless it is in the list already.
    pub fn add(self: *ObjectList, object: *runtime.Instance) std.mem.Allocator.Error!void {
        for (self.items.items) |item| if (item == object) return;
        try self.items.append(self.allocator, object);
    }

    /// Take `object` out of the list, if it is in it.
    pub fn remove(self: *ObjectList, object: *runtime.Instance) void {
        for (self.items.items, 0..) |item, i| {
            if (item == object) {
                _ = self.items.swapRemove(i);
                return;
            }
        }
    }

    /// The objects. BORROWED: a walk whose steps can add or remove one
    /// re-reads it.
    pub fn slice(self: *const ObjectList) []const *runtime.Instance {
        return self.items.items;
    }
};

/// A set of objects keyed by address, for a kind whose objects come and go
/// in numbers (ProcessingInstructions).
pub const ObjectSet = struct {
    map: infra.address_map.AddressHashMap(*runtime.Instance, void),
    guard: infra.tombstones.TombstoneGuard = .{},

    pub fn init(allocator: std.mem.Allocator) ObjectSet {
        return .{ .map = .init(allocator) };
    }

    /// With the Browser's scope: the objects are not touched.
    pub fn deinit(self: *ObjectSet) void {
        self.map.deinit();
    }

    pub fn add(self: *ObjectSet, object: *runtime.Instance) std.mem.Allocator.Error!void {
        self.guard.beforeInsert(&self.map);
        try self.map.put(object, {});
    }

    pub fn remove(self: *ObjectSet, object: *runtime.Instance) void {
        if (self.map.remove(object)) self.guard.noteRemoval(&self.map);
    }

    pub fn count(self: *const ObjectSet) usize {
        return self.map.count();
    }

    /// The objects. A walk must not add or remove one.
    pub fn iterator(self: *const ObjectSet) @TypeOf(self.map).KeyIterator {
        return self.map.keyIterator();
    }

    /// Empty the set (its Browser's end swept every object in it).
    pub fn clear(self: *ObjectSet) void {
        self.map.clearRetainingCapacity();
        self.guard.reset();
    }
};

/// What each tag holds.
pub fn Of(comptime tag: BrowserScope.Table) type {
    return switch (tag) {
        .intersection_observers, .navigations => ObjectList,
        .processing_instructions => ObjectSet,
        else => @compileError("dom.browser_object_lists keeps no list " ++ @tagName(tag)),
    };
}

/// The list `tag` of `object`'s Browser, made on first use.
pub fn of(object: *const runtime.Instance, comptime tag: BrowserScope.Table) std.mem.Allocator.Error!*Of(tag) {
    return BrowserScope.ofInstance(object).table(tag, Of(tag));
}

/// The list `tag` of `object`'s Browser, if one was made.
pub fn existing(object: *const runtime.Instance, comptime tag: BrowserScope.Table) ?*Of(tag) {
    return BrowserScope.ofInstance(object).existingTable(tag, Of(tag));
}

/// The list `tag` of the Browser whose scope is `scope`, if one was made.
pub fn existingIn(scope: *BrowserScope, comptime tag: BrowserScope.Table) ?*Of(tag) {
    return scope.existingTable(tag, Of(tag));
}

test "an object list holds each object once, and a removal takes it out" {
    var list = ObjectList.init(std.testing.allocator);
    defer list.deinit();
    var a: runtime.Instance = undefined;
    var b: runtime.Instance = undefined;
    try list.add(&a);
    try list.add(&b);
    try list.add(&a);
    try std.testing.expectEqual(@as(usize, 2), list.slice().len);
    list.remove(&a);
    list.remove(&a);
    try std.testing.expectEqualSlices(*runtime.Instance, &.{&b}, list.slice());
}

test "an object set adds, removes and clears" {
    var set = ObjectSet.init(std.testing.allocator);
    defer set.deinit();
    var objects: [8]runtime.Instance = undefined;
    for (&objects) |*object| try set.add(object);
    try std.testing.expectEqual(@as(usize, 8), set.count());
    for (objects[0..4]) |*object| set.remove(object);
    try std.testing.expectEqual(@as(usize, 4), set.count());
    set.clear();
    try std.testing.expectEqual(@as(usize, 0), set.count());
}
