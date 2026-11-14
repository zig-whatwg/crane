//! Reading a test framework's result from its own page, through the console
//! - what a person does in DevTools: wait until the framework's report says
//! the run ended, then read the report the page shows. Nothing is injected
//! into the page and no upstream file is edited (the integrator, 2026-11-11:
//! "drive pages only through what it offers a user").
//!
//! Each reader is two console inputs, one line each (`waitInput`,
//! `readInput`): the first awaits the framework's FINAL summary - QUnit's
//! "N tests completed in M milliseconds" (its progress line, "N / M tests
//! completed.", never matches), Mocha's tests all reported against the
//! number its own progress divides by (Runner#grepTotal) - or the page's
//! budget; the second prints one line, `marker` and a JSON object, built
//! from the HTML report:
//!
//!   QUnit 2 (qunit.js, html reporter): `#qunit-tests > li` per test - its
//!   `.module-name` and `.test-name`, its class (pass / fail / skipped /
//!   "pass todo" / "fail todo"; "" or "running" while unfinished), its
//!   `.counts` "(failed, passed, total)" or "(total)", its own `.runtime`, the
//!   first `.qunit-assert-list > li.fail` with its expected and actual; a
//!   `#qunit-tests > li` without a test id is a global failure. The run's
//!   own totals are the `#qunit-testresult-display` text.
//!   Mocha (mocha.js, reporters/html): `#mocha-report li.test` per test, its
//!   suites the enclosing `li.suite > h1`, its title the h2's first text, its
//!   class (pass / fail / "pass pending"), `.duration`, and `pre.error` (or
//!   `.html-error`); a failed hook is reported as a test whose title is
//!   `"before each" hook for ...`. The run's own totals are `#mocha-stats`'
//!   passes and failures.
//!
//! The page also tells, for the exclusion check, every test the framework
//! registered whether it ran or not (QUnit.config.modules[].tests, Mocha's
//! suite tree), and the resources it loaded from other origins (ruling R6).
//!
//! The timers in the waits are the page's own: jQuery's tests install
//! Sinon's fake timers, which replace setTimeout and Date while a test runs,
//! so the wait takes one setInterval and the real Date.now before any test
//! runs (an interval already registered keeps firing; a new setTimeout made
//! under fake timers would never fire).

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");

pub const marker = "CRANE-FW-RESULT ";

pub const Reader = @import("exclusions.zig").Reader;

const qunit_wait =
    \\await new Promise((resolve) => {
    \\  const now = Date.now.bind(Date), t0 = now();
    \\  let last = -1, changed = t0;
    \\  const id = setInterval(() => {
    \\    const d = document.getElementById("qunit-testresult-display");
    \\    const text = d ? d.textContent : "";
    \\    if (/\d+ tests completed in \d+ milliseconds|Tests aborted after/.test(text)) { clearInterval(id); resolve("done"); return; }
    \\    const n = document.querySelectorAll("#qunit-tests > li.pass, #qunit-tests > li.fail, #qunit-tests > li.skipped").length;
    \\    if (n !== last) { last = n; changed = now(); }
    \\    if (now() - t0 > __BUDGET__) { clearInterval(id); resolve("budget"); return; }
    \\    if (now() - changed > __STALL__) { clearInterval(id); resolve("stalled"); }
    \\  }, 500);
    \\})
;

const qunit_read =
    \\(() => {
    \\  const tx = (e) => (e ? e.textContent : null);
    \\  const q = (e, s) => e.querySelector(s);
    \\  const cut = (s) => (s == null ? null : s.length > 2000 ? s.slice(0, 2000) : s);
    \\  const disp = document.getElementById("qunit-testresult-display");
    \\  const tests = [], errors = [];
    \\  for (const li of document.querySelectorAll("#qunit-tests > li")) {
    \\    if (!li.id || li.id.indexOf("qunit-test-output-") !== 0) { errors.push(cut(tx(li))); continue; }
    \\    const fa = q(li, ".qunit-assert-list > li.fail");
    \\    let f = null;
    \\    if (fa) {
    \\      f = tx(q(fa, ".test-message")) || "";
    \\      const ex = q(fa, "tr.test-expected pre"), ac = q(fa, "tr.test-actual pre");
    \\      if (ex) f += "\nExpected: " + tx(ex);
    \\      if (ac) f += "\nResult: " + tx(ac);
    \\    }
    \\    const rt = Array.prototype.find.call(li.children, (c) => c.className === "runtime");
    \\    tests.push({ m: tx(q(li, ".module-name")), n: tx(q(li, ".test-name")), c: li.className, counts: tx(q(li, ".counts")), ms: rt ? tx(rt) : null, f: cut(f) });
    \\  }
    \\  const defined = [];
    \\  if (window.QUnit && QUnit.config && QUnit.config.modules) for (const m of QUnit.config.modules) for (const t of m.tests) defined.push(m.name + ": " + t.name);
    \\  const out = new Set();
    \\  try { for (const e of performance.getEntriesByType("resource")) out.add(e.name); } catch (e) {}
    \\  for (const e of document.querySelectorAll("script[src], link[href]")) out.add(e.src || e.href);
    \\  const resources = [...out].filter((u) => typeof u === "string" && /^https?:/.test(u) && new URL(u).origin !== location.origin);
    \\  console.log("CRANE-FW-RESULT " + JSON.stringify({ summary: tx(disp), tests, errors, defined, resources, userAgent: navigator.userAgent }));
    \\})()
