//! Generated from: speech-api.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechRecognitionEventImpl = @import("impls").SpeechRecognitionEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const SpeechRecognitionResultList = @import("interfaces").SpeechRecognitionResultList;
const EventTarget = @import("interfaces").EventTarget;
const SpeechRecognitionEventInit = @import("dictionaries").SpeechRecognitionEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const SpeechRecognitionEvent = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionEvent";
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
            .{ "resultIndex", "get_resultIndex", null },
            .{ "results", "get_results", null },
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
            .{ "resultIndex", "get_resultIndex", null },
            .{ "results", "get_results", null },
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
            resultIndex: u32 = undefined,
            results: *runtime.Instance = undefined,
            _internal: ?*SpeechRecognitionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_resultIndex = &get_resultIndex,
        .get_results = &get_results,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechRecognitionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: SpeechRecognitionEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechRecognitionEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_resultIndex(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechRecognitionEventImpl.get_resultIndex(instance);
    }

    pub fn get_results(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SpeechRecognitionEventImpl.get_results(instance);
    }

};
