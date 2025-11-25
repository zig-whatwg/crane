//! Generated from: webxr.idl
//! Generated at: 2025-11-25T19:42:23Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRBoundedReferenceSpaceImpl = @import("impls").XRBoundedReferenceSpace;
const XRReferenceSpace = @import("interfaces").XRReferenceSpace;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRBoundedReferenceSpace = struct {
    pub const Meta = struct {
        pub const name = "XRBoundedReferenceSpace";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRReferenceSpace;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "boundsGeometry", "get_boundsGeometry", null },
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
            "getOffsetReferenceSpace",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "boundsGeometry", "get_boundsGeometry", null },
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
            boundsGeometry: runtime.FrozenArray(DOMPointReadOnly) = undefined,
            _internal: ?*XRBoundedReferenceSpaceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_boundsGeometry = &get_boundsGeometry,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRBoundedReferenceSpaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRBoundedReferenceSpaceImpl.deinit(instance);
    }

    pub fn get_boundsGeometry(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRBoundedReferenceSpaceImpl.get_boundsGeometry(instance);
    }

};