;

const mocha_wait =
    \\await new Promise((resolve) => {
    \\  const now = Date.now.bind(Date), t0 = now();
    \\  let last = -1, changed = t0, settled = 0;
    \\  const expected = () => {
    \\    if (!window.mocha || !mocha.suite) return -1;
    \\    const g = mocha.options.grep, inv = !!mocha.options.invert;
    \\    let n = 0;
    \\    const walk = (s) => { for (const t of s.tests) { let m = g ? g.test(t.fullTitle()) : true; if (inv) m = !m; if (m) n++; } s.suites.forEach(walk); };
    \\    walk(mocha.suite);
    \\    return n;
    \\  };
    \\  const hook = /^"(before|after) (all|each)" hook/;
    \\  const id = setInterval(() => {
    \\    let n = 0;
    \\    for (const li of document.querySelectorAll("#mocha-report li.test")) { const h = li.querySelector("h2"); if (!(h && h.firstChild && hook.test(h.firstChild.textContent))) n++; }
    \\    const e = expected();
    \\    if (e >= 0 && n >= e) { if (++settled >= 3) { clearInterval(id); resolve("done"); } return; }
    \\    if (n !== last) { last = n; changed = now(); }
    \\    if (now() - t0 > __BUDGET__) { clearInterval(id); resolve("budget"); return; }
    \\    if (now() - changed > __STALL__) { clearInterval(id); resolve("stalled"); }
    \\  }, 500);
    \\})
;

const mocha_read =
    \\(() => {
    \\  const tx = (e) => (e ? e.textContent : null);
    \\  const cut = (s) => (s == null ? null : s.length > 2000 ? s.slice(0, 2000) : s);
    \\  const hook = /^"(before|after) (all|each)" hook/;
    \\  const tests = [], hooks = [];
    \\  for (const li of document.querySelectorAll("#mocha-report li.test")) {
    \\    const h2 = li.querySelector("h2");
    \\    let title = h2 && h2.firstChild && h2.firstChild.nodeType === 3 ? h2.firstChild.textContent : "";
    \\    if (li.classList.contains("fail") && title.endsWith(" ")) title = title.slice(0, -1);
    \\    const path = [];
    \\    for (let s = li.parentElement ? li.parentElement.closest("li.suite") : null; s; s = s.parentElement ? s.parentElement.closest("li.suite") : null) {
    \\      const h1 = Array.prototype.find.call(s.children, (c) => c.tagName === "H1");
    \\      path.unshift(tx(h1));
    \\    }
    \\    const err = li.querySelector("pre.error") || li.querySelector(".html-error");
    \\    const d = li.querySelector("span.duration");
    \\    const rec = { p: path, n: title, c: li.className, ms: d ? tx(d) : null, f: err ? cut(tx(err)) : null };
    \\    (hook.test(title) ? hooks : tests).push(rec);
    \\  }
    \\  const defined = [];
    \\  let expected = null;
    \\  if (window.mocha && mocha.suite) {
    \\    const g = mocha.options.grep, inv = !!mocha.options.invert;
    \\    expected = 0;
    \\    const walk = (s) => { for (const t of s.tests) { defined.push(t.fullTitle()); let m = g ? g.test(t.fullTitle()) : true; if (inv) m = !m; if (m) expected++; } s.suites.forEach(walk); };
    \\    walk(mocha.suite);
    \\  }
    \\  const num = (s) => { const e = document.querySelector(s); return e ? Number(e.textContent) : null; };
    \\  const out = new Set();
    \\  try { for (const e of performance.getEntriesByType("resource")) out.add(e.name); } catch (e) {}
    \\  for (const e of document.querySelectorAll("script[src], link[href]")) out.add(e.src || e.href);
    \\  const resources = [...out].filter((u) => typeof u === "string" && /^https?:/.test(u) && new URL(u).origin !== location.origin);
    \\  console.log("CRANE-FW-RESULT " + JSON.stringify({ passes: num("#mocha-stats .passes em"), failures: num("#mocha-stats .failures em"), expected, tests, hooks, defined, resources, userAgent: navigator.userAgent }));
    \\})()
