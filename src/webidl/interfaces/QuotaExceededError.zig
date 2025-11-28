//! Generated from: webidl.idl
//! Generated at: 2025-11-28T19:11:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const QuotaExceededErrorImpl = @import("impls").QuotaExceededError;
const mixins = @import("mixins");
const DOMException = @import("interfaces").DOMException;
const QuotaExceededErrorOptions = @import("dictionaries").QuotaExceededErrorOptions;
const DOMString = @import("typedefs").DOMString;

pub const QuotaExceededError = struct {
    pub const Meta = struct {
        pub const name = "QuotaExceededError";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "quota", "get_quota", null },
            .{ "requested", "get_requested", null },
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
            .{ "quota", "get_quota", null },
            .{ "requested", "get_requested", null },
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
            quota: ?f64 = null,
            requested: ?f64 = null,
            _internal: ?*QuotaExceededErrorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_quota = &get_quota,
        .get_requested = &get_requested,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return QuotaExceededErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        QuotaExceededErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: webidl.Opt(DOMString), options: webidl.Opt(QuotaExceededErrorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try QuotaExceededErrorImpl.call_constructor(allocator, ctx, message, options);
    }

    pub fn get_quota(instance: *runtime.Instance) anyerror!?f64 {
        return try QuotaExceededErrorImpl.get_quota(instance);
    }

    pub fn get_requested(instance: *runtime.Instance) anyerror!?f64 {
        return try QuotaExceededErrorImpl.get_requested(instance);
    }

};
