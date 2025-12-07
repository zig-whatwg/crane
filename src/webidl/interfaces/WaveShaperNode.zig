//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WaveShaperNodeImpl = @import("impls").WaveShaperNode;
const mixins = @import("mixins");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const WaveShaperOptions = @import("dictionaries").WaveShaperOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const OverSampleType = @import("enums").OverSampleType;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const WaveShaperNode = struct {
    pub const Meta = struct {
        pub const name = "WaveShaperNode";
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
            .{ "curve", "get_curve", "set_curve" },
            .{ "oversample", "get_oversample", "set_oversample" },
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
            .{ "curve", "get_curve", "set_curve" },
            .{ "oversample", "get_oversample", "set_oversample" },
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
            curve: ?runtime.Float32Array = null,
            oversample: OverSampleType = undefined,
            _internal: ?*WaveShaperNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_curve = &get_curve,
        .get_oversample = &get_oversample,

        .set_curve = &set_curve,
        .set_oversample = &set_oversample,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WaveShaperNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WaveShaperNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(WaveShaperOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WaveShaperNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn get_curve(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try WaveShaperNodeImpl.get_curve(instance);
    }

    pub fn set_curve(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try WaveShaperNodeImpl.set_curve(instance, value);
    }

    pub fn get_oversample(instance: *runtime.Instance) anyerror!OverSampleType {
        return try WaveShaperNodeImpl.get_oversample(instance);
    }

    pub fn set_oversample(instance: *runtime.Instance, value: OverSampleType) anyerror!void {
        try WaveShaperNodeImpl.set_oversample(instance, value);
    }

};
