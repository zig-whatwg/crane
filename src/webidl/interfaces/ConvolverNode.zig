//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ConvolverNodeImpl = @import("impls").ConvolverNode;
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
const ConvolverOptions = @import("dictionaries").ConvolverOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const AudioParam = @import("AudioParam.zig").AudioParam;
const AudioBuffer = @import("AudioBuffer.zig").AudioBuffer;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const ConvolverNode = struct {
    pub const Meta = struct {
        pub const name = "ConvolverNode";
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
            .{ "buffer", "get_buffer", "set_buffer" },
            .{ "normalize", "get_normalize", "set_normalize" },
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
            "disconnect",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "buffer", "get_buffer", "set_buffer" },
            .{ "normalize", "get_normalize", "set_normalize" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            buffer: ?*runtime.Instance = null,
            normalize: bool = undefined,
            _internal: ?*ConvolverNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_buffer = &get_buffer,
        .get_normalize = &get_normalize,

        .set_buffer = &set_buffer,
        .set_normalize = &set_normalize,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ConvolverNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ConvolverNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ConvolverNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(ConvolverOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ConvolverNodeImpl.call_constructor(ctx, context, options);
    }

    pub fn get_buffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ConvolverNodeImpl.get_buffer(instance);
    }

    pub fn set_buffer(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try ConvolverNodeImpl.set_buffer(instance, value);
    }

    pub fn get_normalize(instance: *runtime.Instance) anyerror!bool {
        return try ConvolverNodeImpl.get_normalize(instance);
    }

    pub fn set_normalize(instance: *runtime.Instance, value: bool) anyerror!void {
        try ConvolverNodeImpl.set_normalize(instance, value);
    }

};
