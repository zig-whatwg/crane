//! Implementation for XMLHttpRequestUpload interface
//!
//! XMLHttpRequestUpload inherits from XMLHttpRequestEventTarget, which provides
//! the event handler properties (onloadstart, onprogress, etc.).
//!
//! Those handlers are kept in EventTarget's event handler map, like every
//! other event handler IDL attribute's.
//!
//! Spec: https://xhr.spec.whatwg.org/#xmlhttprequestupload

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XMLHttpRequestUpload = interfaces.XMLHttpRequestUpload;

pub const State = XMLHttpRequestUpload.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};
