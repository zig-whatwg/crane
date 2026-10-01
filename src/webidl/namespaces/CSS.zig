//! WebIDL namespace: CSS
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const CSS_impl = @import("impls").CSS;

pub const CSS = struct {
    pub const Meta = struct {
        pub const name = "CSS";
        pub const is_namespace = true;
        pub const BaseType = null;
        pub const MixinTypes = &.{};

        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
            .{ "parseDeclarationList", "call_parseDeclarationList" },
            .{ "parseCommaValueList", "call_parseCommaValueList" },
            .{ "ric", "call_ric" },
            .{ "lvmin", "call_lvmin" },
            .{ "cqmax", "call_cqmax" },
            .{ "svmin", "call_svmin" },
            .{ "s", "call_s" },
            .{ "ch", "call_ch" },
            .{ "rcap", "call_rcap" },
            .{ "vi", "call_vi" },
            .{ "supports", "call_supports" },
            .{ "lh", "call_lh" },
            .{ "cqh", "call_cqh" },
            .{ "cm", "call_cm" },
            .{ "Hz", "call_Hz" },
            .{ "escape", "call_escape" },
            .{ "svb", "call_svb" },
            .{ "svh", "call_svh" },
            .{ "in", "call_in" },
            .{ "vmax", "call_vmax" },
            .{ "deg", "call_deg" },
            .{ "dvb", "call_dvb" },
            .{ "lvw", "call_lvw" },
            .{ "cqb", "call_cqb" },
            .{ "pt", "call_pt" },
            .{ "kHz", "call_kHz" },
            .{ "fr", "call_fr" },
            .{ "ex", "call_ex" },
            .{ "Q", "call_Q" },
            .{ "dpcm", "call_dpcm" },
            .{ "rch", "call_rch" },
            .{ "rex", "call_rex" },
            .{ "parseRuleList", "call_parseRuleList" },
            .{ "rad", "call_rad" },
            .{ "mm", "call_mm" },
            .{ "svmax", "call_svmax" },
            .{ "cqw", "call_cqw" },
            .{ "percent", "call_percent" },
            .{ "em", "call_em" },
            .{ "grad", "call_grad" },
            .{ "vmin", "call_vmin" },
            .{ "dvh", "call_dvh" },
            .{ "svw", "call_svw" },
            .{ "vb", "call_vb" },
            .{ "lvh", "call_lvh" },
            .{ "rem", "call_rem" },
            .{ "lvb", "call_lvb" },
            .{ "svi", "call_svi" },
            .{ "vw", "call_vw" },
            .{ "parseRule", "call_parseRule" },
            .{ "cap", "call_cap" },
            .{ "dvw", "call_dvw" },
            .{ "dvmax", "call_dvmax" },
            .{ "dpi", "call_dpi" },
            .{ "number", "call_number" },
            .{ "lvmax", "call_lvmax" },
            .{ "ic", "call_ic" },
            .{ "rlh", "call_rlh" },
            .{ "turn", "call_turn" },
            .{ "px", "call_px" },
            .{ "parseDeclaration", "call_parseDeclaration" },
            .{ "parseStylesheet", "call_parseStylesheet" },
            .{ "cqmin", "call_cqmin" },
            .{ "parseValue", "call_parseValue" },
            .{ "registerProperty", "call_registerProperty" },
            .{ "dvi", "call_dvi" },
            .{ "pc", "call_pc" },
            .{ "dppx", "call_dppx" },
            .{ "cqi", "call_cqi" },
            .{ "ms", "call_ms" },
            .{ "dvmin", "call_dvmin" },
            .{ "parseValueList", "call_parseValueList" },
            .{ "vh", "call_vh" },
            .{ "lvi", "call_lvi" },
        };

        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_parseDeclarationList(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseDeclarationList(ctx, css, options);
    }

    pub fn call_parseCommaValueList(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseCommaValueList(ctx, css);
    }

    pub fn call_ric(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_ric(ctx, value);
    }

    pub fn call_lvmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lvmin(ctx, value);
    }

    pub fn call_cqmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cqmax(ctx, value);
    }

    pub fn call_svmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_svmin(ctx, value);
    }

    pub fn call_s(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_s(ctx, value);
    }

    pub fn call_ch(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_ch(ctx, value);
    }

    pub fn call_rcap(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_rcap(ctx, value);
    }

    pub fn call_vi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_vi(ctx, value);
    }

    pub fn call_supports(ctx: runtime.Context, property: runtime.DOMString, value: runtime.DOMString) anyerror!bool {
        return try CSS_impl.call_supports(ctx, property, value);
    }

    pub fn call_supports__1(ctx: runtime.Context, conditionText: runtime.DOMString) anyerror!bool {
        if (comptime @hasDecl(CSS_impl, "call_supports__1")) {
            return try CSS_impl.call_supports__1(ctx, conditionText);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_lh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lh(ctx, value);
    }

    pub fn call_cqh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cqh(ctx, value);
    }

    pub fn call_cm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cm(ctx, value);
    }

    pub fn call_Hz(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_Hz(ctx, value);
    }

    pub fn call_escape(ctx: runtime.Context, ident: runtime.DOMString) anyerror!runtime.DOMString {
        return try CSS_impl.call_escape(ctx, ident);
    }

    pub fn call_svb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_svb(ctx, value);
    }

    pub fn call_svh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_svh(ctx, value);
    }

    pub fn call_in(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_in(ctx, value);
    }

    pub fn call_vmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_vmax(ctx, value);
    }

    pub fn call_deg(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_deg(ctx, value);
    }

    pub fn call_dvb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dvb(ctx, value);
    }

    pub fn call_lvw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lvw(ctx, value);
    }

    pub fn call_cqb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cqb(ctx, value);
    }

    pub fn call_pt(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_pt(ctx, value);
    }

    pub fn call_kHz(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_kHz(ctx, value);
    }

    pub fn call_fr(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_fr(ctx, value);
    }

    pub fn call_ex(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_ex(ctx, value);
    }

    pub fn call_Q(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_Q(ctx, value);
    }

    pub fn call_dpcm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dpcm(ctx, value);
    }

    pub fn call_rch(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_rch(ctx, value);
    }

    pub fn call_rex(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_rex(ctx, value);
    }

    pub fn call_parseRuleList(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseRuleList(ctx, css, options);
    }

    pub fn call_rad(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_rad(ctx, value);
    }

    pub fn call_mm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_mm(ctx, value);
    }

    pub fn call_svmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_svmax(ctx, value);
    }

    pub fn call_cqw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cqw(ctx, value);
    }

    pub fn call_percent(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_percent(ctx, value);
    }

    pub fn call_em(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_em(ctx, value);
    }

    pub fn call_grad(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_grad(ctx, value);
    }

    pub fn call_vmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_vmin(ctx, value);
    }

    pub fn call_dvh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dvh(ctx, value);
    }

    pub fn call_svw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_svw(ctx, value);
    }

    pub fn call_vb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_vb(ctx, value);
    }

    pub fn call_lvh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lvh(ctx, value);
    }

    pub fn call_rem(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_rem(ctx, value);
    }

    pub fn call_lvb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lvb(ctx, value);
    }

    pub fn call_svi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_svi(ctx, value);
    }

    pub fn call_vw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_vw(ctx, value);
    }

    pub fn call_parseRule(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseRule(ctx, css, options);
    }

    pub fn call_cap(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cap(ctx, value);
    }

    pub fn call_dvw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dvw(ctx, value);
    }

    pub fn call_dvmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dvmax(ctx, value);
    }

    pub fn call_dpi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dpi(ctx, value);
    }

    pub fn call_number(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_number(ctx, value);
    }

    pub fn call_lvmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lvmax(ctx, value);
    }

    pub fn call_ic(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_ic(ctx, value);
    }

    pub fn call_rlh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_rlh(ctx, value);
    }

    pub fn call_turn(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_turn(ctx, value);
    }

    pub fn call_px(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_px(ctx, value);
    }

    pub fn call_parseDeclaration(ctx: runtime.Context, css: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseDeclaration(ctx, css, options);
    }

    pub fn call_parseStylesheet(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseStylesheet(ctx, css, options);
    }

    pub fn call_cqmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cqmin(ctx, value);
    }

    pub fn call_parseValue(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseValue(ctx, css);
    }

    pub fn call_registerProperty(ctx: runtime.Context, definition: runtime.JSValue) anyerror!void {
        return try CSS_impl.call_registerProperty(ctx, definition);
    }

    pub fn call_dvi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dvi(ctx, value);
    }

    pub fn call_pc(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_pc(ctx, value);
    }

    pub fn call_dppx(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dppx(ctx, value);
    }

    pub fn call_cqi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_cqi(ctx, value);
    }

    pub fn call_ms(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_ms(ctx, value);
    }

    pub fn call_dvmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_dvmin(ctx, value);
    }

    pub fn call_parseValueList(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
        return try CSS_impl.call_parseValueList(ctx, css);
    }

    pub fn call_vh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_vh(ctx, value);
    }

    pub fn call_lvi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
        return try CSS_impl.call_lvi(ctx, value);
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "supports", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_supports", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },
            .{ .function = "call_supports__1", .implemented = @hasDecl(CSS_impl, "call_supports__1"), .args = &.{.{ .kinds = &.{.string} }} },
        } },
    };

    pub const animationWorklet: runtime.JSValue = undefined;

    pub const highlights: runtime.JSValue = undefined;

    pub const elementSources: runtime.JSValue = undefined;

    pub const layoutWorklet: runtime.JSValue = undefined;

    pub const paintWorklet: runtime.JSValue = undefined;
};
