//! Generated from: webgpu.idl
//! Generated at: 2025-11-28T18:57:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUQuerySetImpl = @import("impls").GPUQuerySet;
const mixins = @import("mixins");
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUQueryType = @import("enums").GPUQueryType;
const GPUSize32Out = @import("typedefs").GPUSize32Out;
const USVString = @import("interfaces").USVString;

pub const GPUQuerySet = struct {
    pub const Meta = struct {
        pub const name = "GPUQuerySet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            GPUObjectBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "count", "get_count", null },
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "count", "get_count", null },
            .{ "label", "get_label", "set_label" },
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
            @"type": GPUQueryType = undefined,
            count: GPUSize32Out = undefined,
            label: runtime.USVString = undefined,
            _internal: ?*GPUQuerySetImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_count = &get_count,
        .get_label = &get_label,
        .get_type = &get_type,

        .set_label = &set_label,

        .call_destroy = &call_destroy,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUQuerySetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUQuerySetImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GPUQueryType {
        return try GPUQuerySetImpl.get_type(instance);
    }

    pub fn get_count(instance: *runtime.Instance) anyerror!GPUSize32Out {
        return try GPUQuerySetImpl.get_count(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUQuerySetImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUQuerySetImpl.set_label(instance, value);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUQuerySetImpl.call_destroy(instance);
    }

};
