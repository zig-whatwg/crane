//! Implementation for CSSRuleList interface (CSSOM 6.4.1)
//!
//! A read-only, live list of a sheet's CSS rules or a group rule's child
//! CSS rules (dom.style.RulesOf, held from construction). Each rule's
//! object is made the first time the list hands it out, and kept by its
//! parent's object (dom.style.objects): one object per rule, as script
//! expects `list[0] === list[0]`.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssrulelist-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const CSSRuleList = interfaces.CSSRuleList;

pub const State = CSSRuleList.State;

pub const ImplError = error{
    NotImplemented,
};

/// What the list lists (its construction argument).
pub const construction_args = .{"rules_of"};

pub const InternalState = struct {
    /// Held.
    of: dom.style.RulesOf,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = allocator;
    const of: dom.style.RulesOf = args.rules_of;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .of = of };
    switch (of) {
        .sheet => |r| r.ref(),
        .rule => |r| r.ref(),
    }
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    switch (internal.of) {
        .sheet => |r| r.unref(),
        .rule => |r| r.unref(),
    }
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// The rules listed, now.
fn items(instance: *runtime.Instance) ![]const *dom.style.Rule {
    const internal = getInternal(instance) orelse return &.{};
    return switch (internal.of) {
        .sheet => |record| (try record.rulesOf(instance)).items,
        .rule => |rule| if (rule.children()) |list| list.items else &.{},
    };
}

/// Getter for length: "the number of CSS rules represented by the
/// collection".
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrulelist-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    return @intCast((try items(instance)).len);
}

/// item(index), and the indexed getter: "the indexth CSSRule object in the
/// collection. If there is no indexth object in the collection, then the
/// method must return null."
///
/// Spec: https://drafts.csswg.org/cssom-1/#dom-cssrulelist-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const list = try items(instance);
    if (index >= list.len) return null;
    return try dom.style.objects.listRuleObject(instance.ctx, list[index]);
}
