//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioProcessingEventImpl = @import("impls").AudioProcessingEvent;
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const AudioBuffer = @import("interfaces").AudioBuffer;
const EventInit = @import("dictionaries").EventInit;
const AudioProcessingEventInit = @import("dictionaries").AudioProcessingEventInit;

pub const AudioProcessingEvent = struct {
    pub const Meta = struct {
        pub const name = "AudioProcessingEvent";
        pub const is_mixin = false;
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
            .{ "playbackTime", "get_playbackTime", null },
            .{ "inputBuffer", "get_inputBuffer", null },
            .{ "outputBuffer", "get_outputBuffer", null },
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
            .{ "playbackTime", "get_playbackTime", null },
            .{ "inputBuffer", "get_inputBuffer", null },
            .{ "outputBuffer", "get_outputBuffer", null },
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
            playbackTime: f64 = undefined,
            inputBuffer: AudioBuffer = undefined,
            outputBuffer: AudioBuffer = undefined,
        },
    );

    const delegates = .{

        .get_inputBuffer = &get_inputBuffer,
        .get_outputBuffer = &get_outputBuffer,
        .get_playbackTime = &get_playbackTime,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioProcessingEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioProcessingEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: AudioProcessingEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioProcessingEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_playbackTime(instance: *runtime.Instance) anyerror!f64 {
        return try AudioProcessingEventImpl.get_playbackTime(instance);
    }

    pub fn get_inputBuffer(instance: *runtime.Instance) anyerror!AudioBuffer {
        return try AudioProcessingEventImpl.get_inputBuffer(instance);
    }

    pub fn get_outputBuffer(instance: *runtime.Instance) anyerror!AudioBuffer {
        return try AudioProcessingEventImpl.get_outputBuffer(instance);
    }

};
