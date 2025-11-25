//! Generated from: webxr.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRInputSourceEventImpl = @import("impls").XRInputSourceEvent;
const Event = @import("interfaces").Event;
const XRInputSource = @import("interfaces").XRInputSource;
const XRFrame = @import("interfaces").XRFrame;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const XRInputSourceEventInit = @import("dictionaries").XRInputSourceEventInit;
const DOMString = @import("typedefs").DOMString;

pub const XRInputSourceEvent = struct {
    pub const Meta = struct {
        pub const name = "XRInputSourceEvent";
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
            .{ "frame", "get_frame", null },
            .{ "inputSource", "get_inputSource", null },
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
            .{ "frame", "get_frame", null },
            .{ "inputSource", "get_inputSource", null },
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
            frame: *runtime.Instance = undefined,
            inputSource: *runtime.Instance = undefined,
            cached_frame: ?*runtime.Instance = null,
            cached_inputSource: ?*runtime.Instance = null,
            _internal: ?*XRInputSourceEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_frame = &get_frame,
        .get_inputSource = &get_inputSource,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRInputSourceEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRInputSourceEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: XRInputSourceEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRInputSourceEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_frame(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_frame) |cached| {
            return cached;
        }
        const value = try XRInputSourceEventImpl.get_frame(instance);
        state.own.cached_frame = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSource(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_inputSource) |cached| {
            return cached;
        }
        const value = try XRInputSourceEventImpl.get_inputSource(instance);
        state.own.cached_inputSource = value;
        return value;
    }

};
