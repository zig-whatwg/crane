//! Implementation for CSSRuleList interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CSSRuleList = interfaces.CSSRuleList;

pub const State = CSSRuleList.State;

pub const ImplError = error{
    NotImplemented,
};

// The CSS rules a list reads are its sheet's model (src/dom/cssom.zig).
const cssom = @import("dom").cssom;

/// A CSSRuleList: the CSS rules of the sheet it was made for
/// (`cssom.bindRuleList`), read live, and the CSSRule object made for each
/// rule it has handed out - one object per rule, as script expects
/// `list[0] === list[0]`. The list's wrapper keeps each object's
/// (`traceRule`: an edge, not a root - Blink's CSSRuleList traces the rule
/// objects it made): nothing else in the list keeps its wrapper.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    objects: std.AutoHashMapUnmanaged(*cssom.StyleRule, Made) = .empty,

    const Made = struct {
        instance: *runtime.Instance,
    };
};

/// The slot a rule object is kept in: one per rule, named by its model.
fn ruleSlot(buffer: []u8, model: *cssom.StyleRule) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "rule:{x}", .{@intFromPtr(model)}) catch "rule" };
}

/// `list` keeps `rule`, the object it made for `model`.
fn traceRule(list: *runtime.Instance, model: *cssom.StyleRule, rule: *runtime.Instance) void {
    var buffer: [48]u8 = undefined;
    engine.traceChild(list, rule, ruleSlot(&buffer, model));
}

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: the rule objects are let go, and the binding to
/// the sheet ends.
pub fn deinit(instance: *runtime.Instance) void {
    cssom.unbindRuleList(instance);
    const internal = getInternal(instance) orelse return;
    // A list freed unwrapped lets the holds waiting for its wrapper go
    // (engine.forgetTracedChild, safe in its teardown); a wrapped one's edges
    // go with its wrapper. No rule object is touched: the collector may have
    // freed it first.
    var it = internal.objects.keyIterator();
    while (it.next()) |model| {
        var buffer: [48]u8 = undefined;
        engine.forgetTracedChild(instance, ruleSlot(&buffer, model.*));
    }
    internal.objects.deinit(internal.allocator);
    internal.allocator.destroy(internal);
    instance.getState(State).own._internal = null;
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for length: the number of the sheet's CSS rules - zero once the
/// sheet has gone.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrulelist-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const sheet = cssom.ruleListSheet(instance) orelse return 0;
    return @intCast(sheet.length());
}

/// Operation: item(index) - and the indexed getter: the CSSRule object of
/// the index-th rule, or null.
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrulelist-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const sheet = cssom.ruleListSheet(instance) orelse return null;
    const model = sheet.ruleAt(index) orelse return null;
    const internal = getInternal(instance) orelse return null;
    if (internal.objects.get(model)) |made| return made.instance;

    // The CSSStyleRule object for the rule, bound to its model.
    const rule = try interfaces.CSSStyleRule.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(rule);
    try cssom.bindRule(rule, model);
    const entry = try internal.objects.getOrPut(internal.allocator, model);
    entry.value_ptr.* = .{ .instance = rule };
    traceRule(instance, model, rule);
    return rule;
}
