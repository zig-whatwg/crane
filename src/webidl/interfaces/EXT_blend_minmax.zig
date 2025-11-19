//! Generated from: EXT_blend_minmax.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_blend_minmaxImpl = @import("impls").EXT_blend_minmax;
const GLenum = @import("typedefs").GLenum;

pub const EXT_blend_minmax = struct {
    pub const Meta = struct {
        pub const name = "EXT_blend_minmax";
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

    /// WebIDL constant: const GLenum MIN_EXT = 32775;
    pub fn get_MIN_EXT() GLenum {
        return 32775;
    }

    /// WebIDL constant: const GLenum MAX_EXT = 32776;
    pub fn get_MAX_EXT() GLenum {
        return 32776;
    }

    pub const vtable = runtime.buildVTable(EXT_blend_minmax, .{
        .deinit_fn = &deinit_wrapper,

        .get_MAX_EXT = &get_MAX_EXT,
        .get_MIN_EXT = &get_MIN_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return EXT_blend_minmaxImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_blend_minmaxImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
