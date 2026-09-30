//! HTML § 4.10.23 "Resetting a form": each resettable element's reset
//! algorithm. A form's reset() runs the reset algorithm of every resettable
//! element whose form owner is that form; what each algorithm does - clear a
//! dirty value flag, restore checkedness, pick default options - is the
//! element type's own state, and no IDL member reaches it. So each type
//! installs its algorithm here, with a brand check, and the form asks. (The
//! select element's is installed by HTMLOptionElement, which holds the whole
//! selection model: selectedness and dirtiness are the options' state.)
//!
//! Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-form-reset-control
//!
//! lint-impls: hook for HTMLInputElement, HTMLTextAreaElement, HTMLSelectElement

const std = @import("std");
const runtime = @import("runtime");

/// One element type's reset algorithm.
pub const Control = struct {
    /// Whether `element` is of this type.
    is: *const fn (element: *runtime.Instance) bool,
    /// The type's reset algorithm.
    reset: *const fn (element: *runtime.Instance) void,
};

const max_controls = 8;
threadlocal var controls: [max_controls]Control = undefined;
threadlocal var count: usize = 0;

/// Install `control`. Idempotent: the same brand check installs once.
pub fn install(control: Control) void {
    for (controls[0..count]) |*existing| {
        if (existing.is == control.is) {
            existing.* = control;
            return;
        }
    }
    if (count == max_controls) return;
    controls[count] = control;
    count += 1;
}

/// Run `element`'s reset algorithm, if its type has one installed.
pub fn reset(element: *runtime.Instance) void {
    for (controls[0..count]) |control| {
        if (control.is(element)) return control.reset(element);
    }
}

var test_resets: usize = 0;
fn testIs(_: *runtime.Instance) bool {
    return true;
}
fn testReset(_: *runtime.Instance) void {
    test_resets += 1;
}

test "an element runs the reset algorithm whose brand check accepts it, installed once" {
    const saved = count;
    defer count = saved;
    count = 0;
    // Never dereferenced: nothing installed reads the element.
    var element: runtime.Instance = undefined;
    reset(&element);
    try std.testing.expectEqual(@as(usize, 0), test_resets);
    install(.{ .is = &testIs, .reset = &testReset });
    install(.{ .is = &testIs, .reset = &testReset });
    try std.testing.expectEqual(@as(usize, 1), count);
    reset(&element);
    try std.testing.expectEqual(@as(usize, 1), test_resets);
}
