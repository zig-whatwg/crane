//! A form's algorithms that other code invokes (HTML § 4.10.22 -
//! § 4.10.23, § 4.10.3): "submit" a form from a submitter, "reset" a form,
//! "construct the entry list", and the past names map's removal rule. A
//! submit button's activation behaviour submits its form owner; a reset
//! button's resets it; FormData's constructor constructs a form's entry
//! list; a mutation anywhere in a tree can give an element of a form's past
//! names map another form owner (html.form_past_names). None of them is an
//! IDL member (requestSubmit() and reset() add steps of their own), and the
//! state they run on - the form's constructing-entry-list and
//! firing-submission-events flags, its planned navigation, its past names
//! map - is the form's. HTMLFormElement installs them here when a form is
//! made, which is before anyone can hold one.
//!
//! Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-form-submit
//!
//! lint-impls: hook for HTMLFormElement

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// HTML "user navigation involvement" of a submission.
pub const UserInvolvement = enum { none, activation, browser_ui };

/// A change that may have given an element another form owner (HTML
/// "reset the form owner" triggers, § 4.10.18.3), as html.form_past_names
/// reports it to a form whose past names map has entries.
pub const OwnerChange = union(enum) {
    /// `node` was inserted, removed or moved; the tree is in its new shape.
    subtree: *runtime.Instance,
    /// `element`'s `form` attribute was set, changed or removed.
    form_attribute: *runtime.Instance,
    /// An `id` attribute changed: the first element with an ID a form
    /// attribute names may be another.
    id_attribute,
    /// The parser recorded `element`'s form association.
    association: *runtime.Instance,
};

/// What the HTMLFormElement impl supplies.
pub const Implementation = struct {
    /// Submit `form` from `submitter` (a submit button, or `form` itself),
    /// with "submitted from submit() method" false.
    submit: *const fn (form: *runtime.Instance, submitter: *runtime.Instance, user_involvement: UserInvolvement) anyerror!void,
    /// Reset `form`.
    reset: *const fn (form: *runtime.Instance) anyerror!void,
    /// Construct the entry list of `form` with `submitter`, and append a
    /// clone of it to `form_data` - FormData(form, submitter)'s steps 1.1-1.4:
    /// TypeError for a submitter that is not a submit button, NotFoundError
    /// for one whose form owner is not `form`, InvalidStateError while `form`
    /// is already constructing its entry list.
    construct_entry_list: *const fn (form: *runtime.Instance, submitter: ?*runtime.Instance, form_data: *runtime.Instance) anyerror!void,
    /// HTML "the form element": "If an element listed in a form element's
    /// past names map changes form owner, then its entries must be removed
    /// from that map." Remove each entry of `form` whose element `change`
    /// gave another owner; answer whether `form` still has entries.
    past_names_owner_change: *const fn (form: *runtime.Instance, change: OwnerChange) bool,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by HTMLFormElement's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Submit `form` from `submitter`.
pub fn submit(form: *runtime.Instance, submitter: *runtime.Instance, user_involvement: UserInvolvement) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.submit(form, submitter, user_involvement);
}

/// Reset `form`.
pub fn reset(form: *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.reset(form);
}

/// Remove `form`'s past names whose element `change` gave another form
/// owner; whether `form` still has some. None without an implementation.
pub fn pastNamesOwnerChange(form: *runtime.Instance, change: OwnerChange) bool {
    const impl = implementation orelse return false;
    return impl.past_names_owner_change(form, change);
}

/// Construct `form`'s entry list with `submitter` into `form_data`.
pub fn constructEntryList(form: *runtime.Instance, submitter: ?*runtime.Instance, form_data: *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.construct_entry_list(form, submitter, form_data);
}

test "without an installed implementation every algorithm reports NotSupported" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the calls do not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, submit(&object, &object, .none));
    try std.testing.expectError(error.NotSupported, reset(&object));
    try std.testing.expectError(error.NotSupported, constructEntryList(&object, null, &object));
    // The default: no form keeps past names.
    try std.testing.expect(!pastNamesOwnerChange(&object, .id_attribute));
}
