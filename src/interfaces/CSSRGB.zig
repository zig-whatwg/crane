//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSRGBImpl = @import("../impls/CSSRGB.zig");
const CSSColorValue = @import("CSSColorValue.zig");

pub const CSSRGB = struct {
    pub const Meta = struct {
        pub const name = "CSSRGB";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSColorValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            r: CSSColorRGBComp = undefined,
            g: CSSColorRGBComp = undefined,
            b: CSSColorRGBComp = undefined,
            alpha: CSSColorPercent = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSRGB, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_g = &get_g,
        .get_r = &get_r,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_g = &set_g,
        .set_r = &set_r,

        .call_parse = &call_parse,
        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSRGBImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSRGBImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, r: anyopaque, g: anyopaque, b: anyopaque, alpha: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSRGBImpl.constructor(state, r, g, b, alpha);
        
        return instance;
    }

    pub fn get_r(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRGBImpl.get_r(state);
    }

    pub fn set_r(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRGBImpl.set_r(state, value);
    }

    pub fn get_g(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRGBImpl.get_g(state);
    }

    pub fn set_g(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRGBImpl.set_g(state, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRGBImpl.get_b(state);
    }

    pub fn set_b(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRGBImpl.set_b(state, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRGBImpl.get_alpha(state);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRGBImpl.set_alpha(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSRGBImpl.call_parseAll(state, property, cssText);
    }

    /// Arguments for parse (WebIDL overloading)
    pub const ParseArgs = union(enum) {
        /// parse(property, cssText)
        USVString_USVString: struct {
            property: runtime.USVString,
            cssText: runtime.USVString,
        },
        /// parse(cssText)
        USVString: runtime.USVString,
    };

    pub fn call_parse(instance: *runtime.Instance, args: ParseArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString_USVString => |a| return CSSRGBImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSRGBImpl.USVString(state, arg),
        }
    }

};
