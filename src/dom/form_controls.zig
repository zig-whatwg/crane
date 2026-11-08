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
const hook = @import("hook.zig");
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
    /// HTML user validity belongs only to input, textarea and select.
    user_validity: ?*const fn (element: *runtime.Instance) bool = null,
    set_user_validity: ?*const fn (element: *runtime.Instance, value: bool) anyerror!void = null,
    user_edit: ?*const fn (element: *runtime.Instance, edit: UserEdit) anyerror!void = null,
    /// Owned with element.ctx.allocator; the caller must deinit the result.
    editor_text: ?*const fn (element: *runtime.Instance) anyerror!runtime.DOMString = null,
    /// The text control selection over the editor text, in UTF-16 code
    /// units - also for an input whose selection APIs do not apply (email,
    /// number: HTML 4.10.5.2.10), which still has one (select() "must cause
    /// the contents of the text control to be fully selected").
    editor_selection: ?*const fn (element: *runtime.Instance) ?EditorSelection = null,
    set_editor_selection: ?*const fn (element: *runtime.Instance, selection: EditorSelection) void = null,
    has_range_limitations: ?*const fn (element: *runtime.Instance) bool = null,
    selected_index: ?*const fn (select: *runtime.Instance) anyerror!?usize = null,
    set_selected_index: ?*const fn (select: *runtime.Instance, index: ?usize) anyerror!void = null,
    has_selected_option: ?*const fn (select: *runtime.Instance) bool = null,
    set_has_selected_option: ?*const fn (select: *runtime.Instance, value: bool) anyerror!void = null,
    /// Whether this insertion also inserted the option's owning select.
    option_owner_unchanged: ?*const fn (select: *runtime.Instance) bool = null,
    /// Diagnostic seam: native tests call it; production algorithms never do.
    selection_invariant: ?*const fn (select: *runtime.Instance) bool = null,
    select_typeahead: ?*const fn (select: *runtime.Instance, text: []const u8) anyerror![]const u8 = null,
    pick_option: ?*const fn (select: *runtime.Instance, option: *runtime.Instance, toggle: bool) anyerror!void = null,
    picker_open: ?*const fn (select: *runtime.Instance) bool = null,
    set_picker_open: ?*const fn (select: *runtime.Instance, open: bool) anyerror!void = null,
    selectedcontent_interest: ?*const fn (select: *runtime.Instance) bool = null,
    set_selectedcontent_interest: ?*const fn (select: *runtime.Instance, present: bool) anyerror!void = null,
};

const max_controls = 16;
/// Process-wide, written once at start-up (hook.zig).
var controls: hook.Hook(hook.List(Control, max_controls)) = .init(.empty);

/// Install `control`. Idempotent: installing the same control again adds
/// nothing - and a control is the same only if EVERY function it names is the
/// installed one's. Two installs that share a brand check but supply other
/// algorithms are two entries, and each dispatch below takes the first entry
/// whose check accepts the element and that has the algorithm.
///
/// Not keyed by the brand check: two types may supply algorithms for one
/// predicate (HTMLSelectElement a select's validity flags, HTMLOptionElement
/// its selection model and reset), and a release build makes their two
/// checks, which have the same body, ONE function - LLVM folds identical
/// functions, so `&HTMLSelectElement.isValidationControl ==
/// &HTMLOptionElement.isSelectElement` in the ReleaseSafe runner, and keying
/// by it dropped one type's algorithms in release builds only. Folding can
/// make two predicates equal but never two whole entries that differ, so this
/// table holds what a Debug build's holds, less exact duplicates
/// (docs/lessons/debugging-equal-constants-share-one-address-in-a-release-build.md).
pub fn install(control: Control) void {
    const installed = controls.installing();
    if (installed.contains(control)) return;
    installed.append(control);
}

/// Run `element`'s reset algorithm, if its type has one installed.
pub fn reset(element: *runtime.Instance) void {
    for (controls.read().slice()) |control| {
        if (control.reset) |run| if (control.is(element)) return run(element);
    }
}

/// Read the flags from the first matching type that supplies them. A type
/// can register its reset and validity algorithms in separate entries.
pub fn validityFlags(element: *runtime.Instance) ValidityFlags {
    for (controls.read().slice()) |control| {
        if (control.validity_flags) |flags| if (control.is(element)) return flags(element);
    }
    return .{};
}

/// HTML 4.10.18.1: initially false; unsupported element types have no flag.
pub fn userValidity(element: *runtime.Instance) bool {
    for (controls.read().slice()) |control| {
        if (control.user_validity) |read| if (control.is(element)) return read(element);
    }
    return false;
}

