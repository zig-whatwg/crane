//! Generated from: streams.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WritableStreamImpl = @import("impls").WritableStream;
const mixins = @import("mixins");
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;

pub const WritableStream = struct {
    pub const Meta = struct {
        pub const name = "WritableStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "locked", "get_locked", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "close", "call_close", 0 },
            .{ "getWriter", "call_getWriter", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "close",
            "getWriter",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "locked", "get_locked", null },
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
            locked: bool = undefined,
            _internal: ?*WritableStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_locked = &get_locked,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getWriter = &call_getWriter,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WritableStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WritableStreamImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, underlyingSink: webidl.Opt(*const anyopaque), strategy: webidl.Opt(QueuingStrategy)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WritableStreamImpl.call_constructor(allocator, ctx, underlyingSink, strategy);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try WritableStreamImpl.get_locked(instance);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WritableStreamImpl.call_getWriter(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
        
        return try WritableStreamImpl.call_abort(instance, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WritableStreamImpl.call_close(instance);
    }

};
