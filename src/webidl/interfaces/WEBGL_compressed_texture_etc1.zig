//! Generated from: WEBGL_compressed_texture_etc1.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_etc1Impl = @import("impls").WEBGL_compressed_texture_etc1;
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_compressed_texture_etc1 = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_etc1";
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
            .{ "COMPRESSED_RGB_ETC1_WEBGL", "get_COMPRESSED_RGB_ETC1_WEBGL" },
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
            _internal: ?*WEBGL_compressed_texture_etc1Impl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COMPRESSED_RGB_ETC1_WEBGL = 36196;
    pub fn get_COMPRESSED_RGB_ETC1_WEBGL() GLenum {
        return 36196;
    }

    const delegates = .{

        .get_COMPRESSED_RGB_ETC1_WEBGL = &get_COMPRESSED_RGB_ETC1_WEBGL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_compressed_texture_etc1Impl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_etc1Impl.deinit(instance);
    }

};
