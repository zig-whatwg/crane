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
pub const InternalState = struct { rule: *dom.style.Rule, block: css.font_feature_values.Block };
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
    internal.rule.data.font_feature_values.objects[@intFromEnum(internal.block)].clearIf(instance);
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
pub fn call_set(instance: *runtime.Instance, featureValueName: typedefs.CSSOMString, input: runtime.JSValue) anyerror!void {
    const internal = try stateOf(instance);
    const Collect = struct {
        ctx: runtime.Context,
        values: std.ArrayList(u32) = .empty,
        fn item(context: ?*anyopaque, value: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            const number = try engine.convertToUnrestrictedDouble(self.ctx, value);
            const converted = webidl.primitives.toUnsignedLong(.{ .number = number }) catch return error.TypeError;
            try self.values.append(self.ctx.allocator, converted);
        }
    };
    var collect: Collect = .{ .ctx = instance.ctx };
    defer collect.values.deinit(instance.ctx.allocator);
    var sequence = false;
    if (engine.typeOf(instance.ctx, input) == .object) sequence = try engine.iterate(instance.ctx, input, Collect.item, &collect);
    if (!sequence) try Collect.item(&collect, input);
    // Q33: the sole map shipper accepts every sequence length, including
    // zero. The parsed descriptor's arity never limits this CSSOM operation.
    try mapOf(internal).set(internal.rule.allocator, featureValueName.asSlice(), collect.values.items);
    changed(internal);
}

// Native sources for the routed generic maplike binding. No unbound IDL
// names are added: the generated maplike delegates will own that routing.
pub fn mapSize(instance: *runtime.Instance) !usize {
    return mapOf(try stateOf(instance)).entries.count();
}
pub fn mapGet(instance: *runtime.Instance, name: []const u8) !?[]const u32 {
    return mapOf(try stateOf(instance)).get(name);
}
pub fn mapHas(instance: *runtime.Instance, name: []const u8) !bool {
    return (try mapGet(instance, name)) != null;
}
pub fn mapDelete(instance: *runtime.Instance, name: []const u8) !bool {
    const internal = try stateOf(instance);
    const removed = mapOf(internal).remove(internal.rule.allocator, name);
    if (removed) changed(internal);
    return removed;
}
pub fn mapClear(instance: *runtime.Instance) !void {
    const internal = try stateOf(instance);
    if (mapOf(internal).entries.count() == 0) return;
    mapOf(internal).clear(internal.rule.allocator);
    changed(internal);
}
pub fn mapEntry(instance: *runtime.Instance, index: usize) !?struct { key: []const u8, value: []const u32 } {
    const map = mapOf(try stateOf(instance));
    if (index >= map.entries.count()) return null;
    return .{ .key = map.entries.keys()[index], .value = map.entries.values()[index] };
}
