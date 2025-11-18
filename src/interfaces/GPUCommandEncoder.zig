//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCommandEncoderImpl = @import("../impls/GPUCommandEncoder.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");
const GPUCommandsMixin = @import("GPUCommandsMixin.zig");
const GPUDebugCommandsMixin = @import("GPUDebugCommandsMixin.zig");

pub const GPUCommandEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPUCommandEncoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
            GPUCommandsMixin,
            GPUDebugCommandsMixin,
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

    pub const vtable = runtime.buildVTable(GPUCommandEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_beginComputePass = &call_beginComputePass,
        .call_beginRenderPass = &call_beginRenderPass,
        .call_clearBuffer = &call_clearBuffer,
        .call_copyBufferToBuffer = &call_copyBufferToBuffer,
        .call_copyBufferToBuffer = &call_copyBufferToBuffer,
        .call_copyBufferToTexture = &call_copyBufferToTexture,
        .call_copyTextureToBuffer = &call_copyTextureToBuffer,
        .call_copyTextureToTexture = &call_copyTextureToTexture,
        .call_finish = &call_finish,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_resolveQuerySet = &call_resolveQuerySet,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUCommandEncoderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUCommandEncoderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPUCommandEncoderImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPUCommandEncoderImpl.set_label(state, value);
    }

    /// Arguments for copyBufferToBuffer (WebIDL overloading)
    pub const CopyBufferToBufferArgs = union(enum) {
        /// copyBufferToBuffer(source, destination, size)
        GPUBuffer_GPUBuffer_GPUSize64: struct {
            source: anyopaque,
            destination: anyopaque,
            size: anyopaque,
        },
        /// copyBufferToBuffer(source, sourceOffset, destination, destinationOffset, size)
        GPUBuffer_GPUSize64_GPUBuffer_GPUSize64_GPUSize64: struct {
            source: anyopaque,
            sourceOffset: anyopaque,
            destination: anyopaque,
            destinationOffset: anyopaque,
            size: anyopaque,
        },
    };

    pub fn call_copyBufferToBuffer(instance: *runtime.Instance, args: CopyBufferToBufferArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GPUBuffer_GPUBuffer_GPUSize64 => |a| return GPUCommandEncoderImpl.GPUBuffer_GPUBuffer_GPUSize64(state, a.source, a.destination, a.size),
            .GPUBuffer_GPUSize64_GPUBuffer_GPUSize64_GPUSize64 => |a| return GPUCommandEncoderImpl.GPUBuffer_GPUSize64_GPUBuffer_GPUSize64_GPUSize64(state, a.source, a.sourceOffset, a.destination, a.destinationOffset, a.size),
        }
    }

    pub fn call_copyTextureToBuffer(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_copyTextureToBuffer(state, source, destination, copySize);
    }

    pub fn call_copyBufferToTexture(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_copyBufferToTexture(state, source, destination, copySize);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUCommandEncoderImpl.call_popDebugGroup(state);
    }

    pub fn call_copyTextureToTexture(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_copyTextureToTexture(state, source, destination, copySize);
    }

    pub fn call_resolveQuerySet(instance: *runtime.Instance, querySet: anyopaque, firstQuery: anyopaque, queryCount: anyopaque, destination: anyopaque, destinationOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_resolveQuerySet(state, querySet, firstQuery, queryCount, destination, destinationOffset);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_insertDebugMarker(state, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_pushDebugGroup(state, groupLabel);
    }

    pub fn call_finish(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_finish(state, descriptor);
    }

    pub fn call_beginComputePass(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_beginComputePass(state, descriptor);
    }

    pub fn call_beginRenderPass(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_beginRenderPass(state, descriptor);
    }

    pub fn call_clearBuffer(instance: *runtime.Instance, buffer: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCommandEncoderImpl.call_clearBuffer(state, buffer, offset, size);
    }

};