;

/// One console input line: newlines become spaces (the JS above has no `//`
/// comment and no string spanning lines, so this changes nothing it means).
fn oneLine(arena: Allocator, js: []const u8) ![]const u8 {
    const out = try arena.dupe(u8, js);
    for (out) |*c| if (c.* == '\n') {
        c.* = ' ';
    };
    return out;
}

/// The console's input for one page: the wait, the read, `.exit`.
pub fn consoleInput(arena: Allocator, reader: Reader, budget_ms: u64, stall_ms: u64) ![]const u8 {
    const wait_src = switch (reader) {
        .qunit => qunit_wait,
        .mocha => mocha_wait,
    };
    const read_src = switch (reader) {
        .qunit => qunit_read,
        .mocha => mocha_read,
    };
    const b = try std.fmt.allocPrint(arena, "{d}", .{budget_ms});
    const s = try std.fmt.allocPrint(arena, "{d}", .{stall_ms});
    const w1 = try std.mem.replaceOwned(u8, arena, wait_src, "__BUDGET__", b);
    const w2 = try std.mem.replaceOwned(u8, arena, w1, "__STALL__", s);
    return std.fmt.allocPrint(arena, "{s}\n{s}\n.exit\n", .{ try oneLine(arena, w2), try oneLine(arena, read_src) });
}

/// The JSON after the last `marker` in the console's output, to its line's
/// end; null when the page never printed one.
pub fn findResult(output: []const u8) ?[]const u8 {
    const at = std.mem.lastIndexOf(u8, output, marker) orelse return null;
    const start = at + marker.len;
    const end = std.mem.indexOfScalarPos(u8, output, start, '\n') orelse output.len;
    return std.mem.trimEnd(u8, output[start..end], "\r");
}

/// One test as the framework reported it.
pub const Reported = struct {
    module: []const u8,
    name: []const u8,
    id: []const u8,
    status: journal.Status,
    project_skip: bool = false,
    assertions_passed: ?u32 = null,
    assertions_total: ?u32 = null,
    message: ?[]const u8 = null,
    duration_ms: ?u64 = null,
};

/// What one page's report says.
pub const PageResult = struct {
    tests: []const Reported,
    /// Every test id the framework registered on the page, run or not.
    defined: []const []const u8,
    /// The framework's own count of the tests it ran (QUnit: the summary's
    /// N; Mocha: the tests its grep selects, Runner#grepTotal's count).
    reported_total: ?u32,
    /// The framework's own count of failures (QUnit: the summary's "F
    /// failed"; Mocha: #mocha-stats failures, failed hooks included).
    reported_failed: ?u32,
    /// Mocha's #mocha-stats passes (null for QUnit).
    reported_passed: ?u32 = null,
    /// QUnit's final summary was shown (Mocha: every selected test reported).
    finished: bool,
    errors: []const []const u8,
    resources: []const []const u8,
    user_agent: []const u8,
};

pub const ParseError = error{ OutOfMemory, BadReport };

const QUnitJson = struct {
    summary: ?[]const u8,
    tests: []const struct { m: ?[]const u8, n: ?[]const u8, c: []const u8, counts: ?[]const u8, ms: ?[]const u8, f: ?[]const u8 },
    errors: []const ?[]const u8,
    defined: []const []const u8,
    resources: []const []const u8,
    userAgent: []const u8,
};

const MochaJson = struct {
    passes: ?f64,
    failures: ?f64,
    expected: ?u32,
    tests: []const MochaTest,
    hooks: []const MochaTest,
    defined: []const []const u8,
    resources: []const []const u8,
    userAgent: []const u8,

    const MochaTest = struct { p: []const ?[]const u8, n: []const u8, c: []const u8, ms: ?[]const u8, f: ?[]const u8 };
};

/// The leading decimal number of `s` (after spaces), or null.
fn leadingNumber(s: []const u8) ?u64 {
    const t = std.mem.trimStart(u8, s, " \t\n");
    var end: usize = 0;
    while (end < t.len and std.ascii.isDigit(t[end])) end += 1;
    if (end == 0) return null;
    return std.fmt.parseInt(u64, t[0..end], 10) catch null;
}

/// The number just before `word` in `text` ("12 failed" -> 12).
fn numberBefore(text: []const u8, word: []const u8) ?u32 {
    const at = std.mem.indexOf(u8, text, word) orelse return null;
    var start = at;
    while (start > 0 and std.ascii.isDigit(text[start - 1])) start -= 1;
    if (start == at) return null;
    return std.fmt.parseInt(u32, text[start..at], 10) catch null;
}

/// QUnit's final summary: "N tests completed in R milliseconds, with F
/// failed, S skipped, and T todo." (qunit.js html reporter, runEnd).
pub const QUnitSummary = struct { total: u32, failed: u32, skipped: u32, todo: u32 };

