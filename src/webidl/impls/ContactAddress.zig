//! Implementation for ContactAddress interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ContactAddress = @import("interfaces").ContactAddress;

pub const State = ContactAddress.State;

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

/// Getter for city
pub fn get_city(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for country
pub fn get_country(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for dependentLocality
pub fn get_dependentLocality(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for organization
pub fn get_organization(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for phone
pub fn get_phone(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for postalCode
pub fn get_postalCode(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for recipient
pub fn get_recipient(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for region
pub fn get_region(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for sortingCode
pub fn get_sortingCode(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for addressLine
pub fn get_addressLine(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

