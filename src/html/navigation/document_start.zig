//! A Browser's document-start host script hook: told synchronously when a
//! new document's Window realm is set up for it and before the document's
//! parser runs any of its scripts, so a host can run script of its own there
//! first (lane life1, for lane cdph's CDP Page.addScriptToEvaluateOnNewDocument,
//! main world and named worlds; and what an extension's document_start
//! content scripts need).
//!
//! The point is Blink's: LocalFrame's main world context is created for the
//! new document (LocalWindowProxy::Initialize ->
//! LocalFrameClient::DidCreateScriptContext), and
//! probe::DidCreateMainWorldContext reaches InspectorPageAgent::
//! DidCreateMainWorldContext (third_party/blink/renderer/core/inspector/
//! inspector_page_agent.cc, BSD-3), which evaluates the scripts the client
//! registered - in the main world, and in each named isolated world it makes
//! for the frame first - before the parser runs the document's own. Reproduced
//! as a hook, not copied. Crane's point: the document factory, once the new
//! document is its Window's associated Document and its navigable's active
//! document, before its parser is made (HTMLIFrameElement
//! createNavigationDocument; an initial about:blank document's in
//! createDocumentForIframe) - right after the navigation observer's
//! `committed` (observer.zig), whose notify runs no script.
//!
//! Unlike the observer this hook MAY run script, and make world realms in the
//! document's agent. Script it runs may take the navigable away (remove its
//! frame, navigate it): the commit goes on as it does after any of the
//! document's own scripts. ONE slot per Browser (`Navigables.document_start`),
//! which the Browser sets to its own dispatcher and fans out from. Generic:
//! compiled in with or without CDP.
const std = @import("std");
const browsing_context = @import("../window/browsing_context.zig");
const observer = @import("observer.zig");

const Navigables = browsing_context.Navigables;

/// One new document, as the hook is told of it. BORROWED for the call.
pub const Start = struct {
    /// The navigable whose active document it is (its browsing context id).
    navigable_id: u64,
    /// The navigation that made it (navigate step 7's navigation ID, the
    /// observer's navigation_id; CDP's loaderId), 0 for an initial
    /// about:blank document.
    navigation_id: u64,
    /// The new document's Window realm - a `runtime.Context`, opaque here
    /// (html_core is engine-free): where its main world's scripts run, and
    /// whose agent a world realm for the document is made in.
    realm: *anyopaque,
    /// The document, by identity and slab generation.
    document: observer.DocumentRef,
    /// Its URL.
    url: []const u8,
};

/// The Browser's hook (`Navigables.document_start`).
pub const Hook = struct {
    context: *anyopaque,
    run: *const fn (context: *anyopaque, start: *const Start) void,
};

/// Run `navigables`' document-start hook, if it has one.
pub fn run(navigables: ?*const Navigables, start: Start) void {
    const list = navigables orelse return;
    const hook = list.document_start orelse return;
    hook.run(hook.context, &start);
}
