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
    /// `document`'s sequential focus navigation starting point (HTML 6.6.5):
    /// the live Range the document keeps for it (`selectStart`), or null
    /// before any element of the document was focused.
    start_range: ?*const fn (document: *runtime.Instance) ?*runtime.Instance = null,
    /// Make the starting point select the contents of `node`, a node of
    /// `document`: the document's one Range for it, made on first use.
    select_start: ?*const fn (document: *runtime.Instance, node: *runtime.Instance) void = null,
    /// Unset the starting point: `start_range` answers null until the next
    /// `select_start`.
    clear_start: ?*const fn (document: *runtime.Instance) void = null,
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
    // The Accessibility agents' focus events (one inline check while no
    // DevTools agent is enabled).
    const inspector_probes = @import("inspector_probes.zig");
    if (inspector_probes.active()) inspector_probes.focusedAreaChanged(document);
    // HTML 6.6.5: "the user agent may set" the sequential focus navigation
    // starting point. A newly focused element is it from here on, and the
    // viewport taking the focus leaves it where it was - so Tab after the
    // focused element is blurred, disabled or removed continues from where
    // it was. Chrome 157 and Firefox 160 pass every one of those cases of
    // html/interaction/focus/sequential-focus-navigation-starting-
    // point.tentative.html (wpt.fyi 4786307730243584, 4877168468033536;
    // Safari 27.2 fails the removed and blurred ones). Blink keeps the point
    // as a live Range on the Document, selecting the focused element's
    // contents (Document::SetSequentialFocusNavigationStartingPoint, called
    // from SetFocusedElement), which the DOM's removal steps move to where a
    // removed element was; `selectStart` is that range.
    if (element) |e| moveStartPoint(document, e);
    // The focus fixup runs at the next rendering opportunity: a focused
    // element asks for one, and its document is watched
    // (dom.update_the_rendering).
    @import("update_the_rendering.zig").focusedAreaChanged(document, element);
}

/// `document`'s sequential focus navigation starting point (HTML 6.6.5): its
/// live Range (`set`), or null when it has none. Read by html.focus's
/// sequential navigation, which takes the point from the range's boundary
/// points.
pub fn startRange(document: *runtime.Instance) ?*runtime.Instance {
    const impl = implementation.get() orelse return null;
    const start_range = impl.start_range orelse return null;
    return start_range(document);
}

/// HTML "move the sequential focus navigation starting point to" `node`, a
/// node of `document`, without focusing it ("potentially reset the focus"
/// step 12, after a focusing step whose fallback was the viewport). The
/// Document itself is the start of its own tree, which an unset point
/// already means (6.6.5 "sequential navigation" step 1).
pub fn moveStartPoint(document: *runtime.Instance, node: *runtime.Instance) void {
    if (node == document) return unsetStartPoint(document);
    const impl = implementation.get() orelse return;
    if (impl.select_start) |select_start| select_start(document, node);
}

/// HTML "unset the sequential focus navigation starting point" of `document`
/// (6.6.5 "sequential navigation" step 7: no candidate was found from it).
pub fn unsetStartPoint(document: *runtime.Instance) void {
    const impl = implementation.get() orelse return;
    if (impl.clear_start) |clear_start| clear_start(document);
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
