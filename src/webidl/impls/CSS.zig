//! Implementation for CSS interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CSS = @import("interfaces").CSS;

pub const State = CSS.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for layoutWorklet
pub fn get_layoutWorklet(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for paintWorklet
pub fn get_paintWorklet(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for highlights
pub fn get_highlights(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for elementSources
pub fn get_elementSources(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for animationWorklet
pub fn get_animationWorklet(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: escape
pub fn call_escape(instance: *runtime.Instance, ident: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = ident;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, property: anyopaque, value: anyopaque) ImplError!bool {
    _ = instance;
    _ = property;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, conditionText: anyopaque) ImplError!bool {
    _ = instance;
    _ = conditionText;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: number
pub fn call_number(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: percent
pub fn call_percent(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cap
pub fn call_cap(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: ch
pub fn call_ch(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: em
pub fn call_em(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: ex
pub fn call_ex(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: ic
pub fn call_ic(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lh
pub fn call_lh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rcap
pub fn call_rcap(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rch
pub fn call_rch(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rem
pub fn call_rem(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rex
pub fn call_rex(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: ric
pub fn call_ric(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rlh
pub fn call_rlh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vw
pub fn call_vw(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vh
pub fn call_vh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vi
pub fn call_vi(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vb
pub fn call_vb(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vmin
pub fn call_vmin(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vmax
pub fn call_vmax(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: svw
pub fn call_svw(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: svh
pub fn call_svh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: svi
pub fn call_svi(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: svb
pub fn call_svb(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: svmin
pub fn call_svmin(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: svmax
pub fn call_svmax(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lvw
pub fn call_lvw(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lvh
pub fn call_lvh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lvi
pub fn call_lvi(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lvb
pub fn call_lvb(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lvmin
pub fn call_lvmin(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lvmax
pub fn call_lvmax(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dvw
pub fn call_dvw(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dvh
pub fn call_dvh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dvi
pub fn call_dvi(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dvb
pub fn call_dvb(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dvmin
pub fn call_dvmin(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dvmax
pub fn call_dvmax(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cqw
pub fn call_cqw(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cqh
pub fn call_cqh(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cqi
pub fn call_cqi(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cqb
pub fn call_cqb(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cqmin
pub fn call_cqmin(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cqmax
pub fn call_cqmax(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cm
pub fn call_cm(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: mm
pub fn call_mm(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: Q
pub fn call_Q(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: in
pub fn call_in(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pt
pub fn call_pt(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pc
pub fn call_pc(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: px
pub fn call_px(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deg
pub fn call_deg(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: grad
pub fn call_grad(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rad
pub fn call_rad(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: turn
pub fn call_turn(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: s
pub fn call_s(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: ms
pub fn call_ms(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: Hz
pub fn call_Hz(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: kHz
pub fn call_kHz(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dpi
pub fn call_dpi(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dpcm
pub fn call_dpcm(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dppx
pub fn call_dppx(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fr
pub fn call_fr(instance: *runtime.Instance, value: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: registerProperty
pub fn call_registerProperty(instance: *runtime.Instance, definition: anyopaque) ImplError!void {
    _ = instance;
    _ = definition;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseStylesheet
pub fn call_parseStylesheet(instance: *runtime.Instance, css: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = css;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseRuleList
pub fn call_parseRuleList(instance: *runtime.Instance, css: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = css;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseRule
pub fn call_parseRule(instance: *runtime.Instance, css: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = css;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseDeclarationList
pub fn call_parseDeclarationList(instance: *runtime.Instance, css: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = css;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseDeclaration
pub fn call_parseDeclaration(instance: *runtime.Instance, css: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = css;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseValue
pub fn call_parseValue(instance: *runtime.Instance, css: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = css;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseValueList
pub fn call_parseValueList(instance: *runtime.Instance, css: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = css;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseCommaValueList
pub fn call_parseCommaValueList(instance: *runtime.Instance, css: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = css;
    // TODO: Implement operation
    return error.NotImplemented;
}

