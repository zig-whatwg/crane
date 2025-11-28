//! Generated from: webgpu.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUTextureImpl = @import("impls").GPUTexture;
const mixins = @import("mixins");
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUTextureView = @import("interfaces").GPUTextureView;
const GPUTextureDimension = @import("enums").GPUTextureDimension;
const GPUSize32Out = @import("typedefs").GPUSize32Out;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;
const GPUTextureFormat = @import("enums").GPUTextureFormat;
const USVString = @import("interfaces").USVString;
const GPUTextureViewDescriptor = @import("dictionaries").GPUTextureViewDescriptor;
const GPUIntegerCoordinateOut = @import("typedefs").GPUIntegerCoordinateOut;

pub const GPUTexture = struct {
    pub const Meta = struct {
        pub const name = "GPUTexture";
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
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "depthOrArrayLayers", "get_depthOrArrayLayers", null },
            .{ "mipLevelCount", "get_mipLevelCount", null },
            .{ "sampleCount", "get_sampleCount", null },
            .{ "dimension", "get_dimension", null },
            .{ "format", "get_format", null },
            .{ "usage", "get_usage", null },
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createView", "call_createView", 0 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createView",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "depthOrArrayLayers", "get_depthOrArrayLayers", null },
            .{ "mipLevelCount", "get_mipLevelCount", null },
            .{ "sampleCount", "get_sampleCount", null },
            .{ "dimension", "get_dimension", null },
            .{ "format", "get_format", null },
            .{ "usage", "get_usage", null },
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
            width: GPUIntegerCoordinateOut = undefined,
            height: GPUIntegerCoordinateOut = undefined,
            depthOrArrayLayers: GPUIntegerCoordinateOut = undefined,
            mipLevelCount: GPUIntegerCoordinateOut = undefined,
            sampleCount: GPUSize32Out = undefined,
            dimension: GPUTextureDimension = undefined,
            format: GPUTextureFormat = undefined,
            usage: GPUFlagsConstant = undefined,
            label: runtime.USVString = undefined,
            _internal: ?*GPUTextureImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_depthOrArrayLayers = &get_depthOrArrayLayers,
        .get_dimension = &get_dimension,
        .get_format = &get_format,
        .get_height = &get_height,
        .get_label = &get_label,
        .get_mipLevelCount = &get_mipLevelCount,
        .get_sampleCount = &get_sampleCount,
        .get_usage = &get_usage,
        .get_width = &get_width,

        .set_label = &set_label,

        .call_createView = &call_createView,
        .call_destroy = &call_destroy,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUTextureImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUTextureImpl.deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_height(instance);
    }

    pub fn get_depthOrArrayLayers(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_depthOrArrayLayers(instance);
    }

    pub fn get_mipLevelCount(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_mipLevelCount(instance);
    }

    pub fn get_sampleCount(instance: *runtime.Instance) anyerror!GPUSize32Out {
        return try GPUTextureImpl.get_sampleCount(instance);
    }

    pub fn get_dimension(instance: *runtime.Instance) anyerror!GPUTextureDimension {
        return try GPUTextureImpl.get_dimension(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try GPUTextureImpl.get_format(instance);
    }

    pub fn get_usage(instance: *runtime.Instance) anyerror!GPUFlagsConstant {
        return try GPUTextureImpl.get_usage(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUTextureImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUTextureImpl.set_label(instance, value);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUTextureImpl.call_destroy(instance);
    }

    pub fn call_createView(instance: *runtime.Instance, descriptor: webidl.Opt(GPUTextureViewDescriptor)) anyerror!*runtime.Instance {
        
        return try GPUTextureImpl.call_createView(instance, descriptor);
    }

};
