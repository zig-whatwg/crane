//! Generated from: webnn.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLTensorImpl = @import("impls").MLTensor;
const FrozenArray<unsignedlong> = @import("interfaces").FrozenArray<unsignedlong>;
const MLOperandDataType = @import("enums").MLOperandDataType;

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
        
        // Initialize the instance (Impl receives full instance)
        MLTensorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLTensorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_dataType(instance: *runtime.Instance) anyerror!MLOperandDataType {
        return try MLTensorImpl.get_dataType(instance);
    }

    pub fn get_shape(instance: *runtime.Instance) anyerror!anyopaque {
        return try MLTensorImpl.get_shape(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_writable(instance);
    }

    pub fn get_constant(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_constant(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try MLTensorImpl.call_destroy(instance);
    }

};
