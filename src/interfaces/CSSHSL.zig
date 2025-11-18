//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSHSLImpl = @import("../impls/CSSHSL.zig");
const CSSColorValue = @import("CSSColorValue.zig");

pub const CSSHSL = struct {
    pub const Meta = struct {
        pub const name = "CSSHSL";
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
            h: CSSColorAngle = undefined,
            s: CSSColorPercent = undefined,
            l: CSSColorPercent = undefined,
            alpha: CSSColorPercent = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSHSL, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_h = &get_h,
        .get_l = &get_l,
        .get_s = &get_s,

        .set_alpha = &set_alpha,
        .set_h = &set_h,
        .set_l = &set_l,
        .set_s = &set_s,

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
        CSSHSLImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSHSLImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, h: anyopaque, s: anyopaque, l: anyopaque, alpha: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSHSLImpl.constructor(state, h, s, l, alpha);
        
        return instance;
    }

    pub fn get_h(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHSLImpl.get_h(state);
    }

    pub fn set_h(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHSLImpl.set_h(state, value);
    }

    pub fn get_s(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHSLImpl.get_s(state);
    }

    pub fn set_s(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHSLImpl.set_s(state, value);
    }

    pub fn get_l(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHSLImpl.get_l(state);
    }

    pub fn set_l(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHSLImpl.set_l(state, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHSLImpl.get_alpha(state);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHSLImpl.set_alpha(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSHSLImpl.call_parseAll(state, property, cssText);
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
            .USVString_USVString => |a| return CSSHSLImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSHSLImpl.USVString(state, arg),
        }
    }

};
