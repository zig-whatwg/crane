//! Generated from: webxr.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRReferenceSpaceEventImpl = @import("impls").XRReferenceSpaceEvent;
const Event = @import("interfaces").Event;
const XRReferenceSpace = @import("interfaces").XRReferenceSpace;
const EventTarget = @import("interfaces").EventTarget;
const XRReferenceSpaceEventInit = @import("dictionaries").XRReferenceSpaceEventInit;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const XRReferenceSpaceEvent = struct {
    pub const Meta = struct {
        pub const name = "XRReferenceSpaceEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "referenceSpace", "get_referenceSpace", null },
            .{ "transform", "get_transform", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "referenceSpace", "get_referenceSpace", null },
            .{ "transform", "get_transform", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            referenceSpace: *runtime.Instance = undefined,
            transform: ?*runtime.Instance = null,
            cached_referenceSpace: ?*runtime.Instance = null,
            cached_transform: ?*runtime.Instance = null,
            _internal: ?*XRReferenceSpaceEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_referenceSpace = &get_referenceSpace,
        .get_transform = &get_transform,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRReferenceSpaceEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRReferenceSpaceEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: XRReferenceSpaceEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRReferenceSpaceEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_referenceSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_referenceSpace) |cached| {
            return cached;
        }
        const value = try XRReferenceSpaceEventImpl.get_referenceSpace(instance);
        state.own.cached_referenceSpace = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try XRReferenceSpaceEventImpl.get_transform(instance);
        state.own.cached_transform = value;
        return value;
    }

};
