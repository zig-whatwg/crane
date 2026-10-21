//! HTML 6.6.7 autofocus insertion and candidate flushing. The Document owns
//! the queue; the browser schedules a rendering opportunity independently of
//! requestAnimationFrame. No getter or insertion synchronously moves focus.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const focus = @import("focus.zig");

/// HTML autofocus insertion steps. The caller already checked the attribute.
pub fn inserted(element: *runtime.Instance) void {
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    // Step 1 permits a user override; no such override is configured.
    // Steps 2–4.
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return;
    if (dom.document_scripts.activeSandboxingFlags(document).automatic_features) return;
    // Step 5: HTML allow focus (self-origin default and transient activation).
    if (!focus.allowFocusSteps(document)) return;
    // Steps 6–7. Candidate order is insertion history, not tree order:
    // WebKit Document::appendAutofocusCandidate likewise removes then appends
    // (Source/WebCore/dom/Document.cpp). first-reconnected.html passes in
    // Chrome/Firefox/Safari, wpt.fyi revision 5d23b743bb.
    const top_document = topDocumentOf(document) orelse return;
    const state = dom.document_autofocus.ensureForDocument(top_document) orelse return;
    if (state.processed) return;
    state.append(top_document.ctx.allocator, top_document, element) catch return;
    dom.window_documents.requestRendering(top_document);
}

/// HTML "flush autofocus candidates", called at update-rendering step 7.
pub fn flush(top_document: *runtime.Instance) void {
    const state = dom.document_autofocus.ofDocument(top_document) orelse return;
    // Steps 1–3.
    if (!state.hasCandidates()) return;
    // Step 4. Designation is observed without causing focus fixup. Chrome and
    // Firefox pass focusable-area-in-top-document.html; WebKit omits this
    // focused-area check. Follow the spec and the majority (5d23b743bb).
    // A fragment target remains set after removal: whatwg/html#1370 made
    // it sticky in 2016. Chrome ships that newer rule (1/1); Firefox/Safari
    // still focus after removal (0/1). Keep the newer spec (row111 Q11).
    if (focus.designatedAreaOf(top_document) != null or dom.target_element.get(top_document) != null) {
        state.complete();
        return;
    }
    // Step 5.
    while (state.first) |first| {
        const element = first.element.get() orelse {
            state.takeFirst().?.release();
            continue;
        };
        // Steps 5.2–5.4. Adoption must be tested against the current document.
        const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse {
            state.takeFirst().?.release();
            continue;
        };
        if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document)) or
            topDocumentOf(document) != top_document)
        {
            state.takeFirst().?.release();
            continue;
        }
        // Step 5.5: preserve the best candidate until its stylesheets unblock.
        if (dom.document_scripts.hasStyleSheetBlockingScripts(document)) return;
        // Step 5.6. Keep this candidate independently of Document state while
        // focusing can run script, empty the list, or tear down the realm.
        const candidate = state.takeFirst().?;
        defer candidate.release();
        // Steps 5.7–5.8.
        if (ancestorHasTarget(document)) continue;
        // Steps 5.9–5.10.
        const target = if (focus.isFocusableArea(element)) element else focus.getFocusableArea(element, .other) orelse continue;
        // Step 5.11: set the flag before script can insert another candidate.
        state.complete();
        focus.focusingSteps(target, null, .other);
        return; // Never read Document state after invoking script.
    }
}

fn ancestorHasTarget(document: *runtime.Instance) bool {
    var current = document;
    while (true) {
        if (dom.target_element.get(current) != null) return true;
        const container = focus.containerOf(current) orelse return false;
        current = (interfaces.Node.get_ownerDocument(container) catch null) orelse return false;
    }
}

/// Dialog focusing steps 7–10, after control's focusing steps have run.
pub fn completeForDialog(control: *runtime.Instance) void {
    const document = (interfaces.Node.get_ownerDocument(control) catch null) orelse return;
    const top_document = topDocumentOf(document) orelse return;
    if (!sameOrigin(document, top_document)) return;
    const state = dom.document_autofocus.ensureForDocument(top_document) orelse return;
    state.complete();
}

/// The active Document of this document's node navigable's top traversable.
/// Use the navigable tree directly, without imposing a DOM nesting limit.
fn topDocumentOf(document: *runtime.Instance) ?*runtime.Instance {
    // A removed frame, a retired realm, or an engine-free document has no
    // node navigable. Never treat such a document as its own traversable.
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
    const navigable = dom.browser_state.browsingContextOf(window) orelse return null;
    if (navigable.is_closed or navigable.orphaned or
        navigable.active_document != @as(?*anyopaque, @ptrCast(document))) return null;
    return @ptrCast(@alignCast(navigable.getTop().getActiveDocument() orelse return null));
}

/// Same-origin compares opaque origin identity as well as serialized tuples.
pub fn sameOrigin(a: *runtime.Instance, b: *runtime.Instance) bool {
    if (a == b) return true;
    const left = (dom.document_origin.shareable(a) catch null) orelse return false;
    const right = (dom.document_origin.shareable(b) catch null) orelse return false;
    return dom.origin_record.sameOrigin(.{ .record = left, .serialized = left.serialized orelse "null" }, .{ .record = right, .serialized = right.serialized orelse "null" });
}
