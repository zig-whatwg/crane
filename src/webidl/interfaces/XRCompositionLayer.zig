//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRCompositionLayerImpl = @import("impls").XRCompositionLayer;
const mixins = @import("mixins");
const XRLayer = @import("interfaces").XRLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const XRLayerQuality = @import("enums").XRLayerQuality;
const Observable = @import("interfaces").Observable;

pub const XRCompositionLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCompositionLayer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRLayer.State;
        pub const ParentInterface = XRLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "layout", "get_layout", null },
            .{ "blendTextureSourceAlpha", "get_blendTextureSourceAlpha", "set_blendTextureSourceAlpha" },
            .{ "forceMonoPresentation", "get_forceMonoPresentation", "set_forceMonoPresentation" },
            .{ "opacity", "get_opacity", "set_opacity" },
            .{ "mipLevels", "get_mipLevels", null },
            .{ "quality", "get_quality", "set_quality" },
            .{ "needsRedraw", "get_needsRedraw", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "layout", "get_layout", null },
            .{ "blendTextureSourceAlpha", "get_blendTextureSourceAlpha", "set_blendTextureSourceAlpha" },
            .{ "forceMonoPresentation", "get_forceMonoPresentation", "set_forceMonoPresentation" },
            .{ "opacity", "get_opacity", "set_opacity" },
            .{ "mipLevels", "get_mipLevels", null },
            .{ "quality", "get_quality", "set_quality" },
            .{ "needsRedraw", "get_needsRedraw", null },
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
            layout: XRLayerLayout = undefined,
            blendTextureSourceAlpha: bool = undefined,
            forceMonoPresentation: bool = undefined,
            opacity: f32 = undefined,
            mipLevels: u32 = undefined,
            quality: XRLayerQuality = undefined,
            needsRedraw: bool = undefined,
            _internal: ?*XRCompositionLayerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_blendTextureSourceAlpha = &get_blendTextureSourceAlpha,
        .get_forceMonoPresentation = &get_forceMonoPresentation,
        .get_layout = &get_layout,
        .get_mipLevels = &get_mipLevels,
        .get_needsRedraw = &get_needsRedraw,
        .get_opacity = &get_opacity,
        .get_quality = &get_quality,

        .set_blendTextureSourceAlpha = &set_blendTextureSourceAlpha,
        .set_forceMonoPresentation = &set_forceMonoPresentation,
        .set_opacity = &set_opacity,
        .set_quality = &set_quality,

        .call_destroy = &call_destroy,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRCompositionLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRCompositionLayerImpl.deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyerror!XRLayerLayout {
        return try XRCompositionLayerImpl.get_layout(instance);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) anyerror!bool {
        return try XRCompositionLayerImpl.get_blendTextureSourceAlpha(instance);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRCompositionLayerImpl.set_blendTextureSourceAlpha(instance, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) anyerror!bool {
        return try XRCompositionLayerImpl.get_forceMonoPresentation(instance);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRCompositionLayerImpl.set_forceMonoPresentation(instance, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) anyerror!f32 {
        return try XRCompositionLayerImpl.get_opacity(instance);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCompositionLayerImpl.set_opacity(instance, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) anyerror!u32 {
        return try XRCompositionLayerImpl.get_mipLevels(instance);
    }

    pub fn get_quality(instance: *runtime.Instance) anyerror!XRLayerQuality {
        return try XRCompositionLayerImpl.get_quality(instance);
    }

    pub fn set_quality(instance: *runtime.Instance, value: XRLayerQuality) anyerror!void {
        try XRCompositionLayerImpl.set_quality(instance, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) anyerror!bool {
        return try XRCompositionLayerImpl.get_needsRedraw(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try XRCompositionLayerImpl.call_destroy(instance);
    }

};
