//! Generated from: background-fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BackgroundFetchRecordImpl = @import("impls").BackgroundFetchRecord;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Request = @import("Request.zig").Request;
const Response = @import("Response.zig").Response;

pub const BackgroundFetchRecord = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchRecord";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "request", "get_request", null },
            .{ "responseReady", "get_responseReady", null },
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
            .{ "request", "get_request", null },
            .{ "responseReady", "get_responseReady", null },
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
            request: *runtime.Instance = undefined,
            responseReady: runtime.JSValue = undefined,
            _internal: ?*BackgroundFetchRecordImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_request = &get_request,
        .get_responseReady = &get_responseReady,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BackgroundFetchRecordImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BackgroundFetchRecordImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchRecordImpl.deinit(instance);
    }

    pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BackgroundFetchRecordImpl.get_request(instance);
    }

    pub fn get_responseReady(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BackgroundFetchRecordImpl.get_responseReady(instance);
    }

};
