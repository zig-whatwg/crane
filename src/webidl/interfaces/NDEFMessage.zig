//! Generated from: web-nfc.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFMessageImpl = @import("impls").NDEFMessage;
const NDEFRecord = @import("interfaces").NDEFRecord;
const NDEFMessageInit = @import("dictionaries").NDEFMessageInit;

pub const NDEFMessage = struct {
    pub const Meta = struct {
        pub const name = "NDEFMessage";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "records", "get_records", null },
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
            .{ "records", "get_records", null },
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
            records: runtime.FrozenArray(NDEFRecord) = undefined,
            _internal: ?*NDEFMessageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_records = &get_records,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NDEFMessageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFMessageImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, messageInit: NDEFMessageInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NDEFMessageImpl.call_constructor(allocator, ctx, messageInit);
    }

    pub fn get_records(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NDEFMessageImpl.get_records(instance);
    }

};
