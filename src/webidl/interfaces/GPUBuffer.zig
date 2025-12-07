//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUBufferImpl = @import("impls").GPUBuffer;
const mixins = @import("mixins");
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUSize64Out = @import("typedefs").GPUSize64Out;
const GPUBufferMapState = @import("enums").GPUBufferMapState;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;
const GPUMapModeFlags = @import("typedefs").GPUMapModeFlags;
const USVString = @import("interfaces").USVString;

pub const GPUBuffer = struct {
    pub const Meta = struct {
        pub const name = "GPUBuffer";
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
            .{ "size", "get_size", null },
            .{ "usage", "get_usage", null },
            .{ "mapState", "get_mapState", null },
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "mapAsync", "call_mapAsync", 1 },
            .{ "getMappedRange", "call_getMappedRange", 0 },
            .{ "unmap", "call_unmap", 0 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "mapAsync",
            "getMappedRange",
            "unmap",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
            .{ "usage", "get_usage", null },
            .{ "mapState", "get_mapState", null },
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
            size: GPUSize64Out = undefined,
            usage: GPUFlagsConstant = undefined,
            mapState: GPUBufferMapState = undefined,
            label: runtime.USVString = undefined,
            _internal: ?*GPUBufferImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_label = &get_label,
        .get_mapState = &get_mapState,
        .get_size = &get_size,
        .get_usage = &get_usage,

        .set_label = &set_label,

        .call_destroy = &call_destroy,
        .call_getMappedRange = &call_getMappedRange,
        .call_mapAsync = &call_mapAsync,
        .call_unmap = &call_unmap,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUBufferImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUBufferImpl.deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!GPUSize64Out {
        return try GPUBufferImpl.get_size(instance);
    }

    pub fn get_usage(instance: *runtime.Instance) anyerror!GPUFlagsConstant {
        return try GPUBufferImpl.get_usage(instance);
    }

    pub fn get_mapState(instance: *runtime.Instance) anyerror!GPUBufferMapState {
        return try GPUBufferImpl.get_mapState(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUBufferImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUBufferImpl.set_label(instance, value);
    }

    pub fn call_unmap(instance: *runtime.Instance) anyerror!void {
        return try GPUBufferImpl.call_unmap(instance);
    }

    pub fn call_getMappedRange(instance: *runtime.Instance, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!*const anyopaque {
        
        return try GPUBufferImpl.call_getMappedRange(instance, offset, size);
    }

    pub fn call_mapAsync(instance: *runtime.Instance, mode: GPUMapModeFlags, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!*const anyopaque {
        
        return try GPUBufferImpl.call_mapAsync(instance, mode, offset, size);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUBufferImpl.call_destroy(instance);
    }

};
