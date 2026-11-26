//! Fonts 4 §12.2: an ordered, live view of one native feature-value map.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSFontFeatureValuesMap.State;
pub const MapView = webidl.maplike.View([]const u8, []const u32);
pub const InternalState = struct {
    rule: *dom.style.Rule,
    block: css.font_feature_values.Block,
    entries_view: MapView = undefined,
};
pub const construction_args = .{ "font_feature_values_of", "font_feature_block" };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    if (!@hasField(@TypeOf(args), "font_feature_values_of")) return;
    const rule: *dom.style.Rule = args.font_feature_values_of;
    if (rule.data != .font_feature_values) return error.TypeError;
    const owner = try dom.style.objects.ruleObject(rule, instance.ctx);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .rule = rule, .block = args.font_feature_block };
    rule.ref();
    instance.getState(State).own._internal = internal;
    // Q42: keeping only the map keeps its owning rule alive. This edge
    // joins the rule -> map edge; neither native model is a GC root.
    dom.style.objects.keepFrom(instance, owner, dom.style.objects.slots.font_feature_map_owner);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    engine.forgetTracedChild(instance, dom.style.objects.slots.font_feature_map_owner);
    internal.rule.data.font_feature_values.objects[@backingInt(internal.block)].clearIf(instance);
    internal.rule.unref();
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

fn stateOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}
fn mapOf(internal: *InternalState) *css.font_feature_values.Map {
    return internal.rule.data.font_feature_values.descriptors.map(internal.block);
}
fn changed(internal: *InternalState) void {
    if (internal.rule.sheet()) |sheet| sheet.changed();
}

/// WebIDL union conversion: an object's defined @@iterator selects the
/// sequence arm. Otherwise convert the input to one unsigned long. The
/// engine does ToNumber (including user script); WebIDL does integer wrap.
pub fn call_set(instance: *runtime.Instance, featureValueName: typedefs.CSSOMString, input: typedefs.UnsignedLongOrSequenceOfUnsignedLong) anyerror!void {
    const internal = try stateOf(instance);
    // `values` is (unsigned long or sequence<unsigned long>), converted by
    // the binding (WebIDL 3.2.25): an iterable object is the sequence, any
    // other value the unsigned long.
    var single: [1]u32 = undefined;
    const values: []const u32 = switch (input) {
        .ulong => |value| blk: {
            single[0] = value;
            break :blk &single;
        },
        .ulong_sequence => |sequence| sequence,
    };
    // Q33: the sole map shipper accepts every sequence length, including
    // zero. The parsed descriptor's arity never limits this CSSOM operation.
    try mapOf(internal).set(internal.rule.allocator, featureValueName.asSlice(), values);
    changed(internal);
}

/// The map entries (WebIDL 2.5.11) for the binding's maplike members; null
/// once the instance's state is gone.
pub fn maplikeEntries(instance: *runtime.Instance) ?*MapView {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    internal.entries_view = .{ .context = internal, .vtable = &view_vtable };
    return &internal.entries_view;
}

const view_vtable: MapView.VTable = .{
    .size = viewSize,
    .get = viewGet,
    .after = viewAfter,
    .remove = viewRemove,
    .clear = viewClear,
};

fn fromContext(context: *anyopaque) *InternalState {
    return @ptrCast(@alignCast(context));
}

fn viewSize(context: *anyopaque) usize {
    return mapOf(fromContext(context)).entries.count();
}

fn viewGet(context: *anyopaque, key: []const u8) ?[]const u32 {
    return mapOf(fromContext(context)).get(key);
}

fn viewAfter(context: *anyopaque, sequence: u64) ?MapView.Entry {
    const entry = mapOf(fromContext(context)).after(sequence) orelse return null;
    return .{ .sequence = entry.sequence, .key = entry.key, .value = entry.value };
}

fn viewRemove(context: *anyopaque, key: []const u8) bool {
    const internal = fromContext(context);
    const removed = mapOf(internal).remove(internal.rule.allocator, key);
    if (removed) changed(internal);
    return removed;
}

fn viewClear(context: *anyopaque) void {
    const internal = fromContext(context);
    if (mapOf(internal).entries.count() == 0) return;
    mapOf(internal).clear(internal.rule.allocator);
    changed(internal);
}
