//! Generated from: webxr.idl
//! Generated at: 2025-12-07T20:02:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const XRReferenceSpaceImpl = @import("impls").XRReferenceSpace;
const mixins = @import("mixins");
const XRSpace = @import("interfaces").XRSpace;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRReferenceSpace = struct {
    pub const Meta = struct {
        pub const name = "XRReferenceSpace";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRSpace.State;
        pub const ParentInterface = XRSpace;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onreset", "get_onreset", "set_onreset" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getOffsetReferenceSpace", "call_getOffsetReferenceSpace", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getOffsetReferenceSpace",
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
            .{ "onreset", "get_onreset", "set_onreset" },
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
            onreset: EventHandler = undefined,
            _internal: ?*XRReferenceSpaceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onreset = &get_onreset,

        .set_onreset = &set_onreset,

        .call_getOffsetReferenceSpace = &call_getOffsetReferenceSpace,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRReferenceSpaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRReferenceSpaceImpl.deinit(instance);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRReferenceSpaceImpl.get_onreset(instance);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRReferenceSpaceImpl.set_onreset(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getOffsetReferenceSpace(instance: *runtime.Instance, originOffset: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try XRReferenceSpaceImpl.call_getOffsetReferenceSpace(instance, originOffset);
    }

};
