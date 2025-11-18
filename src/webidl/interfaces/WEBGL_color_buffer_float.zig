//! Generated from: WEBGL_color_buffer_float.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_color_buffer_floatImpl = @import("impls").WEBGL_color_buffer_float;

pub const WEBGL_color_buffer_float = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_color_buffer_float";
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

    /// WebIDL constant: const GLenum RGBA32F_EXT = 34836;
    pub fn get_RGBA32F_EXT() GLenum {
        return 34836;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT = 33297;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT() GLenum {
        return 33297;
    }

    /// WebIDL constant: const GLenum UNSIGNED_NORMALIZED_EXT = 35863;
    pub fn get_UNSIGNED_NORMALIZED_EXT() GLenum {
        return 35863;
    }

    pub const vtable = runtime.buildVTable(WEBGL_color_buffer_float, .{
        .deinit_fn = &deinit_wrapper,

        .get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT = &get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT,
        .get_RGBA32F_EXT = &get_RGBA32F_EXT,
        .get_UNSIGNED_NORMALIZED_EXT = &get_UNSIGNED_NORMALIZED_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_color_buffer_floatImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_color_buffer_floatImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
