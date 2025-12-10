//! Generated from: push-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushSubscriptionOptionsImpl = @import("impls").PushSubscriptionOptions;
const mixins = @import("mixins");

pub const PushSubscriptionOptions = struct {
    pub const Meta = struct {
        pub const name = "PushSubscriptionOptions";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "userVisibleOnly", "get_userVisibleOnly", null },
            .{ "applicationServerKey", "get_applicationServerKey", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "userVisibleOnly", "get_userVisibleOnly", null },
            .{ "applicationServerKey", "get_applicationServerKey", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            userVisibleOnly: bool = undefined,
            applicationServerKey: ?runtime.ArrayBuffer = null,
            cached_applicationServerKey: ?runtime.ArrayBuffer = null,
            _internal: ?*PushSubscriptionOptionsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_applicationServerKey = &get_applicationServerKey,
        .get_userVisibleOnly = &get_userVisibleOnly,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushSubscriptionOptionsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PushSubscriptionOptionsImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushSubscriptionOptionsImpl.deinit(instance);
    }

    pub fn get_userVisibleOnly(instance: *runtime.Instance) anyerror!bool {
        return try PushSubscriptionOptionsImpl.get_userVisibleOnly(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_applicationServerKey(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_applicationServerKey) |cached| {
            return cached;
        }
        const value = try PushSubscriptionOptionsImpl.get_applicationServerKey(instance);
        state.own.cached_applicationServerKey = value;
        return value;
    }

};
