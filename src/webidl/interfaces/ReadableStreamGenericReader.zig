//! Generated from: streams.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ReadableStreamGenericReaderImpl = @import("impls").ReadableStreamGenericReader;
const mixins = @import("mixins");

pub const ReadableStreamGenericReader = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamGenericReader";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "closed", "get_closed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "cancel", "call_cancel", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            closed: runtime.Promise(void) = undefined,
            _internal: ?*ReadableStreamGenericReaderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_closed = &get_closed,

        .call_cancel = &call_cancel,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ReadableStreamGenericReaderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamGenericReaderImpl.deinit(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ReadableStreamGenericReaderImpl.get_closed(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(v8.JSValue)) anyerror!*const anyopaque {
        
        return try ReadableStreamGenericReaderImpl.call_cancel(instance, reason);
    }

};
