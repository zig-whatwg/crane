//! Generated from: speech-api.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisErrorEventImpl = @import("impls").SpeechSynthesisErrorEvent;
const SpeechSynthesisEvent = @import("interfaces").SpeechSynthesisEvent;
const SpeechSynthesisErrorCode = @import("enums").SpeechSynthesisErrorCode;
const SpeechSynthesisErrorEventInit = @import("dictionaries").SpeechSynthesisErrorEventInit;
const EventTarget = @import("interfaces").EventTarget;
const SpeechSynthesisEventInit = @import("dictionaries").SpeechSynthesisEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const SpeechSynthesisUtterance = @import("interfaces").SpeechSynthesisUtterance;
const DOMString = @import("typedefs").DOMString;

pub const SpeechSynthesisErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisErrorEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SpeechSynthesisEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "error", "get_error", null },
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
            .{ "error", "get_error", null },
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
            @"error": SpeechSynthesisErrorCode = undefined,
            _internal: ?*SpeechSynthesisErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_error = &get_error,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechSynthesisErrorEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisErrorEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: SpeechSynthesisErrorEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechSynthesisErrorEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!SpeechSynthesisErrorCode {
        return try SpeechSynthesisErrorEventImpl.get_error(instance);
    }

};
