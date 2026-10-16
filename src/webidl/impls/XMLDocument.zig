//! Implementation for XMLDocument interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XMLDocument = interfaces.XMLDocument;

pub const State = XMLDocument.State;

pub const ImplError = error{
    NotImplemented,
};

/// XMLDocument has no state of its own (DOM 4.5: "an XMLDocument" is a
/// Document whose interface is XMLDocument).
pub const InternalState = struct {};

// No construction or destruction steps of its own: XMLDocument adds no
// state to Document's, so the generated chain (interfaces.XMLDocument.init
// -> Document -> Node -> EventTarget) makes and tears down all of it. A hand
// init here made an instance with no Node or Document part at all.
