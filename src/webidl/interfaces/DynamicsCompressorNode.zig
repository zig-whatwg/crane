//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DynamicsCompressorNodeImpl = @import("impls").DynamicsCompressorNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("AudioNode.zig").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("BaseAudioContext.zig").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("Event.zig").Event;
const Observable = @import("Observable.zig").Observable;
const DynamicsCompressorOptions = @import("dictionaries").DynamicsCompressorOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("AudioParam.zig").AudioParam;
const EventListener = @import("EventListener.zig").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const DynamicsCompressorNode = struct {
    pub const Meta = struct {
        pub const name = "DynamicsCompressorNode";
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
            .{ "threshold", "get_threshold", null },
            .{ "knee", "get_knee", null },
            .{ "ratio", "get_ratio", null },
            .{ "reduction", "get_reduction", null },
            .{ "attack", "get_attack", null },
            .{ "release", "get_release", null },
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DynamicsCompressorNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DynamicsCompressorNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DynamicsCompressorNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(DynamicsCompressorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DynamicsCompressorNodeImpl.call_constructor(ctx, context, options);
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
