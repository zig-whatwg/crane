//! HTML 6.6.2 "the focused area of the document": one focusable area in each
//! Document is designated the document's focused area.
//!
//! It is the Document's state (Document keeps it as the element
//! `activeElement` reports), and no IDL member designates it - the focusing
//! and unfocusing steps do (src/html/focus.zig). So Document installs this
//! hook from its installHooks, and the focus algorithms reach the designation
//! through it, without importing Document.
//!
//! A focused area is recorded by its DOM anchor element, with the element's
//! slab generation (runtime.SlabAllocator.generationOf) read when it was
//! designated: a removed element can be collected while the document still
//! names it, and the generation is how a reader learns the address no longer
//! means it without touching freed state. Null is the document's viewport,
//! the focused area of a document nothing else in has the focus.
//!
//! Designation reads use html.focus.designatedAreaOf's liveness/connection
//! checks. focusedAreaOf applies update-the-rendering step 17's focus fixup
//! (the integrator's Q34 patch); this hook is the raw designation.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#focused-area-of-the-document
//!
//! lint-impls: hook for Document

const std = @import("std");
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;
const runtime = @import("runtime");

/// A designated element and its generation when it was designated.
pub const Designation = struct {
    element: *runtime.Instance,
    generation: u64,

    /// Whether the address still means the element that was designated. A
    /// weak link (refcount step 5i: a document's focused area never counts):
    /// once weak references see garbage, an element of a garbage tree reads
    /// as gone too (dom.refcount.weakLinkLive).
    pub fn isLive(self: Designation) bool {
        return @import("refcount.zig").weakLinkLive(self.element, self.generation);
    }
};

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s focused area, or null for the viewport.
    get: *const fn (document: *runtime.Instance) ?Designation,
    /// Designate an element (null: the viewport) as `document`'s focused area.
    set: *const fn (document: *runtime.Instance, designation: ?Designation) void,
    /// `document`'s sequential focus navigation starting point (HTML 6.6.5),
    /// when one is kept apart from the focused area; and setting it.
    get_start: ?*const fn (document: *runtime.Instance) ?Designation = null,
    set_start: ?*const fn (document: *runtime.Instance, start: ?Designation) void = null,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: Hook(?Implementation) = .init(null);

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// `document`'s focused area, or null for its viewport. With no Document
/// made yet nothing has been designated: the viewport.
pub fn get(document: *runtime.Instance) ?Designation {
    const impl = implementation.get() orelse return null;
    return impl.get(document);
}

/// Designate `element` as `document`'s focused area (null: the viewport).
pub fn set(document: *runtime.Instance, element: ?*runtime.Instance) void {
    const impl = implementation.get() orelse return;
    impl.set(document, if (element) |e| .{ .element = e, .generation = runtime.SlabAllocator.generationOf(e) } else null);
    // A new focused area is the starting point from here on: one kept apart
    // (`setStartPoint`) is dropped.
    if (impl.set_start) |set_start| set_start(document, null);
    // The focus fixup runs at the next rendering opportunity: a focused
    // element asks for one, and its document is watched
    // (dom.update_the_rendering).
    @import("update_the_rendering.zig").focusedAreaChanged(document, element);
}

/// HTML 6.6.5 "sequential focus navigation starting point", kept apart from
/// the focused area: `element` - the element the focus fixup just took the
/// focus from, still in the tree - so that the next sequential navigation
/// continues from where it was ("the user agent may set it"; Blink keeps its
/// starting point where the focused element was, Document::
/// SetSequentialFocusNavigationStartingPoint; Gecko continues from the
/// element too). Any later change of the focused area drops it (`set`).
pub fn setStartPoint(document: *runtime.Instance, element: *runtime.Instance) void {
    const impl = implementation.get() orelse return;
    const set_start = impl.set_start orelse return;
    set_start(document, .{ .element = element, .generation = runtime.SlabAllocator.generationOf(element) });
}

/// The starting point `setStartPoint` kept, or null.
pub fn startPoint(document: *runtime.Instance) ?Designation {
    const impl = implementation.get() orelse return null;
    const get_start = impl.get_start orelse return null;
    return get_start(document);
}

test "without an installed implementation a document's focused area is its viewport" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    // Never dereferenced: with no implementation nothing reads the document.
    var document: runtime.Instance = undefined;
    try std.testing.expect(get(&document) == null);
    set(&document, null);
    try std.testing.expect(get(&document) == null);
}

test "get and set forward to the installed implementation" {
    const override = implementation.overrideForTest(implementation.get());
    defer override.restore();
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
