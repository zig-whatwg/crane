//! Implementation for PaymentRequestEvent interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestEvent = @import("interfaces").PaymentRequestEvent;

pub const State = PaymentRequestEvent.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance, type: runtime.DOMString, eventInitDict: anyopaque) !void {
    _ = instance;
    _ = type;
    _ = eventInitDict;
    // TODO: Implement constructor logic
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for target
pub fn get_target(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for srcElement
pub fn get_srcElement(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for currentTarget
pub fn get_currentTarget(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for eventPhase
pub fn get_eventPhase(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cancelBubble
pub fn get_cancelBubble(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for bubbles
pub fn get_bubbles(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cancelable
pub fn get_cancelable(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for returnValue
pub fn get_returnValue(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for defaultPrevented
pub fn get_defaultPrevented(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for composed
pub fn get_composed(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isTrusted
pub fn get_isTrusted(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for timeStamp
pub fn get_timeStamp(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for topOrigin
pub fn get_topOrigin(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for paymentRequestOrigin
pub fn get_paymentRequestOrigin(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for paymentRequestId
pub fn get_paymentRequestId(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for methodData
pub fn get_methodData(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for total
pub fn get_total(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for modifiers
pub fn get_modifiers(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for paymentOptions
pub fn get_paymentOptions(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for shippingOptions
pub fn get_shippingOptions(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for cancelBubble
pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for returnValue
pub fn set_returnValue(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: composedPath
pub fn call_composedPath(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stopPropagation
pub fn call_stopPropagation(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stopImmediatePropagation
pub fn call_stopImmediatePropagation(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: preventDefault
pub fn call_preventDefault(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: initEvent
pub fn call_initEvent(instance: *runtime.Instance, type: runtime.DOMString, bubbles: bool, cancelable: bool) ImplError!void {
    _ = instance;
    _ = type;
    _ = bubbles;
    _ = cancelable;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: waitUntil
pub fn call_waitUntil(instance: *runtime.Instance, f: anyopaque) ImplError!void {
    _ = instance;
    _ = f;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: openWindow
pub fn call_openWindow(instance: *runtime.Instance, url: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: changePaymentMethod
pub fn call_changePaymentMethod(instance: *runtime.Instance, methodName: runtime.DOMString, methodDetails: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = methodName;
    _ = methodDetails;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: changeShippingAddress
pub fn call_changeShippingAddress(instance: *runtime.Instance, shippingAddress: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = shippingAddress;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: changeShippingOption
pub fn call_changeShippingOption(instance: *runtime.Instance, shippingOption: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = shippingOption;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: respondWith
pub fn call_respondWith(instance: *runtime.Instance, handlerResponsePromise: anyopaque) ImplError!void {
    _ = instance;
    _ = handlerResponsePromise;
    // TODO: Implement operation
    return error.NotImplemented;
}

