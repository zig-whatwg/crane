//! Generated from: WEBGL_compressed_texture_s3tc_srgb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_compressed_texture_s3tc_srgbImpl = @import("impls").WEBGL_compressed_texture_s3tc_srgb;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_compressed_texture_s3tc_srgb = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_s3tc_srgb";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*WEBGL_compressed_texture_s3tc_srgbImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_S3TC_DXT1_EXT = 35916;
    pub fn get_COMPRESSED_SRGB_S3TC_DXT1_EXT() GLenum {
        return 35916;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT = 35917;
    pub fn get_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT() GLenum {
        return 35917;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT = 35918;
    pub fn get_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT() GLenum {
        return 35918;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT = 35919;
    pub fn get_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT() GLenum {
        return 35919;
    }

    const delegates = .{

        .get_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT = &get_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT,
        .get_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT = &get_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,
        .get_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT = &get_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT,
        .get_COMPRESSED_SRGB_S3TC_DXT1_EXT = &get_COMPRESSED_SRGB_S3TC_DXT1_EXT,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_compressed_texture_s3tc_srgbImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WEBGL_compressed_texture_s3tc_srgbImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_s3tc_srgbImpl.deinit(instance);
    }

};
