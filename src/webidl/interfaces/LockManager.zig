//! Generated from: web-locks.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LockManagerImpl = @import("impls").LockManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const LockOptions = @import("dictionaries").LockOptions;
const LockGrantedCallback = @import("callbacks").LockGrantedCallback;
const DOMString = @import("typedefs").DOMString;
const LockManagerSnapshot = @import("dictionaries").LockManagerSnapshot;

pub const LockManager = struct {
    pub const Meta = struct {
        pub const name = "LockManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "request", "call_request", 2 },
            .{ "query", "call_query", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "request",
            "query",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*LockManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_query = &call_query,
        .call_request = &call_request,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LockManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return LockManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LockManagerImpl.deinit(instance);
    }

    pub fn call_query(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try LockManagerImpl.call_query(instance);
    }

    pub fn call_request(instance: *runtime.Instance, name: DOMString, callback: LockGrantedCallback) anyerror!runtime.JSValue {
        
        return try LockManagerImpl.call_request(instance, name, callback);
    }

};
