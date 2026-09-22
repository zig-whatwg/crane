//! Implementation for CDATASection interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CDATASection = interfaces.CDATASection;

// CDATASection inherits Text -> CharacterData -> Node -> EventTarget.
const CharacterDataImpl = @import("CharacterData.zig");

pub const State = CDATASection.State;

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
    // This was the codegen stub: calling runtime.Instance.init directly skips
    // the whole inheritance chain, so the node had no CharacterData state (its
    // data), no Node state (its node type, parent, owner document) and no
    // EventTarget state. Every one of those accesses then returned
    // InvalidStateError, which is why document.createCDATASection() never
    // produced a usable node - and why dom/common.js, which calls it during
    // setup(), errored out every dom/ranges file.
    //
    // CDATASection adds no internal state of its own, so chaining is all it needs.
    return CharacterDataImpl.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Chain to the parent that owns the state init created.
    // NOTE: do NOT call runtime.Instance.deinit() - the GC layer frees the slab.
    CharacterDataImpl.deinit(instance);
}
