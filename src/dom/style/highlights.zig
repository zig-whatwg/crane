//! CSS Custom Highlight API 1: a Highlight's set of ranges (§2.2, `setlike<AbstractRange>`) and a
//! HighlightRegistry's map of names to highlights (§2.3, `maplike<DOMString, Highlight>`), the
//! state the impls keep for the binding's setlike and maplike members (WebIDL 3.7.11-12).
//!
//! A member - a range of a highlight, a highlight of a registry - is a platform object script made
//! and may drop: the owner keeps it alive with a traced edge (`engine.traceChild`, one slot per
//! member), as Blink's Highlight and HighlightRegistry trace their HeapLinkedHashSet members. The
//! member pointers here are links, generation-checked before every read: an owner and its members
//! may be collected together, and the owner's teardown never reads a member.
//!
//! Iteration is live: each member keeps the sequence it was added with (increasing), and an
//! iterator asks for the first member after the one it yielded last (`after`), so a member removed
//! ahead of it is never yielded and one added (or re-added) is.
//!
//! Spec: https://drafts.csswg.org/css-highlight-api-1/#creation
//! Spec: https://drafts.csswg.org/css-highlight-api-1/#registration

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");

/// A generation-checked link to a platform object.
const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn get(self: Link) ?*runtime.Instance {
        if (!self.instance.ctx.hasEngine()) return null;
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// The first index of `items` whose sequence is after `sequence` (items are in sequence order).
fn firstAfter(comptime T: type, items: []const T, sequence: u64) usize {
    var low: usize = 0;
    var high: usize = items.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (items[middle].sequence <= sequence) low = middle + 1 else high = middle;
    }
    return low;
}

