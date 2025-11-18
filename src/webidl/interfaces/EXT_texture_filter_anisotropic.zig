//! Generated from: EXT_texture_filter_anisotropic.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_filter_anisotropicImpl = @import("impls").EXT_texture_filter_anisotropic;

pub const EXT_texture_filter_anisotropic = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_filter_anisotropic";
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

    /// WebIDL constant: const GLenum TEXTURE_MAX_ANISOTROPY_EXT = 34046;
    pub fn get_TEXTURE_MAX_ANISOTROPY_EXT() GLenum {
        return 34046;
    }

    /// WebIDL constant: const GLenum MAX_TEXTURE_MAX_ANISOTROPY_EXT = 34047;
    pub fn get_MAX_TEXTURE_MAX_ANISOTROPY_EXT() GLenum {
        return 34047;
    }

    pub const vtable = runtime.buildVTable(EXT_texture_filter_anisotropic, .{
        .deinit_fn = &deinit_wrapper,

        .get_MAX_TEXTURE_MAX_ANISOTROPY_EXT = &get_MAX_TEXTURE_MAX_ANISOTROPY_EXT,
        .get_TEXTURE_MAX_ANISOTROPY_EXT = &get_TEXTURE_MAX_ANISOTROPY_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        EXT_texture_filter_anisotropicImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_filter_anisotropicImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
