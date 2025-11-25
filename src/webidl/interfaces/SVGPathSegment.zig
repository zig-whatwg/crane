//! Generated from: svg-paths.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGPathSegmentImpl = @import("impls").SVGPathSegment;
const DOMString = @import("typedefs").DOMString;

pub const SVGPathSegment = struct {
    pub const Meta = struct {
        pub const name = "SVGPathSegment";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "NoInterfaceObject" },
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "values", "get_values", "set_values" },
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
            .{ "type", "get_type", "set_type" },
            .{ "values", "get_values", "set_values" },
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
            @"type": runtime.DOMString = undefined,
            values: runtime.sequence(f32) = undefined,
            _internal: ?*SVGPathSegmentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_type = &get_type,
        .get_values = &get_values,

        .set_type = &set_type,
        .set_values = &set_values,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGPathSegmentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGPathSegmentImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGPathSegmentImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGPathSegmentImpl.set_type(instance, value);
    }

    pub fn get_values(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SVGPathSegmentImpl.get_values(instance);
    }

    pub fn set_values(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try SVGPathSegmentImpl.set_values(instance, value);
    }

};
