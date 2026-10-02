//! Auto-generated mixin: ElementCSSInlineStyle
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ElementCSSInlineStyleImpl = @import("impls").ElementCSSInlineStyle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const StylePropertyMap = @import("interfaces").StylePropertyMap;

pub const impl = @import("impls").ElementCSSInlineStyle;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "ElementCSSInlineStyle")) {
        if (comptime @hasDecl(impls.ElementCSSInlineStyle, "installHooks")) impls.ElementCSSInlineStyle.installHooks();
    }
}

/// Extended attributes: [SameObject], [PutForwards=cssText]
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try ElementCSSInlineStyleImpl.get_style(instance);
}

/// Extended attributes: [SameObject], [PutForwards=cssText]
pub fn set_style(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // [PutForwards] - Get target object and set the forwarded property
    // Per WebIDL spec: setting 'style' forwards to 'cssText' on the attribute's value
    const target = try get_style(instance);

    // Use JavaScript [[Set]] semantics to set the forwarded property
    // This respects prototype chain and user-defined setters
    try runtime.setPropertyOnInstance(target, "cssText", value);
}

/// Extended attributes: [SameObject]
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try ElementCSSInlineStyleImpl.get_attributeStyleMap(instance);
}
