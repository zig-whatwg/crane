//! Generated from: streams.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamBYOBRequestImpl = @import("impls").ReadableStreamBYOBRequest;
const ArrayBufferView = @import("typedefs").ArrayBufferView;

pub const ReadableStreamBYOBRequest = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamBYOBRequest";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "view", "get_view", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "respond", "call_respond", 1 },
            .{ "respondWithNewView", "call_respondWithNewView", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "respond",
            "respondWithNewView",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "view", "get_view", null },
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
            view: ?ArrayBufferView = null,
            _internal: ?*ReadableStreamBYOBRequestImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_view = &get_view,

        .call_respond = &call_respond,
        .call_respondWithNewView = &call_respondWithNewView,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ReadableStreamBYOBRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamBYOBRequestImpl.deinit(instance);
    }

    pub fn get_view(instance: *runtime.Instance) anyerror!ArrayBufferView {
        return try ReadableStreamBYOBRequestImpl.get_view(instance);
    }

    pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) anyerror!void {
        // [EnforceRange] on bytesWritten
        if (!runtime.isInRange(u64, bytesWritten)) return error.TypeError;
        
        return try ReadableStreamBYOBRequestImpl.call_respond(instance, bytesWritten);
    }

    pub fn call_respondWithNewView(instance: *runtime.Instance, view: ArrayBufferView) anyerror!void {
        
        return try ReadableStreamBYOBRequestImpl.call_respondWithNewView(instance, view);
    }

};
