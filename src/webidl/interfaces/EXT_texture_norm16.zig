//! Generated from: EXT_texture_norm16.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_norm16Impl = @import("impls").EXT_texture_norm16;

pub const EXT_texture_norm16 = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_norm16";
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

    /// WebIDL constant: const GLenum R16_EXT = 33322;
    pub fn get_R16_EXT() GLenum {
        return 33322;
    }

    /// WebIDL constant: const GLenum RG16_EXT = 33324;
    pub fn get_RG16_EXT() GLenum {
        return 33324;
    }

    /// WebIDL constant: const GLenum RGB16_EXT = 32852;
    pub fn get_RGB16_EXT() GLenum {
        return 32852;
    }

    /// WebIDL constant: const GLenum RGBA16_EXT = 32859;
    pub fn get_RGBA16_EXT() GLenum {
        return 32859;
    }

    /// WebIDL constant: const GLenum R16_SNORM_EXT = 36760;
    pub fn get_R16_SNORM_EXT() GLenum {
        return 36760;
    }

    /// WebIDL constant: const GLenum RG16_SNORM_EXT = 36761;
    pub fn get_RG16_SNORM_EXT() GLenum {
        return 36761;
    }

    /// WebIDL constant: const GLenum RGB16_SNORM_EXT = 36762;
    pub fn get_RGB16_SNORM_EXT() GLenum {
        return 36762;
    }

    /// WebIDL constant: const GLenum RGBA16_SNORM_EXT = 36763;
    pub fn get_RGBA16_SNORM_EXT() GLenum {
        return 36763;
    }

    pub const vtable = runtime.buildVTable(EXT_texture_norm16, .{
        .deinit_fn = &deinit_wrapper,

        .get_R16_EXT = &get_R16_EXT,
        .get_R16_SNORM_EXT = &get_R16_SNORM_EXT,
        .get_RG16_EXT = &get_RG16_EXT,
        .get_RG16_SNORM_EXT = &get_RG16_SNORM_EXT,
        .get_RGB16_EXT = &get_RGB16_EXT,
        .get_RGB16_SNORM_EXT = &get_RGB16_SNORM_EXT,
        .get_RGBA16_EXT = &get_RGBA16_EXT,
        .get_RGBA16_SNORM_EXT = &get_RGBA16_SNORM_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        EXT_texture_norm16Impl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_norm16Impl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
