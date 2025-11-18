//! Implementation for ValidityState interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ValidityState = @import("interfaces").ValidityState;

pub const State = ValidityState.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for valueMissing
pub fn get_valueMissing(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for typeMismatch
pub fn get_typeMismatch(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for patternMismatch
pub fn get_patternMismatch(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for tooLong
pub fn get_tooLong(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for tooShort
pub fn get_tooShort(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for rangeUnderflow
pub fn get_rangeUnderflow(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for rangeOverflow
pub fn get_rangeOverflow(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for stepMismatch
pub fn get_stepMismatch(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for badInput
pub fn get_badInput(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for customError
pub fn get_customError(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for valid
pub fn get_valid(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

