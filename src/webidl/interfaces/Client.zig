//! Generated from: service-workers.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientImpl = @import("impls").Client;
const FrameType = @import("enums").FrameType;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const ClientLifecycleState = @import("enums").ClientLifecycleState;
const ClientType = @import("enums").ClientType;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Client = struct {
    pub const Meta = struct {
        pub const name = "Client";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "url", "get_url", null },
            .{ "frameType", "get_frameType", null },
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
            .{ "lifecycleState", "get_lifecycleState", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 2 },
            .{ "postMessage", "call_postMessage", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
            "postMessage",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "url", "get_url", null },
            .{ "frameType", "get_frameType", null },
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
            .{ "lifecycleState", "get_lifecycleState", null },
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
            frameType: FrameType = undefined,
            id: runtime.DOMString = undefined,
            @"type": ClientType = undefined,
            lifecycleState: ClientLifecycleState = undefined,
            _internal: ?*ClientImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_frameType = &get_frameType,
        .get_id = &get_id,
        .get_lifecycleState = &get_lifecycleState,
        .get_type = &get_type,
        .get_url = &get_url,

        .call_postMessage = &call_postMessage,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ClientImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClientImpl.deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ClientImpl.get_url(instance);
    }

    pub fn get_frameType(instance: *runtime.Instance) anyerror!FrameType {
        return try ClientImpl.get_frameType(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try ClientImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ClientType {
        return try ClientImpl.get_type(instance);
    }

    pub fn get_lifecycleState(instance: *runtime.Instance) anyerror!ClientLifecycleState {
        return try ClientImpl.get_lifecycleState(instance);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: *const anyopaque, transfer: *const anyopaque) anyerror!void {
        
        return try ClientImpl.call_postMessage(instance, message, transfer);
    }

};
