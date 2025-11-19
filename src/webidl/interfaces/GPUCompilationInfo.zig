//! Generated from: webgpu.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCompilationInfoImpl = @import("impls").GPUCompilationInfo;
const GPUCompilationMessage = @import("interfaces").GPUCompilationMessage;

pub const GPUCompilationInfo = struct {
    pub const Meta = struct {
        pub const name = "GPUCompilationInfo";
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
            messages: runtime.FrozenArray(GPUCompilationMessage) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUCompilationInfo, .{
        .deinit_fn = &deinit_wrapper,

        .get_messages = &get_messages,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return GPUCompilationInfoImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCompilationInfoImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_messages(instance: *runtime.Instance) anyerror!anyopaque {
        return try GPUCompilationInfoImpl.get_messages(instance);
    }

};
