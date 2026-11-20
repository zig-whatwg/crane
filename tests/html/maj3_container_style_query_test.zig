//! CSS Conditional 5 5.4: "Style declarations within the @container rule
//! are filtered by its condition to only match when the container query is
//! true for their element's query container." The query container is the
//! nearest ancestor that is a valid query container for every feature of the
//! query - every element is a style container (container-type: normal, 5.1)
//! - and, with a <container-name>, one whose container-name names it. No
//! eligible ancestor, or an unknown feature (<general-enclosed>, a size
//! feature no layout answers), makes the query unknown, and its rules do not
//! apply. A container style query (6.2) reads the query container's computed
//! values: `--x: v` compares v, computed for the container, with its
//! computed value; `--x` alone is true when the value is not the initial
//! one; a range compares numbers, and is false when an operand is none.
//!
//! Chrome, Firefox and Safari apply them (wpt.fyi 2358bd4835:
//! css/css-conditional/container-queries/at-container-style-parsing.html,
//! "Query condition should be valid: style(--my-prop: foo)" and the rest:
//! PASS in all three).
const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html>
        \\<style>
        \\  #outer { container-name: card; --foo: bar; --n: 10px; }
        \\  #inner { --foo: baz; }
        \\  @container style(--foo: baz) { #t { --nearest: yes; } }
        \\  @container card style(--foo: bar) { #t { --named: yes; } }
        \\  @container card style(--foo: baz) { #t { --named-wrong: yes; } }
        \\  @container style(--foo) { #t { --boolean: yes; } }
        \\  @container style(--missing) { #t { --boolean-missing: yes; } }
        \\  @container nosuch style(--foo: bar) { #t { --no-container: yes; } }
        \\  @container card (style(--n < 20px)) or (not (style(--n < 20px))) { #t { --range-known: yes; } }
        \\  @container card style(--n < 20px) { #t { --range-true: yes; } }
        \\  @container card style(--foo < 20px) { #t { --range-not-numeric: yes; } }
        \\  @container (foo(bar)) or (not (foo(bar))) { #t { --unknown: yes; } }
        \\  @container card { #t { --name-only: yes; } }
        \\  @media all { @container style(--foo: baz) { #t { --nested-media: yes; } } }
        \\</style>
        \\<div id="outer"><div id="inner"><span id="t"></span></div></div>
    , .{ .base_url = "about:blank" });
    const got = try page.evaluateScriptToString(
        \\(() => {
        \\  const cs = getComputedStyle(document.getElementById('t'));
        \\  return ['--nearest', '--named', '--named-wrong', '--boolean', '--boolean-missing', '--no-container',
        \\          '--range-known', '--range-true', '--range-not-numeric', '--unknown', '--name-only', '--nested-media']
        \\    .map((n) => n + '=' + (cs.getPropertyValue(n).trim() || '-')).join(' ');
        \\})()
    , testing.allocator);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(
        "--nearest=yes --named=yes --named-wrong=- --boolean=yes --boolean-missing=- --no-container=- " ++
            "--range-known=yes --range-true=yes --range-not-numeric=- --unknown=- --name-only=yes --nested-media=yes",
        got,
    );
    // A change to the container's value restyles what depends on it.
    const after = try page.evaluateScriptToString(
        \\(() => {
        \\  document.getElementById('inner').style.setProperty('--foo', 'qux');
        \\  return getComputedStyle(document.getElementById('t')).getPropertyValue('--nearest').trim() || '-';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(after);
    try testing.expectEqualStrings("-", after);
}

test "@container style() rules apply when the query is true for the element's query container" {
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
