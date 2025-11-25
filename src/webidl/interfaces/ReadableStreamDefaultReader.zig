//! Generated from: streams.idl
//! Generated at: 2025-11-25T13:07:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamDefaultReaderImpl = @import("impls").ReadableStreamDefaultReader;
const ReadableStreamGenericReader = @import("interfaces").ReadableStreamGenericReader;
const ReadableStream = @import("interfaces").ReadableStream;
const ReadableStreamReadResult = @import("dictionaries").ReadableStreamReadResult;

pub const ReadableStreamDefaultReader = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamDefaultReader";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            ReadableStreamGenericReader,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "closed", "get_closed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "read", "call_read", 0 },
            .{ "releaseLock", "call_releaseLock", 0 },
            .{ "cancel", "call_cancel", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "read",
            "releaseLock",
            "cancel",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "closed", "get_closed", null },
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
            _internal: ?*ReadableStreamDefaultReaderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_closed = &get_closed,

        .call_cancel = &call_cancel,
        .call_read = &call_read,
        .call_releaseLock = &call_releaseLock,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ReadableStreamDefaultReaderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamDefaultReaderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ReadableStreamDefaultReaderImpl.call_constructor(allocator, ctx, stream);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ReadableStreamDefaultReaderImpl.get_closed(instance);
    }

    pub fn call_read(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ReadableStreamDefaultReaderImpl.call_read(instance);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try ReadableStreamDefaultReaderImpl.call_releaseLock(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: *const anyopaque) anyerror!*const anyopaque {
        
        return try ReadableStreamDefaultReaderImpl.call_cancel(instance, reason);
    }

};
