//! Generated from: OVR_multiview2.idl
//! Generated at: 2025-11-29T05:01:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OVR_multiview2Impl = @import("impls").OVR_multiview2;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;
const GLint = @import("typedefs").GLint;
const GLsizei = @import("typedefs").GLsizei;
const WebGLTexture = @import("interfaces").WebGLTexture;

pub const OVR_multiview2 = struct {
    pub const Meta = struct {
        pub const name = "OVR_multiview2";
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
            .{ "framebufferTextureMultiviewOVR", "call_framebufferTextureMultiviewOVR", 6 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR", "get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR" },
            .{ "FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR", "get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR" },
            .{ "MAX_VIEWS_OVR", "get_MAX_VIEWS_OVR" },
            .{ "FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR", "get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "framebufferTextureMultiviewOVR",
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
            _internal: ?*OVR_multiview2Impl.InternalState = null,
        },
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

    const delegates = .{

        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR,
        .get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR = &get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR,
        .get_MAX_VIEWS_OVR = &get_MAX_VIEWS_OVR,

        .call_framebufferTextureMultiviewOVR = &call_framebufferTextureMultiviewOVR,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OVR_multiview2Impl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OVR_multiview2Impl.deinit(instance);
    }

    pub fn call_framebufferTextureMultiviewOVR(instance: *runtime.Instance, target: GLenum, attachment: GLenum, texture: ?*runtime.Instance, level: GLint, baseViewIndex: GLint, numViews: GLsizei) anyerror!void {
        
        return try OVR_multiview2Impl.call_framebufferTextureMultiviewOVR(instance, target, attachment, texture, level, baseViewIndex, numViews);
    }

};
