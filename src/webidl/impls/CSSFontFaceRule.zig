//! Implementation for CSSFontFaceRule interface (CSS Fonts 4)
//!
//! The rule's descriptors are kept (cssText reads them back); `style`, a
//! CSSFontFaceDescriptors object, is not implemented.
//!
//! Spec: https://drafts.csswg.org/css-fonts-4/#om-fontface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const dom = @import("dom");
const CSSFontFaceRule = interfaces.CSSFontFaceRule;

pub const State = CSSFontFaceRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The rule this object is a view of: its CSSRule part's.
fn ruleOf(instance: *runtime.Instance) ?*dom.style.Rule {
    return dom.style.hooks.cssRuleOf(instance);
}

/// Getter for style (CSSFontFaceDescriptors): not implemented.
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
