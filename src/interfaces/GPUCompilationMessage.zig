//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCompilationMessageImpl = @import("../impls/GPUCompilationMessage.zig");

pub const GPUCompilationMessage = struct {
    pub const Meta = struct {
        pub const name = "GPUCompilationMessage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
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
            message: runtime.DOMString = undefined,
            type: GPUCompilationMessageType = undefined,
            lineNum: u64 = undefined,
            linePos: u64 = undefined,
            offset: u64 = undefined,
            length: u64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUCompilationMessage, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_lineNum = &get_lineNum,
        .get_linePos = &get_linePos,
        .get_message = &get_message,
        .get_offset = &get_offset,
        .get_type = &get_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUCompilationMessageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUCompilationMessageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_message(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GPUCompilationMessageImpl.get_message(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUCompilationMessageImpl.get_type(state);
    }

    pub fn get_lineNum(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUCompilationMessageImpl.get_lineNum(state);
    }

    pub fn get_linePos(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUCompilationMessageImpl.get_linePos(state);
    }

    pub fn get_offset(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUCompilationMessageImpl.get_offset(state);
    }

    pub fn get_length(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUCompilationMessageImpl.get_length(state);
    }

};
