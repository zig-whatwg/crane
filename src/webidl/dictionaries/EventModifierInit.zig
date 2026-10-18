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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "ctrlKey", .{ .boolean = false } },
        .{ "shiftKey", .{ .boolean = false } },
        .{ "altKey", .{ .boolean = false } },
        .{ "metaKey", .{ .boolean = false } },
        .{ "modifierAltGraph", .{ .boolean = false } },
        .{ "modifierCapsLock", .{ .boolean = false } },
        .{ "modifierFn", .{ .boolean = false } },
        .{ "modifierFnLock", .{ .boolean = false } },
        .{ "modifierHyper", .{ .boolean = false } },
        .{ "modifierNumLock", .{ .boolean = false } },
        .{ "modifierScrollLock", .{ .boolean = false } },
        .{ "modifierSuper", .{ .boolean = false } },
        .{ "modifierSymbol", .{ .boolean = false } },
        .{ "modifierSymbolLock", .{ .boolean = false } },
    };
};
