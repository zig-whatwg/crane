//! Final teardown's sweeps of per-type side tables - a Browser's (instances
//! B1: every table is a side table of the Browser's runtime.BrowserScope,
//! and a sweep frees that Browser's entries only, never another's).
//!
//! A node in its document when its realm ends is torn down by the realm's
//! tree walk, through its own deinit (Node.deinitNodeByType dispatches on
//! the vtable). What reaches the browser's end is what no exit reached: a
//! node removed from its tree while script held no wrapper of it, or whose
//! wrapper was collected while it was still in a tree - nothing frees such an
//! orphan (node lifetime: the tree traced both ways is the fix). By then its
//! realm is gone, so each type's sweep frees what is left of its side table
//! wholesale, never through a deinit, which would read the instance's freed
//! context. Every type with a side table installs its sweep here (once, at
//! process start: its installHooks), in its `Phase`, and the Browser's end
//! runs every installed sweep over its scope (Browser.deinit, before its
//! agent ends) without naming any type - this was impls/cleanup.zig, which
//! imported eleven impls (impls-boundary design 5.3).
//!
//! The node registries' sweeps (EventTarget, HTMLScriptElement, HTMLElement,
//! Element, Text, Comment, DocumentType, DocumentFragment, CharacterData,
//! Node, Document) free their InternalStates' own memory. The other sweeps,
//! and why (counted at leaks3's tip over the forms, dom/ranges and
//! one-in-four-sample files, 2,881, 2026-10-05):
//! - ProcessingInstruction: an orphaned PI's target (17 freed).
//! - HTMLTextAreaElement, HTMLOptionElement: their state maps fill lazily and
//!   their init frees an entry it finds at the new address, so no entry may
//!   outlive its browser - the allocator its values came from goes with it
//!   (0 entries left at the end: the boundary, not a leak).
//! - HTMLSlotElement: an orphaned slot's SlotState - its name and its
//!   assigned and manually assigned nodes' buffers (64 freed in
//!   shadow-dom/declarative/declarative-shadow-dom-attachment.html, whose
//!   attachShadow calls orphan each declarative root's slot, 2026-10-10).
//! - HTMLImageElement: an img whose slot was freed without its deinit keeps
//!   its requests' URLs, image data and decode() promises (lane imgdec,
//!   tests/html/image_fetch_detach_test.zig).
//! HTMLInputElement's sweep retired with the vtable dispatch: an input in a
//! document is deinit'd by its tree, and none was left at the end (0 of 0).
//!
//! - SVGScriptElement (with HTMLScriptElement's): an orphaned SVG script's
//!   script text (lane fraginert: one per `<svg><script>` dropped by
//!   innerHTML = '' while unwrapped, crane/san-svg-detach-*).
//! - Every node type whose own state owns something (lane orphanleak,
//!   dom.orphan_states, held by tools/lint_refcount.zig's state rules):
//!   HTMLFieldSetElement, HTMLButtonElement, HTMLSelectElement,
//!   HTMLOutputElement, HTMLObjectElement, HTMLInputElement (custom
//!   validity, an output's default value, an input's value), HTMLFormElement
//!   (named elements, past names, pending navigations), HTMLSourceElement
//!   (its URL), HTMLMediaElement and HTMLTrackElement (their whole state,
//!   which queued tasks may outlive the element with), ShadowRoot (its
//!   adopted style sheets' hold), HTMLIFrameElement (cached attribute
//!   strings) and Attr (its names and value). An orphaned fieldset, source,
//!   audio or video leaked its block on every parsed tree dropped unwrapped
//!   (crane/cl-orphan-*).
//!
//! lint-impls: hook for EventTarget, HTMLScriptElement, SVGScriptElement, HTMLElement, Element, HTMLTextAreaElement, HTMLOptionElement, ProcessingInstruction, HTMLSlotElement, HTMLImageElement, Text, Comment, DocumentType, DocumentFragment, CharacterData, Node, Document, Attr, HTMLButtonElement, HTMLFieldSetElement, HTMLFormElement, HTMLIFrameElement, HTMLInputElement, HTMLMediaElement, HTMLObjectElement, HTMLOutputElement, HTMLSelectElement, HTMLSourceElement, HTMLTrackElement, ShadowRoot

const std = @import("std");
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

/// Frees every entry of one type's side table in `scope` - one Browser's.
pub const Sweep = *const fn (scope: *runtime.BrowserScope) void;

/// When a sweep runs, in this order - the order impls/cleanup.zig encoded:
/// event targets first, while the agent lives, so their listeners' engine
/// values are released; then each type's state before its bases' (the most
/// derived first), so no base's sweep frees what a derived type's state
/// still reads; the Document's last.
pub const Phase = enum {
    /// EventTarget: listeners and event handlers.
    event_targets,
    /// HTMLScriptElement.
    script_elements,
    /// HTMLElement.
    html_elements,
    /// Element.
    elements,
    /// Element types with side tables of their own (an option's
    /// selectedness, a textarea's raw value, a slot's assigned nodes) and
    /// ProcessingInstruction's target.
    element_types,
    /// Text, Comment, DocumentType, DocumentFragment.
    node_types,
    /// CharacterData.
    character_data,
    /// Node: the NodeBases.
    nodes,
    /// Document.
    documents,
};
const phase_count = @typeInfo(Phase).@"enum".field_names.len;

/// Room per phase: `.element_types` holds a sweep per node type whose state
/// has one (dom.orphan_states), eighteen since lane orphanleak.
const max_sweeps = 32;
var sweeps: [phase_count][max_sweeps]Sweep = undefined;
var count: [phase_count]usize = @splat(0);

/// Install `sweep` in `phase`. Idempotent: the same function installs once.
pub fn install(phase: Phase, sweep: Sweep) void {
    process_start.assertInstalling();
    const p = @intFromEnum(phase);
    for (sweeps[p][0..count[p]]) |existing| {
        if (existing == sweep) return;
    }
    if (count[p] == max_sweeps) @panic("dom.teardown_sweeps: a phase has room for 32 sweeps");
    sweeps[p][count[p]] = sweep;
    count[p] += 1;
}

/// Run every installed sweep over `scope`, phase by phase, each phase's in
/// installation order: `scope`'s Browser ends. Before its agent ends.
pub fn runAll(scope: *runtime.BrowserScope) void {
    for (0..phase_count) |p| {
        for (sweeps[p][0..count[p]]) |sweep| sweep(scope);
    }
}

var test_sweeps: usize = 0;
fn testSweep(_: *runtime.BrowserScope) void {
    test_sweeps += 1;
}

test "an installed sweep runs once per runAll, however often it was installed" {
    const saved = count;
    defer count = saved;
    count = @splat(0);
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    runAll(&scope);
    try std.testing.expectEqual(@as(usize, 0), test_sweeps);
    install(.nodes, &testSweep);
    install(.nodes, &testSweep);
    runAll(&scope);
    try std.testing.expectEqual(@as(usize, 1), test_sweeps);
}
