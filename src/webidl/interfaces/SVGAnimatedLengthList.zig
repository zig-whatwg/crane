//! Generated from: SVG.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedLengthListImpl = @import("impls").SVGAnimatedLengthList;
const SVGLengthList = @import("interfaces").SVGLengthList;

pub const SVGAnimatedLengthList = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedLengthList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            baseVal: *runtime.Instance = undefined,
            animVal: *runtime.Instance = undefined,
            cached_baseVal: ?*runtime.Instance = null,
            cached_animVal: ?*runtime.Instance = null,
            _internal: ?*SVGAnimatedLengthListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_animVal = &get_animVal,
        .get_baseVal = &get_baseVal,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGAnimatedLengthListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedLengthListImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_baseVal(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_baseVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedLengthListImpl.get_baseVal(instance);
        state.own.cached_baseVal = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animVal(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_animVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedLengthListImpl.get_animVal(instance);
        state.own.cached_animVal = value;
        return value;
    }

};
