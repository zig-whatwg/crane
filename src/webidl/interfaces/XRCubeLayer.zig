//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRCubeLayerImpl = @import("impls").XRCubeLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XRLayerQuality = @import("enums").XRLayerQuality;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRSpace = @import("interfaces").XRSpace;
const EventListener = @import("interfaces").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const XRCubeLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCubeLayer";
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
            .{ "space", "get_space", "set_space" },
            .{ "orientation", "get_orientation", "set_orientation" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
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
            .{ "space", "get_space", "set_space" },
            .{ "orientation", "get_orientation", "set_orientation" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
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
            space: *runtime.Instance = undefined,
            orientation: *runtime.Instance = undefined,
            onredraw: typedefs.EventHandler = undefined,
            _internal: ?*XRCubeLayerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onredraw = &get_onredraw,
        .get_orientation = &get_orientation,
        .get_space = &get_space,

        .set_onredraw = &set_onredraw,
        .set_orientation = &set_orientation,
        .set_space = &set_space,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRCubeLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRCubeLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRCubeLayerImpl.deinit(instance);
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRCubeLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRCubeLayerImpl.set_space(instance, value);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRCubeLayerImpl.get_orientation(instance);
    }

    pub fn set_orientation(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRCubeLayerImpl.set_orientation(instance, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRCubeLayerImpl.get_onredraw(instance);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRCubeLayerImpl.set_onredraw(instance, value);
    }

};
