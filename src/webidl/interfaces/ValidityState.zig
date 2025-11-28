//! Generated from: html.idl
//! Generated at: 2025-11-28T19:11:17Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ValidityStateImpl = @import("impls").ValidityState;
const mixins = @import("mixins");

pub const ValidityState = struct {
    pub const Meta = struct {
        pub const name = "ValidityState";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "valueMissing", "get_valueMissing", null },
            .{ "typeMismatch", "get_typeMismatch", null },
            .{ "patternMismatch", "get_patternMismatch", null },
            .{ "tooLong", "get_tooLong", null },
            .{ "tooShort", "get_tooShort", null },
            .{ "rangeUnderflow", "get_rangeUnderflow", null },
            .{ "rangeOverflow", "get_rangeOverflow", null },
            .{ "stepMismatch", "get_stepMismatch", null },
            .{ "badInput", "get_badInput", null },
            .{ "customError", "get_customError", null },
            .{ "valid", "get_valid", null },
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
            .{ "valueMissing", "get_valueMissing", null },
            .{ "typeMismatch", "get_typeMismatch", null },
            .{ "patternMismatch", "get_patternMismatch", null },
            .{ "tooLong", "get_tooLong", null },
            .{ "tooShort", "get_tooShort", null },
            .{ "rangeUnderflow", "get_rangeUnderflow", null },
            .{ "rangeOverflow", "get_rangeOverflow", null },
            .{ "stepMismatch", "get_stepMismatch", null },
            .{ "badInput", "get_badInput", null },
            .{ "customError", "get_customError", null },
            .{ "valid", "get_valid", null },
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
            valueMissing: bool = undefined,
            typeMismatch: bool = undefined,
            patternMismatch: bool = undefined,
            tooLong: bool = undefined,
            tooShort: bool = undefined,
            rangeUnderflow: bool = undefined,
            rangeOverflow: bool = undefined,
            stepMismatch: bool = undefined,
            badInput: bool = undefined,
            customError: bool = undefined,
            valid: bool = undefined,
            _internal: ?*ValidityStateImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_badInput = &get_badInput,
        .get_customError = &get_customError,
        .get_patternMismatch = &get_patternMismatch,
        .get_rangeOverflow = &get_rangeOverflow,
        .get_rangeUnderflow = &get_rangeUnderflow,
        .get_stepMismatch = &get_stepMismatch,
        .get_tooLong = &get_tooLong,
        .get_tooShort = &get_tooShort,
        .get_typeMismatch = &get_typeMismatch,
        .get_valid = &get_valid,
        .get_valueMissing = &get_valueMissing,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ValidityStateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ValidityStateImpl.deinit(instance);
    }

    pub fn get_valueMissing(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_valueMissing(instance);
    }

    pub fn get_typeMismatch(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_typeMismatch(instance);
    }

    pub fn get_patternMismatch(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_patternMismatch(instance);
    }

    pub fn get_tooLong(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_tooLong(instance);
    }

    pub fn get_tooShort(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_tooShort(instance);
    }

    pub fn get_rangeUnderflow(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_rangeUnderflow(instance);
    }

    pub fn get_rangeOverflow(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_rangeOverflow(instance);
    }

    pub fn get_stepMismatch(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_stepMismatch(instance);
    }

    pub fn get_badInput(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_badInput(instance);
    }

    pub fn get_customError(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_customError(instance);
    }

    pub fn get_valid(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_valid(instance);
    }

};
