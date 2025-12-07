//! Generated from: WEBGL_clip_cull_distance.idl
//! Generated at: 2025-12-07T19:32:58Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const WEBGL_clip_cull_distanceImpl = @import("impls").WEBGL_clip_cull_distance;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_clip_cull_distance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_clip_cull_distance";
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
            .{ "MAX_CLIP_DISTANCES_WEBGL", "get_MAX_CLIP_DISTANCES_WEBGL" },
            .{ "MAX_CULL_DISTANCES_WEBGL", "get_MAX_CULL_DISTANCES_WEBGL" },
            .{ "MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL", "get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL" },
            .{ "CLIP_DISTANCE0_WEBGL", "get_CLIP_DISTANCE0_WEBGL" },
            .{ "CLIP_DISTANCE1_WEBGL", "get_CLIP_DISTANCE1_WEBGL" },
            .{ "CLIP_DISTANCE2_WEBGL", "get_CLIP_DISTANCE2_WEBGL" },
            .{ "CLIP_DISTANCE3_WEBGL", "get_CLIP_DISTANCE3_WEBGL" },
            .{ "CLIP_DISTANCE4_WEBGL", "get_CLIP_DISTANCE4_WEBGL" },
            .{ "CLIP_DISTANCE5_WEBGL", "get_CLIP_DISTANCE5_WEBGL" },
            .{ "CLIP_DISTANCE6_WEBGL", "get_CLIP_DISTANCE6_WEBGL" },
            .{ "CLIP_DISTANCE7_WEBGL", "get_CLIP_DISTANCE7_WEBGL" },
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
            _internal: ?*WEBGL_clip_cull_distanceImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum MAX_CLIP_DISTANCES_WEBGL = 3378;
    pub fn get_MAX_CLIP_DISTANCES_WEBGL() GLenum {
        return 3378;
    }

    /// WebIDL constant: const GLenum MAX_CULL_DISTANCES_WEBGL = 33529;
    pub fn get_MAX_CULL_DISTANCES_WEBGL() GLenum {
        return 33529;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL = 33530;
    pub fn get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL() GLenum {
        return 33530;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE0_WEBGL = 12288;
    pub fn get_CLIP_DISTANCE0_WEBGL() GLenum {
        return 12288;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE1_WEBGL = 12289;
    pub fn get_CLIP_DISTANCE1_WEBGL() GLenum {
        return 12289;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE2_WEBGL = 12290;
    pub fn get_CLIP_DISTANCE2_WEBGL() GLenum {
        return 12290;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE3_WEBGL = 12291;
    pub fn get_CLIP_DISTANCE3_WEBGL() GLenum {
        return 12291;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE4_WEBGL = 12292;
    pub fn get_CLIP_DISTANCE4_WEBGL() GLenum {
        return 12292;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE5_WEBGL = 12293;
    pub fn get_CLIP_DISTANCE5_WEBGL() GLenum {
        return 12293;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE6_WEBGL = 12294;
    pub fn get_CLIP_DISTANCE6_WEBGL() GLenum {
        return 12294;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE7_WEBGL = 12295;
    pub fn get_CLIP_DISTANCE7_WEBGL() GLenum {
        return 12295;
    }

    const delegates = .{

        .get_CLIP_DISTANCE0_WEBGL = &get_CLIP_DISTANCE0_WEBGL,
        .get_CLIP_DISTANCE1_WEBGL = &get_CLIP_DISTANCE1_WEBGL,
        .get_CLIP_DISTANCE2_WEBGL = &get_CLIP_DISTANCE2_WEBGL,
        .get_CLIP_DISTANCE3_WEBGL = &get_CLIP_DISTANCE3_WEBGL,
        .get_CLIP_DISTANCE4_WEBGL = &get_CLIP_DISTANCE4_WEBGL,
        .get_CLIP_DISTANCE5_WEBGL = &get_CLIP_DISTANCE5_WEBGL,
        .get_CLIP_DISTANCE6_WEBGL = &get_CLIP_DISTANCE6_WEBGL,
        .get_CLIP_DISTANCE7_WEBGL = &get_CLIP_DISTANCE7_WEBGL,
        .get_MAX_CLIP_DISTANCES_WEBGL = &get_MAX_CLIP_DISTANCES_WEBGL,
        .get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL = &get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL,
        .get_MAX_CULL_DISTANCES_WEBGL = &get_MAX_CULL_DISTANCES_WEBGL,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_clip_cull_distanceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_clip_cull_distanceImpl.deinit(instance);
    }

};
