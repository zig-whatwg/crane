//! Implementation for CSSLayerStatementRule interface (CSS Cascade 5 7.2)
//!
//! Spec: https://drafts.csswg.org/css-cascade-5/#the-csslayerstatementrule-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSLayerStatementRule = interfaces.CSSLayerStatementRule;

pub const State = CSSLayerStatementRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for nameList: "a list of the names of the associated cascade
/// layers", a frozen array.
pub fn get_nameList(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const rule = ruleOf(instance) orelse return error.InvalidStateError;
    const names = switch (rule.data) {
        .layer_statement => |l| l.names,
        else => &.{},
    };
    const allocator = instance.ctx.allocator;
    const values = try allocator.alloc(runtime.JSValue, names.len);
    defer allocator.free(values);
    for (names, 0..) |n, i| values[i] = runtime.JSValue.fromStringRef(n);
    const array = try engine.createFrozenArray(engine.currentRealm() orelse instance.ctx, values);
    return array.take();
}
