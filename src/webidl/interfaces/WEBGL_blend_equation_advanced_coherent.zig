//! Generated from: WEBGL_blend_equation_advanced_coherent.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_blend_equation_advanced_coherentImpl = @import("impls").WEBGL_blend_equation_advanced_coherent;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_blend_equation_advanced_coherent = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_blend_equation_advanced_coherent";
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
            .{ "MULTIPLY", "get_MULTIPLY" },
            .{ "SCREEN", "get_SCREEN" },
            .{ "OVERLAY", "get_OVERLAY" },
            .{ "DARKEN", "get_DARKEN" },
            .{ "LIGHTEN", "get_LIGHTEN" },
            .{ "COLORDODGE", "get_COLORDODGE" },
            .{ "COLORBURN", "get_COLORBURN" },
            .{ "HARDLIGHT", "get_HARDLIGHT" },
            .{ "SOFTLIGHT", "get_SOFTLIGHT" },
            .{ "DIFFERENCE", "get_DIFFERENCE" },
            .{ "EXCLUSION", "get_EXCLUSION" },
            .{ "HSL_HUE", "get_HSL_HUE" },
            .{ "HSL_SATURATION", "get_HSL_SATURATION" },
            .{ "HSL_COLOR", "get_HSL_COLOR" },
            .{ "HSL_LUMINOSITY", "get_HSL_LUMINOSITY" },
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
            _internal: ?*WEBGL_blend_equation_advanced_coherentImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum MULTIPLY = 37524;
    pub fn get_MULTIPLY() GLenum {
        return 37524;
    }

    /// WebIDL constant: const GLenum SCREEN = 37525;
    pub fn get_SCREEN() GLenum {
        return 37525;
    }

    /// WebIDL constant: const GLenum OVERLAY = 37526;
    pub fn get_OVERLAY() GLenum {
        return 37526;
    }

    /// WebIDL constant: const GLenum DARKEN = 37527;
    pub fn get_DARKEN() GLenum {
        return 37527;
    }

    /// WebIDL constant: const GLenum LIGHTEN = 37528;
    pub fn get_LIGHTEN() GLenum {
        return 37528;
    }

    /// WebIDL constant: const GLenum COLORDODGE = 37529;
    pub fn get_COLORDODGE() GLenum {
        return 37529;
    }

    /// WebIDL constant: const GLenum COLORBURN = 37530;
    pub fn get_COLORBURN() GLenum {
        return 37530;
    }

    /// WebIDL constant: const GLenum HARDLIGHT = 37531;
    pub fn get_HARDLIGHT() GLenum {
        return 37531;
    }

    /// WebIDL constant: const GLenum SOFTLIGHT = 37532;
    pub fn get_SOFTLIGHT() GLenum {
        return 37532;
    }

    /// WebIDL constant: const GLenum DIFFERENCE = 37534;
    pub fn get_DIFFERENCE() GLenum {
        return 37534;
    }

    /// WebIDL constant: const GLenum EXCLUSION = 37536;
    pub fn get_EXCLUSION() GLenum {
        return 37536;
    }

    /// WebIDL constant: const GLenum HSL_HUE = 37549;
    pub fn get_HSL_HUE() GLenum {
        return 37549;
    }

    /// WebIDL constant: const GLenum HSL_SATURATION = 37550;
    pub fn get_HSL_SATURATION() GLenum {
        return 37550;
    }

    /// WebIDL constant: const GLenum HSL_COLOR = 37551;
    pub fn get_HSL_COLOR() GLenum {
        return 37551;
    }

    /// WebIDL constant: const GLenum HSL_LUMINOSITY = 37552;
    pub fn get_HSL_LUMINOSITY() GLenum {
        return 37552;
    }

    const delegates = .{

        .get_COLORBURN = &get_COLORBURN,
        .get_COLORDODGE = &get_COLORDODGE,
        .get_DARKEN = &get_DARKEN,
        .get_DIFFERENCE = &get_DIFFERENCE,
        .get_EXCLUSION = &get_EXCLUSION,
        .get_HARDLIGHT = &get_HARDLIGHT,
        .get_HSL_COLOR = &get_HSL_COLOR,
        .get_HSL_HUE = &get_HSL_HUE,
        .get_HSL_LUMINOSITY = &get_HSL_LUMINOSITY,
        .get_HSL_SATURATION = &get_HSL_SATURATION,
        .get_LIGHTEN = &get_LIGHTEN,
        .get_MULTIPLY = &get_MULTIPLY,
        .get_OVERLAY = &get_OVERLAY,
        .get_SCREEN = &get_SCREEN,
        .get_SOFTLIGHT = &get_SOFTLIGHT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_blend_equation_advanced_coherentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_blend_equation_advanced_coherentImpl.deinit(instance);
    }

};
