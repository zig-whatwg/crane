//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T19:17:31Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IIRFilterNodeImpl = @import("impls").IIRFilterNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const IIRFilterOptions = @import("dictionaries").IIRFilterOptions;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const IIRFilterNode = struct {
    pub const Meta = struct {
        pub const name = "IIRFilterNode";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_getFrequencyResponse = &call_getFrequencyResponse,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IIRFilterNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IIRFilterNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: IIRFilterOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IIRFilterNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn call_getFrequencyResponse(instance: *runtime.Instance, frequencyHz: *const anyopaque, magResponse: *const anyopaque, phaseResponse: *const anyopaque) anyerror!void {
        
        return try IIRFilterNodeImpl.call_getFrequencyResponse(instance, frequencyHz, magResponse, phaseResponse);
    }

};
