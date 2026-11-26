//! CSS Regions 1: `interface NamedFlowMap { maplike<CSSOMString, NamedFlow>; }`.
//!
//! Ordered map of flow names to NamedFlow objects traced from the map instance,
//! exposed to the binding's maplike members (WebIDL 3.7.11) via `maplikeEntries`.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const NamedFlowMap = interfaces.NamedFlowMap;

pub const State = NamedFlowMap.State;

pub const ImplError = error{
    InvalidStateError,
};

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

const Entry = struct {
    name: []u8,
    flow: Link,
    id: u64,
    sequence: u64,
};

pub const InternalState = struct {
    owner: *runtime.Instance,
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,
    next_id: u64 = 0,
    next_sequence: u64 = 1,
    entries_view: webidl.maplike.PlatformObjects = undefined,

    fn slot(id: u64, buffer: *[64]u8) engine.TracedSlot {
        return .{ .name = std.fmt.bufPrint(buffer, "NamedFlowMap:entry:{d}", .{id}) catch unreachable };
    }

    fn forget(self: *InternalState, id: u64) void {
        var buffer: [64]u8 = undefined;
        engine.forgetTracedChild(self.owner, slot(id, &buffer));
    }

    fn indexOf(self: *const InternalState, name: []const u8) ?usize {
        for (self.entries.items, 0..) |entry, index| {
            if (std.mem.eql(u8, entry.name, name)) return index;
        }
        return null;
    }

    fn deinit(self: *InternalState) void {
        const live = self.owner.ctx.hasEngine();
        for (self.entries.items) |entry| {
            if (live) self.forget(entry.id);
            self.allocator.free(entry.name);
        }
        self.entries.deinit(self.allocator);
    }
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .owner = instance, .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    const allocator = internal.allocator;
    internal.deinit();
    allocator.destroy(internal);
}

/// The map entries (WebIDL 2.5.11) for the binding's maplike members; null
/// once the instance's state is gone.
pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.PlatformObjects {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    internal.entries_view = .{ .context = internal, .vtable = &view_vtable };
    return &internal.entries_view;
}

const view_vtable: webidl.maplike.PlatformObjects.VTable = .{
    .size = viewSize,
    .get = viewGet,
    .after = viewAfter,
    .set = viewSet,
    .remove = viewRemove,
    .clear = viewClear,
};

fn fromContext(context: *anyopaque) *InternalState {
    return @ptrCast(@alignCast(context));
}

fn viewSize(context: *anyopaque) usize {
    return fromContext(context).entries.items.len;
}

fn viewGet(context: *anyopaque, key: []const u8) ?*anyopaque {
    const self = fromContext(context);
    const index = self.indexOf(key) orelse return null;
    return self.entries.items[index].flow.get();
}

fn viewAfter(context: *anyopaque, sequence: u64) ?webidl.maplike.PlatformObjects.Entry {
    const self = fromContext(context);
    const items = self.entries.items;
    var low: usize = 0;
    var high: usize = items.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (items[middle].sequence <= sequence) low = middle + 1 else high = middle;
    }
    var index = low;
    while (index < items.len) : (index += 1) {
        const entry = items[index];
        if (entry.flow.get()) |flow| return .{ .sequence = entry.sequence, .key = entry.name, .value = flow };
    }
    return null;
}

fn viewSet(context: *anyopaque, key: []const u8, value: *anyopaque) anyerror!void {
    const self = fromContext(context);
    const flow: *runtime.Instance = @ptrCast(@alignCast(value));
    var buffer: [64]u8 = undefined;
    if (self.indexOf(key)) |index| {
        const entry = &self.entries.items[index];
        engine.traceChild(self.owner, flow, InternalState.slot(entry.id, &buffer));
        entry.flow = Link.to(flow);
        return;
    }
    try self.entries.ensureUnusedCapacity(self.allocator, 1);
    const owned = try self.allocator.dupe(u8, key);
    const id = self.next_id;
    self.next_id += 1;
    engine.traceChild(self.owner, flow, InternalState.slot(id, &buffer));
    self.entries.appendAssumeCapacity(.{
        .name = owned,
        .flow = Link.to(flow),
        .id = id,
        .sequence = self.next_sequence,
    });
    self.next_sequence += 1;
}

fn viewRemove(context: *anyopaque, key: []const u8) bool {
    const self = fromContext(context);
    const index = self.indexOf(key) orelse return false;
    const entry = self.entries.orderedRemove(index);
    self.forget(entry.id);
    self.allocator.free(entry.name);
    return true;
}

fn viewClear(context: *anyopaque) void {
    const self = fromContext(context);
    for (self.entries.items) |entry| {
        self.forget(entry.id);
        self.allocator.free(entry.name);
    }
    self.entries.clearRetainingCapacity();
}
