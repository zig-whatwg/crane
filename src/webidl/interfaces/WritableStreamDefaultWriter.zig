//! Generated from: streams.idl
//! Generated at: 2025-11-23T19:17:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WritableStreamDefaultWriterImpl = @import("impls").WritableStreamDefaultWriter;
const WritableStream = @import("interfaces").WritableStream;

pub const WritableStreamDefaultWriter = struct {
    pub const Meta = struct {
        pub const name = "WritableStreamDefaultWriter";
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
            .{ "closed", "get_closed", null },
            .{ "desiredSize", "get_desiredSize", null },
            .{ "ready", "get_ready", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "close", "call_close", 0 },
            .{ "releaseLock", "call_releaseLock", 0 },
            .{ "write", "call_write", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "close",
            "releaseLock",
            "write",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "closed", "get_closed", null },
            .{ "desiredSize", "get_desiredSize", null },
            .{ "ready", "get_ready", null },
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
            closed: runtime.Promise(void) = undefined,
            desiredSize: ?f64 = null,
            ready: runtime.Promise(void) = undefined,
            _internal: ?*WritableStreamDefaultWriterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_closed = &get_closed,
        .get_desiredSize = &get_desiredSize,
        .get_ready = &get_ready,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_releaseLock = &call_releaseLock,
        .call_write = &call_write,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WritableStreamDefaultWriterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WritableStreamDefaultWriterImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WritableStreamDefaultWriterImpl.call_constructor(allocator, ctx, stream);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WritableStreamDefaultWriterImpl.get_closed(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!f64 {
        return try WritableStreamDefaultWriterImpl.get_desiredSize(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WritableStreamDefaultWriterImpl.get_ready(instance);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try WritableStreamDefaultWriterImpl.call_releaseLock(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: *const anyopaque) anyerror!*const anyopaque {
        
        return try WritableStreamDefaultWriterImpl.call_abort(instance, reason);
    }

    pub fn call_write(instance: *runtime.Instance, chunk: *const anyopaque) anyerror!*const anyopaque {
        
        return try WritableStreamDefaultWriterImpl.call_write(instance, chunk);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WritableStreamDefaultWriterImpl.call_close(instance);
    }

};
