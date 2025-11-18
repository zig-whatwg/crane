//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSHWBImpl = @import("../impls/CSSHWB.zig");
const CSSColorValue = @import("CSSColorValue.zig");

pub const CSSHWB = struct {
    pub const Meta = struct {
        pub const name = "CSSHWB";
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
            h: CSSNumericValue = undefined,
            w: CSSNumberish = undefined,
            b: CSSNumberish = undefined,
            alpha: CSSNumberish = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSHWB, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_h = &get_h,
        .get_w = &get_w,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_h = &set_h,
        .set_w = &set_w,

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
        CSSHWBImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSHWBImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, h: anyopaque, w: anyopaque, b: anyopaque, alpha: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSHWBImpl.constructor(state, h, w, b, alpha);
        
        return instance;
    }

    pub fn get_h(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHWBImpl.get_h(state);
    }

    pub fn set_h(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHWBImpl.set_h(state, value);
    }

    pub fn get_w(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHWBImpl.get_w(state);
    }

    pub fn set_w(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHWBImpl.set_w(state, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHWBImpl.get_b(state);
    }

    pub fn set_b(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHWBImpl.set_b(state, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSHWBImpl.get_alpha(state);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSHWBImpl.set_alpha(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSHWBImpl.call_parseAll(state, property, cssText);
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
            .USVString_USVString => |a| return CSSHWBImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSHWBImpl.USVString(state, arg),
        }
    }

};
