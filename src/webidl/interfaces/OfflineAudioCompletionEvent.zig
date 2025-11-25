//! Generated from: webaudio.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OfflineAudioCompletionEventImpl = @import("impls").OfflineAudioCompletionEvent;
const Event = @import("interfaces").Event;
const OfflineAudioCompletionEventInit = @import("dictionaries").OfflineAudioCompletionEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const AudioBuffer = @import("interfaces").AudioBuffer;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const OfflineAudioCompletionEvent = struct {
    pub const Meta = struct {
        pub const name = "OfflineAudioCompletionEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "renderedBuffer", "get_renderedBuffer", null },
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
            .{ "renderedBuffer", "get_renderedBuffer", null },
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
            renderedBuffer: *runtime.Instance = undefined,
            _internal: ?*OfflineAudioCompletionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_renderedBuffer = &get_renderedBuffer,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OfflineAudioCompletionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OfflineAudioCompletionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: OfflineAudioCompletionEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OfflineAudioCompletionEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_renderedBuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OfflineAudioCompletionEventImpl.get_renderedBuffer(instance);
    }

};
