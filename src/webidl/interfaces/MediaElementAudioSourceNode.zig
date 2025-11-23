//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaElementAudioSourceNodeImpl = @import("impls").MediaElementAudioSourceNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const AudioContext = @import("interfaces").AudioContext;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;
const MediaElementAudioSourceOptions = @import("dictionaries").MediaElementAudioSourceOptions;

pub const MediaElementAudioSourceNode = struct {
    pub const Meta = struct {
        pub const name = "MediaElementAudioSourceNode";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mediaElement", "get_mediaElement", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mediaElement", "get_mediaElement", null },
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
            mediaElement: HTMLMediaElement = undefined,
            cached_mediaElement: ?HTMLMediaElement = null,
        },
    );

    const delegates = .{

        .get_mediaElement = &get_mediaElement,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaElementAudioSourceNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaElementAudioSourceNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: AudioContext, options: MediaElementAudioSourceOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaElementAudioSourceNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaElement(instance: *runtime.Instance) anyerror!HTMLMediaElement {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaElement) |cached| {
            return cached;
        }
        const value = try MediaElementAudioSourceNodeImpl.get_mediaElement(instance);
        state.own.cached_mediaElement = value;
        return value;
    }

};
