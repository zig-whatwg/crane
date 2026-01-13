//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRSystemImpl = @import("impls").XRSystem;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRSessionMode = @import("enums").XRSessionMode;
const XRSession = @import("interfaces").XRSession;
const EventListener = @import("interfaces").EventListener;
const XRSessionInit = @import("dictionaries").XRSessionInit;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRSystem = struct {
    pub const Meta = struct {
        pub const name = "XRSystem";
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
            .{ "ondevicechange", "get_ondevicechange", "set_ondevicechange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "isSessionSupported", "call_isSessionSupported", 1 },
            .{ "requestSession", "call_requestSession", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isSessionSupported",
            "requestSession",
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
            .{ "ondevicechange", "get_ondevicechange", "set_ondevicechange" },
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
            ondevicechange: typedefs.EventHandler = undefined,
            _internal: ?*XRSystemImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_ondevicechange = &get_ondevicechange,

        .set_ondevicechange = &set_ondevicechange,

        .call_isSessionSupported = &call_isSessionSupported,
        .call_requestSession = &call_requestSession,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRSystemImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRSystemImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRSystemImpl.deinit(instance);
    }

    pub fn get_ondevicechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSystemImpl.get_ondevicechange(instance);
    }

    pub fn set_ondevicechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSystemImpl.set_ondevicechange(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestSession(instance: *runtime.Instance, mode: XRSessionMode, options: webidl.Opt(XRSessionInit)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try XRSystemImpl.call_requestSession(instance, mode, options);
    }

    pub fn call_isSessionSupported(instance: *runtime.Instance, mode: XRSessionMode) anyerror!runtime.JSValue {
        
        return try XRSystemImpl.call_isSessionSupported(instance, mode);
    }

};
