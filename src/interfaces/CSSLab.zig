//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSLabImpl = @import("../impls/CSSLab.zig");
const CSSColorValue = @import("CSSColorValue.zig");

pub const CSSLab = struct {
    pub const Meta = struct {
        pub const name = "CSSLab";
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
            l: CSSColorPercent = undefined,
            a: CSSColorNumber = undefined,
            b: CSSColorNumber = undefined,
            alpha: CSSColorPercent = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSLab, .{
        .deinit_fn = &deinit_wrapper,

        .get_a = &get_a,
        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_l = &get_l,

        .set_a = &set_a,
        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_l = &set_l,

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
        CSSLabImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSLabImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, l: anyopaque, a: anyopaque, b: anyopaque, alpha: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSLabImpl.constructor(state, l, a, b, alpha);
        
        return instance;
    }

    pub fn get_l(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSLabImpl.get_l(state);
    }

    pub fn set_l(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSLabImpl.set_l(state, value);
    }

    pub fn get_a(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSLabImpl.get_a(state);
    }

    pub fn set_a(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSLabImpl.set_a(state, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSLabImpl.get_b(state);
    }

    pub fn set_b(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSLabImpl.set_b(state, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSLabImpl.get_alpha(state);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSLabImpl.set_alpha(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSLabImpl.call_parseAll(state, property, cssText);
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
            .USVString_USVString => |a| return CSSLabImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSLabImpl.USVString(state, arg),
        }
    }

};
