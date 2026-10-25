//! Implementation for CSSFontFaceDescriptors interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CSSFontFaceDescriptors = interfaces.CSSFontFaceDescriptors;

pub const State = CSSFontFaceDescriptors.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

// The generated construction/destruction chain owns the CSSStyleDeclaration
// parent. This interface adds only descriptor attribute spellings.

/// Getter for src
pub fn get_src(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("src"));
}

/// Getter for fontFamily
pub fn get_fontFamily(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-family"));
}

/// Getter for font-family
pub fn get_font_family(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-family"));
}

/// Getter for fontStyle
pub fn get_fontStyle(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-style"));
}

/// Getter for font-style
pub fn get_font_style(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-style"));
}

/// Getter for fontWeight
pub fn get_fontWeight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-weight"));
}

/// Getter for font-weight
pub fn get_font_weight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-weight"));
}

/// Getter for fontStretch
pub fn get_fontStretch(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-stretch"));
}

/// Getter for font-stretch
pub fn get_font_stretch(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-stretch"));
}

/// Getter for fontWidth
pub fn get_fontWidth(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-width"));
}

/// Getter for font-width
pub fn get_font_width(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-width"));
}

/// Getter for fontSize
pub fn get_fontSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-size"));
}

/// Getter for font-size
pub fn get_font_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-size"));
}

/// Getter for sizeAdjust
pub fn get_sizeAdjust(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("size-adjust"));
}

/// Getter for size-adjust
pub fn get_size_adjust(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("size-adjust"));
}

/// Getter for unicodeRange
pub fn get_unicodeRange(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("unicode-range"));
}

/// Getter for unicode-range
pub fn get_unicode_range(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("unicode-range"));
}

/// Getter for fontFeatureSettings
pub fn get_fontFeatureSettings(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-feature-settings"));
}

/// Getter for font-feature-settings
pub fn get_font_feature_settings(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-feature-settings"));
}

/// Getter for fontVariationSettings
pub fn get_fontVariationSettings(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-variation-settings"));
}

/// Getter for font-variation-settings
pub fn get_font_variation_settings(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-variation-settings"));
}

/// Getter for fontNamedInstance
pub fn get_fontNamedInstance(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-named-instance"));
}

/// Getter for font-named-instance
pub fn get_font_named_instance(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-named-instance"));
}

/// Getter for fontDisplay
pub fn get_fontDisplay(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-display"));
}

/// Getter for font-display
pub fn get_font_display(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-display"));
}

/// Getter for fontLanguageOverride
pub fn get_fontLanguageOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-language-override"));
}

/// Getter for font-language-override
pub fn get_font_language_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("font-language-override"));
}

/// Getter for ascentOverride
pub fn get_ascentOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("ascent-override"));
}

/// Getter for ascent-override
pub fn get_ascent_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("ascent-override"));
}

/// Getter for descentOverride
pub fn get_descentOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("descent-override"));
}

/// Getter for descent-override
pub fn get_descent_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("descent-override"));
}

/// Getter for lineGapOverride
pub fn get_lineGapOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("line-gap-override"));
}

/// Getter for line-gap-override
pub fn get_line_gap_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("line-gap-override"));
}

/// Getter for superscriptPositionOverride
pub fn get_superscriptPositionOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("superscript-position-override"));
}

/// Getter for superscript-position-override
pub fn get_superscript_position_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("superscript-position-override"));
}

/// Getter for subscriptPositionOverride
pub fn get_subscriptPositionOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("subscript-position-override"));
}

/// Getter for subscript-position-override
pub fn get_subscript_position_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("subscript-position-override"));
}

/// Getter for superscriptSizeOverride
pub fn get_superscriptSizeOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("superscript-size-override"));
}

/// Getter for superscript-size-override
pub fn get_superscript_size_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("superscript-size-override"));
}

/// Getter for subscriptSizeOverride
pub fn get_subscriptSizeOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("subscript-size-override"));
}

/// Getter for subscript-size-override
pub fn get_subscript_size_override(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("subscript-size-override"));
}

/// Setter for src
pub fn set_src(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("src"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontFamily
pub fn set_fontFamily(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-family"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-family
pub fn set_font_family(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-family"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontStyle
pub fn set_fontStyle(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-style"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-style
pub fn set_font_style(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-style"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontWeight
pub fn set_fontWeight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-weight"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-weight
pub fn set_font_weight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-weight"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontStretch
pub fn set_fontStretch(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-stretch"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-stretch
pub fn set_font_stretch(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-stretch"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontWidth
pub fn set_fontWidth(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-width
pub fn set_font_width(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontSize
pub fn set_fontSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-size
pub fn set_font_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for sizeAdjust
pub fn set_sizeAdjust(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("size-adjust"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for size-adjust
pub fn set_size_adjust(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("size-adjust"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for unicodeRange
pub fn set_unicodeRange(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("unicode-range"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for unicode-range
pub fn set_unicode_range(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("unicode-range"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontFeatureSettings
pub fn set_fontFeatureSettings(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-feature-settings"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-feature-settings
pub fn set_font_feature_settings(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-feature-settings"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontVariationSettings
pub fn set_fontVariationSettings(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-variation-settings"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-variation-settings
pub fn set_font_variation_settings(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-variation-settings"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontNamedInstance
pub fn set_fontNamedInstance(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-named-instance"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-named-instance
pub fn set_font_named_instance(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-named-instance"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontDisplay
pub fn set_fontDisplay(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-display"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-display
pub fn set_font_display(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-display"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for fontLanguageOverride
pub fn set_fontLanguageOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-language-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for font-language-override
pub fn set_font_language_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("font-language-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for ascentOverride
pub fn set_ascentOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("ascent-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for ascent-override
pub fn set_ascent_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("ascent-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for descentOverride
pub fn set_descentOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("descent-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for descent-override
pub fn set_descent_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("descent-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for lineGapOverride
pub fn set_lineGapOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("line-gap-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for line-gap-override
pub fn set_line_gap_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("line-gap-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for superscriptPositionOverride
pub fn set_superscriptPositionOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("superscript-position-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for superscript-position-override
pub fn set_superscript_position_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("superscript-position-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for subscriptPositionOverride
pub fn set_subscriptPositionOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("subscript-position-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for subscript-position-override
pub fn set_subscript_position_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("subscript-position-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for superscriptSizeOverride
pub fn set_superscriptSizeOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("superscript-size-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for superscript-size-override
pub fn set_superscript_size_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("superscript-size-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for subscriptSizeOverride
pub fn set_subscriptSizeOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("subscript-size-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// Setter for subscript-size-override
pub fn set_subscript_size_override(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("subscript-size-override"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}
