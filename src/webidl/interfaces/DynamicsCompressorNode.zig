//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DynamicsCompressorNodeImpl = @import("impls").DynamicsCompressorNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const DynamicsCompressorOptions = @import("dictionaries").DynamicsCompressorOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const DynamicsCompressorNode = struct {
    pub const Meta = struct {
        pub const name = "DynamicsCompressorNode";
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
            .{ "threshold", "get_threshold", null },
            .{ "knee", "get_knee", null },
            .{ "ratio", "get_ratio", null },
            .{ "reduction", "get_reduction", null },
            .{ "attack", "get_attack", null },
            .{ "release", "get_release", null },
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
            .{ "threshold", "get_threshold", null },
            .{ "knee", "get_knee", null },
            .{ "ratio", "get_ratio", null },
            .{ "reduction", "get_reduction", null },
            .{ "attack", "get_attack", null },
            .{ "release", "get_release", null },
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
            threshold: *runtime.Instance = undefined,
            knee: *runtime.Instance = undefined,
            ratio: *runtime.Instance = undefined,
            reduction: f32 = undefined,
            attack: *runtime.Instance = undefined,
            release: *runtime.Instance = undefined,
            _internal: ?*DynamicsCompressorNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_attack = &get_attack,
        .get_knee = &get_knee,
        .get_ratio = &get_ratio,
        .get_reduction = &get_reduction,
        .get_release = &get_release,
        .get_threshold = &get_threshold,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DynamicsCompressorNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DynamicsCompressorNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: DynamicsCompressorOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DynamicsCompressorNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn get_threshold(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DynamicsCompressorNodeImpl.get_threshold(instance);
    }

    pub fn get_knee(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DynamicsCompressorNodeImpl.get_knee(instance);
    }

    pub fn get_ratio(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DynamicsCompressorNodeImpl.get_ratio(instance);
    }

    pub fn get_reduction(instance: *runtime.Instance) anyerror!f32 {
        return try DynamicsCompressorNodeImpl.get_reduction(instance);
    }

    pub fn get_attack(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DynamicsCompressorNodeImpl.get_attack(instance);
    }

    pub fn get_release(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DynamicsCompressorNodeImpl.get_release(instance);
    }

};
