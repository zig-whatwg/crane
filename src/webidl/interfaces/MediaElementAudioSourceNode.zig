//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaElementAudioSourceNodeImpl = @import("impls").MediaElementAudioSourceNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("AudioNode.zig").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("BaseAudioContext.zig").BaseAudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const AudioContext = @import("AudioContext.zig").AudioContext;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const HTMLMediaElement = @import("HTMLMediaElement.zig").HTMLMediaElement;
const EventListener = @import("EventListener.zig").EventListener;
const AudioParam = @import("AudioParam.zig").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;
const MediaElementAudioSourceOptions = @import("dictionaries").MediaElementAudioSourceOptions;

pub const MediaElementAudioSourceNode = struct {
    pub const Meta = struct {
        pub const name = "MediaElementAudioSourceNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioNode.State;
        pub const ParentInterface = AudioNode;
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
            mediaElement: *runtime.Instance = undefined,
            cached_mediaElement: ?*runtime.Instance = null,
            _internal: ?*MediaElementAudioSourceNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_mediaElement = &get_mediaElement,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaElementAudioSourceNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaElementAudioSourceNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaElementAudioSourceNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: MediaElementAudioSourceOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaElementAudioSourceNodeImpl.call_constructor(ctx, context, options);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
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
