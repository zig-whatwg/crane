//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUQueueImpl = @import("../impls/GPUQueue.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");

pub const GPUQueue = struct {
    pub const Meta = struct {
        pub const name = "GPUQueue";
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
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUQueue, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_copyExternalImageToTexture = &call_copyExternalImageToTexture,
        .call_onSubmittedWorkDone = &call_onSubmittedWorkDone,
        .call_submit = &call_submit,
        .call_writeBuffer = &call_writeBuffer,
        .call_writeTexture = &call_writeTexture,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUQueueImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUQueueImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPUQueueImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPUQueueImpl.set_label(state, value);
    }

    pub fn call_onSubmittedWorkDone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUQueueImpl.call_onSubmittedWorkDone(state);
    }

    pub fn call_writeBuffer(instance: *runtime.Instance, buffer: anyopaque, bufferOffset: anyopaque, data: anyopaque, dataOffset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUQueueImpl.call_writeBuffer(state, buffer, bufferOffset, data, dataOffset, size);
    }

    pub fn call_writeTexture(instance: *runtime.Instance, destination: anyopaque, data: anyopaque, dataLayout: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUQueueImpl.call_writeTexture(state, destination, data, dataLayout, size);
    }

    pub fn call_submit(instance: *runtime.Instance, commandBuffers: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUQueueImpl.call_submit(state, commandBuffers);
    }

    pub fn call_copyExternalImageToTexture(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUQueueImpl.call_copyExternalImageToTexture(state, source, destination, copySize);
    }

};
