//! Generated from: EXT_texture_compression_rgtc.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const EXT_texture_compression_rgtcImpl = @import("impls").EXT_texture_compression_rgtc;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;

pub const EXT_texture_compression_rgtc = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_compression_rgtc";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "COMPRESSED_RED_RGTC1_EXT", "get_COMPRESSED_RED_RGTC1_EXT" },
            .{ "COMPRESSED_SIGNED_RED_RGTC1_EXT", "get_COMPRESSED_SIGNED_RED_RGTC1_EXT" },
            .{ "COMPRESSED_RED_GREEN_RGTC2_EXT", "get_COMPRESSED_RED_GREEN_RGTC2_EXT" },
            .{ "COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT", "get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT" },
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*EXT_texture_compression_rgtcImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COMPRESSED_RED_RGTC1_EXT = 36283;
    pub fn get_COMPRESSED_RED_RGTC1_EXT() GLenum {
        return 36283;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_RED_RGTC1_EXT = 36284;
    pub fn get_COMPRESSED_SIGNED_RED_RGTC1_EXT() GLenum {
        return 36284;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RED_GREEN_RGTC2_EXT = 36285;
    pub fn get_COMPRESSED_RED_GREEN_RGTC2_EXT() GLenum {
        return 36285;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT = 36286;
    pub fn get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT() GLenum {
        return 36286;
    }

    const delegates = .{

        .get_COMPRESSED_RED_GREEN_RGTC2_EXT = &get_COMPRESSED_RED_GREEN_RGTC2_EXT,
        .get_COMPRESSED_RED_RGTC1_EXT = &get_COMPRESSED_RED_RGTC1_EXT,
        .get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT = &get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT,
        .get_COMPRESSED_SIGNED_RED_RGTC1_EXT = &get_COMPRESSED_SIGNED_RED_RGTC1_EXT,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_texture_compression_rgtcImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_compression_rgtcImpl.deinit(instance);
    }

};
