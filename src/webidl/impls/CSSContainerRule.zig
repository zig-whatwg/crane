//! CSS Conditional 5 section 9.1: CSSOM over the parsed condition list.
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const css = @import("css");

pub const State = interfaces.CSSContainerRule.State;
pub const InternalState = struct {};

fn conditionsOf(instance: *runtime.Instance) []const css.container_queries.Condition {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return &.{};
    return switch (rule.data) {
        .container => |*container| container.conditions.conditions,
        else => &.{},
    };
}

/// Section 9.1, containerName steps 1–3: only a single condition has a name.
pub fn get_containerName(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const conditions = conditionsOf(instance);
    if (conditions.len != 1) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, conditions[0].name);
}

/// Section 9.1, containerQuery steps 1–3: multiple conditions return "".
pub fn get_containerQuery(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const conditions = conditionsOf(instance);
    if (conditions.len != 1) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, conditions[0].query);
}

/// Section 9.1, conditions steps 1–3. These are freshly converted IDL
/// dictionaries in the current realm, inside a frozen array. No cached
/// script value or model-to-wrapper hold is introduced.
pub fn get_conditions(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const conditions = conditionsOf(instance);
    const allocator = instance.ctx.allocator;
    const realm = engine.currentRealm() orelse instance.ctx;
    const owned = try allocator.alloc(engine.Owned, conditions.len);
    defer allocator.free(owned);
    var initialized: usize = 0;
    defer for (owned[0..initialized]) |value| value.release();
    const values = try allocator.alloc(runtime.JSValue, conditions.len);
    defer allocator.free(values);
    for (conditions, 0..) |condition, i| {
        owned[i] = try engine.createDictionaryObject(realm, &.{
            .{ .name = "name", .value = runtime.JSValue.fromStringRef(condition.name) },
            .{ .name = "query", .value = runtime.JSValue.fromStringRef(condition.query) },
        });
        initialized += 1;
        values[i] = owned[i].borrow();
    }
    return (try engine.createFrozenArray(realm, values)).take();
}