/// A Highlight's set entries: its ranges (§2.2 "A custom highlight is a collection of ranges").
pub const RangeSet = struct {
    owner: *runtime.Instance,
    allocator: Allocator,
    members: std.ArrayList(Member) = .empty,
    next_id: u64 = 0,
    /// 0 is "before every member", where an iterator starts.
    next_sequence: u64 = 1,
    /// The view the binding's setlike members read (`view`).
    entries_view: webidl.setlike.PlatformObjects = undefined,

    const Member = struct { range: Link, id: u64, sequence: u64 };

    pub fn init(owner: *runtime.Instance, allocator: Allocator) RangeSet {
        return .{ .owner = owner, .allocator = allocator };
    }

    /// Teardown: the edges die with the owner's wrapper; an owner never wrapped lets its waiting
    /// edges go (engine.forgetTracedChild).
    pub fn deinit(self: *RangeSet) void {
        if (self.owner.ctx.hasEngine()) for (self.members.items) |member| self.forget(member.id);
        self.members.deinit(self.allocator);
        self.* = undefined;
    }

    fn slot(id: u64, buffer: *[64]u8) engine.TracedSlot {
        return .{ .name = std.fmt.bufPrint(buffer, "Highlight:range:{d}", .{id}) catch unreachable };
    }

    fn forget(self: *RangeSet, id: u64) void {
        var buffer: [64]u8 = undefined;
        engine.forgetTracedChild(self.owner, slot(id, &buffer));
    }

    fn indexOf(self: *const RangeSet, range: *runtime.Instance) ?usize {
        for (self.members.items, 0..) |member, index| {
            if (member.range.get() == range) return index;
        }
        return null;
    }

    pub fn size(self: *const RangeSet) usize {
        return self.members.items.len;
    }

    pub fn contains(self: *const RangeSet, range: *runtime.Instance) bool {
        return self.indexOf(range) != null;
    }

    /// Infra "append" to the ordered set: nothing when it contains `range`.
    pub fn add(self: *RangeSet, range: *runtime.Instance) !void {
        if (self.contains(range)) return;
        try self.members.ensureUnusedCapacity(self.allocator, 1);
        const id = self.next_id;
        self.next_id += 1;
        var buffer: [64]u8 = undefined;
        engine.traceChild(self.owner, range, slot(id, &buffer));
        self.members.appendAssumeCapacity(.{ .range = Link.to(range), .id = id, .sequence = self.next_sequence });
        self.next_sequence += 1;
    }

    /// Infra "remove"; whether the set contained `range`.
    pub fn remove(self: *RangeSet, range: *runtime.Instance) bool {
        const index = self.indexOf(range) orelse return false;
        const member = self.members.orderedRemove(index);
        self.forget(member.id);
        return true;
    }

    /// Infra "empty": the set keeps its sequence, so a suspended iterator yields what is added
    /// afterwards.
    pub fn empty(self: *RangeSet) void {
        for (self.members.items) |member| self.forget(member.id);
        self.members.clearRetainingCapacity();
    }

    /// The live ranges in order (for a renderer, or a native read).
    pub fn ranges(self: *const RangeSet, out: *std.ArrayList(*runtime.Instance), allocator: Allocator) Allocator.Error!void {
        for (self.members.items) |member| if (member.range.get()) |range| try out.append(allocator, range);
    }

    /// The set entries for WebIDL's setlike members.
    pub fn view(self: *RangeSet) *webidl.setlike.PlatformObjects {
        self.entries_view = .{ .context = self, .vtable = &vtable };
        return &self.entries_view;
    }

    const vtable: webidl.setlike.PlatformObjects.VTable = .{
        .size = viewSize,
        .contains = viewContains,
        .after = viewAfter,
        .append = viewAppend,
        .remove = viewRemove,
        .empty = viewEmpty,
    };

    fn fromContext(context: *anyopaque) *RangeSet {
        return @ptrCast(@alignCast(context));
    }

    fn viewSize(context: *anyopaque) usize {
        return fromContext(context).size();
    }

    fn viewContains(context: *anyopaque, value: *anyopaque) bool {
        return fromContext(context).contains(@ptrCast(@alignCast(value)));
    }

    fn viewAfter(context: *anyopaque, sequence: u64) ?webidl.setlike.PlatformObjects.Entry {
        const self = fromContext(context);
        var index = firstAfter(Member, self.members.items, sequence);
        while (index < self.members.items.len) : (index += 1) {
            const member = self.members.items[index];
            if (member.range.get()) |range| return .{ .sequence = member.sequence, .value = range };
        }
        return null;
    }

    fn viewAppend(context: *anyopaque, value: *anyopaque) anyerror!void {
        return fromContext(context).add(@ptrCast(@alignCast(value)));
    }

    fn viewRemove(context: *anyopaque, value: *anyopaque) bool {
        return fromContext(context).remove(@ptrCast(@alignCast(value)));
    }

    fn viewEmpty(context: *anyopaque) void {
        fromContext(context).empty();
    }
};