pub fn setUserValidity(element: *runtime.Instance, value: bool) !void {
    for (controls.read().slice()) |control| {
        if (control.set_user_validity) |set| if (control.is(element)) return set(element, value);
    }
}

/// A non-IDL step: script's value/setRangeText writes have different
/// constraint effects. False asks the host to use its existing fallback.
pub fn userEdit(element: *runtime.Instance, edit: UserEdit) anyerror!bool {
    for (controls.read().slice()) |control| {
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
    for (controls.read().slice()) |control| {
        if (control.editor_text) |read| if (control.is(element)) return try read(element);
    }
    return null;
}

/// A text control selection: start and end in UTF-16 code units of the
/// editor text, and whether the focus is at the start (backward).
pub const EditorSelection = struct { start: u32, end: u32, backward: bool = false };

/// The control's text control selection (Control.editor_selection), or null
/// for an element without one.
pub fn editorSelection(element: *runtime.Instance) ?EditorSelection {
    for (controls.read().slice()) |control| {
        if (control.editor_selection) |read| if (control.is(element)) return read(element);
    }
    return null;
}

/// Set the control's text control selection (a user's caret movement).
pub fn setEditorSelection(element: *runtime.Instance, selection: EditorSelection) void {
    for (controls.read().slice()) |control| {
        if (control.set_editor_selection) |write| if (control.is(element)) return write(element, selection);
    }
}

/// HTML: whether the owner defines a minimum or maximum for this control.
pub fn hasRangeLimitations(element: *runtime.Instance) bool {
    for (controls.read().slice()) |control| {
        if (control.has_range_limitations) |read| if (control.is(element)) return read(element);
    }
    return false;
}

pub fn selectedIndex(select: *runtime.Instance) anyerror!?usize {
    for (controls.read().slice()) |control| {
        if (control.selected_index) |read| if (control.is(select)) return read(select);
    }
    return error.NotSupported;
}

pub fn setSelectedIndex(select: *runtime.Instance, index: ?usize) anyerror!void {
    for (controls.read().slice()) |control| {
        if (control.set_selected_index) |set| if (control.is(select)) return set(select, index);
    }
    return error.NotSupported;
}

pub fn pickerOpen(select: *runtime.Instance) bool {
    for (controls.read().slice()) |control| {
        if (control.picker_open) |read| if (control.is(select)) return read(select);
    }
    return false;
}

pub fn setPickerOpen(select: *runtime.Instance, open: bool) !void {
    for (controls.read().slice()) |control| {
        if (control.set_picker_open) |set| if (control.is(select)) return set(select, open);
    }
    return error.NotSupported;
}

pub fn selectedcontentInterest(select: *runtime.Instance) bool {
    for (controls.read().slice()) |control| {
        if (control.selectedcontent_interest) |read| if (control.is(select)) return read(select);
    }
    return false;
}

pub fn setSelectedcontentInterest(select: *runtime.Instance, present: bool) !void {
    for (controls.read().slice()) |control| {
        if (control.set_selectedcontent_interest) |set| if (control.is(select)) return set(select, present);
    }
    return error.NotSupported;
}

test "an element runs the reset algorithm whose brand check accepts it, installed once" {
    // The test's control: its count lives in the test, not in the product.
    const Test = struct {
        var resets: usize = 0;
        fn is(_: *runtime.Instance) bool {
            return true;
        }
        fn reset(_: *runtime.Instance) void {
            resets += 1;
        }
    };
    const override = controls.overrideForTest(.empty);
    defer override.restore();
    // Never dereferenced: nothing installed reads the element.
    var element: runtime.Instance = undefined;
    reset(&element);
    try std.testing.expectEqual(@as(usize, 0), Test.resets);
    install(.{ .is = &Test.is, .reset = &Test.reset });
    install(.{ .is = &Test.is, .reset = &Test.reset });
    try std.testing.expectEqual(@as(usize, 1), controls.get().len);
    reset(&element);
    try std.testing.expectEqual(@as(usize, 1), Test.resets);
}

test "installs that share a brand check keep their algorithms: a release build makes two types' identical checks one function" {
    // HTMLSelectElement installs a select's validity flags and
    // HTMLOptionElement its selection model and reset, each with its own
    // "is this a select" check. The two checks have the same body, and the
    // ReleaseSafe runner folds them into ONE function (nm: Debug has both
    // symbols, ReleaseSafe only the option's), so both installs arrive with
    // the same `is`. Each must keep its algorithms.
    const Test = struct {
        var resets: usize = 0;
        fn is(_: *runtime.Instance) bool {
            return true;
        }
        fn reset(_: *runtime.Instance) void {
            resets += 1;
        }
    };
    const override = controls.overrideForTest(.empty);
    defer override.restore();
    const Select = struct {
        fn flags(_: *runtime.Instance) ValidityFlags {
            return .{ .valueMissing = true };
        }
        fn selected(_: *runtime.Instance) !?usize {
            return 3;
        }
    };
    var element: runtime.Instance = undefined;
    install(.{ .is = &Test.is, .validity_flags = &Select.flags });
    install(.{ .is = &Test.is, .reset = &Test.reset, .selected_index = &Select.selected });
    try std.testing.expect(validityFlags(&element).valueMissing orelse false);
    try std.testing.expectEqual(@as(?usize, 3), try selectedIndex(&element));
    reset(&element);
    try std.testing.expectEqual(@as(usize, 1), Test.resets);
}

test "control dispatch skips matching entries without its callback, in either order" {
    const Test = struct {
        var resets: usize = 0;
        fn is(_: *runtime.Instance) bool {
            return true;
        }
        fn reset(_: *runtime.Instance) void {
            resets += 1;
        }
    };
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
        // Each order on an empty table of the test's own.
        const override = controls.overrideForTest(.empty);
        defer override.restore();
        Test.resets = 0;
        try std.testing.expectEqual(null, try editorText(&element));
        try std.testing.expectError(error.NotSupported, selectedIndex(&element));
        try std.testing.expectError(error.NotSupported, setSelectedIndex(&element, 7));
        try std.testing.expect(!try userEdit(&element, .{ .text = "x", .selection_start = 1, .selection_end = 1 }));
        const validity = Control{ .is = &ValidityOnly.is, .validity_flags = &ValidityOnly.flags, .user_edit = &ValidityOnly.edit, .editor_text = &ValidityOnly.text, .selected_index = &ValidityOnly.selected, .set_selected_index = &ValidityOnly.setSelected };
        const reset_only = Control{ .is = &Test.is, .reset = &Test.reset };
        install(if (validity_first) validity else reset_only);
        install(if (validity_first) reset_only else validity);
        reset(&element);
        try std.testing.expectEqual(@as(usize, 1), Test.resets);
        try std.testing.expect(validityFlags(&element).customError orelse false);
        try std.testing.expectEqual(@as(?usize, 7), try selectedIndex(&element));
        try setSelectedIndex(&element, 7);
        try std.testing.expect(try userEdit(&element, .{ .text = "x", .selection_start = 1, .selection_end = 1 }));
        var text = (try editorText(&element)).?;
        defer text.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("editor", text.asSlice());
    }
}

