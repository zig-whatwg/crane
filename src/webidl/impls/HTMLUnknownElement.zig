//! Implementation for HTMLUnknownElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLElementImpl = @import("HTMLElement.zig");
const HTMLUnknownElement = interfaces.HTMLUnknownElement;

pub const State = HTMLUnknownElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to HTMLElement, exactly as HTMLDivElement and every other element
    // impl does. This was the raw codegen stub, which calls
    // `runtime.Instance.init` directly and therefore creates NO
    // HTMLElement/Element/Node/EventTarget state - so `Element.setLocalName`
    // failed with InvalidStateError and `document.createElement("foo")` threw
    // for every name the element factory does not recognise.
    //
    // The factory was already correct: it returns HTMLUnknownElement for an
    // unknown name, per DOM "create an element". The defect was here.
    //
    // Same shape as 82784123d (CDATASection, ProcessingInstruction) and the
    // AGENTS.md lesson "stub inits produce stateless nodes".
    return try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}
