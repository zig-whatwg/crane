//! Generated from: KHR_parallel_shader_compile.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KHR_parallel_shader_compileImpl = @import("impls").KHR_parallel_shader_compile;
const GLenum = @import("typedefs").GLenum;

pub const KHR_parallel_shader_compile = struct {
    pub const Meta = struct {
        pub const name = "KHR_parallel_shader_compile";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
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

    /// WebIDL constant: const GLenum COMPLETION_STATUS_KHR = 37297;
    pub fn get_COMPLETION_STATUS_KHR() GLenum {
        return 37297;
    }

    pub const vtable = runtime.buildVTable(KHR_parallel_shader_compile, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPLETION_STATUS_KHR = &get_COMPLETION_STATUS_KHR,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return KHR_parallel_shader_compileImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KHR_parallel_shader_compileImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
