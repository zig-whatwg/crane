//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NotRestoredReasonDetailsImpl = @import("impls").NotRestoredReasonDetails;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const NotRestoredReasonDetails = struct {
    pub const Meta = struct {
        pub const name = "NotRestoredReasonDetails";
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
            .{ "reason", "get_reason", null },
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
            .{ "reason", "get_reason", null },
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
            reason: runtime.DOMString = undefined,
            _internal: ?*NotRestoredReasonDetailsImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for NotRestoredReasonDetails
    /// Generated from [Default] toJSON extended attribute
    pub const NotRestoredReasonDetailsToJSON = struct {
        reason: runtime.DOMString,
    };

    const delegates = .{

        .get_reason = &get_reason,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NotRestoredReasonDetailsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NotRestoredReasonDetailsImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NotRestoredReasonDetailsImpl.deinit(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!DOMString {
        return try NotRestoredReasonDetailsImpl.get_reason(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NotRestoredReasonDetailsImpl.call_toJSON(instance);
    }

};
