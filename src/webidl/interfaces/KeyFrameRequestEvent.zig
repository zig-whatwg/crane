//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const KeyFrameRequestEventImpl = @import("impls").KeyFrameRequestEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMString = @import("typedefs").DOMString;

pub const KeyFrameRequestEvent = struct {
    pub const Meta = struct {
        pub const name = "KeyFrameRequestEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "rid", "get_rid", null },
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
            .{ "rid", "get_rid", null },
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
            rid: ?runtime.DOMString = null,
            _internal: ?*KeyFrameRequestEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_rid = &get_rid,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return KeyFrameRequestEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KeyFrameRequestEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, rid: webidl.Opt(DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try KeyFrameRequestEventImpl.call_constructor(allocator, ctx, @"type", rid);
    }

    pub fn get_rid(instance: *runtime.Instance) anyerror!?DOMString {
        return try KeyFrameRequestEventImpl.get_rid(instance);
    }

};
