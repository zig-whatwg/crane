//! Generated from: webxr-depth-sensing.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLDepthInformationImpl = @import("impls").XRWebGLDepthInformation;
const XRDepthInformation = @import("interfaces").XRDepthInformation;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRTextureType = @import("enums").XRTextureType;
const WebGLTexture = @import("interfaces").WebGLTexture;

pub const XRWebGLDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLDepthInformation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRDepthInformation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "texture", "get_texture", null },
            .{ "textureType", "get_textureType", null },
            .{ "imageIndex", "get_imageIndex", null },
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
            .{ "texture", "get_texture", null },
            .{ "textureType", "get_textureType", null },
            .{ "imageIndex", "get_imageIndex", null },
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
            texture: *runtime.Instance = undefined,
            textureType: XRTextureType = undefined,
            imageIndex: ?u32 = null,
            cached_texture: ?*runtime.Instance = null,
            _internal: ?*XRWebGLDepthInformationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_imageIndex = &get_imageIndex,
        .get_texture = &get_texture,
        .get_textureType = &get_textureType,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRWebGLDepthInformationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLDepthInformationImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_texture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_texture) |cached| {
            return cached;
        }
        const value = try XRWebGLDepthInformationImpl.get_texture(instance);
        state.own.cached_texture = value;
        return value;
    }

    pub fn get_textureType(instance: *runtime.Instance) anyerror!XRTextureType {
        return try XRWebGLDepthInformationImpl.get_textureType(instance);
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLDepthInformationImpl.get_imageIndex(instance);
    }

};