pub fn parseQUnitSummary(text: []const u8) ?QUnitSummary {
    const total = numberBefore(text, " tests completed in ") orelse return null;
    return .{
        .total = total,
        .failed = numberBefore(text, " failed, ") orelse return null,
        .skipped = numberBefore(text, " skipped, ") orelse return null,
        .todo = numberBefore(text, " todo.") orelse return null,
    };
}

/// A QUnit test's ".counts": "(F, P, T)" when an assertion failed, "(T)"
/// otherwise (qunit.js testDone).
fn qunitCounts(s: ?[]const u8) struct { passed: ?u32, total: ?u32 } {
    const text = s orelse return .{ .passed = null, .total = null };
    var nums: [3]u32 = undefined;
    var n: usize = 0;
    var it = std.mem.tokenizeAny(u8, text, "(), ");
    while (it.next()) |tok| {
        if (n == 3) break;
        nums[n] = std.fmt.parseInt(u32, tok, 10) catch return .{ .passed = null, .total = null };
        n += 1;
    }
    return switch (n) {
        1 => .{ .passed = nums[0], .total = nums[0] },
        3 => .{ .passed = nums[1], .total = nums[2] },
        else => .{ .passed = null, .total = null },
    };
}

fn hasClass(class_name: []const u8, class: []const u8) bool {
    var it = std.mem.tokenizeScalar(u8, class_name, ' ');
    while (it.next()) |c| if (std.mem.eql(u8, c, class)) return true;
    return false;
}

pub fn parseQUnit(arena: Allocator, json: []const u8) ParseError!PageResult {
    const r = std.json.parseFromSliceLeaky(QUnitJson, arena, json, .{}) catch return error.BadReport;
    var tests: std.ArrayList(Reported) = .empty;
    for (r.tests) |t| {
        const module = t.m orelse "";
        const name = t.n orelse "";
        const counts = qunitCounts(t.counts);
        // "pass todo" / "fail todo" carry pass or fail; unfinished tests
        // ("" / "running" / "aborted") were not reported.
        const skip = hasClass(t.c, "skipped");
        const status: journal.Status = if (skip)
            .NOTRUN
        else if (hasClass(t.c, "fail"))
            .FAIL
        else if (hasClass(t.c, "pass"))
            .PASS
        else
            continue;
        try tests.append(arena, .{
            .module = module,
            .name = name,
            .id = try std.fmt.allocPrint(arena, "{s}: {s}", .{ module, name }),
            .status = status,
            .project_skip = skip,
            .assertions_passed = counts.passed,
            .assertions_total = counts.total,
            .message = if (status == .FAIL) (t.f orelse "(no failed assertion shown)") else null,
            .duration_ms = if (t.ms) |ms| leadingNumber(ms) else null,
        });
    }
    var errors: std.ArrayList([]const u8) = .empty;
    for (r.errors) |e| if (e) |text| try errors.append(arena, text);
    const summary = if (r.summary) |s| parseQUnitSummary(s) else null;
    return .{
        .tests = tests.items,
        .defined = r.defined,
        .reported_total = if (summary) |s| s.total else null,
        .reported_failed = if (summary) |s| s.failed else null,
        .finished = summary != null,
        .errors = errors.items,
        .resources = r.resources,
        .user_agent = r.userAgent,
    };
}

pub fn parseMocha(arena: Allocator, json: []const u8) ParseError!PageResult {
    const r = std.json.parseFromSliceLeaky(MochaJson, arena, json, .{}) catch return error.BadReport;
    var tests: std.ArrayList(Reported) = .empty;
    for (r.tests) |t| {
        var path: std.ArrayList([]const u8) = .empty;
        for (t.p) |p| try path.append(arena, p orelse "");
        const module = try std.mem.join(arena, " > ", path.items);
        try path.append(arena, t.n);
        // Runnable#fullTitle: titlePath().join(' '), the root suite's empty
        // title left out (Suite#titlePath).
        const id = try std.mem.join(arena, " ", path.items);
        const pending = hasClass(t.c, "pending");
        const status: journal.Status = if (pending) .NOTRUN else if (hasClass(t.c, "fail")) .FAIL else .PASS;
        try tests.append(arena, .{
            .module = module,
            .name = t.n,
            .id = id,
            .status = status,
            .project_skip = pending,
            .message = if (status == .FAIL) (t.f orelse "(no error shown)") else null,
            .duration_ms = if (t.ms) |ms| leadingNumber(ms) else null,
        });
    }
    var errors: std.ArrayList([]const u8) = .empty;
    for (r.hooks) |h| try errors.append(arena, try std.fmt.allocPrint(arena, "{s}: {s}", .{ h.n, h.f orelse "" }));
    const finished = if (r.expected) |e| tests.items.len >= e else false;
    return .{
        .tests = tests.items,
        .defined = r.defined,
        .reported_total = r.expected,
        .reported_failed = if (r.failures) |f| @intFromFloat(f) else null,
        .reported_passed = if (r.passes) |p| @intFromFloat(p) else null,
        .finished = finished,
        .errors = errors.items,
        .resources = r.resources,
        .user_agent = r.userAgent,
    };
}

