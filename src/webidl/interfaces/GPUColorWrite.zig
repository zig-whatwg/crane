//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUColorWriteImpl = @import("impls").GPUColorWrite;

pub const GPUColorWrite = struct {
    pub const Meta = struct {
        pub const name = "GPUColorWrite";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GPUFlagsConstant RED = 1;
    pub fn get_RED() GPUFlagsConstant {
        return 1;
    }

    /// WebIDL constant: const GPUFlagsConstant GREEN = 2;
    pub fn get_GREEN() GPUFlagsConstant {
        return 2;
    }

    /// WebIDL constant: const GPUFlagsConstant BLUE = 4;
    pub fn get_BLUE() GPUFlagsConstant {
        return 4;
    }

    /// WebIDL constant: const GPUFlagsConstant ALPHA = 8;
    pub fn get_ALPHA() GPUFlagsConstant {
        return 8;
    }

    /// WebIDL constant: const GPUFlagsConstant ALL = 15;
    pub fn get_ALL() GPUFlagsConstant {
        return 15;
    }

    pub const vtable = runtime.buildVTable(GPUColorWrite, .{
        .deinit_fn = &deinit_wrapper,

        .get_ALL = &get_ALL,
        .get_ALPHA = &get_ALPHA,
        .get_BLUE = &get_BLUE,
        .get_GREEN = &get_GREEN,
        .get_RED = &get_RED,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUColorWriteImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUColorWriteImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
