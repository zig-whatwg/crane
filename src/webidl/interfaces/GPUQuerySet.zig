//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUQuerySetImpl = @import("impls").GPUQuerySet;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUQueryType = @import("enums").GPUQueryType;
const GPUSize32Out = @import("typedefs").GPUSize32Out;

pub const GPUQuerySet = struct {
    pub const Meta = struct {
        pub const name = "GPUQuerySet";
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
            type: GPUQueryType = undefined,
            count: GPUSize32Out = undefined,
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUQuerySet, .{
        .deinit_fn = &deinit_wrapper,

        .get_count = &get_count,
        .get_label = &get_label,
        .get_type = &get_type,

        .set_label = &set_label,

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
        GPUQuerySetImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUQuerySetImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GPUQueryType {
        return try GPUQuerySetImpl.get_type(instance);
    }

    pub fn get_count(instance: *runtime.Instance) anyerror!GPUSize32Out {
        return try GPUQuerySetImpl.get_count(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUQuerySetImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUQuerySetImpl.set_label(instance, value);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUQuerySetImpl.call_destroy(instance);
    }

};