pub fn parse(arena: Allocator, reader: Reader, json: []const u8) ParseError!PageResult {
    return switch (reader) {
        .qunit => parseQUnit(arena, json),
        .mocha => parseMocha(arena, json),
    };
}

/// Where the framework's own counts disagree with the tests read from its
/// list, one line each (empty: they agree). The counts come from the
/// summary display, the tests from the per-test list: two reads of the
/// page, neither derived from the other.
pub fn countProblems(arena: Allocator, reader: Reader, r: PageResult) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var pass: u32 = 0;
    var fail: u32 = 0;
    var skip: u32 = 0;
    for (r.tests) |t| switch (t.status) {
        .PASS => pass += 1,
        .FAIL => fail += 1,
        else => skip += 1,
    };
    const all: u32 = pass + fail + skip;
    switch (reader) {
        .qunit => {
            if (r.reported_total) |n| if (n != all) try out.append(arena, try std.fmt.allocPrint(arena, "QUnit's summary says {d} tests completed; its list shows {d}", .{ n, all }));
            if (r.reported_failed) |n| if (n != fail) try out.append(arena, try std.fmt.allocPrint(arena, "QUnit's summary says {d} failed; its list shows {d}", .{ n, fail }));
        },
        .mocha => {
            if (r.reported_total) |n| if (n != all) try out.append(arena, try std.fmt.allocPrint(arena, "Mocha selects {d} tests; its report lists {d}", .{ n, all }));
            if (r.reported_passed) |n| if (n != pass) try out.append(arena, try std.fmt.allocPrint(arena, "Mocha's stats say {d} passes; its report lists {d}", .{ n, pass }));
            const hooks: u32 = @intCast(r.errors.len);
            if (r.reported_failed) |n| if (n != fail + hooks) try out.append(arena, try std.fmt.allocPrint(arena, "Mocha's stats say {d} failures; its report lists {d} tests and {d} hooks", .{ n, fail, hooks }));
        },
    }
    return out.items;
}

const testing = std.testing;

test "the console input: three lines, the budget and stall filled in, no newline inside an input" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    for ([_]Reader{ .qunit, .mocha }) |reader| {
        const input = try consoleInput(a, reader, 900000, 150000);
        try testing.expectEqual(@as(usize, 3), std.mem.count(u8, input, "\n"));
        try testing.expect(std.mem.endsWith(u8, input, "\n.exit\n"));
        try testing.expect(std.mem.indexOf(u8, input, "__") == null);
        try testing.expect(std.mem.indexOf(u8, input, "> 900000") != null);
        try testing.expect(std.mem.indexOf(u8, input, "> 150000") != null);
        try testing.expect(std.mem.indexOf(u8, input, "//") == null);
        try testing.expect(std.mem.indexOf(u8, input, marker) != null);
    }
    // QUnit's wait matches only the final summary, never its progress line.
    const q = try consoleInput(a, .qunit, 1, 1);
    try testing.expect(std.mem.indexOf(u8, q, "tests completed in \\d+ milliseconds") != null);
}

test "findResult: the last marker's line, or null" {
    try testing.expectEqualStrings("{\"b\":2}", findResult("x\nCRANE-FW-RESULT {\"a\":1}\nlog\n> CRANE-FW-RESULT {\"b\":2}\r\nundefined\n").?);
    try testing.expectEqual(@as(?[]const u8, null), findResult("nothing here\n"));
}

test "QUnit's final summary, and its progress line refused" {
    const s = parseQUnitSummary("14 tests completed in 61234 milliseconds, with 2 failed, 1 skipped, and 0 todo.60 assertions of 65 passed, 5 failed.").?;
    try testing.expectEqual(@as(u32, 14), s.total);
    try testing.expectEqual(@as(u32, 2), s.failed);
    try testing.expectEqual(@as(u32, 1), s.skipped);
    try testing.expectEqual(@as(?QUnitSummary, null), parseQUnitSummary("3 / 14 tests completed.Running: basic: ajax"));
}

