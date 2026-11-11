//! Attribute-block sharing must not be web-observable (lane nd2 batch 4,
//! plan-v2 A3): what the FULL A/B of a5453d48706 against generation 216
//! lost, as tests on a real Browser.
//!
//! The parser and a clone now set an element's whole attribute list at once
//! and then run "handle attribute changes" for each attribute (Blink's
//! Element::ParserSetAttributes, WebKit's Element::parserSetAttributes).
//! Two things the spec's one-by-one "Append each attribute in the given
//! token to element" (HTML 13.2.6.1) gave for free have to hold anyway:
//!
//! 1. An element that ALREADY has attributes when the parser reaches that
//!    step keeps them and gets the token's too. A customized built-in is
//!    upgraded synchronously inside "create an element", so its constructor
//!    runs first (custom-elements/customized-built-in-constructor-
//!    exceptions.html, "Make sure customized <input> element that sets
//!    attributes doesnt crash").
//! 2. An input's `type` change steps run with its `value` attribute already
//!    in the list. A clean value must not be written back into the value
//!    attribute, sanitized for the state the element is leaving (html/
//!    semantics/forms/the-input-element/clone.html, "Hidden field must
//!    retain changed value."), and such an input must still share its block.
//! 3. Which values step 1 of the type change steps does write, by script:
//!    the predicate that keeps 2 true (section 3 below).
//!
//! tests/html is one executable: each test runs its Browser on a thread of
//! its own.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const browser_mod = @import("browser");

const page_url = "http://nd2.test/order.html";

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn loadPage(browser: *browser_mod.Browser, html: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
}

/// `source` answers true; a failure names it (the checks run on a thread of
/// their own, so the test's error trace does not reach the line).
fn check(browser: *browser_mod.Browser, source: []const u8) !void {
    if (try truthy(browser, source)) return;
    std.debug.print("\nA3 order: not true: {s}\n", .{source});
    return error.TestUnexpectedResult;
}

/// The platform object `source` evaluates to. Script must keep it alive (the
/// document holds it): the instance is borrowed from its wrapper.
fn instanceOf(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

/// The attribute block the element `source` evaluates to holds.
fn blockOf(browser: *browser_mod.Browser, source: []const u8) !*const dom.element_data.AttributeList {
    const element = try instanceOf(browser, source);
    const view = dom.element_data.of(element) orelse return error.NotAnElement;
    return view.data.attrs orelse error.NoAttributes;
}

// ---------------------------------------------------------------------------
// 1. An element that already has attributes at "Append each attribute in the
//    given token to element"

fn constructorSetsAnAttributeBeforeTheTokens() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body><script>" ++
        "globalThis.NdInput = class extends HTMLInputElement {" ++
        "  constructor() { super(); this.setAttribute('foo', 'bar'); }" ++
        "};" ++
        "customElements.define('nd-input', NdInput, { extends: 'input' });" ++
        "</script><input id=made is=nd-input title=t></body>");
    // The token's attributes were appended, not dropped: the element is found
    // by its id, and it is the customized built-in.
    try check(browser, "document.getElementById('made') instanceof NdInput");
    // The constructor's attribute first, then the token's, in the token's
    // order - each appended, none lost.
    try check(browser, "Array.from(document.querySelector('input').attributes, a => a.name + '=' + a.value).join() === 'foo=bar,id=made,is=nd-input,title=t'");
}

test "A3 order: a customized built-in whose constructor sets an attribute keeps it and gets its token's attributes" {
    try onFreshThread(constructorSetsAnAttributeBeforeTheTokens);
}

// ---------------------------------------------------------------------------
// 2. An input's type change steps, with the whole list in place

fn parsedHiddenInputKeepsItsValueAttribute() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // `type` before `value`, and `value` before `type`: Chrome and Safari
    // keep the attribute as written in both orders.
    try loadPage(browser, "<!doctype html><body>" ++
        "<input id=a type=hidden value=\"a&#10;b\">" ++
        "<input id=b value=\"a&#10;b\" type=hidden></body>");
    try check(browser, "document.getElementById('a').getAttribute('value') === 'a\\nb'");
    try check(browser, "document.getElementById('a').value === 'a\\nb'");
    try check(browser, "document.getElementById('b').getAttribute('value') === 'a\\nb'");
    try check(browser, "document.getElementById('b').value === 'a\\nb'");
}

test "A3 order: a parsed hidden input keeps its value attribute as written" {
    try onFreshThread(parsedHiddenInputKeepsItsValueAttribute);
}

