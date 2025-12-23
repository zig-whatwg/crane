//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BiquadFilterNodeImpl = @import("impls").BiquadFilterNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const BiquadFilterOptions = @import("dictionaries").BiquadFilterOptions;
const BiquadFilterType = @import("enums").BiquadFilterType;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const BiquadFilterNode = struct {
    pub const Meta = struct {
        pub const name = "BiquadFilterNode";
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
            .{ "type", "get_type", "set_type" },
            .{ "frequency", "get_frequency", null },
            .{ "detune", "get_detune", null },
            .{ "Q", "get_Q", null },
            .{ "gain", "get_gain", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getFrequencyResponse", "call_getFrequencyResponse", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getFrequencyResponse",
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
            .{ "type", "get_type", "set_type" },
            .{ "frequency", "get_frequency", null },
            .{ "detune", "get_detune", null },
            .{ "Q", "get_Q", null },
            .{ "gain", "get_gain", null },
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
            @"type": enums.BiquadFilterType = undefined,
            frequency: *runtime.Instance = undefined,
            detune: *runtime.Instance = undefined,
            Q: *runtime.Instance = undefined,
            gain: *runtime.Instance = undefined,
            _internal: ?*BiquadFilterNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_Q = &get_Q,
        .get_detune = &get_detune,
        .get_frequency = &get_frequency,
        .get_gain = &get_gain,
        .get_type = &get_type,

        .set_type = &set_type,

        .call_getFrequencyResponse = &call_getFrequencyResponse,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BiquadFilterNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BiquadFilterNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BiquadFilterNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(BiquadFilterOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BiquadFilterNodeImpl.call_constructor(ctx, context, options);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!BiquadFilterType {
        return try BiquadFilterNodeImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: BiquadFilterType) anyerror!void {
        try BiquadFilterNodeImpl.set_type(instance, value);
    }

    pub fn get_frequency(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BiquadFilterNodeImpl.get_frequency(instance);
    }

    pub fn get_detune(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BiquadFilterNodeImpl.get_detune(instance);
    }

    pub fn get_Q(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BiquadFilterNodeImpl.get_Q(instance);
    }

    pub fn get_gain(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BiquadFilterNodeImpl.get_gain(instance);
    }

    pub fn call_getFrequencyResponse(instance: *runtime.Instance, frequencyHz: runtime.JSValue, magResponse: runtime.JSValue, phaseResponse: runtime.JSValue) anyerror!void {
        
        return try BiquadFilterNodeImpl.call_getFrequencyResponse(instance, frequencyHz, magResponse, phaseResponse);
    }

};
