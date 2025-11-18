//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUBufferUsageImpl = @import("../impls/GPUBufferUsage.zig");

pub const GPUBufferUsage = struct {
    pub const Meta = struct {
        pub const name = "GPUBufferUsage";
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

    /// WebIDL constant: const GPUFlagsConstant MAP_READ = 1;
    pub fn get_MAP_READ() GPUFlagsConstant {
        return 1;
    }

    /// WebIDL constant: const GPUFlagsConstant MAP_WRITE = 2;
    pub fn get_MAP_WRITE() GPUFlagsConstant {
        return 2;
    }

    /// WebIDL constant: const GPUFlagsConstant COPY_SRC = 4;
    pub fn get_COPY_SRC() GPUFlagsConstant {
        return 4;
    }

    /// WebIDL constant: const GPUFlagsConstant COPY_DST = 8;
    pub fn get_COPY_DST() GPUFlagsConstant {
        return 8;
    }

    /// WebIDL constant: const GPUFlagsConstant INDEX = 16;
    pub fn get_INDEX() GPUFlagsConstant {
        return 16;
    }

    /// WebIDL constant: const GPUFlagsConstant VERTEX = 32;
    pub fn get_VERTEX() GPUFlagsConstant {
        return 32;
    }

    /// WebIDL constant: const GPUFlagsConstant UNIFORM = 64;
    pub fn get_UNIFORM() GPUFlagsConstant {
        return 64;
    }

    /// WebIDL constant: const GPUFlagsConstant STORAGE = 128;
    pub fn get_STORAGE() GPUFlagsConstant {
        return 128;
    }

    /// WebIDL constant: const GPUFlagsConstant INDIRECT = 256;
    pub fn get_INDIRECT() GPUFlagsConstant {
        return 256;
    }

    /// WebIDL constant: const GPUFlagsConstant QUERY_RESOLVE = 512;
    pub fn get_QUERY_RESOLVE() GPUFlagsConstant {
        return 512;
    }

    pub const vtable = runtime.buildVTable(GPUBufferUsage, .{
        .deinit_fn = &deinit_wrapper,

        .get_COPY_DST = &get_COPY_DST,
        .get_COPY_SRC = &get_COPY_SRC,
        .get_INDEX = &get_INDEX,
        .get_INDIRECT = &get_INDIRECT,
        .get_MAP_READ = &get_MAP_READ,
        .get_MAP_WRITE = &get_MAP_WRITE,
        .get_QUERY_RESOLVE = &get_QUERY_RESOLVE,
        .get_STORAGE = &get_STORAGE,
        .get_UNIFORM = &get_UNIFORM,
        .get_VERTEX = &get_VERTEX,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUBufferUsageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUBufferUsageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
