//! Generated from: compute-pressure.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PressureRecordImpl = @import("impls").PressureRecord;
const PressureSource = @import("enums").PressureSource;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PressureState = @import("enums").PressureState;

pub const PressureRecord = struct {
    pub const Meta = struct {
        pub const name = "PressureRecord";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "source", "get_source", null },
            .{ "state", "get_state", null },
            .{ "time", "get_time", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "source", "get_source", null },
            .{ "state", "get_state", null },
            .{ "time", "get_time", null },
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
            source: PressureSource = undefined,
            state: PressureState = undefined,
            time: DOMHighResTimeStamp = undefined,
            _internal: ?*PressureRecordImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_source = &get_source,
        .get_state = &get_state,
        .get_time = &get_time,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PressureRecordImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PressureRecordImpl.deinit(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!PressureSource {
        return try PressureRecordImpl.get_source(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PressureState {
        return try PressureRecordImpl.get_state(instance);
    }

    pub fn get_time(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PressureRecordImpl.get_time(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PressureRecordImpl.call_toJSON(instance);
    }

};
