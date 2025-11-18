//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUBufferImpl = @import("impls").GPUBuffer;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUSize64Out = @import("typedefs").GPUSize64Out;
const GPUBufferMapState = @import("enums").GPUBufferMapState;
const GPUSize64 = @import("typedefs").GPUSize64;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;
const GPUMapModeFlags = @import("typedefs").GPUMapModeFlags;
const Promise<undefined> = @import("interfaces").Promise<undefined>;

pub const GPUBuffer = struct {
    pub const Meta = struct {
        pub const name = "GPUBuffer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            size: GPUSize64Out = undefined,
            usage: GPUFlagsConstant = undefined,
            mapState: GPUBufferMapState = undefined,
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUBuffer, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,
        .get_mapState = &get_mapState,
        .get_size = &get_size,
        .get_usage = &get_usage,

        .set_label = &set_label,

        .call_destroy = &call_destroy,
        .call_getMappedRange = &call_getMappedRange,
        .call_mapAsync = &call_mapAsync,
        .call_unmap = &call_unmap,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUBufferImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUBufferImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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

    pub fn call_getMappedRange(instance: *runtime.Instance, offset: GPUSize64, size: GPUSize64) anyerror!anyopaque {
        
        return try GPUBufferImpl.call_getMappedRange(instance, offset, size);
    }

    pub fn call_mapAsync(instance: *runtime.Instance, mode: GPUMapModeFlags, offset: GPUSize64, size: GPUSize64) anyerror!anyopaque {
        
        return try GPUBufferImpl.call_mapAsync(instance, mode, offset, size);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUBufferImpl.call_destroy(instance);
    }

};
