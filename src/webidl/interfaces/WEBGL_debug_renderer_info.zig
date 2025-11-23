//! Generated from: WEBGL_debug_renderer_info.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_debug_renderer_infoImpl = @import("impls").WEBGL_debug_renderer_info;
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_debug_renderer_info = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_debug_renderer_info";
        pub const is_mixin = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "UNMASKED_VENDOR_WEBGL", "get_UNMASKED_VENDOR_WEBGL" },
            .{ "UNMASKED_RENDERER_WEBGL", "get_UNMASKED_RENDERER_WEBGL" },
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
        struct {},
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum UNMASKED_VENDOR_WEBGL = 37445;
    pub fn get_UNMASKED_VENDOR_WEBGL() GLenum {
        return 37445;
    }

    /// WebIDL constant: const GLenum UNMASKED_RENDERER_WEBGL = 37446;
    pub fn get_UNMASKED_RENDERER_WEBGL() GLenum {
        return 37446;
    }

    const delegates = .{

        .get_UNMASKED_RENDERER_WEBGL = &get_UNMASKED_RENDERER_WEBGL,
        .get_UNMASKED_VENDOR_WEBGL = &get_UNMASKED_VENDOR_WEBGL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_debug_renderer_infoImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_debug_renderer_infoImpl.deinit(instance);
    }

};
