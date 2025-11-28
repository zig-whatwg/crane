//! Generated from: webxr.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRInputSourcesChangeEventImpl = @import("impls").XRInputSourcesChangeEvent;
const Event = @import("interfaces").Event;
const XRInputSource = @import("interfaces").XRInputSource;
const EventTarget = @import("interfaces").EventTarget;
const XRInputSourcesChangeEventInit = @import("dictionaries").XRInputSourcesChangeEventInit;
const XRSession = @import("interfaces").XRSession;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const XRInputSourcesChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "XRInputSourcesChangeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "session", "get_session", null },
            .{ "added", "get_added", null },
            .{ "removed", "get_removed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "session", "get_session", null },
            .{ "added", "get_added", null },
            .{ "removed", "get_removed", null },
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
            session: *runtime.Instance = undefined,
            added: runtime.FrozenArray(XRInputSource) = undefined,
            removed: runtime.FrozenArray(XRInputSource) = undefined,
            cached_session: ?*runtime.Instance = null,
            cached_added: ?runtime.FrozenArray(XRInputSource) = null,
            cached_removed: ?runtime.FrozenArray(XRInputSource) = null,
            _internal: ?*XRInputSourcesChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_added = &get_added,
        .get_removed = &get_removed,
        .get_session = &get_session,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRInputSourcesChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRInputSourcesChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: XRInputSourcesChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRInputSourcesChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_session) |cached| {
            return cached;
        }
        const value = try XRInputSourcesChangeEventImpl.get_session(instance);
        state.own.cached_session = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_added(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_added) |cached| {
            return cached;
        }
        const value = try XRInputSourcesChangeEventImpl.get_added(instance);
        state.own.cached_added = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_removed(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_removed) |cached| {
            return cached;
        }
        const value = try XRInputSourcesChangeEventImpl.get_removed(instance);
        state.own.cached_removed = value;
        return value;
    }

};
