//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameTransformErrorEventImpl = @import("impls").SFrameTransformErrorEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const SFrameTransformErrorEventInit = @import("dictionaries").SFrameTransformErrorEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const SFrameTransformErrorEventType = @import("enums").SFrameTransformErrorEventType;
const EventInit = @import("dictionaries").EventInit;
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const DOMString = @import("typedefs").DOMString;

pub const SFrameTransformErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "SFrameTransformErrorEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "errorType", "get_errorType", null },
            .{ "keyID", "get_keyID", null },
            .{ "frame", "get_frame", null },
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
            .{ "errorType", "get_errorType", null },
            .{ "keyID", "get_keyID", null },
            .{ "frame", "get_frame", null },
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
            errorType: SFrameTransformErrorEventType = undefined,
            keyID: ?CryptoKeyID = null,
            frame: runtime.JSValue = undefined,
            _internal: ?*SFrameTransformErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_errorType = &get_errorType,
        .get_frame = &get_frame,
        .get_keyID = &get_keyID,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SFrameTransformErrorEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameTransformErrorEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: SFrameTransformErrorEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SFrameTransformErrorEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_errorType(instance: *runtime.Instance) anyerror!SFrameTransformErrorEventType {
        return try SFrameTransformErrorEventImpl.get_errorType(instance);
    }

    pub fn get_keyID(instance: *runtime.Instance) anyerror!?CryptoKeyID {
        return try SFrameTransformErrorEventImpl.get_keyID(instance);
    }

    pub fn get_frame(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SFrameTransformErrorEventImpl.get_frame(instance);
    }

};