// A report as the console printed it on server1 (fw1 b1's probe of jQuery
// 4.0.0's `basic` module, cut to three tests and one global failure).
const qunit_report =
    \\{"summary":"3 tests completed in 61021 milliseconds, with 1 failed, 1 skipped, and 0 todo.5 assertions of 7 passed, 2 failed.","tests":[{"m":"basic","n":"ajax","c":"fail","counts":"(2, 1, 3)","ms":"60002 ms","f":"Test took longer than 60000ms; test timed out.\nExpected: 1"},{"m":"basic","n":"attributes","c":"pass","counts":"(4)","ms":"3 ms","f":null},{"m":"basic","n":"skipped one","c":"skipped","counts":"(0)","ms":null,"f":null},{"m":"basic","n":"running","c":"running","counts":null,"ms":null,"f":null}],"errors":["global failure: Uncaught TypeError"],"defined":["basic: ajax","basic: attributes","basic: skipped one","basic: running","core: other"],"resources":[],"userAgent":"Mozilla/5.0 (X11; Linux x86_64) WhatWG-Zig/1.0"}
;

test "QUnit: per-test records from the list, counts from the summary; unfinished tests not reported" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const r = try parseQUnit(a, qunit_report);
    try testing.expect(r.finished);
    try testing.expectEqual(@as(usize, 3), r.tests.len);
    try testing.expectEqualStrings("basic: ajax", r.tests[0].id);
    try testing.expectEqual(journal.Status.FAIL, r.tests[0].status);
    try testing.expectEqual(@as(?u32, 1), r.tests[0].assertions_passed);
    try testing.expectEqual(@as(?u32, 3), r.tests[0].assertions_total);
    try testing.expectEqual(@as(?u64, 60002), r.tests[0].duration_ms);
    try testing.expectEqual(@as(?u32, 4), r.tests[1].assertions_passed);
    try testing.expect(r.tests[2].project_skip);
    try testing.expectEqual(journal.Status.NOTRUN, r.tests[2].status);
    try testing.expectEqual(@as(?u32, 3), r.reported_total);
    try testing.expectEqual(@as(usize, 1), r.errors.len);
    try testing.expectEqual(@as(usize, 5), r.defined.len);
    try testing.expectEqual(@as(usize, 0), (try countProblems(a, .qunit, r)).len);
}

test "QUnit: a summary that disagrees with the list is a problem, and no summary is unfinished" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const wrong = try std.mem.replaceOwned(u8, a, qunit_report, "3 tests completed", "4 tests completed");
    try testing.expectEqual(@as(usize, 1), (try countProblems(a, .qunit, try parseQUnit(a, wrong))).len);
    const running = try std.mem.replaceOwned(u8, a, qunit_report, "3 tests completed in 61021 milliseconds, with 1 failed, 1 skipped, and 0 todo.5 assertions of 7 passed, 2 failed.", "3 / 4 tests completed.");
    const r = try parseQUnit(a, running);
    try testing.expect(!r.finished);
    try testing.expectEqual(@as(?u32, null), r.reported_total);
    try testing.expectError(error.BadReport, parseQUnit(a, "{\"tests\":1}"));
}

const mocha_report =
    \\{"passes":2,"failures":2,"expected":4,"tests":[{"p":["swap() unit tests"],"n":"triggers view transition events with transition:true","c":"test fail","ms":null,"f":"AssertionError: expected false to be true\n    at Context.<anonymous> (http://127.0.0.1:1/test/tests/unit/swap.js:400:34)"},{"p":["hx-swap modifiers","nested"],"n":"swaps","c":"test pass fast","ms":"3ms","f":null},{"p":["hx-get"],"n":"gets","c":"test pass medium","ms":"40ms","f":null},{"p":["hx-get"],"n":"later","c":"test pass pending","ms":null,"f":null}],"hooks":[{"p":["hx-sse"],"n":"\"before each\" hook for \"x\"","c":"test fail","ms":null,"f":"Error: boom"}],"defined":["swap() unit tests triggers view transition events with transition:true","hx-swap modifiers nested swaps","hx-get gets","hx-get later","hx-sse x"],"resources":["https://unpkg.com/chai@4.5.0/chai.js","https://unpkg.com/mocha@11.7.5/mocha.js"],"userAgent":"UA"}
;

test "Mocha: full titles from the suite path, pending as the project's skip, hooks apart" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const r = try parseMocha(a, mocha_report);
    try testing.expectEqual(@as(usize, 4), r.tests.len);
    try testing.expectEqualStrings("hx-swap modifiers nested swaps", r.tests[1].id);
    try testing.expectEqualStrings("hx-swap modifiers > nested", r.tests[1].module);
    try testing.expectEqual(@as(?u64, 3), r.tests[1].duration_ms);
    try testing.expectEqual(journal.Status.FAIL, r.tests[0].status);
    try testing.expect(r.tests[3].project_skip);
    try testing.expectEqual(@as(usize, 1), r.errors.len);
    try testing.expect(r.finished);
    try testing.expectEqual(@as(usize, 2), r.resources.len);
    // stats: 2 passes = 2 PASS (pending is not a pass); 2 failures = 1 test + 1 hook.
    try testing.expectEqual(@as(usize, 0), (try countProblems(a, .mocha, r)).len);
    const wrong = try std.mem.replaceOwned(u8, a, mocha_report, "\"passes\":2", "\"passes\":3");
    try testing.expectEqual(@as(usize, 1), (try countProblems(a, .mocha, try parseMocha(a, wrong))).len);
}