fn clonedHiddenInputKeepsItsValueAttribute() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><body><input id=h type=hidden value=first></body>");
    // clone.html's step: a hidden input's value IS its attribute.
    try check(browser, "(() => {" ++
        "  const h = document.getElementById('h');" ++
        "  h.value = 'CHANGED\\nCHANGED';" ++
        "  globalThis.copy = h.cloneNode(true);" ++
        "  return copy.getAttribute('value') === 'CHANGED\\nCHANGED' && copy.value === 'CHANGED\\nCHANGED'" ++
        "    && h.getAttribute('value') === 'CHANGED\\nCHANGED';" ++
        "})()");
    // The copy shares its source's block: nothing wrote it.
    if (try blockOf(browser, "copy") != try blockOf(browser, "document.getElementById('h')")) {
        std.debug.print("\nA3 order: the cloned hidden input does not share its source's block\n", .{});
        return error.TestUnexpectedResult;
    }
}

test "A3 order: a cloned hidden input keeps its value attribute and shares its source's block" {
    try onFreshThread(clonedHiddenInputKeepsItsValueAttribute);
}

fn parsedDefaultModeInputsShare() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // Two equal attribute sets a state: the default mode (hidden, submit) and
    // the default/on mode (checkbox). A type change that writes the value
    // attribute copies the element's block; none may.
    // The control (class k): two equal sets on elements with no change step
    // that writes - what the helper and the holder count read when nothing
    // is wrong.
    try loadPage(browser, "<!doctype html><body>" ++
        "<p class=k title=tok></p><p class=k title=tok></p>" ++
        "<input class=h type=hidden value=tok><input class=h type=hidden value=tok>" ++
        "<input class=s type=submit value=Save><input class=s type=submit value=Save>" ++
        "<input class=c type=checkbox value=yes><input class=c type=checkbox value=yes></body>");
    inline for (.{ "k", "h", "s", "c" }) |class| {
        const first = try blockOf(browser, "document.getElementsByClassName('" ++ class ++ "')[0]");
        const second = try blockOf(browser, "document.getElementsByClassName('" ++ class ++ "')[1]");
        if (first != second or first.holders != 2) {
            std.debug.print("\nA3 order: class {s}: the two elements {s}, the first's block has {d} holder(s)\n", .{ class, if (first == second) "share a block" else "hold two blocks", first.holders });
            return error.TestUnexpectedResult;
        }
    }
}

test "A3 order: parsed inputs in a default or default/on state with a value attribute share their block" {
    try onFreshThread(parsedDefaultModeInputsShare);
}

// ---------------------------------------------------------------------------
// 3. Step 1 of the type change steps, by script: which values it writes
//
// HTML 4.10.5 "When an input element's type attribute changes state", step 1,
// sets the value content attribute to the element's value whenever that value
// is not empty. Crane applies it only to a value something STORED on the
// element (HTMLInputElement.zig typeChangeSteps has the evidence):
//   A. a value that only ever came from the value attribute is not written
//      back (Chrome and Safari; Firefox writes it);
//   B. a value an earlier type change's step 2 took from the attribute is
//      written (Safari and Firefox; Chrome does not);
//   and a dirty value is written by all three.

fn scriptPage() !*browser_mod.Browser {
    const browser = try startBrowser();
    errdefer browser.deinit();
    try loadPage(browser, "<!doctype html><body></body>");
    return browser;
}

fn dirtyValueIsWrittenByATypeChange() !void {
    const browser = try scriptPage();
    defer browser.deinit();
    // The dirty value, sanitized for Text when it was set, replaces the
    // attribute: step 1 as written.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.setAttribute('value', 'attr');" ++
        "  i.value = 'x\\ny';" ++
        "  i.type = 'hidden';" ++
        "  globalThis.dirty = i;" ++
        "  return i.getAttribute('value') === 'xy';" ++
        "})()");
    try check(browser, "dirty.value === 'xy'");
    // To a default/on state too.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.value = 'x\\ny';" ++
        "  i.type = 'checkbox';" ++
        "  return i.getAttribute('value') === 'xy' && i.value === 'xy';" ++
        "})()");
    // "and the element's value is not the empty string": a dirty empty value
    // leaves the attribute.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.setAttribute('value', 'attr');" ++
        "  i.value = '';" ++
        "  i.type = 'hidden';" ++
        "  return i.getAttribute('value') === 'attr';" ++
        "})()");
}

test "A3 order: a type change writes a dirty value into the value attribute" {
    try onFreshThread(dirtyValueIsWrittenByATypeChange);
}

