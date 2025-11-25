//! Generated from: webaudio.idl
//! Generated at: 2025-11-25T20:02:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaStreamAudioDestinationNodeImpl = @import("impls").MediaStreamAudioDestinationNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const AudioNodeOptions = @import("dictionaries").AudioNodeOptions;
const AudioContext = @import("interfaces").AudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const MediaStream = @import("interfaces").MediaStream;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const MediaStreamAudioDestinationNode = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamAudioDestinationNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "stream", "get_stream", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "stream", "get_stream", null },
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
            stream: *runtime.Instance = undefined,
            _internal: ?*MediaStreamAudioDestinationNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_stream = &get_stream,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaStreamAudioDestinationNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaStreamAudioDestinationNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: AudioNodeOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaStreamAudioDestinationNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn get_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaStreamAudioDestinationNodeImpl.get_stream(instance);
    }

};
