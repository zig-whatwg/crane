//! Implementation for XMLHttpRequestEventTarget interface
//!
//! XMLHttpRequestEventTarget provides event handler properties for XHR events.
//! Spec: https://xhr.spec.whatwg.org/#xmlhttprequesteventtarget
//!
//! Its seven attributes are event handler IDL attributes (HTML §8.1.8.1), and
//! like every other one they keep their values in EventTarget's event handler
//! map - an XMLHttpRequestEventTarget is an EventTarget. They used to live in
//! this interface's generated state, which nothing disposed and dispatch could
//! not see: the XHR impl invoked them itself, after every listener and with
//! `this` undefined, and each one pinned its page for the rest of the process.
//! The map owns its values, and dispatch runs them where they were activated.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XMLHttpRequestEventTarget = interfaces.XMLHttpRequestEventTarget;

pub const State = XMLHttpRequestEventTarget.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};