fn cleanValueIsNotWrittenByATypeChange() !void {
    const browser = try scriptPage();
    defer browser.deinit();
    // Case A, value mode -> default mode: the attribute is not replaced by
    // its Text sanitization, and nothing but `type` changed.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  globalThis.seen = new MutationObserver(() => {});" ++
        "  seen.observe(i, { attributes: true });" ++
        "  i.type = 'hidden';" ++
        // Taken here: the microtask checkpoint that ends this script
        // delivers the queue to the observer's callback.
        "  globalThis.changed = seen.takeRecords().map(r => r.attributeName).join();" ++
        "  globalThis.clean = i;" ++
        "  return i.getAttribute('value') === 'a\\nb';" ++
        "})()");
    try check(browser, "clean.value === 'a\\nb'");
    try check(browser, "changed === 'type'");
    // Value mode -> default/on mode.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'checkbox';" ++
        "  return i.getAttribute('value') === 'a\\nb' && i.value === 'a\\nb';" ++
        "})()");
    // The other direction, default mode -> value mode (step 2): the attribute
    // stays as written, the value is its sanitization, and it is still clean -
    // it follows the attribute.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.type = 'hidden';" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'text';" ++
        "  globalThis.back = i;" ++
        "  return i.getAttribute('value') === 'a\\nb' && i.value === 'ab';" ++
        "})()");
    try check(browser, "(back.setAttribute('value', 'c\\nd'), back.value === 'cd')");
    // A value attribute added after step 2 ran without one was never stored:
    // case A again.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.type = 'hidden';" ++
        "  i.type = 'text';" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'hidden';" ++
        "  return i.getAttribute('value') === 'a\\nb';" ++
        "})()");
}

test "A3 order: a type change does not write a value that only ever came from the value attribute" {
    try onFreshThread(cleanValueIsNotWrittenByATypeChange);
}

fn cleanValueIsNotRewrittenUnchanged() !void {
    const browser = try scriptPage();
    defer browser.deinit();
    // Case A where the sanitization leaves the value as it is: the attribute
    // reads the same either way, so ask an observer. It sees `type` alone; a
    // write would add a `value` record (and copy a shared attribute block).
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.setAttribute('value', 'abc');" ++
        "  const observer = new MutationObserver(() => {});" ++
        "  observer.observe(i, { attributes: true });" ++
        "  i.type = 'hidden';" ++
        "  return observer.takeRecords().map(r => r.attributeName).join() === 'type';" ++
        "})()");
    // The control: a dirty value is written, and the observer sees it.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.value = 'abc';" ++
        "  const observer = new MutationObserver(() => {});" ++
        "  observer.observe(i, { attributes: true });" ++
        "  i.type = 'hidden';" ++
        "  return observer.takeRecords().map(r => r.attributeName).join() === 'type,value';" ++
        "})()");
}

test "A3 order: a type change does not rewrite a clean value with itself" {
    try onFreshThread(cleanValueIsNotRewrittenUnchanged);
}

fn valueTakenByATypeChangeIsWritten() !void {
    const browser = try scriptPage();
    defer browser.deinit();
    // Case B: default -> value -> default. Step 2 took the attribute's value;
    // step 1 writes the element's value, sanitized for Text, as the spec says.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.type = 'hidden';" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'text';" ++
        "  i.type = 'hidden';" ++
        "  return i.getAttribute('value') === 'ab' && i.value === 'ab';" ++
        "})()");
    // The value written is the element's value at the change, not the one
    // step 2 saw.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.type = 'hidden';" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'text';" ++
        "  i.setAttribute('value', 'c\\nd');" ++
        "  i.type = 'hidden';" ++
        "  return i.getAttribute('value') === 'cd';" ++
        "})()");
    // A clone carries it, with the value and its dirty value flag.
    try check(browser, "(() => {" ++
        "  const i = document.createElement('input');" ++
        "  i.type = 'hidden';" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'text';" ++
        "  const copy = i.cloneNode();" ++
        "  copy.type = 'hidden';" ++
        "  return copy.getAttribute('value') === 'ab' && i.getAttribute('value') === 'a\\nb';" ++
        "})()");
    // The reset algorithm sets the value back to the attribute's: nothing is
    // stored any more, case A.
    try check(browser, "(() => {" ++
        "  const form = document.createElement('form');" ++
        "  const i = document.createElement('input');" ++
        "  form.append(i);" ++
        "  i.type = 'hidden';" ++
        "  i.setAttribute('value', 'a\\nb');" ++
        "  i.type = 'text';" ++
        "  form.reset();" ++
        "  i.type = 'hidden';" ++
        "  return i.getAttribute('value') === 'a\\nb';" ++
        "})()");
}

test "A3 order: a type change writes a value an earlier type change took from the value attribute" {
    try onFreshThread(valueTakenByATypeChangeIsWritten);
}
