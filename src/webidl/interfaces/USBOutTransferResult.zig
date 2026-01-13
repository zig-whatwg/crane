//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBOutTransferResultImpl = @import("impls").USBOutTransferResult;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBTransferStatus = @import("enums").USBTransferStatus;

pub const USBOutTransferResult = struct {
    pub const Meta = struct {
        pub const name = "USBOutTransferResult";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "bytesWritten", "get_bytesWritten", null },
            .{ "status", "get_status", null },
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
            .{ "bytesWritten", "get_bytesWritten", null },
            .{ "status", "get_status", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            bytesWritten: u32 = undefined,
            status: enums.USBTransferStatus = undefined,
            _internal: ?*USBOutTransferResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_bytesWritten = &get_bytesWritten,
        .get_status = &get_status,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBOutTransferResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return USBOutTransferResultImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBOutTransferResultImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, status: USBTransferStatus, bytesWritten: webidl.Opt(u32)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBOutTransferResultImpl.call_constructor(ctx, status, bytesWritten);
    }

    pub fn get_bytesWritten(instance: *runtime.Instance) anyerror!u32 {
        return try USBOutTransferResultImpl.get_bytesWritten(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!USBTransferStatus {
        return try USBOutTransferResultImpl.get_status(instance);
    }

};
