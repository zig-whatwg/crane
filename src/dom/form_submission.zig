//! A form's algorithms that other element types invoke (HTML § 4.10.22 -
//! § 4.10.23): "submit" a form from a submitter, "reset" a form, and
//! "construct the entry list". A submit button's activation behaviour
//! submits its form owner; a reset button's resets it; FormData's
//! constructor constructs a form's entry list. None of them is an IDL member
//! (requestSubmit() and reset() add steps of their own), and the state they
//! run on - the form's constructing-entry-list and firing-submission-events
//! flags, its planned navigation - is the form's. HTMLFormElement installs
//! them here when a form is made, which is before anyone can hold one.
//!
//! Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-form-submit
//!
//! lint-impls: hook for HTMLFormElement

const std = @import("std");
const runtime = @import("runtime");

/// HTML "user navigation involvement" of a submission.
pub const UserInvolvement = enum { none, activation, browser_ui };

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
};

/// Per thread, like the forms themselves.
threadlocal var implementation: ?Implementation = null;

/// Called by the HTMLFormElement impl. Idempotent.
pub fn install(impl: Implementation) void {
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
}
