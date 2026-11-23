//! A tab's system focus (HTML 6.6.2) is its scope's (runtime.TabScope;
//! lane tab1, the user's ruling 2026-11-19 "Host decides, headless
//! default"): every tab has it until the host narrows focus to its active
//! tab, and a tab without it is what a page sees: document.hasFocus() false
//! (has focus steps step 2), no currently focused area (step 1) so nothing
//! matches :focus, and - as all three browsers do - focus() still designates
//! the element, firing nothing (Blink Document::SetFocusedElement and WebKit
//! Document::setFocusedElement dispatch only while the page's focus
//! controller is focused; Gecko nsFocusManager::SetFocusInner only "if the
//! element is in the active window"). Losing it fires blur at the focused
//! element and then at its Window; regaining it, focus at the Window and
//! then at the element (Blink FocusController
//! DispatchEventsOnWindowAndFocusedElement, WebKit's the same) - each a task.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const fixture_mod = @import("inst2_tabs_fixture.zig");

const Fixture = fixture_mod.Fixture;

const listeners =
    \\globalThis.log = [];
    \\globalThis.input = document.createElement('input');
    \\document.body.appendChild(input);
    \\input.addEventListener('focus', () => log.push('focus'));
    \\input.addEventListener('blur', () => log.push('blur'));
    \\input.addEventListener('focusin', () => log.push('focusin'));
    \\input.addEventListener('focusout', () => log.push('focusout'));
    \\addEventListener('focus', e => { if (e.target === window) log.push('window-focus'); });
    \\addEventListener('blur', e => { if (e.target === window) log.push('window-blur'); });
    \\true
;

test "a tab without system focus: hasFocus() is false, :focus matches nothing, focus() designates without events" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    try fixture.run(host, listeners);
    // Every tab has system focus until a host narrows it.
    try fixture.expect(host, "document.hasFocus()", "true");
    const realm = fixture_mod.activeRealm(host) orelse return error.NoRealm;
    const tab = runtime.TabScope.ofRealm(realm) orelse return error.NoTab;
    try testing.expect(tab.hasSystemFocus());

    // The tab loses system focus, nothing focused in it: blur at its Window.
    html.focus.setSystemFocus(host, false);
    try testing.expect(!tab.hasSystemFocus());
    try fixture.waitFor(host, "log.length === 1");
    try fixture.expect(host, "log.join()", "window-blur");
    try fixture.expect(host, "document.hasFocus()", "false");

    // focus() moves the focus there all the same, firing nothing; nothing
    // matches :focus while the tab has no system focus.
    try fixture.run(host, "input.focus(); true");
    try fixture.expect(host, "[document.activeElement === input, input.matches(':focus'), input.matches(':focus-within'), log.length].join()", "true,false,false,1");

    // The tab regains it: focus at the Window, then at the focused element.
    html.focus.setSystemFocus(host, true);
    try fixture.waitFor(host, "log.length === 4");
    try fixture.expect(host, "log.join()", "window-blur,window-focus,focus,focusin");
    try fixture.expect(host, "[document.hasFocus(), input.matches(':focus')].join()", "true,true");

    // And loses it again: blur at the element, then at the Window.
    html.focus.setSystemFocus(host, false);
    try fixture.waitFor(host, "log.length === 7");
    try fixture.expect(host, "log.slice(4).join()", "blur,focusout,window-blur");
    // The element stays the document's focused area (activeElement), as it
    // does when a browser window loses the OS focus.
    try fixture.expect(host, "[document.activeElement === input, input.matches(':focus')].join()", "true,false");
}

test "blur() in a tab without system focus clears the designation, firing nothing" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    try fixture.run(host, listeners);
    try fixture.run(host, "input.focus(); log.length = 0; true");
    html.focus.setSystemFocus(host, false);
    try fixture.waitFor(host, "log.length === 3");
    try fixture.run(host, "log.length = 0; input.blur(); true");
    try fixture.expect(host, "[document.activeElement === document.body, log.length].join()", "true,0");
    // Regained, with nothing focused: only the Window hears it.
    html.focus.setSystemFocus(host, true);
    try fixture.waitFor(host, "log.length === 1");
    try fixture.expect(host, "log.join()", "window-focus");
}
