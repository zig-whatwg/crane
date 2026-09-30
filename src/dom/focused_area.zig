//! HTML 6.6.2 "the focused area of the document": one focusable area in each
//! Document is designated the document's focused area.
//!
//! It is the Document's state (Document keeps it as the element
//! `activeElement` reports), and no IDL member designates it - the focusing
//! and unfocusing steps do (src/html/focus.zig). So Document installs this
//! hook from its init, and the focus algorithms reach the designation
//! through it, without importing Document.
//!
//! A focused area is recorded by its DOM anchor element, with the element's
//! slab generation (runtime.SlabAllocator.generationOf) read when it was
//! designated: a removed element can be collected while the document still
//! names it, and the generation is how a reader learns the address no longer
//! means it without touching freed state. Null is the document's viewport,
//! the focused area of a document nothing else in has the focus.
//!
//! Read it through html.focus.focusedAreaOf, which applies the focus fixup
//! rule; this hook is the raw designation.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#focused-area-of-the-document
//!
//! lint-impls: hook for Document

const std = @import("std");
const runtime = @import("runtime");

/// A designated element and its generation when it was designated.
pub const Designation = struct {
    element: *runtime.Instance,
    generation: u64,

    /// Whether the address still means the element that was designated.
    pub fn isLive(self: Designation) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.generation;
    }
};

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s focused area, or null for the viewport.
    get: *const fn (document: *runtime.Instance) ?Designation,
    /// Designate an element (null: the viewport) as `document`'s focused area.
    set: *const fn (document: *runtime.Instance, designation: ?Designation) void,
};

/// Per thread, like the documents themselves.
threadlocal var implementation: ?Implementation = null;

/// Called by Document's init. Idempotent: every call installs the same functions.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `document`'s focused area, or null for its viewport. With no Document
/// made yet nothing has been designated: the viewport.
pub fn get(document: *runtime.Instance) ?Designation {
    const impl = implementation orelse return null;
    return impl.get(document);
}

/// Designate `element` as `document`'s focused area (null: the viewport).
pub fn set(document: *runtime.Instance, element: ?*runtime.Instance) void {
    const impl = implementation orelse return;
    impl.set(document, if (element) |e| .{ .element = e, .generation = runtime.SlabAllocator.generationOf(e) } else null);
}

test "without an installed implementation a document's focused area is its viewport" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads the document.
    var document: runtime.Instance = undefined;
    try std.testing.expect(get(&document) == null);
    set(&document, null);
    try std.testing.expect(get(&document) == null);
}

test "get and set forward to the installed implementation" {
    const saved = implementation;
    defer implementation = saved;
    const Fake = struct {
        var stored: ?Designation = null;
        fn get(_: *runtime.Instance) ?Designation {
            return stored;
        }
        fn set(_: *runtime.Instance, designation: ?Designation) void {
            stored = designation;
        }
    };
    install(.{ .get = &Fake.get, .set = &Fake.set });
    var document: runtime.Instance = undefined;
    set(&document, null);
    try std.testing.expect(get(&document) == null);
    Fake.stored = .{ .element = &document, .generation = 7 };
    try std.testing.expectEqual(@as(u64, 7), get(&document).?.generation);
}
