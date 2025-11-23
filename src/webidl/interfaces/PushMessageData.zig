//! Generated from: push-api.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushMessageDataImpl = @import("impls").PushMessageData;
const Blob = @import("interfaces").Blob;
const USVString = @import("interfaces").USVString;

pub const PushMessageData = struct {
    pub const Meta = struct {
        pub const name = "PushMessageData";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "arrayBuffer", "call_arrayBuffer", 0 },
            .{ "blob", "call_blob", 0 },
            .{ "bytes", "call_bytes", 0 },
            .{ "json", "call_json", 0 },
            .{ "text", "call_text", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "arrayBuffer",
            "blob",
            "bytes",
            "json",
            "text",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_arrayBuffer = &call_arrayBuffer,
        .call_blob = &call_blob,
        .call_bytes = &call_bytes,
        .call_json = &call_json,
        .call_text = &call_text,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushMessageDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushMessageDataImpl.deinit(instance);
    }

    pub fn call_blob(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PushMessageDataImpl.call_blob(instance);
    }

    pub fn call_text(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PushMessageDataImpl.call_text(instance);
    }

    pub fn call_json(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PushMessageDataImpl.call_json(instance);
    }

    pub fn call_bytes(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PushMessageDataImpl.call_bytes(instance);
    }

    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PushMessageDataImpl.call_arrayBuffer(instance);
    }

};
