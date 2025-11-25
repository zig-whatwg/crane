//! Generated from: speech-api.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionErrorEventImpl = @import("impls").SpeechRecognitionErrorEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const SpeechRecognitionErrorEventInit = @import("dictionaries").SpeechRecognitionErrorEventInit;
const SpeechRecognitionErrorCode = @import("enums").SpeechRecognitionErrorCode;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const SpeechRecognitionErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionErrorEvent";
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
            .{ "error", "get_error", null },
            .{ "message", "get_message", null },
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
            .{ "error", "get_error", null },
            .{ "message", "get_message", null },
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
            @"error": SpeechRecognitionErrorCode = undefined,
            message: runtime.DOMString = undefined,
            _internal: ?*SpeechRecognitionErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_error = &get_error,
        .get_message = &get_message,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechRecognitionErrorEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionErrorEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: SpeechRecognitionErrorEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechRecognitionErrorEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!SpeechRecognitionErrorCode {
        return try SpeechRecognitionErrorEventImpl.get_error(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechRecognitionErrorEventImpl.get_message(instance);
    }

};
