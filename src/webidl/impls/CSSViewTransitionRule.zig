//! CSS View Transitions 2 §8.3.3: CSSViewTransitionRule, the CSSOM view of
//! an @view-transition rule (dom.style.rules' view_transition data, parsed
//! by css.view_transition_rule). CSSRule's generated construction chain
//! keeps the native rule; the binding keeps the [SameObject] types array in
//! the generated `cached_types`.
//!
//! Spec: https://drafts.csswg.org/css-view-transitions-2/#cssviewtransitionrule

const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSViewTransitionRule.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

fn dataOf(instance: *runtime.Instance) !*const css.view_transition_rule.Data {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.data != .view_transition) return error.InvalidStateError;
    return rule.data.view_transition;
}

/// "The navigation getter step is to return the value of the corresponding
/// navigation descriptor if one exists, otherwise the empty string."
pub fn get_navigation(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const data = try dataOf(instance);
    const text: []const u8 = if (data.navigation) |navigation| @tagName(navigation) else "";
    return runtime.DOMString.initDupe(instance.ctx.allocator, text);
}

/// "The types getter steps is to return the value of the corresponding
/// types descriptor if one exists, otherwise an empty list" - a frozen
/// array, the same one each time ([SameObject]: the binding caches it).
pub fn get_types(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const names = (try dataOf(instance)).typeList();
    const allocator = instance.ctx.allocator;
    const items = try allocator.alloc(runtime.JSValue, names.len);
    defer allocator.free(items);
    for (names, 0..) |name, i| items[i] = runtime.JSValue.fromStringRef(name);
    const array = try engine.createFrozenArray(engine.currentRealm() orelse instance.ctx, items);
    return array.take();
}
