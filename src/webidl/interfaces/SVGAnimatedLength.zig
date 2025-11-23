//! Generated from: SVG.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedLengthImpl = @import("impls").SVGAnimatedLength;
const SVGLength = @import("interfaces").SVGLength;

pub const SVGAnimatedLength = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedLength";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "baseVal", "get_baseVal", null },
            .{ "animVal", "get_animVal", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "baseVal", "get_baseVal", null },
            .{ "animVal", "get_animVal", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            baseVal: SVGLength = undefined,
            animVal: SVGLength = undefined,
            cached_baseVal: ?SVGLength = null,
            cached_animVal: ?SVGLength = null,
        },
    );

    const delegates = .{

        .get_animVal = &get_animVal,
        .get_baseVal = &get_baseVal,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGAnimatedLengthImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedLengthImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_baseVal(instance: *runtime.Instance) anyerror!SVGLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_baseVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedLengthImpl.get_baseVal(instance);
        state.own.cached_baseVal = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animVal(instance: *runtime.Instance) anyerror!SVGLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_animVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedLengthImpl.get_animVal(instance);
        state.own.cached_animVal = value;
        return value;
    }

};
