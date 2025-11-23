//! Implementation for CSSFontFeatureValuesRule interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CSSFontFeatureValuesRule = interfaces.CSSFontFeatureValuesRule;

pub const State = CSSFontFeatureValuesRule.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for fontFamily
pub fn get_fontFamily(instance: *runtime.Instance) ImplError!typedefs.CSSOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for annotation
pub fn get_annotation(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ornaments
pub fn get_ornaments(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for stylistic
pub fn get_stylistic(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for swash
pub fn get_swash(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for characterVariant
pub fn get_characterVariant(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for styleset
pub fn get_styleset(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for historicalForms
pub fn get_historicalForms(instance: *runtime.Instance) ImplError!interfaces.CSSFontFeatureValuesMap {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for fontFamily
pub fn set_fontFamily(instance: *runtime.Instance, value: typedefs.CSSOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

