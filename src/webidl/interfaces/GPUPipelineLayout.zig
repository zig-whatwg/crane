//! Generated from: webgpu.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUPipelineLayoutImpl = @import("impls").GPUPipelineLayout;
const mixins = @import("mixins");
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const USVString = @import("interfaces").USVString;

pub const GPUPipelineLayout = struct {
    pub const Meta = struct {
        pub const name = "GPUPipelineLayout";
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
            .{ "label", "get_label", "set_label" },
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
            label: runtime.USVString = undefined,
            _internal: ?*GPUPipelineLayoutImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_label = &get_label,

        .set_label = &set_label,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUPipelineLayoutImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUPipelineLayoutImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUPipelineLayoutImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUPipelineLayoutImpl.set_label(instance, value);
    }

};
