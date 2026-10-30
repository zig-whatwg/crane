//! Fonts 4 §12.2: font families and the six shipping feature-value maps.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSFontFeatureValuesRule.State;
pub const InternalState = struct {};

fn ruleOf(instance: *runtime.Instance) !*dom.style.Rule {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.data != .font_feature_values) return error.InvalidStateError;
    return rule;
}

pub fn get_fontFamily(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const data = &(try ruleOf(instance)).data.font_feature_values.descriptors;
    // Q39 mechanism majorities: generic names stay quoted, ordinary
    // multiword families do not. The existing family serializer does both.
    return runtime.DOMString.initDupe(instance.ctx.allocator, data.font_families.text.bytes);
}

pub fn set_fontFamily(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const rule = try ruleOf(instance);
    // Q39: Fonts 4 has no setter algorithm. The integrator ruled to parse
    // <family-name># and ignore invalid input, matching the rule grammar.
    if (try rule.data.font_feature_values.descriptors.setFamily(value.asSlice())) if (rule.sheet()) |sheet| sheet.changed();
}

fn map(instance: *runtime.Instance, block: css.font_feature_values.Block) !*runtime.Instance {
    return dom.style.objects.fontFeatureMapObject(try ruleOf(instance), instance, block);
}
pub fn get_annotation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return map(instance, .annotation);
}
pub fn get_ornaments(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return map(instance, .ornaments);
}
pub fn get_stylistic(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return map(instance, .stylistic);
}
pub fn get_swash(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return map(instance, .swash);
}
pub fn get_characterVariant(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return map(instance, .character_variant);
}
pub fn get_styleset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return map(instance, .styleset);
}

/// Q41 ROUTED: no browser exposes this pinned-IDL member. The integrator's
/// "IDL MEMBERS NO BROWSER EXPOSES" item owns suppressing its exposure.
pub fn get_historicalForms(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
