//! Generated from: OVR_multiview2.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OVR_multiview2Impl = @import("../impls/OVR_multiview2.zig");

pub const OVR_multiview2 = struct {
    pub const Meta = struct {
        pub const name = "OVR_multiview2";
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

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR = 38448;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR() GLenum {
        return 38448;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR = 38450;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR() GLenum {
        return 38450;
    }

    /// WebIDL constant: const GLenum MAX_VIEWS_OVR = 38449;
    pub fn get_MAX_VIEWS_OVR() GLenum {
        return 38449;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR = 38451;
    pub fn get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR() GLenum {
        return 38451;
    }

    pub const vtable = runtime.buildVTable(OVR_multiview2, .{
        .deinit_fn = &deinit_wrapper,

        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR,
        .get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR = &get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR,
        .get_MAX_VIEWS_OVR = &get_MAX_VIEWS_OVR,

        .call_framebufferTextureMultiviewOVR = &call_framebufferTextureMultiviewOVR,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        OVR_multiview2Impl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        OVR_multiview2Impl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_framebufferTextureMultiviewOVR(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, texture: anyopaque, level: anyopaque, baseViewIndex: anyopaque, numViews: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OVR_multiview2Impl.call_framebufferTextureMultiviewOVR(state, target, attachment, texture, level, baseViewIndex, numViews);
    }

};
