//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DelayNodeImpl = @import("impls").DelayNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("AudioNode.zig").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("BaseAudioContext.zig").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DelayOptions = @import("dictionaries").DelayOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("Event.zig").Event;
const Observable = @import("Observable.zig").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("AudioParam.zig").AudioParam;
const EventListener = @import("EventListener.zig").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const DelayNode = struct {
    pub const Meta = struct {
        pub const name = "DelayNode";
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
            .{ "delayTime", "get_delayTime", null },
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
            .{ "delayTime", "get_delayTime", null },
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
            delayTime: *runtime.Instance = undefined,
            _internal: ?*DelayNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_delayTime = &get_delayTime,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DelayNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DelayNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DelayNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(DelayOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DelayNodeImpl.call_constructor(ctx, context, options);
    }

    pub fn get_delayTime(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DelayNodeImpl.get_delayTime(instance);
    }

};
