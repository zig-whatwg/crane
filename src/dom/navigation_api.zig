//! The navigation API's side of a same-document navigation (HTML 7.2.6.4
//! "update the navigation API entries for a same-document navigation"): the
//! window's `navigation` object moves its current entry, fires
//! currententrychange, disposes the entries that fell out, and settles the
//! promises of the navigate(), traverseTo(), back() and forward() calls the
//! navigation completes.
//!
//! The entries and trackers are the Navigation object's state, so Navigation
//! installs this hook, and what performs same-document navigations - History
//! (pushState, replaceState, traversal), Location and the navigable
//! container (fragment navigations) - tells it, without importing it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#update-the-navigation-api-entries-for-a-same-document-navigation
//!
//! lint-impls: hook for Navigation

const runtime = @import("runtime");

/// The NavigationType of a same-document navigation.
pub const Kind = enum { push, replace, traverse };

pub const Implementation = struct {
    same_document_navigation: *const fn (window: *runtime.Instance, kind: Kind) void,
};

threadlocal var implementation: ?Implementation = null;

/// Called by Navigation. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `window`'s navigable has made a same-document navigation of `kind`:
/// its current session history entry is the destination. Nothing happens
/// before any window has a navigation object.
pub fn sameDocumentNavigation(window: *runtime.Instance, kind: Kind) void {
    const impl = implementation orelse return;
    impl.same_document_navigation(window, kind);
}

test "without an installed implementation nothing is told" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var window: runtime.Instance = undefined;
    sameDocumentNavigation(&window, .push);
}
