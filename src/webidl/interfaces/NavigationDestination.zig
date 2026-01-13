//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationDestinationImpl = @import("impls").NavigationDestination;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const NavigationDestination = struct {
    pub const Meta = struct {
        pub const name = "NavigationDestination";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "url", "get_url", null },
            .{ "key", "get_key", null },
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "sameDocument", "get_sameDocument", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getState", "call_getState", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getState",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "url", "get_url", null },
            .{ "key", "get_key", null },
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "sameDocument", "get_sameDocument", null },
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
            url: runtime.USVString = undefined,
            key: typedefs.DOMString = undefined,
            id: typedefs.DOMString = undefined,
            index: i64 = undefined,
            sameDocument: bool = undefined,
            _internal: ?*NavigationDestinationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_index = &get_index,
        .get_key = &get_key,
        .get_sameDocument = &get_sameDocument,
        .get_url = &get_url,

        .call_getState = &call_getState,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationDestinationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NavigationDestinationImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationDestinationImpl.deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NavigationDestinationImpl.get_url(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationDestinationImpl.get_key(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationDestinationImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
        return try NavigationDestinationImpl.get_index(instance);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
        return try NavigationDestinationImpl.get_sameDocument(instance);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationDestinationImpl.call_getState(instance);
    }

};
