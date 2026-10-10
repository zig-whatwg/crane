//! Declarative shadow roots: the HTML parser's attach step (HTML "in head", a
//! start tag whose tag name is "template", step 7.11) and the shadow root
//! flags it sets, which have no IDL member.
//!
//! The parser attaches through DOM attach-a-shadow-root
//! (custom_elements.attachShadow, which Element installs), then sets the new
//! root's "available to element internals" and "declarative" to true and, for
//! a shadowrootcustomelementregistry attribute, its "keep custom element
//! registry null". DOM attach-a-shadow-root step 4 reads and clears
//! "declarative" when script attaches to a declarative host. The ShadowRoot
//! impl owns those flags and installs their steps here.
//!
//! lint-impls: hook for ShadowRoot
const runtime = @import("runtime");
const dictionaries = @import("dictionaries");
const process_start = @import("process_start.zig");
const custom_elements = @import("custom_elements.zig");

pub const Implementation = struct {
    /// The parser's step 7.11.4-7.11.7 flags on a root it just attached.
    mark_declarative: *const fn (shadow: *runtime.Instance, keep_registry_null: bool) void,
    is_declarative: *const fn (shadow: *runtime.Instance) bool,
    set_declarative: *const fn (shadow: *runtime.Instance, value: bool) void,
};

// process-wide: immutable function pointers installed once at process start by the ShadowRoot impl; the flags they set live on each shadow root
var implementation: ?Implementation = null;

/// Called by ShadowRoot's installHooks, once, at process start.
pub fn install(steps: Implementation) void {
    process_start.assertInstalling();
    implementation = steps;
}

/// What a declarative shadow root's template start tag asks for (steps
/// 7.4-7.9 and 7.11.1).
pub const Request = struct {
    mode: @import("enums").ShadowRootMode,
    delegates_focus: bool = false,
    serializable: bool = false,
    slot_assignment: @import("enums").SlotAssignmentMode = ._named_,
    clonable: bool = false,
    /// A shadowrootcustomelementregistry attribute: the root's registry is
    /// null and stays null (7.11.1, 7.11.7).
    keep_registry_null: bool = false,
};

/// Step 7.11: attach a shadow root to `host` with `request` and mark it
/// declarative. `registry` is 7.11.1's: null for a
/// shadowrootcustomelementregistry attribute, else the host's node
/// document's registry. An error is the "if an exception is thrown" branch -
/// the caller inserts the template instead.
pub fn attach(host: *runtime.Instance, request: Request, registry: ?*runtime.Instance) !*runtime.Instance {
    const steps = implementation orelse return error.InvalidStateError;
    const init: dictionaries.ShadowRootInit = .{
        .mode = request.mode,
        .delegatesFocus = request.delegates_focus,
        .slotAssignment = request.slot_assignment,
        .clonable = request.clonable,
        .serializable = request.serializable,
    };
    const shadow = try custom_elements.attachShadow(host, init, if (request.keep_registry_null) null else registry);
    // Steps 7.11.4, 7.11.5 and 7.11.7.
    steps.mark_declarative(shadow, request.keep_registry_null);
    return shadow;
}

/// DOM attach-a-shadow-root step 4.2: whether `shadow` is declarative.
pub fn isDeclarative(shadow: *runtime.Instance) bool {
    const steps = implementation orelse return false;
    return steps.is_declarative(shadow);
}

/// DOM attach-a-shadow-root step 4.4: set `shadow`'s declarative to `value`.
pub fn setDeclarative(shadow: *runtime.Instance, value: bool) void {
    const steps = implementation orelse return;
    steps.set_declarative(shadow, value);
}

test "with no implementation installed, nothing is declarative and attach fails" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var node: runtime.Instance = undefined;
    try std.testing.expect(!isDeclarative(&node));
    try std.testing.expectError(error.InvalidStateError, attach(&node, .{ .mode = ._open_ }, null));
}
