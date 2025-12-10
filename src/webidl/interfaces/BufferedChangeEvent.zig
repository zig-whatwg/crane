//! Generated from: media-source.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BufferedChangeEventImpl = @import("impls").BufferedChangeEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const TimeRanges = @import("interfaces").TimeRanges;
const EventTarget = @import("interfaces").EventTarget;
const BufferedChangeEventInit = @import("dictionaries").BufferedChangeEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const BufferedChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "BufferedChangeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "addedRanges", "get_addedRanges", null },
            .{ "removedRanges", "get_removedRanges", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "addedRanges", "get_addedRanges", null },
            .{ "removedRanges", "get_removedRanges", null },
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
            addedRanges: *runtime.Instance = undefined,
            removedRanges: *runtime.Instance = undefined,
            cached_addedRanges: ?*runtime.Instance = null,
            cached_removedRanges: ?*runtime.Instance = null,
            _internal: ?*BufferedChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_addedRanges = &get_addedRanges,
        .get_removedRanges = &get_removedRanges,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BufferedChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BufferedChangeEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BufferedChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(BufferedChangeEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BufferedChangeEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_addedRanges(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_addedRanges) |cached| {
            return cached;
        }
        const value = try BufferedChangeEventImpl.get_addedRanges(instance);
        state.own.cached_addedRanges = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_removedRanges(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_removedRanges) |cached| {
            return cached;
        }
        const value = try BufferedChangeEventImpl.get_removedRanges(instance);
        state.own.cached_removedRanges = value;
        return value;
    }

};
