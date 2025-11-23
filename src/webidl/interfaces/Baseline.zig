//! Generated from: font-metrics-api.idl
//! Generated at: 2025-11-23T19:17:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BaselineImpl = @import("impls").Baseline;
const DOMString = @import("typedefs").DOMString;

pub const Baseline = struct {
    pub const Meta = struct {
        pub const name = "Baseline";
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
            .{ "name", "get_name", null },
            .{ "value", "get_value", null },
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
            .{ "name", "get_name", null },
            .{ "value", "get_value", null },
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
            name: runtime.DOMString = undefined,
            value: f64 = undefined,
            _internal: ?*BaselineImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_value = &get_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BaselineImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BaselineImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try BaselineImpl.get_name(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
        return try BaselineImpl.get_value(instance);
    }

};
