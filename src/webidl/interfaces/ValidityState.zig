//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ValidityStateImpl = @import("impls").ValidityState;

pub const ValidityState = struct {
    pub const Meta = struct {
        pub const name = "ValidityState";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ValidityState, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ValidityStateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ValidityStateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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
