//! WebIDL dictionary: MutationObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MutationObserverInit = struct {
    childList: ?bool = null,
    attributes: ?bool = null,
    characterData: ?bool = null,
    subtree: ?bool = null,
    attributeOldValue: ?bool = null,
    characterDataOldValue: ?bool = null,
    attributeFilter: ?[]const runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "childList", .{ .boolean = false } },
        .{ "subtree", .{ .boolean = false } },
    };
};
