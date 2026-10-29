//! CSS Typed OM 1 §4.1: a live list of strings and variable references.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");

pub const State = interfaces.CSSUnparsedValue.State;
pub const ImplError = error{ TypeError, RangeError };
pub const construction_args = .{"unparsed_segments"};
const Segment = union(enum) { string: []u8, reference: dom.style.rules.ObjectLink };
pub const InternalState = struct { segments: std.ArrayList(Segment) = .empty };

fn clone(allocator: std.mem.Allocator, value: typedefs.CSSUnparsedSegment) !Segment {
    return switch (value) {
        .usvstring => |string| .{ .string = try allocator.dupe(u8, string) },
        .cssvariable_reference_value => |reference| blk: {
            if (reference.stateAs(interfaces.CSSVariableReferenceValue.State) == null) return error.TypeError;
            var link: dom.style.rules.ObjectLink = .{};
            link.set(reference);
            break :blk .{ .reference = link };
        },
    };
}

fn freeSegment(allocator: std.mem.Allocator, segment: Segment) void {
    if (segment == .string) allocator.free(segment.string);
}

fn slot(index: usize, buffer: *[64]u8) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "CSSUnparsedValue:{d}", .{index}) catch unreachable };
}

fn trace(instance: *runtime.Instance, index: usize, value: Segment) void {
    var buffer: [64]u8 = undefined;
    const edge = slot(index, &buffer);
    switch (value) {
        .reference => |link| if (link.get()) |child| {
            dom.style.objects.keepFrom(instance, child, edge);
        },
        .string => engine.forgetTracedChild(instance, edge),
    }
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const input: []const typedefs.CSSUnparsedSegment = if (@hasField(@TypeOf(args), "unparsed_segments")) args.unparsed_segments else &.{};
    var segments: std.ArrayList(Segment) = .empty;
    errdefer {
        for (segments.items) |segment| freeSegment(allocator, segment);
        segments.deinit(allocator);
    }
    try segments.ensureTotalCapacity(allocator, input.len);
    for (input) |value| segments.appendAssumeCapacity(try clone(allocator, value));
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .segments = segments };
    instance.getState(State).own._internal = internal;
    // Every allocation and conversion is complete before publishing edges.
    // No pending hold on an unwrapped owner: keepFrom wraps the owner first.
    for (segments.items, 0..) |value, index| trace(instance, index, value);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    for (internal.segments.items, 0..) |value, index| {
        var buffer: [64]u8 = undefined;
        engine.forgetTracedChild(instance, slot(index, &buffer));
        freeSegment(instance.ctx.allocator, value);
    }
    internal.segments.deinit(instance.ctx.allocator);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// WebIDL sequence conversion runs each union conversion before requesting
/// the next iterator item. Earlier object items survive later script/GC.
pub fn call_constructor(ctx: runtime.Context, members: runtime.JSValue) !*runtime.Instance {
    const Collect = struct {
        realm: runtime.Context,
        values: std.ArrayList(typedefs.CSSUnparsedSegment) = .empty,
        holds: std.ArrayList(engine.Owned) = .empty,

        fn item(data: ?*anyopaque, value: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const allocator = self.realm.allocator;
            if (engine.convertToPlatformObject(self.realm, value)) |instance| {
                if (instance.stateAs(interfaces.CSSVariableReferenceValue.State) != null) {
                    try self.values.ensureUnusedCapacity(allocator, 1);
                    try self.holds.ensureUnusedCapacity(allocator, 1);
                    const held = try engine.retainValue(instance.ctx, .{ .instance = instance });
                    self.holds.appendAssumeCapacity(held);
                    self.values.appendAssumeCapacity(.{ .cssvariable_reference_value = instance });
                    return;
                }
            }
            const text = try engine.convertToUSVString(self.realm, value, allocator);
            errdefer allocator.free(text);
            try self.values.append(allocator, .{ .usvstring = text });
        }
    };
    var collect: Collect = .{ .realm = ctx };
    defer {
        for (collect.values.items) |value| if (value == .usvstring) ctx.allocator.free(value.usvstring);
        collect.values.deinit(ctx.allocator);
        for (collect.holds.items) |held| held.release();
        collect.holds.deinit(ctx.allocator);
    }
    if (!try engine.iterate(ctx, members, Collect.item, &collect)) return error.TypeError;
    return interfaces.CSSUnparsedValue.initWith(ctx.allocator, ctx, .{ .unparsed_segments = collect.values.items });
}

pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return @intCast(internal.segments.items.len);
}

pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!typedefs.CSSUnparsedSegment {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (index >= internal.segments.items.len) return error.RangeError;
    return switch (internal.segments.items[index]) {
        .string => |string| .{ .usvstring = try instance.ctx.allocator.dupe(u8, string) },
        .reference => |link| .{ .cssvariable_reference_value = link.get() orelse return error.InvalidStateError },
    };
}

pub fn call_setter(instance: *runtime.Instance, index: u32, value: typedefs.CSSUnparsedSegment) anyerror!void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;
    if (index > internal.segments.items.len) return error.RangeError;
    const owned = try clone(allocator, value);
    errdefer freeSegment(allocator, owned);
    if (index == internal.segments.items.len) {
        try internal.segments.append(allocator, owned);
    } else {
        freeSegment(allocator, internal.segments.items[index]);
        internal.segments.items[index] = owned;
    }
    trace(instance, index, owned);
}
