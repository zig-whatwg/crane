//! Generated from: webgpu.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderPipelineImpl = @import("impls").GPURenderPipeline;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUPipelineBase = @import("interfaces").GPUPipelineBase;
const GPUBindGroupLayout = @import("interfaces").GPUBindGroupLayout;
const USVString = @import("interfaces").USVString;

pub const GPURenderPipeline = struct {
    pub const Meta = struct {
        pub const name = "GPURenderPipeline";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            GPUObjectBase,
            GPUPipelineBase,
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getBindGroupLayout", "call_getBindGroupLayout", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getBindGroupLayout",
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
        },
    );

    const delegates = .{

        .get_label = &get_label,

        .set_label = &set_label,

        .call_getBindGroupLayout = &call_getBindGroupLayout,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPURenderPipelineImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderPipelineImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPURenderPipelineImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPURenderPipelineImpl.set_label(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBindGroupLayout(instance: *runtime.Instance, index: u32) anyerror!GPUBindGroupLayout {
        // [NewObject] - Caller owns the returned object
        
        return try GPURenderPipelineImpl.call_getBindGroupLayout(instance, index);
    }

};
