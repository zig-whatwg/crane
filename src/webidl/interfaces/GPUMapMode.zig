//! Generated from: webgpu.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUMapModeImpl = @import("impls").GPUMapMode;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;

pub const GPUMapMode = struct {
    pub const Meta = struct {
        pub const name = "GPUMapMode";
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

    /// WebIDL constant: const GPUFlagsConstant READ = 1;
    pub fn get_READ() GPUFlagsConstant {
        return 1;
    }

    /// WebIDL constant: const GPUFlagsConstant WRITE = 2;
    pub fn get_WRITE() GPUFlagsConstant {
        return 2;
    }

    pub const vtable = runtime.buildVTable(GPUMapMode, .{
        .deinit_fn = &deinit_wrapper,

        .get_READ = &get_READ,
        .get_WRITE = &get_WRITE,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return GPUMapModeImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUMapModeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
