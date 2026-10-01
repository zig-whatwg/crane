//! Implementation of the WebIDL namespace CSS.
//!
//! CSSOM defines the namespace (escape); CSS Conditional 3 adds supports();
//! the Houdini specs (Properties and Values, Paint, Layout, Animation
//! Worklet), the Highlight API, CSS Images 4, the Parser API and Typed OM
//! (the numeric factories CSS.px(), CSS.em(), ...) extend it with partial
//! namespaces. escape and both supports overloads are implemented; every
//! other operation answers NotImplemented until it is. They exist because
//! codegen merges every partial namespace (WebIDL "partial definitions"); it
//! used to keep only the last file's.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const css_syntax = @import("css");
const selector = @import("selector");

/// CSSOM: "The escape(ident) operation must return the result of invoking
/// serialize an identifier of ident."
/// https://drafts.csswg.org/cssom/#dom-css-escape
pub fn call_escape(ctx: runtime.Context, ident: runtime.DOMString) anyerror!runtime.DOMString {
    const escaped = try css_syntax.serialize.serializeIdentifier(ctx.getAllocator(), ident.asSlice());
    return runtime.DOMString.initOwned(escaped);
}

/// CSS Conditional 3: supports(property, value) - "If property is an ASCII
/// case-insensitive match for any defined CSS property that the UA supports,
/// or is a custom property name string, and value successfully parses
/// according to that property's grammar, return true. Otherwise, return
/// false." Never throws.
/// https://drafts.csswg.org/css-conditional-3/#dom-css-supports
pub fn call_supports(ctx: runtime.Context, property: runtime.DOMString, value: runtime.DOMString) anyerror!bool {
    return css_syntax.supports.supportsDeclaration(ctx.getAllocator(), property.asSlice(), value.asSlice());
}

/// CSS Conditional 3: supports(conditionText) - the text parsed and
/// evaluated as a <supports-condition>, then retried wrapped in
/// parentheses; selector() asks src/selector. Never throws.
/// https://drafts.csswg.org/css-conditional-3/#dom-css-supports-conditiontext
pub fn call_supports__1(ctx: runtime.Context, conditionText: runtime.DOMString) anyerror!bool {
    return css_syntax.supports.supportsCondition(ctx.getAllocator(), conditionText.asSlice(), &selectorIsSupported);
}

/// CSS Conditional 4 <supports-selector-fn>: "true if the UA supports the
/// selector" - it parses as exactly one <complex-selector>.
fn selectorIsSupported(allocator: std.mem.Allocator, text: []const u8) bool {
    var tokenizer = selector.Tokenizer.init(allocator, text);
    var parser = selector.Parser.init(allocator, &tokenizer) catch return false;
    defer parser.deinit();
    var list = parser.parse() catch return false;
    defer list.deinit();
    if (list.selectors.len != 1) return false;
    if (parser.current_token) |token| {
        if (token.tag != .eof) return false;
    }
    return true;
}

// Not implemented yet: each answers NotImplemented (an operation throws).

pub fn call_parseDeclarationList(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_parseCommaValueList(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    return error.NotImplemented;
}

pub fn call_ric(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lvmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_cqmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_svmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_s(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_ch(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_rcap(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_vi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_cqh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_cm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_Hz(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_svb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_svh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_in(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_vmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_deg(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dvb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lvw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_cqb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_pt(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_kHz(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_fr(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_ex(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_Q(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dpcm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_rch(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_rex(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_parseRuleList(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_rad(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_mm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_svmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_cqw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_percent(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_em(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_grad(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_vmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dvh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_svw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_vb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lvh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_rem(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lvb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_svi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_vw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_parseRule(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_cap(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dvw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dvmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dpi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_number(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lvmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_ic(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_rlh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_turn(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_px(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_parseDeclaration(ctx: runtime.Context, css: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_parseStylesheet(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_cqmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_parseValue(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    return error.NotImplemented;
}

pub fn call_registerProperty(ctx: runtime.Context, definition: runtime.JSValue) anyerror!void {
    _ = ctx;
    _ = definition;
    return error.NotImplemented;
}

pub fn call_dvi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_pc(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dppx(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_cqi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_ms(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_dvmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_parseValueList(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    return error.NotImplemented;
}

pub fn call_vh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}

pub fn call_lvi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    _ = ctx;
    _ = value;
    return error.NotImplemented;
}
