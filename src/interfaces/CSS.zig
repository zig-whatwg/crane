//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSImpl = @import("../impls/CSS.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CSSImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_layoutWorklet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_layoutWorklet) |cached| {
            return cached;
        }
        const value = CSSImpl.get_layoutWorklet(state);
        state.cached_layoutWorklet = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_paintWorklet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_paintWorklet) |cached| {
            return cached;
        }
        const value = CSSImpl.get_paintWorklet(state);
        state.cached_paintWorklet = value;
        return value;
    }

    pub fn get_highlights(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImpl.get_highlights(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_elementSources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_elementSources) |cached| {
            return cached;
        }
        const value = CSSImpl.get_elementSources(state);
        state.cached_elementSources = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animationWorklet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_animationWorklet) |cached| {
            return cached;
        }
        const value = CSSImpl.get_animationWorklet(state);
        state.cached_animationWorklet = value;
        return value;
    }

    pub fn call_lvmin(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lvmin(state, value);
    }

    pub fn call_lvi(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lvi(state, value);
    }

    pub fn call_parseValue(instance: *runtime.Instance, css: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseValue(state, css);
    }

    pub fn call_dvb(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dvb(state, value);
    }

    pub fn call_vw(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_vw(state, value);
    }

    pub fn call_percent(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_percent(state, value);
    }

    pub fn call_vh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_vh(state, value);
    }

    pub fn call_svw(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_svw(state, value);
    }

    pub fn call_fr(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_fr(state, value);
    }

    pub fn call_lvh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lvh(state, value);
    }

    pub fn call_parseDeclarationList(instance: *runtime.Instance, css: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseDeclarationList(state, css, options);
    }

    pub fn call_number(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_number(state, value);
    }

    pub fn call_vmax(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_vmax(state, value);
    }

    pub fn call_ic(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_ic(state, value);
    }

    pub fn call_in(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_in(state, value);
    }

    pub fn call_em(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_em(state, value);
    }

    pub fn call_escape(instance: *runtime.Instance, ident: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_escape(state, ident);
    }

    pub fn call_ex(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_ex(state, value);
    }

    pub fn call_dppx(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dppx(state, value);
    }

    pub fn call_lvmax(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lvmax(state, value);
    }

    pub fn call_mm(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_mm(state, value);
    }

    pub fn call_Q(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_Q(state, value);
    }

    pub fn call_ms(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_ms(state, value);
    }

    pub fn call_parseStylesheet(instance: *runtime.Instance, css: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseStylesheet(state, css, options);
    }

    pub fn call_registerProperty(instance: *runtime.Instance, definition: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_registerProperty(state, definition);
    }

    pub fn call_s(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_s(state, value);
    }

    pub fn call_svmax(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_svmax(state, value);
    }

    pub fn call_cqmax(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cqmax(state, value);
    }

    pub fn call_svh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_svh(state, value);
    }

    pub fn call_dvw(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dvw(state, value);
    }

    pub fn call_dvmin(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dvmin(state, value);
    }

    pub fn call_svi(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_svi(state, value);
    }

    pub fn call_parseValueList(instance: *runtime.Instance, css: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseValueList(state, css);
    }

    pub fn call_dpi(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dpi(state, value);
    }

    pub fn call_lh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lh(state, value);
    }

    pub fn call_pc(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_pc(state, value);
    }

    pub fn call_parseRuleList(instance: *runtime.Instance, css: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseRuleList(state, css, options);
    }

    pub fn call_vi(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_vi(state, value);
    }

    pub fn call_cqmin(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cqmin(state, value);
    }

    pub fn call_rcap(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_rcap(state, value);
    }

    pub fn call_cqh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cqh(state, value);
    }

    pub fn call_pt(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_pt(state, value);
    }

    pub fn call_rem(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_rem(state, value);
    }

    pub fn call_dpcm(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dpcm(state, value);
    }

    pub fn call_dvh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dvh(state, value);
    }

    pub fn call_parseDeclaration(instance: *runtime.Instance, css: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseDeclaration(state, css, options);
    }

    pub fn call_turn(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_turn(state, value);
    }

    pub fn call_rex(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_rex(state, value);
    }

    pub fn call_cqb(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cqb(state, value);
    }

    pub fn call_svb(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_svb(state, value);
    }

    pub fn call_lvb(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lvb(state, value);
    }

    pub fn call_dvi(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dvi(state, value);
    }

    pub fn call_px(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_px(state, value);
    }

    pub fn call_cap(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cap(state, value);
    }

    pub fn call_kHz(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_kHz(state, value);
    }

    pub fn call_ric(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_ric(state, value);
    }

    pub fn call_cqi(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cqi(state, value);
    }

    pub fn call_dvmax(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_dvmax(state, value);
    }

    pub fn call_cm(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cm(state, value);
    }

    pub fn call_deg(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_deg(state, value);
    }

    pub fn call_parseRule(instance: *runtime.Instance, css: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseRule(state, css, options);
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

    pub fn call_supports(instance: *runtime.Instance, args: SupportsArgs) bool {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString_CSSOMString => |a| return CSSImpl.CSSOMString_CSSOMString(state, a.property, a.value),
            .CSSOMString => |arg| return CSSImpl.CSSOMString(state, arg),
        }
    }

    pub fn call_rlh(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_rlh(state, value);
    }

    pub fn call_rch(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_rch(state, value);
    }

    pub fn call_vb(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_vb(state, value);
    }

    pub fn call_svmin(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_svmin(state, value);
    }

    pub fn call_lvw(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_lvw(state, value);
    }

    pub fn call_cqw(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_cqw(state, value);
    }

    pub fn call_grad(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_grad(state, value);
    }

    pub fn call_rad(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_rad(state, value);
    }

    pub fn call_parseCommaValueList(instance: *runtime.Instance, css: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_parseCommaValueList(state, css);
    }

    pub fn call_Hz(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_Hz(state, value);
    }

    pub fn call_vmin(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_vmin(state, value);
    }

    pub fn call_ch(instance: *runtime.Instance, value: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSImpl.call_ch(state, value);
    }

};
