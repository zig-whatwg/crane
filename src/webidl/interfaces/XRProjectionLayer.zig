//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRProjectionLayerImpl = @import("impls").XRProjectionLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRCompositionLayer = @import("XRCompositionLayer.zig").XRCompositionLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRRigidTransform = @import("XRRigidTransform.zig").XRRigidTransform;
const EventListener = @import("EventListener.zig").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const XRLayerQuality = @import("enums").XRLayerQuality;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("Observable.zig").Observable;

pub const XRProjectionLayer = struct {
    pub const Meta = struct {
        pub const name = "XRProjectionLayer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRCompositionLayer.State;
        pub const ParentInterface = XRCompositionLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "textureWidth", "get_textureWidth", null },
            .{ "textureHeight", "get_textureHeight", null },
            .{ "textureArrayLength", "get_textureArrayLength", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "deltaPose", "get_deltaPose", "set_deltaPose" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "destroy",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "textureWidth", "get_textureWidth", null },
            .{ "textureHeight", "get_textureHeight", null },
            .{ "textureArrayLength", "get_textureArrayLength", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "deltaPose", "get_deltaPose", "set_deltaPose" },
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
            textureWidth: u32 = undefined,
            textureHeight: u32 = undefined,
            textureArrayLength: u32 = undefined,
            ignoreDepthValues: bool = undefined,
            fixedFoveation: ?f32 = null,
            deltaPose: ?*runtime.Instance = null,
            _internal: ?*XRProjectionLayerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_deltaPose = &get_deltaPose,
        .get_fixedFoveation = &get_fixedFoveation,
        .get_ignoreDepthValues = &get_ignoreDepthValues,
        .get_textureArrayLength = &get_textureArrayLength,
        .get_textureHeight = &get_textureHeight,
        .get_textureWidth = &get_textureWidth,

        .set_deltaPose = &set_deltaPose,
        .set_fixedFoveation = &set_fixedFoveation,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRProjectionLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRProjectionLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRProjectionLayerImpl.deinit(instance);
    }

    pub fn get_textureWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureWidth(instance);
    }

    pub fn get_textureHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureHeight(instance);
    }

    pub fn get_textureArrayLength(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureArrayLength(instance);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRProjectionLayerImpl.get_ignoreDepthValues(instance);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyerror!?f32 {
        return try XRProjectionLayerImpl.get_fixedFoveation(instance);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: ?f32) anyerror!void {
        try XRProjectionLayerImpl.set_fixedFoveation(instance, value);
    }

    pub fn get_deltaPose(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try XRProjectionLayerImpl.get_deltaPose(instance);
    }

    pub fn set_deltaPose(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try XRProjectionLayerImpl.set_deltaPose(instance, value);
    }

};
