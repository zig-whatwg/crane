//! Fonts4 §12.3: a CSSFontPaletteValuesRule's readonly descriptor view.
//! CSSRule's generated construction chain retains the native rule owner.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSFontPaletteValuesRule.State;
pub const InternalState = struct {};

fn dataOf(instance: *runtime.Instance) !*const css.font_palette_descriptors.Data {
    const rule = dom.style.hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.data != .font_palette_values) return error.InvalidStateError;
    return rule.data.font_palette_values;
}

pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try dataOf(instance)).name);
}

fn descriptor(instance: *runtime.Instance, kind: css.font_palette_descriptors.Descriptor) !typedefs.CSSOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try dataOf(instance)).get(kind));
}

pub fn get_fontFamily(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .font_family);
}

pub fn get_basePalette(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .base_palette);
}

pub fn get_overrideColors(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, .override_colors);
}
