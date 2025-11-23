//! WebIDL dictionary: EventModifierInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const UIEventInit = @import("UIEventInit.zig").UIEventInit;

pub const EventModifierInit = struct {
    // Inherited from UIEventInit
    base: UIEventInit,

    ctrlKey: ?bool = null,
    shiftKey: ?bool = null,
    altKey: ?bool = null,
    metaKey: ?bool = null,
    modifierAltGraph: ?bool = null,
    modifierCapsLock: ?bool = null,
    modifierFn: ?bool = null,
    modifierFnLock: ?bool = null,
    modifierHyper: ?bool = null,
    modifierNumLock: ?bool = null,
    modifierScrollLock: ?bool = null,
    modifierSuper: ?bool = null,
    modifierSymbol: ?bool = null,
    modifierSymbolLock: ?bool = null,
};