/// Select-owned summary of the options' stored selectedness, not a node cache.
pub fn hasSelectedOption(select: *runtime.Instance) bool {
    for (controls.read().slice()) |control| {
        if (control.has_selected_option) |read| if (control.is(select)) return read(select);
    }
    return false;
}

pub fn setHasSelectedOption(select: *runtime.Instance, value: bool) !void {
    for (controls.read().slice()) |control| {
        if (control.set_has_selected_option) |write| if (control.is(select)) return write(select, value);
    }
    return error.NotSupported;
}

/// The select owns the scalar insertion stamp; the option owns its bits.
pub fn optionOwnerUnchanged(select: *runtime.Instance) bool {
    for (controls.read().slice()) |control| {
        if (control.option_owner_unchanged) |read| if (control.is(select)) return read(select);
    }
    return false;
}

/// Read-only, allocation-free diagnostic. Only native tests call this hook;
/// putting the scan in a production write path would make insertion quadratic.
pub fn selectionInvariant(select: *runtime.Instance) bool {
    var found = false;
    for (controls.read().slice()) |control| {
        if (control.selection_invariant) |check| if (control.is(select)) {
            found = true;
            if (!check(select)) return false;
        };
    }
    return found;
}

/// Borrowed until the next typeahead call for this select; no script runs
/// while the caller compares it with option labels.
pub fn selectTypeahead(select: *runtime.Instance, text: []const u8) ![]const u8 {
    for (controls.read().slice()) |control| {
        if (control.select_typeahead) |run| if (control.is(select)) return run(select, text);
    }
    return error.NotSupported;
}

pub fn pickOption(select: *runtime.Instance, option: *runtime.Instance, toggle: bool) !void {
    for (controls.read().slice()) |control| {
        if (control.pick_option) |run| if (control.is(select)) return run(select, option, toggle);
    }
    return error.NotSupported;
}
