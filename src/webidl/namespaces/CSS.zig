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
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "animationWorklet", .{"Window"} },
        };
        pub const BaseType = null;
        pub const MixinTypes = &.{};

        /// Method binding hints (JS name, Zig function name, WebIDL length)
        pub const methods = .{
            .{ "parseDeclarationList", "call_parseDeclarationList", 1 },
            .{ "parseCommaValueList", "call_parseCommaValueList", 1 },
            .{ "ric", "call_ric", 1 },
            .{ "lvmin", "call_lvmin", 1 },
            .{ "cqmax", "call_cqmax", 1 },
            .{ "svmin", "call_svmin", 1 },
            .{ "s", "call_s", 1 },
            .{ "ch", "call_ch", 1 },
            .{ "rcap", "call_rcap", 1 },
            .{ "vi", "call_vi", 1 },
            .{ "supports", "call_supports", 1 },
            .{ "lh", "call_lh", 1 },
            .{ "cqh", "call_cqh", 1 },
            .{ "cm", "call_cm", 1 },
            .{ "Hz", "call_Hz", 1 },
            .{ "escape", "call_escape", 1 },
            .{ "svb", "call_svb", 1 },
            .{ "svh", "call_svh", 1 },
            .{ "in", "call_in", 1 },
            .{ "vmax", "call_vmax", 1 },
            .{ "deg", "call_deg", 1 },
            .{ "dvb", "call_dvb", 1 },
            .{ "lvw", "call_lvw", 1 },
            .{ "cqb", "call_cqb", 1 },
            .{ "pt", "call_pt", 1 },
            .{ "kHz", "call_kHz", 1 },
            .{ "fr", "call_fr", 1 },
            .{ "ex", "call_ex", 1 },
            .{ "Q", "call_Q", 1 },
            .{ "dpcm", "call_dpcm", 1 },
            .{ "rch", "call_rch", 1 },
            .{ "rex", "call_rex", 1 },
            .{ "parseRuleList", "call_parseRuleList", 1 },
            .{ "rad", "call_rad", 1 },
            .{ "mm", "call_mm", 1 },
            .{ "svmax", "call_svmax", 1 },
            .{ "cqw", "call_cqw", 1 },
            .{ "percent", "call_percent", 1 },
            .{ "em", "call_em", 1 },
            .{ "grad", "call_grad", 1 },
            .{ "vmin", "call_vmin", 1 },
            .{ "dvh", "call_dvh", 1 },
            .{ "svw", "call_svw", 1 },
            .{ "vb", "call_vb", 1 },
            .{ "lvh", "call_lvh", 1 },
            .{ "rem", "call_rem", 1 },
            .{ "lvb", "call_lvb", 1 },
            .{ "svi", "call_svi", 1 },
            .{ "vw", "call_vw", 1 },
            .{ "parseRule", "call_parseRule", 1 },
            .{ "cap", "call_cap", 1 },
            .{ "dvw", "call_dvw", 1 },
            .{ "dvmax", "call_dvmax", 1 },
            .{ "dpi", "call_dpi", 1 },
            .{ "number", "call_number", 1 },
            .{ "lvmax", "call_lvmax", 1 },
            .{ "ic", "call_ic", 1 },
            .{ "rlh", "call_rlh", 1 },
            .{ "turn", "call_turn", 1 },
            .{ "px", "call_px", 1 },
            .{ "parseDeclaration", "call_parseDeclaration", 1 },
            .{ "parseStylesheet", "call_parseStylesheet", 1 },
            .{ "cqmin", "call_cqmin", 1 },
            .{ "parseValue", "call_parseValue", 1 },
            .{ "registerProperty", "call_registerProperty", 1 },
            .{ "dvi", "call_dvi", 1 },
            .{ "pc", "call_pc", 1 },
            .{ "dppx", "call_dppx", 1 },
            .{ "cqi", "call_cqi", 1 },
            .{ "ms", "call_ms", 1 },
            .{ "dvmin", "call_dvmin", 1 },
            .{ "parseValueList", "call_parseValueList", 1 },
            .{ "vh", "call_vh", 1 },
            .{ "lvi", "call_lvi", 1 },
        };

        pub const has_constructor = false;
        pub const properties = .{};

        /// Attribute binding hints (JS name, getter, implemented by the impl)
        pub const attributes = .{
            .{ "animationWorklet", "get_animationWorklet", @hasDecl(CSS_impl, "get_animationWorklet") },
            .{ "highlights", "get_highlights", @hasDecl(CSS_impl, "get_highlights") },
            .{ "elementSources", "get_elementSources", @hasDecl(CSS_impl, "get_elementSources") },
            .{ "layoutWorklet", "get_layoutWorklet", @hasDecl(CSS_impl, "get_layoutWorklet") },
            .{ "paintWorklet", "get_paintWorklet", @hasDecl(CSS_impl, "get_paintWorklet") },
        };
    };

    pub const State = struct {};

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_ric", 0b1 },
        .{ "call_lvmin", 0b1 },
        .{ "call_cqmax", 0b1 },
        .{ "call_svmin", 0b1 },
        .{ "call_s", 0b1 },
        .{ "call_ch", 0b1 },
        .{ "call_rcap", 0b1 },
        .{ "call_vi", 0b1 },
        .{ "call_lh", 0b1 },
        .{ "call_cqh", 0b1 },
        .{ "call_cm", 0b1 },
        .{ "call_Hz", 0b1 },
        .{ "call_svb", 0b1 },
        .{ "call_svh", 0b1 },
        .{ "call_in", 0b1 },
        .{ "call_vmax", 0b1 },
        .{ "call_deg", 0b1 },
        .{ "call_dvb", 0b1 },
        .{ "call_lvw", 0b1 },
        .{ "call_cqb", 0b1 },
        .{ "call_pt", 0b1 },
        .{ "call_kHz", 0b1 },
        .{ "call_fr", 0b1 },
        .{ "call_ex", 0b1 },
        .{ "call_Q", 0b1 },
        .{ "call_dpcm", 0b1 },
        .{ "call_rch", 0b1 },
        .{ "call_rex", 0b1 },
        .{ "call_rad", 0b1 },
        .{ "call_mm", 0b1 },
        .{ "call_svmax", 0b1 },
        .{ "call_cqw", 0b1 },
        .{ "call_percent", 0b1 },
        .{ "call_em", 0b1 },
        .{ "call_grad", 0b1 },
        .{ "call_vmin", 0b1 },
        .{ "call_dvh", 0b1 },
        .{ "call_svw", 0b1 },
        .{ "call_vb", 0b1 },
        .{ "call_lvh", 0b1 },
        .{ "call_rem", 0b1 },
        .{ "call_lvb", 0b1 },
        .{ "call_svi", 0b1 },
        .{ "call_vw", 0b1 },
        .{ "call_cap", 0b1 },
        .{ "call_dvw", 0b1 },
        .{ "call_dvmax", 0b1 },
        .{ "call_dpi", 0b1 },
        .{ "call_number", 0b1 },
        .{ "call_lvmax", 0b1 },
        .{ "call_ic", 0b1 },
        .{ "call_rlh", 0b1 },
        .{ "call_turn", 0b1 },
        .{ "call_px", 0b1 },
        .{ "call_cqmin", 0b1 },
        .{ "call_dvi", 0b1 },
        .{ "call_pc", 0b1 },
        .{ "call_dppx", 0b1 },
        .{ "call_cqi", 0b1 },
        .{ "call_ms", 0b1 },
        .{ "call_dvmin", 0b1 },
        .{ "call_vh", 0b1 },
        .{ "call_lvi", 0b1 },
    };

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

    pub fn get_animationWorklet(ctx: runtime.Context) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CSS_impl, "get_animationWorklet")) {
            return try CSS_impl.get_animationWorklet(ctx);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn get_highlights(ctx: runtime.Context) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CSS_impl, "get_highlights")) {
            return try CSS_impl.get_highlights(ctx);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn get_elementSources(ctx: runtime.Context) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CSS_impl, "get_elementSources")) {
            return try CSS_impl.get_elementSources(ctx);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn get_layoutWorklet(ctx: runtime.Context) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CSS_impl, "get_layoutWorklet")) {
            return try CSS_impl.get_layoutWorklet(ctx);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn get_paintWorklet(ctx: runtime.Context) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CSS_impl, "get_paintWorklet")) {
            return try CSS_impl.get_paintWorklet(ctx);
        } else {
            return error.NotImplemented;
        }
    }
};
