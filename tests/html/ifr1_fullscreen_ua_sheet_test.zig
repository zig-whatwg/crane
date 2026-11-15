//! Lane ifr1: Fullscreen 5.2's user-agent rules live in a sheet of their own
//! (src/dom/style/fullscreen.css) that a document's style engine matches only
//! while the document has a fullscreen element (StyleEngine.observeFullscreen,
//! as Blink's EnsureDefaultStyleSheetForFullscreen and WebKit's on-demand
//! fullscreen sheet). These tests pin:
//! - a fullscreen element's computed style and its ::backdrop's are the rules'
//!   values - the same values as when the rules were html.css's last block;
//! - a document with no fullscreen element never matches the sheet;
//! - the decision is each document's own: a fullscreen element in a frame's
//!   document turns on that document's sheet and not its parent's.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");

fn pumpUntil(page: helpers.Page, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        const value = try page.evaluate(condition);
        defer std.testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    const value = try page.evaluate(condition);
    defer std.testing.allocator.free(value);
    std.debug.print("condition never held: {s} -> {s}\n", .{ condition, value });
    return error.ConditionNeverHeld;
}

fn expectValue(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const value = try page.evaluate(source);
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings(expected, value);
}

fn document(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

const computed =
    \\globalThis.styleOf = (e, pseudo) => {
    \\  const s = getComputedStyle(e, pseudo);
    \\  return ['position', 'top', 'right', 'bottom', 'left', 'margin-top', 'box-sizing', 'min-width', 'max-width',
    \\    'min-height', 'max-height', 'width', 'height', 'transform', 'object-fit', 'border-top-style', 'padding-top']
    \\    .map(p => p + '=' + s.getPropertyValue(p)).join(';');
    \\};
;

fn fullscreenStyles() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(computed);
    try page.run(
        \\globalThis.frame = document.body.appendChild(document.createElement('iframe'));
        \\globalThis.changed = 0;
        \\document.onfullscreenchange = () => { changed++; };
    );
    // No fullscreen element: the sheet is not matched.
    try expectValue(page, "styleOf(frame).split(';')[0]", "position=static");
    try std.testing.expect(!dom.style.engine.matchesFullscreenSheet(document(page)));
    html.user_activation.notifyActivation(document(page));
    try page.run("frame.requestFullscreen()");
    try pumpUntil(page, "changed === 1 && document.fullscreenElement === frame", 400);
    // Fullscreen 5.2's values, every !important one, the object-fit default,
    // and iframe:fullscreen's border and padding.
    try expectValue(page, "styleOf(frame)", "position=fixed;top=0px;right=0px;bottom=0px;left=0px;margin-top=0px;box-sizing=border-box;min-width=0px;max-width=none;" ++
        "min-height=0px;max-height=none;width=100%;height=100%;transform=none;object-fit=contain;border-top-style=none;padding-top=0px");
    try expectValue(page, "getComputedStyle(frame, '::backdrop').backgroundColor", "rgb(0, 0, 0)");
    try std.testing.expect(dom.style.engine.matchesFullscreenSheet(document(page)));
    // An author rule loses to the !important ones and wins over object-fit.
    try page.run(
        \\const sheet = document.head.appendChild(document.createElement('style'));
        \\sheet.textContent = 'iframe { position: absolute; object-fit: cover; border: 3px solid red }';
    );
    try expectValue(page, "[getComputedStyle(frame).position, getComputedStyle(frame).objectFit, getComputedStyle(frame).borderTopStyle].join()", "fixed,cover,none");
    try page.run("document.exitFullscreen()");
    try pumpUntil(page, "changed === 2 && document.fullscreenElement === null", 400);
    try expectValue(page, "getComputedStyle(frame).position", "absolute");
    try std.testing.expect(!dom.style.engine.matchesFullscreenSheet(document(page)));
}

test "a fullscreen element's computed style and its ::backdrop are Fullscreen 5.2's, and only while it is fullscreen" {
    try helpers.onFreshThread(fullscreenStyles);
}

fn neverWithoutFullscreen() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(computed);
    // Popovers and a modal dialog use the top layer - its revision moves -
    // with no fullscreen element: the sheet stays off.
    try page.run(
        \\document.body.innerHTML = '<div id=p popover>p</div><dialog id=d>d</dialog><span id=s>s</span>';
        \\document.getElementById('p').showPopover();
        \\document.getElementById('d').showModal();
        \\globalThis.read = styleOf(document.getElementById('s'));
    );
    try expectValue(page, "read.split(';')[0]", "position=static");
    try std.testing.expect(!dom.style.engine.matchesFullscreenSheet(document(page)));
    try page.run("document.getElementById('d').close(); document.getElementById('p').hidePopover(); read = styleOf(document.body);");
    try std.testing.expect(!dom.style.engine.matchesFullscreenSheet(document(page)));
}

test "a document with no fullscreen element never matches the fullscreen sheet, whatever its top layer holds" {
    try helpers.onFreshThread(neverWithoutFullscreen);
}

fn eachDocumentItsOwn() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.frame = document.body.appendChild(document.createElement('iframe'));
        \\frame.srcdoc = '<!doctype html><body><div id=inner>inner</div>';
        \\globalThis.loaded = false;
        \\frame.onload = () => { loaded = true; };
    );
    try pumpUntil(page, "loaded && frame.contentDocument.getElementById('inner') !== null", 400);
    const parent = document(page);
    const child = try childDocument(page);
    const inner = (try dom.selector_matching.querySelector(child, "#inner")).?;
    // The child's top layer alone gets a fullscreen element (no container
    // chain: the parent's top layer is untouched).
    const state = (try dom.top_layer.ofDocument(child, true)).?;
    _ = try state.addFullscreen(inner);
    try expectValue(page, "getComputedStyle(frame.contentDocument.getElementById('inner')).position", "fixed");
    try expectValue(page, "getComputedStyle(document.body).position", "static");
    try std.testing.expect(dom.style.engine.matchesFullscreenSheet(child));
    try std.testing.expect(!dom.style.engine.matchesFullscreenSheet(parent));
    _ = state.removeFullscreen(inner);
    try expectValue(page, "getComputedStyle(frame.contentDocument.getElementById('inner')).position", "static");
    try std.testing.expect(!dom.style.engine.matchesFullscreenSheet(child));
}

fn childDocument(page: helpers.Page) !*runtime.Instance {
    const frame = (try dom.selector_matching.querySelector(document(page), "iframe")) orelse return error.NoFrame;
    return (try @import("interfaces").HTMLIFrameElement.get_contentDocument(frame)) orelse error.NoDocument;
}

test "the fullscreen sheet is each document's own: a frame's fullscreen element does not turn on its parent's" {
    try helpers.onFreshThread(eachDocumentItsOwn);
}
