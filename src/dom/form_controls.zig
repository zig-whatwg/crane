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
//! Also supplies each native control's live constraint flags (HTML 4.10.21).
//! lint-impls: hook for HTMLInputElement, HTMLTextAreaElement, HTMLSelectElement, HTMLOptionElement, HTMLButtonElement, HTMLOutputElement, HTMLFieldSetElement, HTMLObjectElement

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
pub const ValidityFlags = @import("dictionaries").ValidityStateFlags;

/// The whole raw editor text after a genuine user edit, borrowed for the
/// call, and its resulting selection in UTF-16 code units.
pub const UserEdit = struct { text: []const u8, selection_start: u32, selection_end: u32 };

/// One element type's reset algorithm.
pub const Control = struct {
    /// Whether `element` is of this type.
    is: *const fn (element: *runtime.Instance) bool,
    /// The type's reset algorithm.
    reset: ?*const fn (element: *runtime.Instance) void = null,
    /// Current constraint flags, including for a barred control.
    validity_flags: ?*const fn (element: *runtime.Instance) ValidityFlags = null,
    user_edit: ?*const fn (element: *runtime.Instance, edit: UserEdit) anyerror!void = null,
    /// Owned with element.ctx.allocator; the caller must deinit the result.
    editor_text: ?*const fn (element: *runtime.Instance) anyerror!runtime.DOMString = null,
    selected_index: ?*const fn (select: *runtime.Instance) anyerror!?usize = null,
    set_selected_index: ?*const fn (select: *runtime.Instance, index: ?usize) anyerror!void = null,
};

const max_controls = 16;
var controls: [max_controls]Control = undefined;
var count: usize = 0;

/// Install `control`. Idempotent: the same brand check installs once.
pub fn install(control: Control) void {
    process_start.assertInstalling();
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
        if (control.reset) |run| if (control.is(element)) return run(element);
    }
}

/// Read the flags from the first matching type that supplies them. A type
/// can register its reset and validity algorithms in separate entries.
pub fn validityFlags(element: *runtime.Instance) ValidityFlags {
    for (controls[0..count]) |control| {
        if (control.validity_flags) |flags| if (control.is(element)) return flags(element);
    }
    return .{};
}

/// A non-IDL step: script's value/setRangeText writes have different
/// constraint effects. False asks the host to use its existing fallback.
pub fn userEdit(element: *runtime.Instance, edit: UserEdit) anyerror!bool {
    for (controls[0..count]) |control| {
        if (control.user_edit) |run| if (control.is(element)) {
            try run(element, edit);
            return true;
        };
    }
    return false;
}

/// An owned snapshot: a beforeinput listener or the following edit can
/// replace the control's buffer. A missing handler asks the host to fall back.
pub fn editorText(element: *runtime.Instance) anyerror!?runtime.DOMString {
    for (controls[0..count]) |control| {
        if (control.editor_text) |read| if (control.is(element)) return try read(element);
    }
    return null;
}

pub fn selectedIndex(select: *runtime.Instance) anyerror!?usize {
    for (controls[0..count]) |control| {
        if (control.selected_index) |read| if (control.is(select)) return read(select);
    }
    return error.NotSupported;
}

pub fn setSelectedIndex(select: *runtime.Instance, index: ?usize) anyerror!void {
    for (controls[0..count]) |control| {
        if (control.set_selected_index) |set| if (control.is(select)) return set(select, index);
    }
    return error.NotSupported;
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
    const saved_controls = controls;
    const saved_resets = test_resets;
    defer {
        count = saved;
        controls = saved_controls;
        test_resets = saved_resets;
    }
    count = 0;
    test_resets = 0;
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

test "control dispatch skips matching entries without its callback, in either order" {
    const saved_controls = controls;
    const saved_count = count;
    const saved_resets = test_resets;
    defer {
        controls = saved_controls;
        count = saved_count;
        test_resets = saved_resets;
    }
    const ValidityOnly = struct {
        fn is(_: *runtime.Instance) bool {
            return true;
        }
        fn flags(_: *runtime.Instance) @import("dictionaries").ValidityStateFlags {
            return .{ .customError = true };
        }
        fn edit(_: *runtime.Instance, _: UserEdit) !void {}
        fn text(_: *runtime.Instance) !runtime.DOMString {
            return runtime.DOMString.initDupe(std.testing.allocator, "editor");
        }
        fn selected(_: *runtime.Instance) !?usize {
            return 7;
        }
        fn setSelected(_: *runtime.Instance, index: ?usize) !void {
            try std.testing.expectEqual(@as(?usize, 7), index);
        }
    };
    var element: runtime.Instance = undefined;
    for ([_]bool{ false, true }) |validity_first| {
        count = 0;
        test_resets = 0;
        try std.testing.expectEqual(null, try editorText(&element));
        try std.testing.expectError(error.NotSupported, selectedIndex(&element));
        try std.testing.expectError(error.NotSupported, setSelectedIndex(&element, 7));
        try std.testing.expect(!try userEdit(&element, .{ .text = "x", .selection_start = 1, .selection_end = 1 }));
        const validity = Control{ .is = &ValidityOnly.is, .validity_flags = &ValidityOnly.flags, .user_edit = &ValidityOnly.edit, .editor_text = &ValidityOnly.text, .selected_index = &ValidityOnly.selected, .set_selected_index = &ValidityOnly.setSelected };
        const reset_only = Control{ .is = &testIs, .reset = &testReset };
        install(if (validity_first) validity else reset_only);
        install(if (validity_first) reset_only else validity);
        reset(&element);
        try std.testing.expectEqual(@as(usize, 1), test_resets);
        try std.testing.expect(validityFlags(&element).customError orelse false);
        try std.testing.expectEqual(@as(?usize, 7), try selectedIndex(&element));
        try setSelectedIndex(&element, 7);
        try std.testing.expect(try userEdit(&element, .{ .text = "x", .selection_start = 1, .selection_end = 1 }));
        var text = (try editorText(&element)).?;
        defer text.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("editor", text.asSlice());
    }
}
