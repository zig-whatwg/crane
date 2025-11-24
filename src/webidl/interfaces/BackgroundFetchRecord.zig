//! Generated from: background-fetch.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchRecordImpl = @import("impls").BackgroundFetchRecord;
const Request = @import("interfaces").Request;
const Response = @import("interfaces").Response;

pub const BackgroundFetchRecord = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchRecord";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            responseReady: runtime.Promise(Response) = undefined,
            _internal: ?*BackgroundFetchRecordImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_request = &get_request,
        .get_responseReady = &get_responseReady,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BackgroundFetchRecordImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchRecordImpl.deinit(instance);
    }

    pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BackgroundFetchRecordImpl.get_request(instance);
    }

    pub fn get_responseReady(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BackgroundFetchRecordImpl.get_responseReady(instance);
    }

};
