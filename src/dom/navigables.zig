//! Navigating by target name: HTML "the rules for choosing a navigable"
//! (7.3.1.7) followed by "navigate", and "follow the hyperlink" (4.6.4) on top
//! of them - what a hyperlink's activation behaviour and a form's planned
//! navigation do.
//!
//! The navigables and their navigations are the navigable containers' state
//! (an iframe's content navigable, a popup's), so the container that runs them
//! installs this hook, and the elements that navigate - `a`, `area`, `form` -
//! ask it without importing it. The shape of `navigable_container.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#the-rules-for-choosing-a-navigable
//! Spec: https://html.spec.whatwg.org/multipage/links.html#following-hyperlinks-2
//!
//! lint-impls: hook for HTMLIFrameElement

const runtime = @import("runtime");

/// `NavigationHistoryBehavior`.
pub const HistoryBehavior = enum { auto, push, replace };

/// A navigation by target name.
pub const Request = struct {
    /// The target: "", "_self", "_parent", "_top", "_blank", or a name.
    target: []const u8,
    /// The URL, parsed and serialized.
    url: []const u8,
    noopener: bool = false,
    history_behavior: HistoryBehavior = .auto,
    /// Form submission step 22: the form document had not completely loaded
    /// when the form was submitted - decided then, not when the planned
    /// navigation runs, by which time an onload handler's submission has
    /// seen the load finish. The navigation replaces if the form document
    /// is the chosen navigable's active document.
    source_not_completely_loaded: bool = false,
};

/// What the navigable container supplies.
pub const Implementation = struct {
    navigate_by_target: *const fn (source_document: *runtime.Instance, request: Request) void,
    follow_hyperlink: *const fn (subject: *runtime.Instance) void,
    traverse_navigable: *const fn (browsing_context: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8) void,
};

threadlocal var implementation: ?Implementation = null;

/// Called by the container. Idempotent: every call installs the same functions.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Whether a container has installed the implementation. It installs when
/// its first element is made; a caller on a page with none makes one first,
/// as the window open steps do for dom.auxiliary_navigables.
pub fn isInstalled() bool {
    return implementation != null;
}

/// Choose a navigable for `request.target` from `source_document`'s node
/// navigable and navigate it to `request.url`, using `source_document`.
pub fn navigateByTarget(source_document: *runtime.Instance, request: Request) void {
    const impl = implementation orelse return;
    impl.navigate_by_target(source_document, request);
}

/// HTML "follow the hyperlink created by" `subject` - an `a` or `area`
/// element - with no hyperlink suffix.
pub fn followHyperlink(subject: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.follow_hyperlink(subject);
}

/// A history traversal changes `browsing_context`'s document (an
/// `html_core` BrowsingContext): navigate it to its session history entry
/// `entry_id`, whose URL is `url`, without adding an entry - the entry takes
/// the document the navigation makes. `resource` is the entry's document
/// state's resource when it is a string (a srcdoc document's markup).
pub fn traverseNavigable(browsing_context: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8) void {
    const impl = implementation orelse return;
    impl.traverse_navigable(browsing_context, entry_id, url, resource);
}

test "without an installed implementation nothing navigates" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var element: runtime.Instance = undefined;
    navigateByTarget(&element, .{ .target = "", .url = "about:blank" });
    followHyperlink(&element);
    traverseNavigable(@ptrCast(&element), 1, "about:blank", null);
}
