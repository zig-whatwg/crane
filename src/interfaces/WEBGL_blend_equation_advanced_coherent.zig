//! Generated from: WEBGL_blend_equation_advanced_coherent.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_blend_equation_advanced_coherentImpl = @import("../impls/WEBGL_blend_equation_advanced_coherent.zig");

pub const WEBGL_blend_equation_advanced_coherent = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_blend_equation_advanced_coherent";
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

    pub const vtable = runtime.buildVTable(WEBGL_blend_equation_advanced_coherent, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_blend_equation_advanced_coherentImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_blend_equation_advanced_coherentImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