/// A HighlightRegistry's map entries: names to highlights (§2.3 "The highlight registry ... is an
/// ordered map from names to custom highlights").
pub const HighlightMap = struct {
    owner: *runtime.Instance,
    allocator: Allocator,
    entries: std.ArrayList(Entry) = .empty,
    next_id: u64 = 0,
    next_sequence: u64 = 1,
    entries_view: webidl.maplike.PlatformObjects = undefined,

    const Entry = struct {
        /// OWNED.
        name: []u8,
        highlight: Link,
        id: u64,
        sequence: u64,
    };

    pub fn init(owner: *runtime.Instance, allocator: Allocator) HighlightMap {
        return .{ .owner = owner, .allocator = allocator };
    }

    pub fn deinit(self: *HighlightMap) void {
        const live = self.owner.ctx.hasEngine();
        for (self.entries.items) |entry| {
            if (live) self.forget(entry.id);
            self.allocator.free(entry.name);
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    fn slot(id: u64, buffer: *[64]u8) engine.TracedSlot {
        return .{ .name = std.fmt.bufPrint(buffer, "HighlightRegistry:entry:{d}", .{id}) catch unreachable };
    }

    fn forget(self: *HighlightMap, id: u64) void {
        var buffer: [64]u8 = undefined;
        engine.forgetTracedChild(self.owner, slot(id, &buffer));
    }

    fn indexOf(self: *const HighlightMap, name: []const u8) ?usize {
        for (self.entries.items, 0..) |entry, index| {
            if (std.mem.eql(u8, entry.name, name)) return index;
        }
        return null;
    }

    pub fn size(self: *const HighlightMap) usize {
        return self.entries.items.len;
    }

    /// map[name], or null.
    pub fn get(self: *const HighlightMap, name: []const u8) ?*runtime.Instance {
        const index = self.indexOf(name) orelse return null;
        return self.entries.items[index].highlight.get();
    }

    /// Infra "set" map[name] to `highlight`: an existing entry keeps its place and takes the new
    /// value; a new one goes at the end.
    pub fn set(self: *HighlightMap, name: []const u8, highlight: *runtime.Instance) !void {
        var buffer: [64]u8 = undefined;
        if (self.indexOf(name)) |index| {
            const entry = &self.entries.items[index];
            // The same slot: the new edge replaces the old one.
            engine.traceChild(self.owner, highlight, slot(entry.id, &buffer));
            entry.highlight = Link.to(highlight);
            return;
        }
        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        const owned = try self.allocator.dupe(u8, name);
        const id = self.next_id;
        self.next_id += 1;
        engine.traceChild(self.owner, highlight, slot(id, &buffer));
        self.entries.appendAssumeCapacity(.{ .name = owned, .highlight = Link.to(highlight), .id = id, .sequence = self.next_sequence });
        self.next_sequence += 1;
    }

    /// Infra "remove" map[name]; whether the map contained it.
    pub fn remove(self: *HighlightMap, name: []const u8) bool {
        const index = self.indexOf(name) orelse return false;
        const entry = self.entries.orderedRemove(index);
        self.forget(entry.id);
        self.allocator.free(entry.name);
        return true;
    }

    /// Infra "clear".
    pub fn clear(self: *HighlightMap) void {
        for (self.entries.items) |entry| {
            self.forget(entry.id);
            self.allocator.free(entry.name);
        }
        self.entries.clearRetainingCapacity();
    }

    /// The map entries for WebIDL's maplike members.
    pub fn view(self: *HighlightMap) *webidl.maplike.PlatformObjects {
        self.entries_view = .{ .context = self, .vtable = &vtable };
        return &self.entries_view;
    }

    const vtable: webidl.maplike.PlatformObjects.VTable = .{
        .size = viewSize,
        .get = viewGet,
        .after = viewAfter,
        .set = viewSet,
        .remove = viewRemove,
        .clear = viewClear,
    };

    fn fromContext(context: *anyopaque) *HighlightMap {
        return @ptrCast(@alignCast(context));
    }

    fn viewSize(context: *anyopaque) usize {
        return fromContext(context).size();
    }

    fn viewGet(context: *anyopaque, key: []const u8) ?*anyopaque {
        return fromContext(context).get(key);
    }

    fn viewAfter(context: *anyopaque, sequence: u64) ?webidl.maplike.PlatformObjects.Entry {
        const self = fromContext(context);
        var index = firstAfter(Entry, self.entries.items, sequence);
        while (index < self.entries.items.len) : (index += 1) {
            const entry = self.entries.items[index];
            if (entry.highlight.get()) |highlight| return .{ .sequence = entry.sequence, .key = entry.name, .value = highlight };
        }
        return null;
    }

    fn viewSet(context: *anyopaque, key: []const u8, value: *anyopaque) anyerror!void {
        return fromContext(context).set(key, @ptrCast(@alignCast(value)));
    }

    fn viewRemove(context: *anyopaque, key: []const u8) bool {
        return fromContext(context).remove(key);
    }

    fn viewClear(context: *anyopaque) void {
        fromContext(context).clear();
    }
};

test "firstAfter: the first member appended after a sequence" {
    const Item = struct { sequence: u64 };
    const items = [_]Item{ .{ .sequence = 1 }, .{ .sequence = 3 }, .{ .sequence = 4 } };
    try std.testing.expectEqual(@as(usize, 0), firstAfter(Item, &items, 0));
    try std.testing.expectEqual(@as(usize, 1), firstAfter(Item, &items, 1));
    try std.testing.expectEqual(@as(usize, 1), firstAfter(Item, &items, 2));
    try std.testing.expectEqual(@as(usize, 3), firstAfter(Item, &items, 4));
}
