//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSImpl = @import("impls").CSS;
const Worklet = @import("interfaces").Worklet;
const CSSParserDeclaration = @import("interfaces").CSSParserDeclaration;
const CSSUnitValue = @import("interfaces").CSSUnitValue;
const CSSOMString = @import("interfaces").CSSOMString;
const PropertyDefinition = @import("dictionaries").PropertyDefinition;
const CSSToken = @import("typedefs").CSSToken;
const CSSStringSource = @import("typedefs").CSSStringSource;
const HighlightRegistry = @import("interfaces").HighlightRegistry;
const Promise<sequence<CSSParserRule>> = @import("interfaces").Promise<sequence<CSSParserRule>>;
const CSSParserOptions = @import("dictionaries").CSSParserOptions;
const Promise<CSSParserRule> = @import("interfaces").Promise<CSSParserRule>;

pub const CSS = struct {
    pub const Meta = struct {
        pub const name = "CSS";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            layoutWorklet: Worklet = undefined,
            paintWorklet: Worklet = undefined,
            highlights: HighlightRegistry = undefined,
            elementSources: anyopaque = undefined,
            animationWorklet: Worklet = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSS, .{
        .deinit_fn = &deinit_wrapper,

        .get_animationWorklet = &get_animationWorklet,
        .get_elementSources = &get_elementSources,
        .get_highlights = &get_highlights,
        .get_layoutWorklet = &get_layoutWorklet,
        .get_paintWorklet = &get_paintWorklet,

        .call_Hz = &call_Hz,
        .call_Q = &call_Q,
        .call_cap = &call_cap,
        .call_ch = &call_ch,
        .call_cm = &call_cm,
        .call_cqb = &call_cqb,
        .call_cqh = &call_cqh,
        .call_cqi = &call_cqi,
        .call_cqmax = &call_cqmax,
        .call_cqmin = &call_cqmin,
        .call_cqw = &call_cqw,
        .call_deg = &call_deg,
        .call_dpcm = &call_dpcm,
        .call_dpi = &call_dpi,
        .call_dppx = &call_dppx,
        .call_dvb = &call_dvb,
        .call_dvh = &call_dvh,
        .call_dvi = &call_dvi,
        .call_dvmax = &call_dvmax,
        .call_dvmin = &call_dvmin,
        .call_dvw = &call_dvw,
        .call_em = &call_em,
        .call_escape = &call_escape,
        .call_ex = &call_ex,
        .call_fr = &call_fr,
        .call_grad = &call_grad,
        .call_ic = &call_ic,
        .call_in = &call_in,
        .call_kHz = &call_kHz,
        .call_lh = &call_lh,
        .call_lvb = &call_lvb,
        .call_lvh = &call_lvh,
        .call_lvi = &call_lvi,
        .call_lvmax = &call_lvmax,
        .call_lvmin = &call_lvmin,
        .call_lvw = &call_lvw,
        .call_mm = &call_mm,
        .call_ms = &call_ms,
        .call_number = &call_number,
        .call_parseCommaValueList = &call_parseCommaValueList,
        .call_parseDeclaration = &call_parseDeclaration,
        .call_parseDeclarationList = &call_parseDeclarationList,
        .call_parseRule = &call_parseRule,
        .call_parseRuleList = &call_parseRuleList,
        .call_parseStylesheet = &call_parseStylesheet,
        .call_parseValue = &call_parseValue,
        .call_parseValueList = &call_parseValueList,
        .call_pc = &call_pc,
        .call_percent = &call_percent,
        .call_pt = &call_pt,
        .call_px = &call_px,
        .call_rad = &call_rad,
        .call_rcap = &call_rcap,
        .call_rch = &call_rch,
        .call_registerProperty = &call_registerProperty,
        .call_rem = &call_rem,
        .call_rex = &call_rex,
        .call_ric = &call_ric,
        .call_rlh = &call_rlh,
        .call_s = &call_s,
        .call_supports = &call_supports,
        .call_svb = &call_svb,
        .call_svh = &call_svh,
        .call_svi = &call_svi,
        .call_svmax = &call_svmax,
        .call_svmin = &call_svmin,
        .call_svw = &call_svw,
        .call_turn = &call_turn,
        .call_vb = &call_vb,
        .call_vh = &call_vh,
        .call_vi = &call_vi,
        .call_vmax = &call_vmax,
        .call_vmin = &call_vmin,
        .call_vw = &call_vw,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_layoutWorklet(instance: *runtime.Instance) anyerror!Worklet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_layoutWorklet) |cached| {
            return cached;
        }
        const value = try CSSImpl.get_layoutWorklet(instance);
        state.cached_layoutWorklet = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_paintWorklet(instance: *runtime.Instance) anyerror!Worklet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_paintWorklet) |cached| {
            return cached;
        }
        const value = try CSSImpl.get_paintWorklet(instance);
        state.cached_paintWorklet = value;
        return value;
    }

    pub fn get_highlights(instance: *runtime.Instance) anyerror!HighlightRegistry {
        return try CSSImpl.get_highlights(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_elementSources(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_elementSources) |cached| {
            return cached;
        }
        const value = try CSSImpl.get_elementSources(instance);
        state.cached_elementSources = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animationWorklet(instance: *runtime.Instance) anyerror!Worklet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_animationWorklet) |cached| {
            return cached;
        }
        const value = try CSSImpl.get_animationWorklet(instance);
        state.cached_animationWorklet = value;
        return value;
    }

    pub fn call_lvmin(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lvmin(instance, value);
    }

    pub fn call_lvi(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lvi(instance, value);
    }

    pub fn call_parseValue(instance: *runtime.Instance, css: DOMString) anyerror!CSSToken {
        
        return try CSSImpl.call_parseValue(instance, css);
    }

    pub fn call_dvb(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dvb(instance, value);
    }

    pub fn call_vw(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_vw(instance, value);
    }

    pub fn call_percent(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_percent(instance, value);
    }

    pub fn call_vh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_vh(instance, value);
    }

    pub fn call_svw(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_svw(instance, value);
    }

    pub fn call_fr(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_fr(instance, value);
    }

    pub fn call_lvh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lvh(instance, value);
    }

    pub fn call_parseDeclarationList(instance: *runtime.Instance, css: CSSStringSource, options: CSSParserOptions) anyerror!anyopaque {
        
        return try CSSImpl.call_parseDeclarationList(instance, css, options);
    }

    pub fn call_number(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_number(instance, value);
    }

    pub fn call_vmax(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_vmax(instance, value);
    }

    pub fn call_ic(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_ic(instance, value);
    }

    pub fn call_in(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_in(instance, value);
    }

    pub fn call_em(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_em(instance, value);
    }

    pub fn call_escape(instance: *runtime.Instance, ident: anyopaque) anyerror!anyopaque {
        
        return try CSSImpl.call_escape(instance, ident);
    }

    pub fn call_ex(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_ex(instance, value);
    }

    pub fn call_dppx(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dppx(instance, value);
    }

    pub fn call_lvmax(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lvmax(instance, value);
    }

    pub fn call_mm(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_mm(instance, value);
    }

    pub fn call_Q(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_Q(instance, value);
    }

    pub fn call_ms(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_ms(instance, value);
    }

    pub fn call_parseStylesheet(instance: *runtime.Instance, css: CSSStringSource, options: CSSParserOptions) anyerror!anyopaque {
        
        return try CSSImpl.call_parseStylesheet(instance, css, options);
    }

    pub fn call_registerProperty(instance: *runtime.Instance, definition: PropertyDefinition) anyerror!void {
        
        return try CSSImpl.call_registerProperty(instance, definition);
    }

    pub fn call_s(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_s(instance, value);
    }

    pub fn call_svmax(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_svmax(instance, value);
    }

    pub fn call_cqmax(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cqmax(instance, value);
    }

    pub fn call_svh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_svh(instance, value);
    }

    pub fn call_dvw(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dvw(instance, value);
    }

    pub fn call_dvmin(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dvmin(instance, value);
    }

    pub fn call_svi(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_svi(instance, value);
    }

    pub fn call_parseValueList(instance: *runtime.Instance, css: DOMString) anyerror!anyopaque {
        
        return try CSSImpl.call_parseValueList(instance, css);
    }

    pub fn call_dpi(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dpi(instance, value);
    }

    pub fn call_lh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lh(instance, value);
    }

    pub fn call_pc(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_pc(instance, value);
    }

    pub fn call_parseRuleList(instance: *runtime.Instance, css: CSSStringSource, options: CSSParserOptions) anyerror!anyopaque {
        
        return try CSSImpl.call_parseRuleList(instance, css, options);
    }

    pub fn call_vi(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_vi(instance, value);
    }

    pub fn call_cqmin(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cqmin(instance, value);
    }

    pub fn call_rcap(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_rcap(instance, value);
    }

    pub fn call_cqh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cqh(instance, value);
    }

    pub fn call_pt(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_pt(instance, value);
    }

    pub fn call_rem(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_rem(instance, value);
    }

    pub fn call_dpcm(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dpcm(instance, value);
    }

    pub fn call_dvh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dvh(instance, value);
    }

    pub fn call_parseDeclaration(instance: *runtime.Instance, css: DOMString, options: CSSParserOptions) anyerror!CSSParserDeclaration {
        
        return try CSSImpl.call_parseDeclaration(instance, css, options);
    }

    pub fn call_turn(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_turn(instance, value);
    }

    pub fn call_rex(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_rex(instance, value);
    }

    pub fn call_cqb(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cqb(instance, value);
    }

    pub fn call_svb(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_svb(instance, value);
    }

    pub fn call_lvb(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lvb(instance, value);
    }

    pub fn call_dvi(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dvi(instance, value);
    }

    pub fn call_px(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_px(instance, value);
    }

    pub fn call_cap(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cap(instance, value);
    }

    pub fn call_kHz(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_kHz(instance, value);
    }

    pub fn call_ric(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_ric(instance, value);
    }

    pub fn call_cqi(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cqi(instance, value);
    }

    pub fn call_dvmax(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_dvmax(instance, value);
    }

    pub fn call_cm(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cm(instance, value);
    }

    pub fn call_deg(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_deg(instance, value);
    }

    pub fn call_parseRule(instance: *runtime.Instance, css: CSSStringSource, options: CSSParserOptions) anyerror!anyopaque {
        
        return try CSSImpl.call_parseRule(instance, css, options);
    }

    /// Arguments for supports (WebIDL overloading)
    pub const SupportsArgs = union(enum) {
        /// supports(property, value)
        CSSOMString_CSSOMString: struct {
            property: anyopaque,
            value: anyopaque,
        },
        /// supports(conditionText)
        CSSOMString: anyopaque,
    };

    pub fn call_supports(instance: *runtime.Instance, args: SupportsArgs) anyerror!bool {
        switch (args) {
            .CSSOMString_CSSOMString => |a| return try CSSImpl.CSSOMString_CSSOMString(instance, a.property, a.value),
            .CSSOMString => |arg| return try CSSImpl.CSSOMString(instance, arg),
        }
    }

    pub fn call_rlh(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_rlh(instance, value);
    }

    pub fn call_rch(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_rch(instance, value);
    }

    pub fn call_vb(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_vb(instance, value);
    }

    pub fn call_svmin(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_svmin(instance, value);
    }

    pub fn call_lvw(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_lvw(instance, value);
    }

    pub fn call_cqw(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_cqw(instance, value);
    }

    pub fn call_grad(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_grad(instance, value);
    }

    pub fn call_rad(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_rad(instance, value);
    }

    pub fn call_parseCommaValueList(instance: *runtime.Instance, css: DOMString) anyerror!anyopaque {
        
        return try CSSImpl.call_parseCommaValueList(instance, css);
    }

    pub fn call_Hz(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_Hz(instance, value);
    }

    pub fn call_vmin(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_vmin(instance, value);
    }

    pub fn call_ch(instance: *runtime.Instance, value: f64) anyerror!CSSUnitValue {
        
        return try CSSImpl.call_ch(instance, value);
    }

};
