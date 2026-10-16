//! HTML's state-dependent selector semantics, installed by HTMLElement.
//! The selector module stays below HTML and asks through this seam.
//! lint-impls: hook for HTMLElement
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

pub const Kind = union(enum) {
    any_link,
    visited,
    enabled,
    disabled,
    checked,
    indeterminate,
    default,
    valid,
    invalid,
    required,
    optional,
    in_range,
    out_of_range,
    read_only,
    read_write,
    placeholder_shown,
    autofill,
    user_valid,
    user_invalid,
    open,
    popover_open,
    modal,
    playing,
    paused,
    seeking,
    buffering,
    stalled,
    muted,
    volume_locked,
    dir_ltr,
    dir_rtl,
    heading: u6,
    /// HTML 4.16.3 :hover and :active, through the states a Document keeps
    /// for them (dom.pointer_states).
    hover,
    active,
};
pub const Implementation = struct {
    matches: *const fn (*runtime.Instance, Kind) bool,
    popover_showing: *const fn (*runtime.Instance) bool,
};
// process-wide: HTMLElement installs immutable function pointers once at process start, shared by all Browsers and threads
var implementation: ?Implementation = null;

pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

pub fn matches(element: *runtime.Instance, which: Kind) bool {
    return (implementation orelse return false).matches(element, which);
}

pub fn popoverShowing(element: *runtime.Instance) bool {
    return (implementation orelse return false).popover_showing(element);
}