// ---------------------------------------------------------------------------
// Chrome, for the comparison column: an in-page QUnit suite with QUnit's own
// TAP reporter on (the TodoMVC port sets QUnit.config.reporters.tap) prints
// its run on the console, and headless Chrome started with
// `--enable-logging=stderr --log-level=0` writes each console message to its
// stderr as `[...:INFO:CONSOLE:<n>] "<message>", source: <url> (<n>)`, a
// message's own newlines kept (lesson workflow-headless-chromes-console-log-
// carries-a-pages-tap.md). QUnit 2.24's TapReporter: "ok N <full name>",
// "ok N <full name> # SKIP", "not ok N <full name> # TODO", "not ok N <full
// name>" then a YAML block per failed assertion ("  message: ..."), and at
// the end "1..T", "# pass P", "# skip S", "# todo D", "# fail F" - some
// parts coloured with ANSI escapes. A full name is the module path and the
// test's name joined by " > ".

/// The console messages of a Chrome stderr log, in order, ANSI escapes
/// removed (arena-owned).
pub fn chromeConsoleMessages(arena: Allocator, log: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var current: ?std.ArrayList(u8) = null;
    var it = std.mem.splitScalar(u8, log, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        var text: []const u8 = line;
        if (current == null) {
            const tag = std.mem.indexOf(u8, line, ":CONSOLE") orelse continue;
            const open = std.mem.indexOfPos(u8, line, tag, "] \"") orelse continue;
            current = .empty;
            text = line[open + 3 ..];
        } else try current.?.append(arena, '\n');
        if (std.mem.lastIndexOf(u8, text, "\", source: ")) |end| {
            try current.?.appendSlice(arena, text[0..end]);
            try out.append(arena, try stripAnsi(arena, current.?.items));
            current = null;
        } else try current.?.appendSlice(arena, text);
    }
    return out.items;
}

fn stripAnsi(arena: Allocator, s: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == 0x1b and i + 1 < s.len and s[i + 1] == '[') {
            var j = i + 2;
            while (j < s.len and (std.ascii.isDigit(s[j]) or s[j] == ';')) j += 1;
            i = if (j < s.len) j + 1 else j;
            continue;
        }
        try out.append(arena, s[i]);
        i += 1;
    }
    return out.items;
}

/// The run's last line has been printed: "# fail F" after the plan.
pub fn tapEnded(arena: Allocator, log: []const u8) !bool {
    var plan = false;
    for (try chromeConsoleMessages(arena, log)) |m| {
        if (std.mem.startsWith(u8, m, "1..")) plan = true;
        if (plan and std.mem.startsWith(u8, m, "# fail ")) return true;
    }
    return false;
}

/// "Module > name": the module path before the last " > " (a nested
/// module's name is its path joined by " > " in QUnit too), as QUnit's id
/// "<module>: <name>".
fn tapTest(arena: Allocator, full: []const u8, status: journal.Status, skip: bool) !Reported {
    const cut = std.mem.lastIndexOf(u8, full, " > ");
    const module = if (cut) |c| full[0..c] else "";
    const name = if (cut) |c| full[c + 3 ..] else full;
    return .{ .module = module, .name = name, .id = try std.fmt.allocPrint(arena, "{s}: {s}", .{ module, name }), .status = status, .project_skip = skip };
}

