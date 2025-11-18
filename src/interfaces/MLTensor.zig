//! Generated from: webnn.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLTensorImpl = @import("../impls/MLTensor.zig");

pub const MLTensor = struct {
    pub const Meta = struct {
        pub const name = "MLTensor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            dataType: MLOperandDataType = undefined,
            shape: FrozenArray<unsignedlong> = undefined,
            readable: bool = undefined,
            writable: bool = undefined,
            constant: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MLTensor, .{
        .deinit_fn = &deinit_wrapper,

        .get_constant = &get_constant,
        .get_dataType = &get_dataType,
        .get_readable = &get_readable,
        .get_shape = &get_shape,
        .get_writable = &get_writable,

        .call_destroy = &call_destroy,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MLTensorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MLTensorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_dataType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MLTensorImpl.get_dataType(state);
    }

    pub fn get_shape(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MLTensorImpl.get_shape(state);
    }

    pub fn get_readable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MLTensorImpl.get_readable(state);
    }

    pub fn get_writable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MLTensorImpl.get_writable(state);
    }

    pub fn get_constant(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MLTensorImpl.get_constant(state);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MLTensorImpl.call_destroy(state);
    }

};
