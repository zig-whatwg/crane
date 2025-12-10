//! Generated from: js-self-profiling.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ProfilerImpl = @import("impls").Profiler;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const ProfilerTrace = @import("dictionaries").ProfilerTrace;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const ProfilerInitOptions = @import("dictionaries").ProfilerInitOptions;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const Profiler = struct {
    pub const Meta = struct {
        pub const name = "Profiler";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sampleInterval", "get_sampleInterval", null },
            .{ "stopped", "get_stopped", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "stop", "call_stop", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "stop",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sampleInterval", "get_sampleInterval", null },
            .{ "stopped", "get_stopped", null },
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
            sampleInterval: DOMHighResTimeStamp = undefined,
            stopped: bool = undefined,
            _internal: ?*ProfilerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sampleInterval = &get_sampleInterval,
        .get_stopped = &get_stopped,

        .call_stop = &call_stop,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ProfilerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ProfilerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProfilerImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: ProfilerInitOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ProfilerImpl.call_constructor(ctx, options);
    }

    pub fn get_sampleInterval(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try ProfilerImpl.get_sampleInterval(instance);
    }

    pub fn get_stopped(instance: *runtime.Instance) anyerror!bool {
        return try ProfilerImpl.get_stopped(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ProfilerImpl.call_stop(instance);
    }

};
