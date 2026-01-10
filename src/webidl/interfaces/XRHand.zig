//! Generated from: webxr-hand-input.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRHandImpl = @import("impls").XRHand;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRJointSpace = @import("XRJointSpace.zig").XRJointSpace;
const XRHandJoint = @import("enums").XRHandJoint;

pub const XRHand = struct {
    pub const Meta = struct {
        pub const name = "XRHand";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*XRHandImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_size = &get_size,

        .call_forEach = &call_forEach,
        .call_get = &call_get,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRHandImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRHandImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRHandImpl.deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try XRHandImpl.get_size(instance);
    }

    pub fn call_get(instance: *runtime.Instance, key: XRHandJoint) anyerror!*runtime.Instance {
        
        return try XRHandImpl.call_get(instance, key);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
        
        return try XRHandImpl.call_forEach(instance, callback);
    }

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const XRHandImpl.IterableEntry {
        return XRHandImpl.getEntriesInternal(instance);
    }

};
