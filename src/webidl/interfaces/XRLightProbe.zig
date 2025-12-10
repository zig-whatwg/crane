//! Generated from: webxr-lighting-estimation.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRLightProbeImpl = @import("impls").XRLightProbe;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRSpace = @import("interfaces").XRSpace;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRLightProbe = struct {
    pub const Meta = struct {
        pub const name = "XRLightProbe";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "probeSpace", "get_probeSpace", null },
            .{ "onreflectionchange", "get_onreflectionchange", "set_onreflectionchange" },
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "probeSpace", "get_probeSpace", null },
            .{ "onreflectionchange", "get_onreflectionchange", "set_onreflectionchange" },
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
            probeSpace: *runtime.Instance = undefined,
            onreflectionchange: EventHandler = undefined,
            _internal: ?*XRLightProbeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onreflectionchange = &get_onreflectionchange,
        .get_probeSpace = &get_probeSpace,

        .set_onreflectionchange = &set_onreflectionchange,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRLightProbeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRLightProbeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRLightProbeImpl.deinit(instance);
    }

    pub fn get_probeSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRLightProbeImpl.get_probeSpace(instance);
    }

    pub fn get_onreflectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRLightProbeImpl.get_onreflectionchange(instance);
    }

    pub fn set_onreflectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRLightProbeImpl.set_onreflectionchange(instance, value);
    }

};
