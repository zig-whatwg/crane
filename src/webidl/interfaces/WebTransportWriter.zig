//! Generated from: webtransport.idl
//! Generated at: 2025-11-29T11:15:58Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebTransportWriterImpl = @import("impls").WebTransportWriter;
const mixins = @import("mixins");
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const WritableStream = @import("interfaces").WritableStream;

pub const WebTransportWriter = struct {
    pub const Meta = struct {
        pub const name = "WebTransportWriter";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WritableStreamDefaultWriter.State;
        pub const ParentInterface = WritableStreamDefaultWriter;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "atomicWrite", "call_atomicWrite", 0 },
            .{ "commit", "call_commit", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "atomicWrite",
            "commit",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "abort",
            "close",
            "releaseLock",
            "write",
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
        struct {
            _internal: ?*WebTransportWriterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_atomicWrite = &call_atomicWrite,
        .call_commit = &call_commit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebTransportWriterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportWriterImpl.deinit(instance);
    }

    pub fn call_commit(instance: *runtime.Instance) anyerror!void {
        return try WebTransportWriterImpl.call_commit(instance);
    }

    pub fn call_atomicWrite(instance: *runtime.Instance, chunk: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
        
        return try WebTransportWriterImpl.call_atomicWrite(instance, chunk);
    }

};
