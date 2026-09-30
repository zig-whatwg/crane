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

const std = @import("std");
const runtime = @import("runtime");
const joint_history = @import("html_core").navigation.joint_history;
const navigation_api = @import("navigation_api.zig");

/// `NavigationHistoryBehavior`.
pub const HistoryBehavior = enum { auto, push, replace };

/// A navigation by target name.
pub const Request = struct {
    /// The target: "", "_self", "_parent", "_top", "_blank", or a name.
    target: []const u8,
    /// The document whose node navigable "the rules for choosing a
    /// navigable" start from, when it is not the source document's: the
    /// window open steps choose from `this`'s navigable while the entry
    /// global's document navigates (`frame.contentWindow.open(url, "_self")`
    /// called by the page navigates the frame).
    current_document: ?*runtime.Instance = null,
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
    /// The element that navigates: a hyperlink, or a form's submitter.
    source_element: ?*runtime.Instance = null,
    user_involvement: navigation_api.UserInvolvement = .none,
    /// navigate()'s navigation API state. BORROWED.
    navigation_api_state: ?joint_history.SerializedState = null,
    /// A form's submission "as entity body": the navigation's document
    /// resource. BORROWED for the call.
    post_resource: ?PostResource = null,
    /// With it, the form's entry list as a FormData, for the navigate event.
    /// BORROWED for the call.
    form_data: ?*runtime.Instance = null,
};

/// HTML "POST resource": a request body and its request content-type.
pub const PostResource = struct {
    body: []const u8,
    content_type: []const u8,
};

/// What the navigable container supplies.
pub const Implementation = struct {
    navigate_by_target: *const fn (source_document: *runtime.Instance, request: Request) void,
    follow_hyperlink: *const fn (subject: *runtime.Instance) void,
    traverse_navigable: *const fn (browsing_context: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8, from_entry_id: u64) void,
    find_by_name: *const fn (source_document: *runtime.Instance, name: []const u8) ?*runtime.Instance,
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
/// `from_entry_id` is the entry the navigable is on before the traversal -
/// the entry itself, for a reload - which the new document's
/// navigation.activation names (HTML "apply the history step" 12.1's
/// previousEntry).
pub fn traverseNavigable(browsing_context: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8, from_entry_id: u64) void {
    const impl = implementation orelse return;
    impl.traverse_navigable(browsing_context, entry_id, url, resource, from_entry_id);
}

/// HTML "find a navigable by target name" among the frames of
/// `current_document`'s page: the active window of the first whose target
/// name is `name`, or null. (The page's popups are the window open steps'
/// own to find.)
pub fn findByName(current_document: *runtime.Instance, name: []const u8) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.find_by_name(current_document, name);
}

test "without an installed implementation nothing navigates" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var element: runtime.Instance = undefined;
    navigateByTarget(&element, .{ .target = "", .url = "about:blank" });
    followHyperlink(&element);
    traverseNavigable(@ptrCast(&element), 1, "about:blank", null, 1);
    try std.testing.expect(findByName(&element, "name") == null);
}