/// A page's result from QUnit's TAP in a Chrome stderr log.
pub fn parseChromeTap(arena: Allocator, log: []const u8) ParseError!PageResult {
    var tests: std.ArrayList(Reported) = .empty;
    var defined: std.ArrayList([]const u8) = .empty;
    var errors: std.ArrayList([]const u8) = .empty;
    var total: ?u32 = null;
    var failed: ?u32 = null;
    // The test a following YAML block belongs to.
    var last_fail: ?usize = null;
    var global = false;
    for (try chromeConsoleMessages(arena, log)) |m| {
        if (std.mem.startsWith(u8, m, "ok ") or std.mem.startsWith(u8, m, "not ok ")) {
            const ok = m[0] == 'o';
            const prefix: []const u8 = if (ok) "ok " else "not ok ";
            var rest = m[prefix.len..];
            // The test's number.
            while (rest.len > 0 and std.ascii.isDigit(rest[0])) rest = rest[1..];
            rest = std.mem.trimStart(u8, rest, " ");
            last_fail = null;
            global = false;
            if (!ok and std.mem.eql(u8, rest, "global failure")) {
                global = true;
                continue;
            }
            var status: journal.Status = if (ok) .PASS else .FAIL;
            var skip = false;
            if (std.mem.endsWith(u8, rest, " # SKIP")) {
                rest = rest[0 .. rest.len - " # SKIP".len];
                status = .NOTRUN;
                skip = true;
            } else if (std.mem.endsWith(u8, rest, " # TODO")) {
                // A todo test failing as it is expected to: QUnit does not
                // count it failed.
                rest = rest[0 .. rest.len - " # TODO".len];
                status = .PASS;
            }
            const t = try tapTest(arena, rest, status, skip);
            try defined.append(arena, t.id);
            try tests.append(arena, t);
            if (status == .FAIL) last_fail = tests.items.len - 1;
            continue;
        }
        if (std.mem.indexOf(u8, m, "  message: ")) |at| {
            const value_end = std.mem.indexOfScalarPos(u8, m, at, '\n') orelse m.len;
            const value = std.mem.trim(u8, m[at + "  message: ".len .. value_end], " \"");
            if (global) {
                if (errors.items.len < journal.max_errors) try errors.append(arena, value);
            } else if (last_fail) |i| {
                if (tests.items[i].message == null) tests.items[i].message = value;
            }
            continue;
        }
        if (std.mem.startsWith(u8, m, "1..")) total = std.fmt.parseInt(u32, m[3..], 10) catch null;
        if (std.mem.startsWith(u8, m, "# fail ")) failed = std.fmt.parseInt(u32, std.mem.trim(u8, m["# fail ".len..], " "), 10) catch null;
    }
    for (tests.items) |*t| if (t.status == .FAIL and t.message == null) {
        t.message = "(no failed assertion shown)";
    };
    return .{
        .tests = tests.items,
        .defined = defined.items,
        .reported_total = total,
        .reported_failed = failed,
        .finished = total != null and failed != null,
        .errors = errors.items,
        .resources = &.{},
        .user_agent = "",
    };
}

const chrome_log =
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"TAP version 13\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"ok 1 When page is initially opened > should focus on the todo input field\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "some other line\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"not ok 2 \x1b[31mNew Todo > should allow me to add todo items\x1b[39m\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"  ---\n  message: \"expected 2 items\"\n  severity: failed\n  actual  : 1\n  ...\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"ok 3 \x1b[33mPersistence > should persist its data\x1b[39m # SKIP\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"1..3\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"# pass 1\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n" ++
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"# \x1b[33mskip 1\x1b[39m\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n";
const chrome_log_end =
    "[1:2:1114/130000.000:INFO:CONSOLE:23] \"# \x1b[31mfail 1\x1b[39m\", source: http://127.0.0.1:1/external/qunit/qunit.js (23)\n";

test "Chrome's stderr: QUnit's TAP read back as QUnit's ids, a failure's first message, skips, the plan and the end" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // Not ended until "# fail" follows the plan.
    try testing.expect(!try tapEnded(a, chrome_log));
    try testing.expect(try tapEnded(a, chrome_log ++ chrome_log_end));

    const msgs = try chromeConsoleMessages(a, chrome_log);
    try testing.expectEqual(@as(usize, 8), msgs.len);
    // A message's own newlines are kept; the colour is gone.
    try testing.expect(std.mem.indexOf(u8, msgs[3], "\n  severity: failed\n") != null);
    try testing.expectEqualStrings("not ok 2 New Todo > should allow me to add todo items", msgs[2]);

    const r = try parseChromeTap(a, chrome_log ++ chrome_log_end);
    try testing.expectEqual(@as(usize, 3), r.tests.len);
    try testing.expectEqualStrings("When page is initially opened: should focus on the todo input field", r.tests[0].id);
    try testing.expectEqualStrings("When page is initially opened", r.tests[0].module);
    try testing.expectEqual(journal.Status.FAIL, r.tests[1].status);
    try testing.expectEqualStrings("expected 2 items", r.tests[1].message.?);
    try testing.expect(r.tests[2].project_skip);
    try testing.expectEqualStrings("Persistence: should persist its data", r.tests[2].id);
    try testing.expect(r.finished);
    try testing.expectEqual(@as(?u32, 3), r.reported_total);
    try testing.expectEqual(@as(?u32, 1), r.reported_failed);
    try testing.expectEqual(@as(usize, 3), r.defined.len);
    try testing.expectEqual(@as(usize, 0), (try countProblems(a, .qunit, r)).len);
    // Cut before its end: not finished.
    try testing.expect(!(try parseChromeTap(a, chrome_log)).finished);
}
