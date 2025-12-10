//! Generated from: background-fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BackgroundFetchUpdateUIEventImpl = @import("impls").BackgroundFetchUpdateUIEvent;
const mixins = @import("mixins");
const BackgroundFetchEvent = @import("interfaces").BackgroundFetchEvent;
const BackgroundFetchRegistration = @import("interfaces").BackgroundFetchRegistration;
const BackgroundFetchEventInit = @import("dictionaries").BackgroundFetchEventInit;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const BackgroundFetchUIOptions = @import("dictionaries").BackgroundFetchUIOptions;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const BackgroundFetchUpdateUIEvent = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchUpdateUIEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = BackgroundFetchEvent.State;
        pub const ParentInterface = BackgroundFetchEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "updateUI", "call_updateUI", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "updateUI",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "waitUntil",
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
        struct {
            _internal: ?*BackgroundFetchUpdateUIEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_updateUI = &call_updateUI,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BackgroundFetchUpdateUIEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BackgroundFetchUpdateUIEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchUpdateUIEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, init_data: BackgroundFetchEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BackgroundFetchUpdateUIEventImpl.call_constructor(ctx, @"type", init_data);
    }

    pub fn call_updateUI(instance: *runtime.Instance, options: webidl.Opt(BackgroundFetchUIOptions)) anyerror!runtime.JSValue {
        
        return try BackgroundFetchUpdateUIEventImpl.call_updateUI(instance, options);
    }

};
