//! Implementation for HTMLDivElement interface
//! Spec: https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLDivElement = interfaces.HTMLDivElement;

pub const State = HTMLDivElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// HTMLDivElement has no additional internal state beyond HTMLElement
pub const InternalState = struct {};

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLDivElement.init(ctx.allocator, ctx);
    errdefer HTMLDivElement.deinit(instance);
    return instance;
}
