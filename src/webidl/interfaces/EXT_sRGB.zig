//! Generated from: EXT_sRGB.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_sRGBImpl = @import("impls").EXT_sRGB;

pub const EXT_sRGB = struct {
    pub const Meta = struct {
        pub const name = "EXT_sRGB";
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

    /// WebIDL constant: const GLenum SRGB_EXT = 35904;
    pub fn get_SRGB_EXT() GLenum {
        return 35904;
    }

    /// WebIDL constant: const GLenum SRGB_ALPHA_EXT = 35906;
    pub fn get_SRGB_ALPHA_EXT() GLenum {
        return 35906;
    }

    /// WebIDL constant: const GLenum SRGB8_ALPHA8_EXT = 35907;
    pub fn get_SRGB8_ALPHA8_EXT() GLenum {
        return 35907;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT = 33296;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT() GLenum {
        return 33296;
    }

    pub const vtable = runtime.buildVTable(EXT_sRGB, .{
        .deinit_fn = &deinit_wrapper,

        .get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT = &get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT,
        .get_SRGB8_ALPHA8_EXT = &get_SRGB8_ALPHA8_EXT,
        .get_SRGB_ALPHA_EXT = &get_SRGB_ALPHA_EXT,
        .get_SRGB_EXT = &get_SRGB_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        EXT_sRGBImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_sRGBImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
