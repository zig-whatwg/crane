//! The rules the public WPT results site is built on, std only, so that
//! `zig build test` pins them.
//!
//! * `gateOf` - how one test file's latest record reads under the 0.1 gate
//!   (tools/wpt_progress.py `gate_status`, rule 2): TIMEOUT, ERROR and CRASH
//!   block, and so does an OK run in which none of the file's subtests
//!   passed (NONE-PASSED). A file that reported no subtests at all is not
//!   NONE-PASSED - there was nothing to fail.
//! * `Totals` - the counts a conformance box shows. Subtests are REPORTED
//!   counts (pass + fail + timeout + notrun as the journal line sums them),
//!   never a model or an estimate, and there is deliberately no ratio here:
//!   the site shows no headline pass percentage.
//! * `sourceForTestUrl` - which worklist source a wptreport test URL belongs
//!   to (`/x/y.any.worker.html?v` -> `x/y.any.js`).
//! * `labelCommit` - the Crane commit a results label names
//!   (`sweep-5c8dd64da` -> `5c8dd64da`).
//! * `isoUtc` - a journal mtime as an ISO 8601 UTC timestamp.

const std = @import("std");

// ============================================================================
// The gate
// ============================================================================

/// One file's standing. The first four are the runner's OK; `timeout`,
/// `err` and `crash` are its other statuses; `unrun` is a worklist file with
/// no record at all.
pub const Gate = enum {
    /// OK, and every subtest it reported passed.
    clean,
    /// OK, some subtests pass and some do not.
    partial,
    /// OK, and it reported no subtests at all.
    empty,
    /// OK, but none of its subtests passed: blocks the gate.
    none_passed,
    timeout,
    err,
    crash,
    unrun,
    /// Would block (NONE-PASSED, TIMEOUT, ERROR or CRASH), but the file is
    /// listed in tools/wpt_gate_exemptions.txt: all three browsers
    /// intentionally deviate from the spec it tests (the user, 2026-10-17).
    /// Counted in its own group, never as blocking.
    exempt,

    pub fn blocking(g: Gate) bool {
        return switch (g) {
            .none_passed, .timeout, .err, .crash => true,
            else => false,
        };
    }

    /// The word the site prints and the JSON carries.
    pub fn word(g: Gate) []const u8 {
        return switch (g) {
            .clean => "clean",
            .partial => "partial",
            .empty => "empty",
            .none_passed => "none-passed",
            .timeout => "timeout",
            .err => "error",
            .crash => "crash",
            .unrun => "unrun",
            .exempt => "exempt",
        };
    }

    /// The standing of a file listed in the exemptions: `exempt` where it
    /// would block, its own standing otherwise.
    pub fn exempted(g: Gate) Gate {
        return if (g.blocking()) .exempt else g;
    }
};

/// Subtest counts as the journal reports them for one file (every run of
/// the file summed: each global and each declared variant is one WPT test).
pub const Counts = struct {
    passed: u64 = 0,
    failed: u64 = 0,
    timed_out: u64 = 0,
    notrun: u64 = 0,
    /// True when the journal record came from a WPT crashtest (`crashtest: true`),
    /// which reports 0 subtests and passes when its top-level status is OK.
    crashtest: bool = false,

    pub fn reported(c: Counts) u64 {
        return c.passed + c.failed + c.timed_out + c.notrun;
    }
};

/// The gate status of a record with runner status `status` (null: no
/// record) and subtest counts `c`.
///
/// Where this differs from tools/wpt_progress.py: that tool files an OK run
/// whose only non-passing subtests are NOTRUN as clean (its clean test looks
/// at failed and timed_out only). A NOTRUN subtest did not pass, so here such
/// a file is `partial` - "Clean" on the site means every reported subtest passed.
/// The blocking set is identical.
pub fn gateOf(status: ?[]const u8, c: Counts) Gate {
    const st = status orelse return .unrun;
    if (std.mem.eql(u8, st, "OK")) {
        // WPT crashtests report 0 subtests: completing with status OK is a
        // clean pass, never `empty` or `none_passed`.
        if (c.crashtest) return .clean;
        if (c.reported() == 0) return .empty;
        if (c.passed == 0) return .none_passed;
        if (c.passed == c.reported()) return .clean;
        return .partial;
    }
    if (std.mem.eql(u8, st, "TIMEOUT")) return .timeout;
    if (std.mem.eql(u8, st, "CRASH")) return .crash;
    // ERROR, EXTERNAL-TIMEOUT, PRECONDITION_FAILED and anything unknown:
    // a status we do not recognise is not a pass (wpt_progress.py files
    // these under error in its history too).
    return .err;
}

/// Convenience wrapper for callers holding `crashtest` separately from `Counts`.
pub fn gateOfRecord(status: ?[]const u8, c: Counts, crashtest: bool) Gate {
    var counts = c;
    counts.crashtest = counts.crashtest or crashtest;
    return gateOf(status, counts);
}

// ============================================================================
// Totals
// ============================================================================

pub const Totals = struct {
    files: u64 = 0,
    clean: u64 = 0,
    partial: u64 = 0,
    empty: u64 = 0,
    none_passed: u64 = 0,
    timeout: u64 = 0,
    err: u64 = 0,
    crash: u64 = 0,
    unrun: u64 = 0,
    exempt: u64 = 0,
    sub_pass: u64 = 0,
    sub_fail: u64 = 0,
    sub_timeout: u64 = 0,
    sub_notrun: u64 = 0,

    pub fn add(t: *Totals, g: Gate, c: Counts) void {
        t.files += 1;
        switch (g) {
            .clean => t.clean += 1,
            .partial => t.partial += 1,
            .empty => t.empty += 1,
            .none_passed => t.none_passed += 1,
            .timeout => t.timeout += 1,
            .err => t.err += 1,
            .crash => t.crash += 1,
            .unrun => t.unrun += 1,
            .exempt => t.exempt += 1,
        }
        t.sub_pass += c.passed;
        t.sub_fail += c.failed;
        t.sub_timeout += c.timed_out;
        t.sub_notrun += c.notrun;
    }

    pub fn merge(t: *Totals, o: Totals) void {
        inline for (@typeInfo(Totals).@"struct".field_names) |f_name| @field(t, f_name) += @field(o, f_name);
    }

    pub fn blocking(t: Totals) u64 {
        return t.none_passed + t.timeout + t.err + t.crash;
    }

    pub fn subReported(t: Totals) u64 {
        return t.sub_pass + t.sub_fail + t.sub_timeout + t.sub_notrun;
    }

    /// Keys in sorted order, so an unchanged directory writes unchanged bytes.
    pub fn writeJson(t: Totals, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print(
            "{{\"blocking\":{d},\"clean\":{d},\"crash\":{d},\"empty\":{d},\"error\":{d},\"exempt\":{d},\"files\":{d}," ++
                "\"none_passed\":{d},\"partial\":{d},\"sub_fail\":{d},\"sub_notrun\":{d},\"sub_pass\":{d}," ++
                "\"sub_reported\":{d},\"sub_timeout\":{d},\"timeout\":{d},\"unrun\":{d}}}",
            .{
                t.blocking(),  t.clean,   t.crash,    t.empty,      t.err,      t.exempt,        t.files,
                t.none_passed, t.partial, t.sub_fail, t.sub_notrun, t.sub_pass, t.subReported(), t.sub_timeout,
                t.timeout,     t.unrun,
            },
        );
    }
};

// ============================================================================
// Test URLs and sources
// ============================================================================

/// The source path a wptreport test URL was generated from, when that source
/// is in `known` (keys are worklist paths without a leading slash). Returns
/// the key as stored in `known`, or null.
///
/// WPT names a test by its URL: a plain document is its own path; a
/// `.any.js` source becomes `.any.html`, `.any.worker.html` and the other
/// `.any.<global>.html` forms; `.window.js` becomes `.window.html` and
/// `.worker.js` `.worker.html`; a variant adds `?query`. A real document
/// named `x.worker.html` stays itself, which is why `known` is consulted
/// before any rewrite.
pub fn sourceForTestUrl(known: *const std.StringHashMapUnmanaged(void), url: []const u8) ?[]const u8 {
    var p = url;
    if (std.mem.startsWith(u8, p, "/")) p = p[1..];
    if (std.mem.indexOfAny(u8, p, "?#")) |q| p = p[0..q];
    if (known.getKey(p)) |k| return k;

    var buf: [1024]u8 = undefined;
    const slash = if (std.mem.lastIndexOfScalar(u8, p, '/')) |s| s + 1 else 0;
    const base = p[slash..];
    if (std.mem.indexOf(u8, base, ".any.")) |i| {
        if (std.mem.endsWith(u8, base, ".html")) {
            const cand = std.fmt.bufPrint(&buf, "{s}.any.js", .{p[0 .. slash + i]}) catch return null;
            if (known.getKey(cand)) |k| return k;
        }
        return null;
    }
    const rewrites = [_][2][]const u8{
        .{ ".window.html", ".window.js" },
        .{ ".worker.html", ".worker.js" },
        .{ ".extension.html", ".extension.js" },
    };
    for (rewrites) |r| {
        if (std.mem.endsWith(u8, p, r[0])) {
            const cand = std.fmt.bufPrint(&buf, "{s}{s}", .{ p[0 .. p.len - r[0].len], r[1] }) catch return null;
            if (known.getKey(cand)) |k| return k;
        }
    }
    return null;
}

/// The Crane commit a results label names, by the repository's convention
/// that a run's directory is `<purpose>-<short sha>` (wpt-results/ab-<sha>,
/// sweep-<sha>, testdriver-<sha>). Null when the label ends in anything but
/// 7 to 40 lowercase hex digits.
pub fn labelCommit(label: []const u8) ?[]const u8 {
    const dash = std.mem.lastIndexOfScalar(u8, label, '-') orelse return null;
    const tail = label[dash + 1 ..];
    if (tail.len < 7 or tail.len > 40) return null;
    for (tail) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return null;
    return tail;
}

/// `secs` (Unix time) as `YYYY-MM-DDTHH:MM:SSZ`.
pub fn isoUtc(buf: *[20]u8, secs: u64) []const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        yd.year,              md.month.numeric(),      @as(u32, md.day_index) + 1,
        ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch unreachable;
}

// ============================================================================
// Subtest detail
// ============================================================================

/// Above this many subtests in one file, its detail shard keeps every
/// subtest that did not pass, in full, and only a count of the passing ones:
/// the encoding/ codepoint sweeps report up to 23,097 each, nearly all PASS.
pub const detail_limit: usize = 500;

/// Whether a file with `total` subtests across its runs keeps its passing
/// ones in its detail shard.
pub fn keepsPassing(total: usize) bool {
    return total <= detail_limit;
}

// ============================================================================
// Gate exemptions
// ============================================================================

/// The three browsers an exemption needs evidence from, in the order the
/// evidence is stored and shown.
pub const Browser = enum {
    chrome,
    firefox,
    safari,

    pub fn label(b: Browser) []const u8 {
        return switch (b) {
            .chrome => "Chrome",
            .firefox => "Firefox",
            .safari => "Safari",
        };
    }
};

/// Why a file is exempt from the gate: the entry's `kind` key.
pub const ExemptionKind = enum {
    /// All three browsers intentionally deviate from the spec the file
    /// tests, each with evidence of intent (the user, 2026-10-17). An entry
    /// with no `kind` key is this kind, as every entry was before kinds.
    intentional,
    /// The file fails identically in Chrome, Firefox and Safari because of
    /// a bug in the test filed upstream (the user, 2026-11-08); exempt until
    /// that bug is resolved, then revisited.
    test_bug,
    /// The file fails ONLY because no renderer answers geometry - a layout
    /// box's size or position (the user, 2026-11-09): it still runs and
    /// shows, but does not block 0.1 until a renderer exists.
    needs_renderer,
    /// The file blocks although Crane's result is the one golden rule 2 says
    /// is correct: it equals the browser majority's, subtest by subtest, or a
    /// recorded ruling decides it, so no change in Crane can clear it (the
    /// user, 2026-11-18 2:36 PM ET, "Add the exemption kind"). The entry comes
    /// off when the browsers change.
    follows_majority,
    /// Like `needs_renderer`: the file fails ONLY because the platform WPT runs
    /// on has no decoder for its media (the user, 2026-11-18 2:53 PM ET); the
    /// entry comes off when a video-capable platform runs WPT.
    needs_decoder,
    /// The file tests a feature only ONE browser ships, and its remaining
    /// failures hinge on a mechanism where Crane does what the other two
    /// browsers and the spec do (the user, 2026-11-21 5:58 AM ET, choice (a)).
    /// The entry comes off when a second browser ships the feature.
    single_shipper,

    /// The word the file spells the kind with.
    pub fn word(k: ExemptionKind) []const u8 {
        return switch (k) {
            .intentional => "intentional",
            .test_bug => "test-bug",
            .needs_renderer => "needs-renderer",
            .follows_majority => "follows-majority",
            .needs_decoder => "needs-decoder",
            .single_shipper => "single-shipper",
        };
    }

    /// The kind a file's `kind` value names, or null.
    pub fn fromWord(w: []const u8) ?ExemptionKind {
        inline for (comptime std.enums.values(ExemptionKind)) |k| {
            if (std.mem.eql(u8, w, k.word())) return k;
        }
        return null;
    }
};

/// One entry of tools/wpt_gate_exemptions.txt: a worklist file omitted from
/// the blocking count - because all three browsers intentionally deviate from
/// the spec it tests (`intentional`), because it fails identically in all
/// three through a test bug filed upstream (`test_bug`), because it fails
/// only for want of a renderer to answer geometry (`needs_renderer`) or of a
/// decoder for its media (`needs_decoder`), because Crane's result is the
/// browser majority's (`follows_majority`), or because it tests a feature only
/// one browser ships (`single_shipper`). Every key of the entry's kind is
/// required but a follows-majority entry's ruling; slices point into the text.
pub const Exemption = struct {
    path: []const u8,
    kind: ExemptionKind = .intentional,
    /// What the browsers do instead, what is wrong with the test, why the
    /// failing assertion needs a layout box or a decoder, or what Crane does
    /// and which browsers do the same.
    why: []const u8,
    /// `intentional`: the spec text (and change) the browsers decline;
    /// `single_shipper`: the spec text of the mechanism Crane follows.
    spec: []const u8 = "",
    /// `intentional`, `test_bug`, `follows_majority` and `single_shipper`, per `Browser`:
    /// "wpt.fyi run <id>: <passes>/<total>".
    result: [3][]const u8 = .{ "", "", "" },
    /// `intentional` only, per `Browser`: the standards position, WontFix
    /// bug or objection URL.
    intent: [3][]const u8 = .{ "", "", "" },
    /// `test_bug` only: the web-platform-tests issue or pull request.
    upstream: []const u8 = "",
    /// `test_bug`: "when <upstream> is resolved"; `follows_majority`: "when
    /// ...", what ends the exemption; `single_shipper`: "when <a second
    /// browser> ships <the feature>".
    revisit: []const u8 = "",
    /// `needs_renderer` and `needs_decoder`: the failing assertion, as the run
    /// reports it.
    assertion: []const u8 = "",
    /// `follows_majority` only, per `Browser`: whether Crane's result equals
    /// that browser's, subtest by subtest (the `matches` key).
    matches: [3]bool = .{ false, false, false },
    /// `follows_majority` only, optional: the user's ruling, or the golden
    /// rule 2 case, that decides the entry.
    ruling: []const u8 = "",
    /// `needs_decoder` only: the media file(s) the test needs and their type.
    media: []const u8 = "",
    /// `follows_majority` only, optional: the subtests that fail in Crane
    /// only for want of a renderer, as written - "<name> :: <why>", several
    /// separated by " || " (`rendererSubtests`). With a renderer they would
    /// have the matched browsers' results.
    renderer_subtests: []const u8 = "",
    /// `single_shipper` only: the one browser that ships the feature.
    shipper: Browser = .chrome,
    /// `single_shipper` only: what Crane follows - what the other two
    /// browsers and the spec do.
    mechanism: []const u8 = "",

    pub const RendererSubtest = struct { name: []const u8, why: []const u8 };

    /// The entry's renderer subtests, in order.
    pub fn rendererSubtests(self: *const Exemption) RendererSubtestIterator {
        return .{ .rest = self.renderer_subtests };
    }

    pub fn rendererSubtestCount(self: *const Exemption) usize {
        var it = self.rendererSubtests();
        var n: usize = 0;
        while (it.next()) |_| n += 1;
        return n;
    }

    pub const RendererSubtestIterator = struct {
        rest: ?[]const u8,

        pub fn next(self: *RendererSubtestIterator) ?RendererSubtest {
            const rest = self.rest orelse return null;
            if (rest.len == 0) return null;
            const end = std.mem.indexOf(u8, rest, renderer_subtest_sep);
            const item = rest[0 .. end orelse rest.len];
            self.rest = if (end) |e| rest[e + renderer_subtest_sep.len ..] else null;
            return parseRendererSubtest(item);
        }
    };
};

/// `renderer-subtests` (lane blk5, main's GO 2026-11-20 1:37 PM ET): items
/// separated by " || ", each "<name> :: <why>".
const renderer_subtest_sep = " || ";
const renderer_reason_sep = " :: ";

fn parseRendererSubtest(item: []const u8) ?Exemption.RendererSubtest {
    const sep = std.mem.indexOf(u8, item, renderer_reason_sep) orelse return null;
    const name = std.mem.trim(u8, item[0..sep], " \t");
    const why = std.mem.trim(u8, item[sep + renderer_reason_sep.len ..], " \t");
    if (name.len == 0 or why.len == 0) return null;
    return .{ .name = name, .why = why };
}

/// Whether every item of a `renderer-subtests` value reads "<name> :: <why>".
fn validRendererSubtests(value: []const u8) bool {
    var rest: []const u8 = value;
    while (true) {
        const end = std.mem.indexOf(u8, rest, renderer_subtest_sep);
        if (parseRendererSubtest(rest[0 .. end orelse rest.len]) == null) return false;
        rest = rest[(end orelse return true) + renderer_subtest_sep.len ..];
    }
}

/// `matches = none` needs a ruling that names one of these golden rule 2
/// cases (main's GO 2026-11-20 1:37 PM ET): Crane's result is the spec's.
const none_ruling_cases = [_][]const u8{ "all three differ", "newer spec", "timing-bound" };

/// Where and why the exemptions are invalid. The message lives in `buf`, so
/// it outlives the parse's arena; `path` points into the caller's text.
pub const ExemptionDiag = struct {
    /// 1-based line of the text; 0 when the problem is not one line's.
    line: usize = 0,
    message: []const u8 = "",
    buf: [512]u8 = undefined,
    /// The exempt path a problem is about, when it is not one line's.
    path: []const u8 = "",
};

const exemption_keys = [_][]const u8{
    "why",            "spec",
    "chrome.result",  "chrome.intent",
    "firefox.result", "firefox.intent",
    "safari.result",  "safari.intent",
    "kind",           "upstream",
    "revisit",        "assertion",
    "matches",        "ruling",
    "media",          "renderer-subtests",
    "shipper",        "mechanism",
};
const key_why = 0;
const key_spec = 1;
const key_kind = 8;
const key_upstream = 9;
const key_revisit = 10;
const key_assertion = 11;
const key_matches = 12;
const key_ruling = 13;
const key_media = 14;
const key_renderer_subtests = 15;
const key_shipper = 16;
const key_mechanism = 17;
/// The `result` key of each `Browser`, and its `intent` key (the next one).
const key_result = [3]usize{ 2, 4, 6 };

/// Which keys an entry of `kind` has: every one of them is required but
/// those `optionalKey` names, and no other may appear.
fn keyOf(kind: ExemptionKind, ki: usize) bool {
    const is_result = for (key_result) |r| {
        if (ki == r) break true;
    } else false;
    return switch (kind) {
        .intentional => ki <= 7 or ki == key_kind,
        .test_bug => is_result or switch (ki) {
            key_why, key_kind, key_upstream, key_revisit => true,
            else => false,
        },
        .needs_renderer => ki == key_why or ki == key_kind or ki == key_assertion,
        .follows_majority => is_result or switch (ki) {
            key_why, key_kind, key_matches, key_ruling, key_revisit, key_renderer_subtests => true,
            else => false,
        },
        .needs_decoder => ki == key_why or ki == key_kind or ki == key_media or ki == key_assertion,
        .single_shipper => is_result or switch (ki) {
            key_why, key_kind, key_shipper, key_mechanism, key_spec, key_revisit => true,
            else => false,
        },
    };
}

/// The keys of `kind` an entry may leave out: `kind` itself (an intentional
/// entry written before kinds existed has none; every other kind names
/// itself), and a follows-majority entry's ruling.
fn optionalKey(kind: ExemptionKind, ki: usize) bool {
    return ki == key_kind or (kind == .follows_majority and (ki == key_ruling or ki == key_renderer_subtests));
}

/// A `shipper` value: one of "chrome", "firefox" and "safari"; null for
/// anything else.
fn parseShipper(v: []const u8) ?Browser {
    if (std.mem.eql(u8, v, "chrome")) return .chrome;
    if (std.mem.eql(u8, v, "firefox")) return .firefox;
    if (std.mem.eql(u8, v, "safari")) return .safari;
    return null;
}

/// A single-shipper entry's revisit: "when <...> ships <...>" - the entry
/// comes off when a second browser ships the feature.
fn shipsRevisit(v: []const u8) bool {
    if (v.len <= revisit_prefix.len or !std.mem.startsWith(u8, v, revisit_prefix) or v[revisit_prefix.len] == ' ') return false;
    const at = std.mem.indexOf(u8, v[revisit_prefix.len..], " ships ") orelse return false;
    const after = v[revisit_prefix.len + at + " ships ".len ..];
    return after.len > 0 and after[0] != ' ';
}

/// A `matches` value: Chrome, Firefox or Safari ("chrome", "firefox",
/// "safari"), comma-separated, each once, or "none" (no browser: all false);
/// null when it is anything else.
fn parseMatches(v: []const u8) ?[3]bool {
    var out: [3]bool = .{ false, false, false };
    if (std.mem.eql(u8, std.mem.trim(u8, v, " \t"), "none")) return out;
    var it = std.mem.splitScalar(u8, v, ',');
    while (it.next()) |raw| {
        const name = std.mem.trim(u8, raw, " \t");
        const b: Browser = if (std.mem.eql(u8, name, "chrome")) .chrome else if (std.mem.eql(u8, name, "firefox")) .firefox else if (std.mem.eql(u8, name, "safari")) .safari else return null;
        if (out[@backingInt(b)]) return null;
        out[@backingInt(b)] = true;
    }
    return out;
}

fn isHttpUrl(v: []const u8) bool {
    const rest = if (std.mem.startsWith(u8, v, "https://"))
        v["https://".len..]
    else if (std.mem.startsWith(u8, v, "http://"))
        v["http://".len..]
    else
        return false;
    return rest.len > 0 and std.mem.indexOfAny(u8, v, " \t") == null;
}

fn digitsAt(v: []const u8, i: *usize) bool {
    const start = i.*;
    while (i.* < v.len and std.ascii.isDigit(v[i.*])) i.* += 1;
    return i.* > start;
}

/// "wpt.fyi run <id>: <passes>/<total>", optionally followed by a note.
fn isWptFyiResult(v: []const u8) bool {
    const prefix = "wpt.fyi run ";
    if (!std.mem.startsWith(u8, v, prefix)) return false;
    var i: usize = prefix.len;
    if (!digitsAt(v, &i)) return false;
    if (i >= v.len or v[i] != ':') return false;
    i += 1;
    while (i < v.len and v[i] == ' ') i += 1;
    if (!digitsAt(v, &i)) return false;
    if (i >= v.len or v[i] != '/') return false;
    i += 1;
    return digitsAt(v, &i);
}

/// A web-platform-tests issue or pull request:
/// "https://github.com/web-platform-tests/wpt/issues/<n>" or ".../pull/<n>".
fn isWptIssueUrl(v: []const u8) bool {
    const base = "https://github.com/web-platform-tests/wpt/";
    if (!std.mem.startsWith(u8, v, base)) return false;
    var rest = v[base.len..];
    if (std.mem.startsWith(u8, rest, "issues/")) {
        rest = rest["issues/".len..];
    } else if (std.mem.startsWith(u8, rest, "pull/")) {
        rest = rest["pull/".len..];
    } else return false;
    var i: usize = 0;
    return digitsAt(rest, &i) and i == rest.len;
}

const revisit_prefix = "when ";
const revisit_suffix = " is resolved";

/// The "<passes>/<total>" of a wpt.fyi result already checked by
/// `isWptFyiResult`.
fn resultCounts(v: []const u8) []const u8 {
    const colon = std.mem.indexOfScalar(u8, v, ':').?;
    var i = colon + 1;
    while (v[i] == ' ') i += 1;
    const start = i;
    _ = digitsAt(v, &i);
    i += 1; // '/'
    _ = digitsAt(v, &i);
    return v[start..i];
}

fn invalid(diag: *ExemptionDiag, line: usize, comptime fmt: []const u8, args: anytype) error{InvalidExemption} {
    diag.line = line;
    diag.message = std.fmt.bufPrint(&diag.buf, fmt, args) catch diag.buf[0..];
    return error.InvalidExemption;
}

const PendingExemption = struct {
    path: []const u8,
    line: usize,
    values: [exemption_keys.len]?[]const u8 = @splat(null),
    lines: [exemption_keys.len]usize = @splat(0),
};

fn finishExemption(p: PendingExemption, diag: *ExemptionDiag) error{InvalidExemption}!Exemption {
    const v = p.values;
    // No kind: intentional, the one kind there was before the user's
    // 2026-11-08 ruling added the second - every older entry keeps its meaning.
    const kind: ExemptionKind = if (v[key_kind]) |k| ExemptionKind.fromWord(k).? else .intentional;
    const article = if (kind == .intentional) "an" else "a";
    // A key of the other kind: the entry mixes them (or names the wrong kind).
    for (v, exemption_keys, 0..) |value, k, ki| {
        if (value != null and !keyOf(kind, ki))
            return invalid(diag, p.lines[ki], "[{s}]: \"{s}\" is not a key of {s} {s} exemption", .{ p.path, k, article, kind.word() });
    }
    for (v, exemption_keys, 0..) |value, k, ki| {
        if (optionalKey(kind, ki) or !keyOf(kind, ki)) continue;
        if (value == null) return switch (kind) {
            .intentional => invalid(diag, p.line, "[{s}]: missing \"{s}\" - an exemption needs the spec and every browser's evidence", .{ p.path, k }),
            .test_bug => invalid(diag, p.line, "[{s}]: missing \"{s}\" - a test-bug exemption needs the upstream issue, every browser's result and when to revisit", .{ p.path, k }),
            .needs_renderer => invalid(diag, p.line, "[{s}]: missing \"{s}\" - a needs-renderer exemption needs the failing assertion and why it needs a layout box", .{ p.path, k }),
            .follows_majority => invalid(diag, p.line, "[{s}]: missing \"{s}\" - a follows-majority exemption needs every browser's result, the browsers Crane matches and when to revisit", .{ p.path, k }),
            .needs_decoder => invalid(diag, p.line, "[{s}]: missing \"{s}\" - a needs-decoder exemption needs the media the test plays, the failing assertion and why it needs a decoder", .{ p.path, k }),
            .single_shipper => invalid(diag, p.line, "[{s}]: missing \"{s}\" - a single-shipper exemption needs the browser that ships the feature, every browser's result, the mechanism Crane follows with its spec, and when to revisit", .{ p.path, k }),
        };
    }
    switch (kind) {
        .intentional => return .{
            .path = p.path,
            .why = v[key_why].?,
            .spec = v[key_spec].?,
            .result = .{ v[2].?, v[4].?, v[6].? },
            .intent = .{ v[3].?, v[5].?, v[7].? },
        },
        .test_bug => {
            const upstream = v[key_upstream].?;
            const revisit = v[key_revisit].?;
            const formed = revisit.len > revisit_prefix.len + revisit_suffix.len and
                std.mem.startsWith(u8, revisit, revisit_prefix) and std.mem.endsWith(u8, revisit, revisit_suffix);
            if (!formed or !std.mem.eql(u8, revisit[revisit_prefix.len .. revisit.len - revisit_suffix.len], upstream))
                return invalid(diag, p.lines[key_revisit], "[{s}]: revisit must read \"when {s} is resolved\"", .{ p.path, upstream });
            // "Fails IDENTICALLY in Chrome, Firefox and Safari": the same
            // passes of the same total in each browser's run.
            const counts = [3][]const u8{ resultCounts(v[2].?), resultCounts(v[4].?), resultCounts(v[6].?) };
            if (!std.mem.eql(u8, counts[0], counts[1]) or !std.mem.eql(u8, counts[0], counts[2]))
                return invalid(diag, p.line, "[{s}]: a test-bug exemption needs the same result in all three browsers (Chrome {s}, Firefox {s}, Safari {s})", .{ p.path, counts[0], counts[1], counts[2] });
            return .{
                .path = p.path,
                .kind = .test_bug,
                .why = v[key_why].?,
                .result = .{ v[2].?, v[4].?, v[6].? },
                .upstream = upstream,
                .revisit = revisit,
            };
        },
        .needs_renderer => return .{
            .path = p.path,
            .kind = .needs_renderer,
            .why = v[key_why].?,
            .assertion = v[key_assertion].?,
        },
        .follows_majority => {
            const revisit = v[key_revisit].?;
            if (revisit.len <= revisit_prefix.len or !std.mem.startsWith(u8, revisit, revisit_prefix))
                return invalid(diag, p.lines[key_revisit], "[{s}]: revisit must read \"when <what ends the exemption>\"", .{p.path});
            const matches = parseMatches(v[key_matches].?).?;
            var n: usize = 0;
            for (matches) |m| n += @intFromBool(m);
            // matches = none: the spec's result, which no browser has - with
            // a ruling that names its golden rule 2 case.
            if (n == 0) {
                const ruling = v[key_ruling] orelse "";
                const named = for (none_ruling_cases) |case| {
                    if (std.mem.indexOf(u8, ruling, case) != null) break true;
                } else false;
                if (!named) return invalid(diag, p.lines[key_matches], "[{s}]: matches = none needs a ruling that names its golden rule 2 case: \"all three differ\", \"newer spec\", \"timing-bound\"", .{p.path});
            }
            // The user's 2026-11-18 ruling: the browser majority - or a recorded ruling.
            if (n < 2 and v[key_ruling] == null)
                return invalid(diag, p.lines[key_matches], "[{s}]: a follows-majority exemption needs at least two browsers in matches, or a ruling", .{p.path});
            // Crane's result equals each matched browser's, so theirs are the same.
            var first: ?[]const u8 = null;
            var differ = false;
            for (matches, key_result) |m, r| {
                if (!m) continue;
                const c = resultCounts(v[r].?);
                if (first) |f| {
                    if (!std.mem.eql(u8, f, c)) differ = true;
                } else first = c;
            }
            if (differ) {
                var shown: [128]u8 = undefined;
                var len: usize = 0;
                inline for (comptime std.enums.values(Browser)) |b| {
                    if (matches[@backingInt(b)]) {
                        const part = std.fmt.bufPrint(shown[len..], "{s}{s} {s}", .{ if (len == 0) "" else ", ", b.label(), resultCounts(v[key_result[@backingInt(b)]].?) }) catch "";
                        len += part.len;
                    }
                }
                return invalid(diag, p.line, "[{s}]: the browsers in matches need the same result ({s})", .{ p.path, shown[0..len] });
            }
            return .{
                .path = p.path,
                .kind = .follows_majority,
                .why = v[key_why].?,
                .result = .{ v[2].?, v[4].?, v[6].? },
                .matches = matches,
                .ruling = v[key_ruling] orelse "",
                .revisit = revisit,
                .renderer_subtests = v[key_renderer_subtests] orelse "",
            };
        },
        .needs_decoder => return .{
            .path = p.path,
            .kind = .needs_decoder,
            .why = v[key_why].?,
            .media = v[key_media].?,
            .assertion = v[key_assertion].?,
        },
        .single_shipper => {
            const revisit = v[key_revisit].?;
            if (!shipsRevisit(revisit))
                return invalid(diag, p.lines[key_revisit], "[{s}]: revisit must read \"when <a second browser> ships <the feature>\"", .{p.path});
            const shipper = parseShipper(v[key_shipper].?).?;
            // The two that do not ship the feature fail it alike.
            var others: [2]Browser = undefined;
            var n: usize = 0;
            for (std.enums.values(Browser)) |browser| {
                if (browser == shipper) continue;
                others[n] = browser;
                n += 1;
            }
            const first = resultCounts(v[key_result[@backingInt(others[0])]].?);
            const second = resultCounts(v[key_result[@backingInt(others[1])]].?);
            if (!std.mem.eql(u8, first, second))
                return invalid(diag, p.line, "[{s}]: the browsers that do not ship the feature need the same result ({s} {s}, {s} {s})", .{ p.path, others[0].label(), first, others[1].label(), second });
            return .{
                .path = p.path,
                .kind = .single_shipper,
                .why = v[key_why].?,
                .spec = v[key_spec].?,
                .result = .{ v[2].?, v[4].?, v[6].? },
                .revisit = revisit,
                .shipper = shipper,
                .mechanism = v[key_mechanism].?,
            };
        },
    }
}

/// Parses tools/wpt_gate_exemptions.txt (its header documents the format;
/// tools/wpt_progress.py `load_exemptions` reads it by the same rules).
/// Any invalid entry fails the whole parse with `diag` set: a malformed
/// exemption must stop the report, never exempt silently or be skipped.
pub fn parseExemptions(arena: std.mem.Allocator, text: []const u8, diag: *ExemptionDiag) error{ InvalidExemption, OutOfMemory }![]const Exemption {
    var out: std.ArrayList(Exemption) = .empty;
    var cur: ?PendingExemption = null;
    var it = std.mem.splitScalar(u8, text, '\n');
    var n: usize = 0;
    while (it.next()) |raw| {
        n += 1;
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (line[0] == '[') {
            if (line.len < 3 or line[line.len - 1] != ']' or std.mem.indexOfAny(u8, line[1 .. line.len - 1], " \t[]") != null)
                return invalid(diag, n, "\"{s}\": expected [path], a worklist path in brackets", .{line});
            if (cur) |p| try out.append(arena, try finishExemption(p, diag));
            const path = line[1 .. line.len - 1];
            for (out.items) |e| if (std.mem.eql(u8, e.path, path))
                return invalid(diag, n, "[{s}] is listed twice", .{path});
            cur = .{ .path = path, .line = n };
            continue;
        }
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse
            return invalid(diag, n, "\"{s}\": expected key = value", .{line});
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
        const p = if (cur) |*c| c else return invalid(diag, n, "\"{s}\" before any [path]", .{key});
        const ki = for (exemption_keys, 0..) |k, i| {
            if (std.mem.eql(u8, k, key)) break i;
        } else return invalid(diag, n, "[{s}]: unknown key \"{s}\"", .{ p.path, key });
        if (p.values[ki] != null) return invalid(diag, n, "[{s}]: \"{s}\" given twice", .{ p.path, key });
        if (value.len == 0) return invalid(diag, n, "[{s}]: \"{s}\" is empty", .{ p.path, key });
        const is_result = std.mem.endsWith(u8, key, ".result");
        if (is_result and !isWptFyiResult(value))
            return invalid(diag, n, "[{s}]: {s} must read \"wpt.fyi run <id>: <passes>/<total>\"", .{ p.path, key });
        if ((std.mem.eql(u8, key, "spec") or std.mem.endsWith(u8, key, ".intent")) and !isHttpUrl(value))
            return invalid(diag, n, "[{s}]: {s} must be an http(s) URL", .{ p.path, key });
        if (ki == key_kind and ExemptionKind.fromWord(value) == null)
            return invalid(diag, n, "[{s}]: kind must be intentional, test-bug, needs-renderer, follows-majority, needs-decoder or single-shipper, not \"{s}\"", .{ p.path, value });
        if (ki == key_shipper and parseShipper(value) == null)
            return invalid(diag, n, "[{s}]: shipper must name chrome, firefox or safari", .{p.path});
        if (ki == key_upstream and !isWptIssueUrl(value))
            return invalid(diag, n, "[{s}]: upstream must be a web-platform-tests issue or pull request (https://github.com/web-platform-tests/wpt/issues/<n> or /pull/<n>)", .{p.path});
        // (revisit's form is the kind's: checked when the entry is finished.)
        if (ki == key_matches and parseMatches(value) == null)
            return invalid(diag, n, "[{s}]: matches must name chrome, firefox or safari, comma-separated, each once, or read none", .{p.path});
        if (ki == key_renderer_subtests and !validRendererSubtests(value))
            return invalid(diag, n, "[{s}]: renderer-subtests must give each subtest its name and its geometry reason (\"<name> :: <why>\", several separated by \" || \")", .{p.path});
        p.values[ki] = value;
        p.lines[ki] = n;
    }
    if (cur) |p| try out.append(arena, try finishExemption(p, diag));
    return out.items;
}

// ============================================================================
// Where each generation was swept
// ============================================================================

/// One line of tools/wpt_generation_hosts.txt: the host a results run (a
/// sweep, by its label in wpt-results/) ran on, that host's OS and
/// architecture, and how many runners the run used. Slices point into the text.
pub const SweepHost = struct {
    label: []const u8,
    host: []const u8,
    /// "<os>-<arch>": "linux-x86_64", "macos-arm64".
    os: []const u8,
    runners: u32,
    /// The host's installed font set when the run was made (`fonts=<hash>`,
    /// a hash of its fontconfig list): the production run takes its fonts
    /// from the host, as a browser does (lane wptcfg; the integrator accepted
    /// recording it with each generation, as wpt.fyi pins its font set in its
    /// image), so a generation names the set its font results came from.
    /// Null: not recorded.
    fonts: ?[]const u8 = null,
};

/// Parses tools/wpt_generation_hosts.txt (its header documents the format):
/// one `<label> <host> <os>-<arch> <runners> [fonts=<hash>]` line per run. Any invalid line
/// fails the whole parse with `diag` set: a wrong host must stop the site,
/// never print silently.
pub fn parseSweepHosts(arena: std.mem.Allocator, text: []const u8, diag: *ExemptionDiag) error{ InvalidHosts, OutOfMemory }![]const SweepHost {
    var out: std.ArrayList(SweepHost) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    var n: usize = 0;
    while (it.next()) |raw| {
        n += 1;
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        // One more than a line may hold, so a line with too many is seen.
        var fields: [6][]const u8 = undefined;
        var count: usize = 0;
        var words = std.mem.tokenizeAny(u8, line, " \t");
        while (words.next()) |word| : (count += 1) {
            if (count == fields.len) break;
            fields[count] = word;
        }
        if (count != 4 and count != 5) return hostsInvalid(diag, n, "\"{s}\": expected <label> <host> <os>-<arch> <runners> [fonts=<hash>]", .{line});
        const fonts: ?[]const u8 = if (count == 5) fonts: {
            const prefix = "fonts=";
            const hash = if (std.mem.startsWith(u8, fields[4], prefix)) fields[4][prefix.len..] else "";
            const hex = hash.len > 0 and for (hash) |c| {
                if (!std.ascii.isHex(c)) break false;
            } else true;
            if (!hex) return hostsInvalid(diag, n, "\"{s}\": the fifth field must read fonts=<hash> (hex)", .{fields[4]});
            break :fonts hash;
        } else null;
        const os = fields[2];
        const dash = std.mem.indexOfScalar(u8, os, '-') orelse 0;
        const known_os = std.mem.eql(u8, os[0..dash], "linux") or std.mem.eql(u8, os[0..dash], "macos");
        const arch = os[@min(dash + 1, os.len)..];
        const arch_ok = arch.len > 0 and for (arch) |c| {
            if (!(std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '_')) break false;
        } else true;
        if (dash == 0 or !known_os or !arch_ok)
            return hostsInvalid(diag, n, "\"{s}\": the OS must read <os>-<arch>, <os> linux or macos (linux-x86_64, macos-arm64)", .{os});
        const runners = std.fmt.parseInt(u32, fields[3], 10) catch 0;
        if (runners == 0) return hostsInvalid(diag, n, "\"{s}\": runners must be a whole number above 0", .{fields[3]});
        for (out.items) |h| if (std.mem.eql(u8, h.label, fields[0]))
            return hostsInvalid(diag, n, "{s} is listed twice", .{fields[0]});
        try out.append(arena, .{ .label = fields[0], .host = fields[1], .os = os, .runners = runners, .fonts = fonts });
    }
    return out.items;
}

fn hostsInvalid(diag: *ExemptionDiag, line: usize, comptime fmt: []const u8, args: anytype) error{InvalidHosts} {
    diag.line = line;
    diag.message = std.fmt.bufPrint(&diag.buf, fmt, args) catch diag.buf[0..];
    return error.InvalidHosts;
}

/// "linux-x86_64" as the site says it: "Linux x86-64"; "macos-arm64":
/// "macOS arm64". The OS was checked by `parseSweepHosts`.
pub fn osLabel(w: *std.Io.Writer, os: []const u8) std.Io.Writer.Error!void {
    const dash = std.mem.indexOfScalar(u8, os, '-') orelse return w.writeAll(os);
    const name = os[0..dash];
    try w.writeAll(if (std.mem.eql(u8, name, "macos")) "macOS" else if (std.mem.eql(u8, name, "linux")) "Linux" else name);
    try w.writeByte(' ');
    const arch = os[dash + 1 ..];
    try w.writeAll(if (std.mem.eql(u8, arch, "x86_64")) "x86-64" else arch);
}

/// Every exemption names a worklist file: an exemption for a file the gate
/// does not count is a typo or a stale entry, and either is an error.
pub fn checkExemptionPaths(list: []const Exemption, known: *const std.StringHashMapUnmanaged(void), diag: *ExemptionDiag) error{InvalidExemption}!void {
    for (list) |e| {
        if (!known.contains(e.path)) {
            diag.line = 0;
            diag.path = e.path;
            diag.message = "an exempt path is not in the worklist";
            return error.InvalidExemption;
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "gate: an OK run with nothing passing is NONE-PASSED, and it blocks" {
    const g = gateOf("OK", .{ .failed = 3 });
    try testing.expectEqual(Gate.none_passed, g);
    try testing.expect(g.blocking());
    try testing.expectEqualStrings("none-passed", g.word());
    // Timed-out or not-run subtests alone are still nothing passing.
    try testing.expectEqual(Gate.none_passed, gateOf("OK", .{ .timed_out = 1, .notrun = 2 }));
}

test "gate: an OK run with no subtests at all is empty, not NONE-PASSED" {
    const g = gateOf("OK", .{});
    try testing.expectEqual(Gate.empty, g);
    try testing.expect(!g.blocking());
}

test "gate: an OK crashtest counts as clean, not empty or NONE-PASSED; non-OK still blocks" {
    const g = gateOf("OK", .{ .crashtest = true });
    try testing.expectEqual(Gate.clean, g);
    try testing.expect(!g.blocking());
    try testing.expectEqual(Gate.clean, gateOf("OK", .{ .failed = 1, .crashtest = true }));
    try testing.expectEqual(Gate.clean, gateOfRecord("OK", .{}, true));
    try testing.expectEqual(Gate.empty, gateOfRecord("OK", .{}, false));
    try testing.expectEqual(Gate.timeout, gateOf("TIMEOUT", .{ .crashtest = true }));
    try testing.expect(gateOf("TIMEOUT", .{ .crashtest = true }).blocking());
    try testing.expectEqual(Gate.crash, gateOf("CRASH", .{ .crashtest = true }));
    try testing.expectEqual(Gate.err, gateOf("ERROR", .{ .crashtest = true }));
    try testing.expectEqual(Gate.unrun, gateOf(null, .{ .crashtest = true }));
    var t: Totals = .{};
    t.add(gateOfRecord("OK", .{}, true), .{ .crashtest = true });
    t.add(gateOfRecord("TIMEOUT", .{}, true), .{ .crashtest = true });
    try testing.expectEqual(@as(u64, 2), t.files);
    try testing.expectEqual(@as(u64, 1), t.clean);
    try testing.expectEqual(@as(u64, 0), t.empty);
    try testing.expectEqual(@as(u64, 0), t.none_passed);
    try testing.expectEqual(@as(u64, 1), t.blocking());
}

test "gate: clean means every reported subtest passed, NOTRUN included" {
    try testing.expectEqual(Gate.clean, gateOf("OK", .{ .passed = 5 }));
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 5, .failed = 1 }));
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 5, .timed_out = 1 }));
    // wpt_progress.py would call this clean; a NOTRUN subtest did not pass.
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 5, .notrun = 1 }));
}

test "gate: runner statuses, the unknown default, and no record" {
    try testing.expectEqual(Gate.timeout, gateOf("TIMEOUT", .{ .passed = 4 }));
    try testing.expectEqual(Gate.crash, gateOf("CRASH", .{}));
    try testing.expectEqual(Gate.err, gateOf("ERROR", .{}));
    try testing.expectEqual(Gate.err, gateOf("EXTERNAL-TIMEOUT", .{}));
    try testing.expectEqual(Gate.err, gateOf("PRECONDITION_FAILED", .{}));
    // The default for a status nobody taught this code is the safe one.
    try testing.expectEqual(Gate.err, gateOf("SOMETHING-NEW", .{ .passed = 9 }));
    try testing.expect(gateOf("SOMETHING-NEW", .{}).blocking());
    try testing.expectEqual(Gate.unrun, gateOf(null, .{}));
    try testing.expect(!Gate.unrun.blocking());
}

test "totals: blocking is the four blocking kinds, subtests are reported counts" {
    var t: Totals = .{};
    t.add(gateOf("OK", .{ .passed = 2 }), .{ .passed = 2 });
    t.add(gateOf("OK", .{ .passed = 1, .failed = 1 }), .{ .passed = 1, .failed = 1 });
    t.add(gateOf("OK", .{ .failed = 4 }), .{ .failed = 4 });
    t.add(gateOf("TIMEOUT", .{ .passed = 3, .timed_out = 1 }), .{ .passed = 3, .timed_out = 1 });
    t.add(gateOf("CRASH", .{}), .{});
    t.add(gateOf("ERROR", .{}), .{});
    t.add(gateOf(null, .{}), .{});
    try testing.expectEqual(@as(u64, 7), t.files);
    try testing.expectEqual(@as(u64, 4), t.blocking());
    try testing.expectEqual(@as(u64, 1), t.clean);
    try testing.expectEqual(@as(u64, 1), t.partial);
    try testing.expectEqual(@as(u64, 1), t.unrun);
    // A timed-out file's passing subtests still count as passed subtests.
    try testing.expectEqual(@as(u64, 6), t.sub_pass);
    try testing.expectEqual(@as(u64, 12), t.subReported());

    var sum: Totals = .{};
    sum.merge(t);
    sum.merge(t);
    try testing.expectEqual(@as(u64, 14), sum.files);
    try testing.expectEqual(@as(u64, 8), sum.blocking());
}

test "totals: JSON keys are sorted and every count is present" {
    var t: Totals = .{};
    t.add(.timeout, .{ .passed = 1, .timed_out = 2 });
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try t.writeJson(&aw.writer);
    const json = aw.written();
    try testing.expectEqualStrings(
        "{\"blocking\":1,\"clean\":0,\"crash\":0,\"empty\":0,\"error\":0,\"exempt\":0,\"files\":1,\"none_passed\":0," ++
            "\"partial\":0,\"sub_fail\":0,\"sub_notrun\":0,\"sub_pass\":1,\"sub_reported\":3,\"sub_timeout\":2," ++
            "\"timeout\":1,\"unrun\":0}",
        json,
    );
    // Sorted keys: every key is greater than the one before it.
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, json, .{});
    defer parsed.deinit();
    const keys = parsed.value.object.keys();
    for (keys[1..], keys[0 .. keys.len - 1]) |k, prev| try testing.expect(std.mem.order(u8, prev, k) == .lt);
    // And no ratio anywhere: the site shows no headline percentage.
    try testing.expect(std.mem.indexOf(u8, json, "pct") == null and std.mem.indexOf(u8, json, "rate") == null);
}

test "test URLs map back to their worklist source" {
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    for ([_][]const u8{
        "console/console-is-a-namespace.any.js",
        "dom/nodes/Node-cloneNode.html",
        "html/x/real.worker.html",
        "fetch/api/basic.window.js",
        "workers/thing.worker.js",
        "encoding/legacy-mb-korean/euc-kr/euckr-encode-href-errors-han.html",
    }) |k| try known.put(testing.allocator, k, {});

    const cases = [_][2][]const u8{
        .{ "/console/console-is-a-namespace.any.html", "console/console-is-a-namespace.any.js" },
        .{ "/console/console-is-a-namespace.any.worker.html", "console/console-is-a-namespace.any.js" },
        .{ "/console/console-is-a-namespace.any.sharedworker-module.html", "console/console-is-a-namespace.any.js" },
        .{ "/dom/nodes/Node-cloneNode.html", "dom/nodes/Node-cloneNode.html" },
        .{ "/fetch/api/basic.window.html", "fetch/api/basic.window.js" },
        .{ "/workers/thing.worker.html", "workers/thing.worker.js" },
        // A document that really is named .worker.html is not rewritten.
        .{ "/html/x/real.worker.html", "html/x/real.worker.html" },
        // A variant's query is not part of the source.
        .{ "/encoding/legacy-mb-korean/euc-kr/euckr-encode-href-errors-han.html?1001-2000", "encoding/legacy-mb-korean/euc-kr/euckr-encode-href-errors-han.html" },
    };
    for (cases) |c| {
        const got = sourceForTestUrl(&known, c[0]) orelse return error.TestExpectedSource;
        try testing.expectEqualStrings(c[1], got);
    }
    try testing.expect(sourceForTestUrl(&known, "/not/in/worklist.html") == null);
    try testing.expect(sourceForTestUrl(&known, "/crane/our-own.any.html") == null);
}

test "a results label names its Crane commit by its hex suffix" {
    try testing.expectEqualStrings("5c8dd64da", labelCommit("sweep-5c8dd64da").?);
    try testing.expectEqualStrings("97899d589", labelCommit("testdriver-97899d589").?);
    try testing.expectEqualStrings("1abc6828a", labelCommit("networking-1abc6828a").?);
    try testing.expect(labelCommit("sweep-1c0e1f867-partial") == null);
    try testing.expect(labelCommit("ab-scripting") == null);
    try testing.expect(labelCommit("archive") == null);
    try testing.expect(labelCommit("x-ABCDEF0123") == null);
    try testing.expect(labelCommit("x-abc12") == null);
}

test "a journal mtime renders as ISO 8601 UTC" {
    var buf: [20]u8 = undefined;
    try testing.expectEqualStrings("1970-01-01T00:00:00Z", isoUtc(&buf, 0));
    // The testdriver sweep's journal, 1790781505 = 2026-09-30 15:18:25 UTC.
    try testing.expectEqualStrings("2026-09-30T15:18:25Z", isoUtc(&buf, 1790781505));
}

test "detail shards keep passing subtests only up to the limit" {
    try testing.expect(keepsPassing(0));
    try testing.expect(keepsPassing(detail_limit));
    try testing.expect(!keepsPassing(detail_limit + 1));
    try testing.expect(!keepsPassing(23097));
}

// ============================================================================
// Gate exemptions (tests)
// ============================================================================

const fixture_exemption =
    \\# a comment
    \\
    \\[css/x/declined.html]
    \\why = all three keep the old behaviour on purpose
    \\spec = https://example.org/spec#step
    \\chrome.result = wpt.fyi run 6218298311311360: 0/4
    \\chrome.intent = https://issues.chromium.org/issues/1
    \\firefox.result = wpt.fyi run 4877098740350976: 0/4
    \\firefox.intent = https://bugzilla.mozilla.org/show_bug.cgi?id=2
    \\safari.result = wpt.fyi run 5164107446878208: 1/4
    \\safari.intent = https://github.com/WebKit/standards-positions/issues/3
    \\
;

test "exemptions: a complete entry parses, with every browser's evidence" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_exemption, &diag);
    try testing.expectEqual(@as(usize, 1), list.len);
    const e = list[0];
    try testing.expectEqualStrings("css/x/declined.html", e.path);
    try testing.expectEqualStrings("all three keep the old behaviour on purpose", e.why);
    try testing.expectEqualStrings("https://example.org/spec#step", e.spec);
    try testing.expectEqualStrings("wpt.fyi run 4877098740350976: 0/4", e.result[@backingInt(Browser.firefox)]);
    try testing.expectEqualStrings("https://github.com/WebKit/standards-positions/issues/3", e.intent[@backingInt(Browser.safari)]);
}

test "exemptions: the empty file, and comments alone, exempt nothing" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    try testing.expectEqual(@as(usize, 0), (try parseExemptions(arena.allocator(), "", &diag)).len);
    try testing.expectEqual(@as(usize, 0), (try parseExemptions(arena.allocator(), "# only\n\n# comments\n", &diag)).len);
}

fn expectInvalid(text: []const u8, needle: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    try testing.expectError(error.InvalidExemption, parseExemptions(arena.allocator(), text, &diag));
    if (std.mem.indexOf(u8, diag.message, needle) == null) {
        std.debug.print("diag {d}: \"{s}\" lacks \"{s}\"\n", .{ diag.line, diag.message, needle });
        return error.TestUnexpectedDiagnostic;
    }
}

test "exemptions: an entry missing any browser's evidence is invalid, never a silent exemption" {
    // Each required key removed in turn.
    const keys = [_][]const u8{ "why =", "spec =", "chrome.result", "chrome.intent", "firefox.result", "firefox.intent", "safari.result", "safari.intent" };
    for (keys) |k| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(testing.allocator);
        var it = std.mem.splitScalar(u8, fixture_exemption, '\n');
        while (it.next()) |line| {
            if (std.mem.startsWith(u8, line, k)) continue;
            try buf.appendSlice(testing.allocator, line);
            try buf.append(testing.allocator, '\n');
        }
        try expectInvalid(buf.items, "missing");
    }
}

test "exemptions: malformed values, duplicates, unknown keys and stray lines are invalid" {
    const swap = struct {
        fn f(a: std.mem.Allocator, from: []const u8, to: []const u8) ![]u8 {
            return std.mem.replaceOwned(u8, a, fixture_exemption, from, to);
        }
    }.f;
    const a = testing.allocator;
    const cases = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "https://bugzilla.mozilla.org/show_bug.cgi?id=2", "bug 2", "URL" },
        .{ "https://example.org/spec#step", "the spec", "URL" },
        .{ "wpt.fyi run 6218298311311360: 0/4", "fails", "wpt.fyi run" },
        .{ "wpt.fyi run 5164107446878208: 1/4", "wpt.fyi run x: 1/4", "wpt.fyi run" },
        .{ "chrome.intent", "edge.intent", "unknown key" },
        .{ "why = all", "why all", "key = value" },
        .{ "[css/x/declined.html]", "[]", "path" },
    };
    for (cases) |c| {
        const text = try swap(a, c[0], c[1]);
        defer a.free(text);
        try expectInvalid(text, c[2]);
    }
    // A key before any [path].
    try expectInvalid("why = x\n", "before");
    // A key given twice.
    {
        const text = try swap(a, "spec = ", "spec = https://a.example/\nspec = ");
        defer a.free(text);
        try expectInvalid(text, "twice");
    }
    // A path listed twice.
    {
        const text = try std.mem.concat(a, u8, &.{ fixture_exemption, fixture_exemption });
        defer a.free(text);
        try expectInvalid(text, "listed twice");
    }
}

test "exemptions: an exempt file does not block, and only a blocking standing becomes exempt" {
    try testing.expect(!Gate.exempt.blocking());
    try testing.expectEqualStrings("exempt", Gate.exempt.word());
    try testing.expectEqual(Gate.exempt, gateOf("OK", .{ .failed = 4 }).exempted());
    try testing.expectEqual(Gate.exempt, gateOf("TIMEOUT", .{}).exempted());
    try testing.expectEqual(Gate.exempt, gateOf("CRASH", .{}).exempted());
    // A listed file that does not block keeps its own standing.
    try testing.expectEqual(Gate.partial, gateOf("OK", .{ .passed = 1, .failed = 3 }).exempted());
    try testing.expectEqual(Gate.clean, gateOf("OK", .{ .passed = 4 }).exempted());
    try testing.expectEqual(Gate.unrun, gateOf(null, .{}).exempted());

    var t: Totals = .{};
    t.add(gateOf("OK", .{ .failed = 4 }), .{ .failed = 4 });
    t.add(gateOf("OK", .{ .failed = 4 }).exempted(), .{ .failed = 4 });
    try testing.expectEqual(@as(u64, 1), t.blocking());
    try testing.expectEqual(@as(u64, 1), t.exempt);
    try testing.expectEqual(@as(u64, 2), t.files);
}

test "exemptions: a path outside the worklist is invalid" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_exemption, &diag);
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    try known.put(testing.allocator, "css/x/other.html", {});
    try testing.expectError(error.InvalidExemption, checkExemptionPaths(list, &known, &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message, "not in the worklist") != null);
    try testing.expectEqualStrings("css/x/declined.html", diag.path);
    try known.put(testing.allocator, "css/x/declined.html", {});
    try checkExemptionPaths(list, &known, &diag);
}

// The second kind (the user, 2026-11-08): a file that fails identically in all
// three browsers because of a test bug filed upstream, exempt until it is resolved.
const fixture_test_bug =
    \\[html/x/posts-a-report.https.html]
    \\kind = test-bug
    \\why = the test posts a platform object, which structured clone rejects in every engine
    \\upstream = https://github.com/web-platform-tests/wpt/issues/99999
    \\chrome.result = wpt.fyi run 5070179567140864: 3/9 TIMEOUT
    \\firefox.result = wpt.fyi run 5140459022974976: 3/9 TIMEOUT
    \\safari.result = wpt.fyi run 5107094106406912: 3/9 TIMEOUT
    \\revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved
    \\
;

test "exemptions: a test-bug entry parses, with its upstream issue, every browser's result and when to revisit" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_test_bug, &diag);
    try testing.expectEqual(@as(usize, 1), list.len);
    const e = list[0];
    try testing.expectEqual(ExemptionKind.test_bug, e.kind);
    try testing.expectEqualStrings("test-bug", e.kind.word());
    try testing.expectEqualStrings("html/x/posts-a-report.https.html", e.path);
    try testing.expectEqualStrings("the test posts a platform object, which structured clone rejects in every engine", e.why);
    try testing.expectEqualStrings("https://github.com/web-platform-tests/wpt/issues/99999", e.upstream);
    try testing.expectEqualStrings("when https://github.com/web-platform-tests/wpt/issues/99999 is resolved", e.revisit);
    try testing.expectEqualStrings("wpt.fyi run 5140459022974976: 3/9 TIMEOUT", e.result[@backingInt(Browser.firefox)]);
    // It has no spec and no intent: nobody declined anything.
    try testing.expectEqualStrings("", e.spec);
    try testing.expectEqualStrings("", e.intent[@backingInt(Browser.chrome)]);
    // A pull request is an upstream report too.
    const pr = try std.mem.replaceOwned(u8, arena.allocator(), fixture_test_bug, "issues/99999", "pull/12345");
    const via_pr = try parseExemptions(arena.allocator(), pr, &diag);
    try testing.expectEqualStrings("https://github.com/web-platform-tests/wpt/pull/12345", via_pr[0].upstream);
}

test "exemptions: an entry without kind is intentional as before, and kind = intentional is the same entry" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const legacy = try parseExemptions(arena.allocator(), fixture_exemption, &diag);
    try testing.expectEqual(ExemptionKind.intentional, legacy[0].kind);
    try testing.expectEqualStrings("intentional", legacy[0].kind.word());
    try testing.expectEqualStrings("", legacy[0].upstream);
    try testing.expectEqualStrings("", legacy[0].revisit);
    const text = try std.mem.replaceOwned(u8, arena.allocator(), fixture_exemption, "why = ", "kind = intentional\nwhy = ");
    const explicit = try parseExemptions(arena.allocator(), text, &diag);
    try testing.expectEqual(ExemptionKind.intentional, explicit[0].kind);
    try testing.expectEqualStrings(legacy[0].spec, explicit[0].spec);
    for (0..3) |i| {
        try testing.expectEqualStrings(legacy[0].result[i], explicit[0].result[i]);
        try testing.expectEqualStrings(legacy[0].intent[i], explicit[0].intent[i]);
    }
    // Both kinds in one file, in the file's order.
    const both = try std.mem.concat(arena.allocator(), u8, &.{ fixture_exemption, fixture_test_bug });
    const list = try parseExemptions(arena.allocator(), both, &diag);
    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqual(ExemptionKind.intentional, list[0].kind);
    try testing.expectEqual(ExemptionKind.test_bug, list[1].kind);
}

test "exemptions: a test-bug entry missing any of its keys is invalid, never a silent exemption" {
    const keys = [_][]const u8{ "kind =", "why =", "upstream =", "chrome.result", "firefox.result", "safari.result", "revisit =" };
    for (keys) |k| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(testing.allocator);
        var it = std.mem.splitScalar(u8, fixture_test_bug, '\n');
        while (it.next()) |line| {
            if (std.mem.startsWith(u8, line, k)) continue;
            try buf.appendSlice(testing.allocator, line);
            try buf.append(testing.allocator, '\n');
        }
        // Without its kind it reads as intentional, which lacks a spec and
        // intents and has keys an intentional entry does not: still invalid.
        try expectInvalid(buf.items, if (std.mem.eql(u8, k, "kind =")) "not a key of an intentional exemption" else "missing");
    }
}

test "exemptions: a malformed test-bug entry, or one mixing the kinds' keys, is invalid" {
    const swap = struct {
        fn f(a: std.mem.Allocator, from: []const u8, to: []const u8) ![]u8 {
            return std.mem.replaceOwned(u8, a, fixture_test_bug, from, to);
        }
    }.f;
    const a = testing.allocator;
    const cases = [_]struct { []const u8, []const u8, []const u8 }{
        // An unknown kind.
        .{ "kind = test-bug", "kind = testbug", "kind must be intentional, test-bug, needs-renderer, follows-majority, needs-decoder or single-shipper" },
        // Upstream is a web-platform-tests issue or pull request, nothing else.
        .{ "upstream = https://github.com/web-platform-tests/wpt/issues/99999", "upstream = https://bugs.webkit.org/show_bug.cgi?id=1", "web-platform-tests issue or pull request" },
        .{ "upstream = https://github.com/web-platform-tests/wpt/issues/99999", "upstream = https://github.com/web-platform-tests/wpt/issues/", "web-platform-tests issue or pull request" },
        .{ "upstream = https://github.com/web-platform-tests/wpt/issues/99999", "upstream = https://github.com/web-platform-tests/wpt.fyi/issues/99999", "web-platform-tests issue or pull request" },
        .{ "upstream = https://github.com/web-platform-tests/wpt/issues/99999", "upstream = wpt#99999", "web-platform-tests issue or pull request" },
        // Revisit names the upstream report, in the one form.
        .{ "revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved", "revisit = later", "revisit must read" },
        .{ "revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved", "revisit = when https://github.com/web-platform-tests/wpt/issues/1 is resolved", "revisit must read" },
        // The same wpt.fyi run form as an intentional entry's.
        .{ "wpt.fyi run 5070179567140864: 3/9 TIMEOUT", "TIMEOUT", "wpt.fyi run" },
        // Identical in all three browsers, or it is not this kind.
        .{ "wpt.fyi run 5107094106406912: 3/9 TIMEOUT", "wpt.fyi run 5107094106406912: 9/9", "the same result in all three browsers" },
        .{ "wpt.fyi run 5140459022974976: 3/9 TIMEOUT", "wpt.fyi run 5140459022974976: 3/10 TIMEOUT", "the same result in all three browsers" },
        // An intentional entry's keys do not belong in a test-bug entry.
        .{ "why = ", "spec = https://example.org/spec#step\nwhy = ", "\"spec\" is not a key of a test-bug exemption" },
        .{ "why = ", "chrome.intent = https://issues.chromium.org/issues/1\nwhy = ", "\"chrome.intent\" is not a key of a test-bug exemption" },
        // A kind given twice.
        .{ "kind = test-bug", "kind = test-bug\nkind = test-bug", "twice" },
    };
    for (cases) |c| {
        const text = try swap(a, c[0], c[1]);
        defer a.free(text);
        try expectInvalid(text, c[2]);
    }
    // A test-bug entry's keys do not belong in an intentional one.
    {
        const text = try std.mem.replaceOwned(u8, a, fixture_exemption, "why = ", "upstream = https://github.com/web-platform-tests/wpt/issues/99999\nwhy = ");
        defer a.free(text);
        try expectInvalid(text, "\"upstream\" is not a key of an intentional exemption");
    }
}

test "exemptions: a test-bug exempt file counts as exempt, never as blocking" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_test_bug, &diag);
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    try known.put(testing.allocator, "css/x/other.html", {});
    // Its path is checked against the worklist like any other entry's.
    try testing.expectError(error.InvalidExemption, checkExemptionPaths(list, &known, &diag));
    try known.put(testing.allocator, "html/x/posts-a-report.https.html", {});
    try checkExemptionPaths(list, &known, &diag);
    try testing.expectEqual(Gate.exempt, gateOf("TIMEOUT", .{ .passed = 3, .timed_out = 1, .notrun = 5 }).exempted());
}

// The third kind (the user, 2026-11-09): a file that fails ONLY because no
// renderer answers geometry, exempt until a renderer exists. Its keys: kind,
// why (why the assertion needs a layout box) and the failing assertion.
const fixture_needs_renderer =
    \\[html/x/decodes-image-data.html]
    \\kind = needs-renderer
    \\why = common/security-features decodeImageData reads the image back with getImageData(0, 0, img.clientWidth, img.clientHeight); with no renderer clientWidth is 0 (CSSOM View's no-box answer), so getImageData throws IndexSizeError
    \\assertion = promise_test: Unhandled rejection with value: object "IndexSizeError: IndexSizeError"
    \\
;

test "exemptions: a needs-renderer entry parses, with why and the failing assertion and nothing else" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_needs_renderer, &diag);
    try testing.expectEqual(@as(usize, 1), list.len);
    const e = list[0];
    try testing.expectEqual(ExemptionKind.needs_renderer, e.kind);
    try testing.expectEqualStrings("needs-renderer", e.kind.word());
    try testing.expectEqualStrings("html/x/decodes-image-data.html", e.path);
    try testing.expect(std.mem.startsWith(u8, e.why, "common/security-features decodeImageData reads the image back"));
    try testing.expectEqualStrings("promise_test: Unhandled rejection with value: object \"IndexSizeError: IndexSizeError\"", e.assertion);
    // No other kind's evidence: no spec, intent, result, upstream or revisit.
    try testing.expectEqualStrings("", e.spec);
    try testing.expectEqualStrings("", e.upstream);
    try testing.expectEqualStrings("", e.revisit);
    for (0..3) |i| {
        try testing.expectEqualStrings("", e.result[i]);
        try testing.expectEqualStrings("", e.intent[i]);
    }
    // All three kinds in one file, in the file's order.
    const every = try std.mem.concat(arena.allocator(), u8, &.{ fixture_exemption, fixture_test_bug, fixture_needs_renderer });
    const all = try parseExemptions(arena.allocator(), every, &diag);
    try testing.expectEqual(@as(usize, 3), all.len);
    try testing.expectEqual(ExemptionKind.intentional, all[0].kind);
    try testing.expectEqual(ExemptionKind.test_bug, all[1].kind);
    try testing.expectEqual(ExemptionKind.needs_renderer, all[2].kind);
    try testing.expectEqualStrings("", all[0].assertion);
    try testing.expectEqualStrings("", all[1].assertion);
}

test "exemptions: a needs-renderer entry missing a key, or with any other, is invalid" {
    const missing = [_]struct { []const u8, []const u8 }{
        // Without its kind it reads as intentional, which has no assertion.
        .{ "kind =", "\"assertion\" is not a key of an intentional exemption" },
        .{ "why =", "missing \"why\" - a needs-renderer exemption needs the failing assertion and why it needs a layout box" },
        .{ "assertion =", "missing \"assertion\" - a needs-renderer exemption needs the failing assertion and why it needs a layout box" },
    };
    for (missing) |m| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(testing.allocator);
        var it = std.mem.splitScalar(u8, fixture_needs_renderer, '\n');
        while (it.next()) |line| {
            if (std.mem.startsWith(u8, line, m[0])) continue;
            try buf.appendSlice(testing.allocator, line);
            try buf.append(testing.allocator, '\n');
        }
        try expectInvalid(buf.items, m[1]);
    }
    const a = testing.allocator;
    const cases = [_]struct { []const u8, []const u8, []const u8 }{
        // No other kind's key, and no unknown key.
        .{ "why = ", "spec = https://example.org/spec#step\nwhy = ", "\"spec\" is not a key of a needs-renderer exemption" },
        .{ "why = ", "upstream = https://github.com/web-platform-tests/wpt/issues/99999\nwhy = ", "\"upstream\" is not a key of a needs-renderer exemption" },
        .{ "why = ", "chrome.result = wpt.fyi run 5070179567140864: 0/2\nwhy = ", "\"chrome.result\" is not a key of a needs-renderer exemption" },
        .{ "why = ", "renderer = none\nwhy = ", "unknown key \"renderer\"" },
        // An unknown kind, a kind given twice, an empty assertion.
        .{ "kind = needs-renderer", "kind = needs-a-renderer", "kind must be intentional, test-bug, needs-renderer, follows-majority, needs-decoder or single-shipper" },
        .{ "kind = needs-renderer", "kind = needs-renderer\nkind = needs-renderer", "twice" },
        .{ "assertion = promise_test", "assertion = \nassertion_ = promise_test", "\"assertion\" is empty" },
    };
    for (cases) |c| {
        const text = try std.mem.replaceOwned(u8, a, fixture_needs_renderer, c[0], c[1]);
        defer a.free(text);
        try expectInvalid(text, c[2]);
    }
    // Its assertion belongs to no other kind.
    {
        const text = try std.mem.replaceOwned(u8, a, fixture_exemption, "why = ", "assertion = promise_test: x\nwhy = ");
        defer a.free(text);
        try expectInvalid(text, "\"assertion\" is not a key of an intentional exemption");
    }
    {
        const text = try std.mem.replaceOwned(u8, a, fixture_test_bug, "why = ", "assertion = promise_test: x\nwhy = ");
        defer a.free(text);
        try expectInvalid(text, "\"assertion\" is not a key of a test-bug exemption");
    }
}

test "exemptions: a needs-renderer exempt file counts as exempt, never as blocking" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_needs_renderer, &diag);
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    try known.put(testing.allocator, "css/x/other.html", {});
    try testing.expectError(error.InvalidExemption, checkExemptionPaths(list, &known, &diag));
    try known.put(testing.allocator, "html/x/decodes-image-data.html", {});
    try checkExemptionPaths(list, &known, &diag);
    try testing.expectEqual(Gate.exempt, gateOf("OK", .{ .failed = 4 }).exempted());
}

// The fourth kind (the user, 2026-11-18 2:36 PM ET, "Add the exemption kind"): a
// file that blocks although Crane's result is the one golden rule 2 says is
// correct - it equals the browser majority's, subtest by subtest, or a recorded
// ruling decides it - so no change in Crane can clear it. Its keys: kind, why,
// each browser's wpt.fyi result, matches (the browsers Crane's result equals),
// revisit, and an optional ruling.
const fixture_follows_majority =
    \\[html/x/majority.html]
    \\kind = follows-majority
    \\why = Crane keeps the value as typed, as Firefox and Safari do; only Chrome converts it
    \\chrome.result = wpt.fyi run 4786307730243584: 4/4
    \\firefox.result = wpt.fyi run 4877168468033536: 0/4
    \\safari.result = wpt.fyi run 6479119966273536: 0/4
    \\matches = firefox, safari
    \\revisit = when Chrome, Firefox or Safari changes its result
    \\
;

test "exemptions: a follows-majority entry parses, with every browser's result, the browsers Crane matches and when to revisit" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_follows_majority, &diag);
    try testing.expectEqual(@as(usize, 1), list.len);
    const e = list[0];
    try testing.expectEqual(ExemptionKind.follows_majority, e.kind);
    try testing.expectEqualStrings("follows-majority", e.kind.word());
    try testing.expectEqualStrings("html/x/majority.html", e.path);
    try testing.expectEqualStrings("Crane keeps the value as typed, as Firefox and Safari do; only Chrome converts it", e.why);
    try testing.expectEqualStrings("wpt.fyi run 4786307730243584: 4/4", e.result[@backingInt(Browser.chrome)]);
    try testing.expectEqualStrings("wpt.fyi run 6479119966273536: 0/4", e.result[@backingInt(Browser.safari)]);
    try testing.expectEqual([3]bool{ false, true, true }, e.matches);
    try testing.expectEqualStrings("when Chrome, Firefox or Safari changes its result", e.revisit);
    // The ruling is optional; no other kind's evidence.
    try testing.expectEqualStrings("", e.ruling);
    try testing.expectEqualStrings("", e.spec);
    try testing.expectEqualStrings("", e.upstream);
    try testing.expectEqualStrings("", e.assertion);
    for (0..3) |i| try testing.expectEqualStrings("", e.intent[i]);
    // One browser is enough with a ruling that decides it; the order of matches is free.
    const ruled = try std.mem.replaceOwned(u8, arena.allocator(), fixture_follows_majority, "matches = firefox, safari\n", "matches = safari\nruling = the user, 2026-11-14 7:17 AM ET: keep Safari's order\n");
    const one = try parseExemptions(arena.allocator(), ruled, &diag);
    try testing.expectEqual([3]bool{ false, false, true }, one[0].matches);
    try testing.expectEqualStrings("the user, 2026-11-14 7:17 AM ET: keep Safari's order", one[0].ruling);
    const all3 = try std.mem.replaceOwned(u8, arena.allocator(), fixture_follows_majority, "4786307730243584: 4/4", "4786307730243584: 0/4");
    const every = try parseExemptions(arena.allocator(), try std.mem.replaceOwned(u8, arena.allocator(), all3, "matches = firefox, safari", "matches = safari,chrome , firefox"), &diag);
    try testing.expectEqual([3]bool{ true, true, true }, every[0].matches);
    // All four kinds in one file, in the file's order.
    const four = try std.mem.concat(arena.allocator(), u8, &.{ fixture_exemption, fixture_test_bug, fixture_needs_renderer, fixture_follows_majority });
    const kinds = try parseExemptions(arena.allocator(), four, &diag);
    try testing.expectEqual(@as(usize, 4), kinds.len);
    try testing.expectEqual(ExemptionKind.follows_majority, kinds[3].kind);
    try testing.expectEqual([3]bool{ false, false, false }, kinds[1].matches);
}

test "exemptions: a follows-majority entry missing a key is invalid, never a silent exemption" {
    const missing = [_]struct { []const u8, []const u8 }{
        // Without its kind it reads as intentional, which has no revisit.
        .{ "kind =", "is not a key of an intentional exemption" },
        .{ "why =", "missing \"why\" - a follows-majority exemption needs every browser's result, the browsers Crane matches and when to revisit" },
        .{ "chrome.result", "missing \"chrome.result\" - a follows-majority exemption" },
        .{ "firefox.result", "missing \"firefox.result\" - a follows-majority exemption" },
        .{ "safari.result", "missing \"safari.result\" - a follows-majority exemption" },
        .{ "matches =", "missing \"matches\" - a follows-majority exemption" },
        .{ "revisit =", "missing \"revisit\" - a follows-majority exemption" },
    };
    for (missing) |m| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(testing.allocator);
        var it = std.mem.splitScalar(u8, fixture_follows_majority, '\n');
        while (it.next()) |line| {
            if (std.mem.startsWith(u8, line, m[0])) continue;
            try buf.appendSlice(testing.allocator, line);
            try buf.append(testing.allocator, '\n');
        }
        try expectInvalid(buf.items, m[1]);
    }
}

test "exemptions: a malformed follows-majority entry, or one mixing the kinds' keys, is invalid" {
    const a = testing.allocator;
    const m = "matches = firefox, safari";
    const cases = [_]struct { []const u8, []const u8, []const u8 }{
        // matches names Chrome, Firefox or Safari, each once.
        .{ m, "matches = firefox, edge", "matches must name chrome, firefox or safari" },
        .{ m, "matches = firefox, firefox", "matches must name chrome, firefox or safari" },
        .{ m, "matches = firefox,", "matches must name chrome, firefox or safari" },
        .{ m, "matches = Firefox and Safari", "matches must name chrome, firefox or safari" },
        // At least two browsers, or a ruling that decides it.
        .{ m, "matches = safari", "needs at least two browsers in matches, or a ruling" },
        // Crane's result equals each matched browser's, so theirs are the same.
        .{ "6479119966273536: 0/4", "6479119966273536: 1/4", "the browsers in matches need the same result (Firefox 0/4, Safari 1/4)" },
        .{ m, "matches = chrome, safari", "the browsers in matches need the same result (Chrome 4/4, Safari 0/4)" },
        // revisit says when the entry comes off.
        .{ "revisit = when Chrome", "revisit = Chrome", "revisit must read \"when " },
        .{ "revisit = when Chrome, Firefox or Safari changes its result", "revisit = when", "revisit must read \"when " },
        // The same wpt.fyi run form as the other kinds'.
        .{ "wpt.fyi run 4877168468033536: 0/4", "0/4 on wpt.fyi", "wpt.fyi run" },
        // No other kind's key, and no unknown key.
        .{ "why = ", "spec = https://example.org/spec#step\nwhy = ", "\"spec\" is not a key of a follows-majority exemption" },
        .{ "why = ", "chrome.intent = https://issues.chromium.org/issues/1\nwhy = ", "\"chrome.intent\" is not a key of a follows-majority exemption" },
        .{ "why = ", "upstream = https://github.com/web-platform-tests/wpt/issues/99999\nwhy = ", "\"upstream\" is not a key of a follows-majority exemption" },
        .{ "why = ", "assertion = promise_test: x\nwhy = ", "\"assertion\" is not a key of a follows-majority exemption" },
        .{ "why = ", "majority = yes\nwhy = ", "unknown key \"majority\"" },
        // An unknown kind, a kind or a ruling given twice, an empty ruling.
        .{ "kind = follows-majority", "kind = majority", "kind must be intentional, test-bug, needs-renderer, follows-majority, needs-decoder or single-shipper" },
        .{ "kind = follows-majority", "kind = follows-majority\nkind = follows-majority", "twice" },
        .{ m, m ++ "\nruling = a\nruling = b", "twice" },
        .{ m, m ++ "\nruling = ", "\"ruling\" is empty" },
    };
    for (cases) |c| {
        try testing.expect(std.mem.indexOf(u8, fixture_follows_majority, c[0]) != null);
        const text = try std.mem.replaceOwned(u8, a, fixture_follows_majority, c[0], c[1]);
        defer a.free(text);
        try expectInvalid(text, c[2]);
    }
    // Its matches and ruling belong to no other kind.
    const others = [_]struct { []const u8, []const u8 }{
        .{ fixture_exemption, "an intentional" },
        .{ fixture_test_bug, "a test-bug" },
        .{ fixture_needs_renderer, "a needs-renderer" },
    };
    for (others) |o| {
        for ([_][]const u8{ "matches = chrome, firefox\n", "ruling = the user, 2026-11-18\n" }) |line| {
            const with = try std.mem.concat(a, u8, &.{ line, "why = " });
            defer a.free(with);
            const text = try std.mem.replaceOwned(u8, a, o[0], "why = ", with);
            defer a.free(text);
            const key = line[0..std.mem.indexOfScalar(u8, line, ' ').?];
            const needle = try std.fmt.allocPrint(a, "\"{s}\" is not a key of {s} exemption", .{ key, o[1] });
            defer a.free(needle);
            try expectInvalid(text, needle);
        }
    }
    // A test-bug entry's revisit keeps its own form.
    {
        const text = try std.mem.replaceOwned(u8, a, fixture_test_bug, "revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved", "revisit = when the browsers change");
        defer a.free(text);
        try expectInvalid(text, "revisit must read \"when https://github.com/web-platform-tests/wpt/issues/99999 is resolved\"");
    }
}

test "exemptions: a follows-majority exempt file counts as exempt, never as blocking" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_follows_majority, &diag);
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    try known.put(testing.allocator, "css/x/other.html", {});
    try testing.expectError(error.InvalidExemption, checkExemptionPaths(list, &known, &diag));
    try known.put(testing.allocator, "html/x/majority.html", {});
    try checkExemptionPaths(list, &known, &diag);
    try testing.expectEqual(Gate.exempt, gateOf("TIMEOUT", .{ .timed_out = 1 }).exempted());
}

// Two follows-majority forms (lane blk5, main's GO 2026-11-20 1:37 PM ET), on the fixture
// tools/wpt_progress.py --self-test reads too, so the two readers agree: matches = none, with a ruling
// that names its golden rule 2 case - Crane's result is the spec's and equals no browser's - and
// renderer-subtests, the subtests that fail in Crane only for want of a renderer, each "<name> :: <why>".
const fixture_shared = @embedFile("exemption_fixture.txt");

test "exemptions: matches = none with a ruling naming its case, and renderer-subtests, parse as tools/wpt_progress.py reads them" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_shared, &diag);
    try testing.expectEqual(@as(usize, 3), list.len);
    const alone = list[0];
    try testing.expectEqualStrings("html/x/spec-alone.html", alone.path);
    try testing.expectEqual(ExemptionKind.follows_majority, alone.kind);
    try testing.expectEqual([3]bool{ false, false, false }, alone.matches);
    try testing.expect(std.mem.startsWith(u8, alone.ruling, "golden rule 2, the spec where all three differ"));
    try testing.expectEqual(@as(usize, 0), alone.rendererSubtestCount());
    const part = list[1];
    try testing.expectEqual([3]bool{ true, true, false }, part.matches);
    try testing.expectEqual(@as(usize, 2), part.rendererSubtestCount());
    var it = part.rendererSubtests();
    const first = it.next().?;
    try testing.expectEqualStrings("the second subtest", first.name);
    try testing.expectEqualStrings("its click lands on an absolutely positioned link", first.why);
    const second = it.next().?;
    try testing.expectEqualStrings("the third subtest", second.name);
    try testing.expectEqualStrings("it reads a box's size", second.why);
    try testing.expect(it.next() == null);
    // Each of the three cases makes a ruling for none.
    for ([_][]const u8{ "all three differ", "newer spec", "timing-bound" }) |case| {
        const text = try std.mem.replaceOwned(u8, arena.allocator(), fixture_shared, "the spec where all three differ", case);
        _ = try parseExemptions(arena.allocator(), text, &diag);
    }
}

test "exemptions: matches = none without a ruling naming its case, a malformed renderer-subtests, or one on another kind, is invalid" {
    const a = testing.allocator;
    const rule = "ruling            = golden rule 2, the spec where all three differ: the main session, 2026-11-20\n";
    try testing.expect(std.mem.indexOf(u8, fixture_shared, rule) != null);
    const cases = "needs a ruling that names its golden rule 2 case";
    const no_rule = try std.mem.replaceOwned(u8, a, fixture_shared, rule, "");
    defer a.free(no_rule);
    try expectInvalid(no_rule, cases);
    const vague = try std.mem.replaceOwned(u8, a, fixture_shared, rule, "ruling            = the main session, 2026-11-20\n");
    defer a.free(vague);
    try expectInvalid(vague, cases);
    const mixed = try std.mem.replaceOwned(u8, a, fixture_shared, "matches           = none", "matches           = none, chrome");
    defer a.free(mixed);
    try expectInvalid(mixed, "or read none");
    const whole = "renderer-subtests = the second subtest :: its click lands on an absolutely positioned link || the third subtest :: it reads a box's size";
    try testing.expect(std.mem.indexOf(u8, fixture_shared, whole) != null);
    for ([_][]const u8{ "renderer-subtests = the second subtest", "renderer-subtests = :: a reason", "renderer-subtests = a name :: " }) |bad| {
        const text = try std.mem.replaceOwned(u8, a, fixture_shared, whole, bad);
        defer a.free(text);
        try expectInvalid(text, "renderer-subtests must give");
    }
    const other = try std.mem.replaceOwned(u8, a, fixture_needs_renderer, "why = ", "renderer-subtests = a :: b\nwhy = ");
    defer a.free(other);
    try expectInvalid(other, "\"renderer-subtests\" is not a key of a needs-renderer exemption");
}

// The sixth kind (the user, 2026-11-21 5:58 AM ET, choice (a)): a file that
// tests a feature only ONE browser ships, whose remaining failures hinge on a
// mechanism where Crane does what the other two browsers and the spec do. Its
// form is on the shared fixture, which tools/wpt_progress.py --self-test reads
// too.
fn singleShipperEntry() []const u8 {
    return fixture_shared[std.mem.indexOf(u8, fixture_shared, "[resource-timing/x/only-one-ships.html]").?..];
}

test "exemptions: a single-shipper entry names its shipper, every browser's result, the mechanism Crane follows with its spec, and when to revisit - as tools/wpt_progress.py reads it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_shared, &diag);
    const e = list[2];
    try testing.expectEqualStrings("resource-timing/x/only-one-ships.html", e.path);
    try testing.expectEqual(ExemptionKind.single_shipper, e.kind);
    try testing.expectEqual(Browser.chrome, e.shipper);
    try testing.expectEqualStrings("Crane keeps parsing past an in-body style sheet, as Firefox, Safari and the spec do", e.mechanism);
    try testing.expectEqualStrings("https://html.spec.whatwg.org/multipage/parsing.html#speculative-html-parsing", e.spec);
    try testing.expectEqualStrings("when Firefox or Safari ships the feature", e.revisit);
    try testing.expectEqualStrings("wpt.fyi run 4877168468033536: 0/1", e.result[@backingInt(Browser.firefox)]);
    try testing.expectEqualStrings("single-shipper", ExemptionKind.single_shipper.word());
    // Firefox shipping alone: the other two are Chrome and Safari.
    var text = try std.mem.replaceOwned(u8, arena.allocator(), singleShipperEntry(), "shipper           = chrome", "shipper           = firefox");
    text = try std.mem.replaceOwned(u8, arena.allocator(), text, "4786307730243584: 1/1", "4786307730243584: 0/1");
    text = try std.mem.replaceOwned(u8, arena.allocator(), text, "4877168468033536: 0/1", "4877168468033536: 1/1");
    const firefox = try parseExemptions(arena.allocator(), text, &diag);
    try testing.expectEqual(Browser.firefox, firefox[0].shipper);
}

test "exemptions: a malformed single-shipper entry, one missing a key, or one mixing the kinds' keys, is invalid" {
    const a = testing.allocator;
    const entry = singleShipperEntry();
    const needs = "a single-shipper exemption needs the browser that ships the feature, every browser's result, the mechanism Crane follows with its spec, and when to revisit";
    for ([_][]const u8{ "why", "shipper", "chrome.result", "firefox.result", "safari.result", "mechanism", "spec", "revisit" }) |key| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(a);
        var it = std.mem.splitScalar(u8, entry, '\n');
        while (it.next()) |line| {
            if (std.mem.startsWith(u8, line, key) and line.len > key.len and line[key.len] == ' ') continue;
            try buf.appendSlice(a, line);
            try buf.append(a, '\n');
        }
        const needle = try std.fmt.allocPrint(a, "missing \"{s}\" - {s}", .{ key, needs });
        defer a.free(needle);
        try expectInvalid(buf.items, needle);
    }
    const cases = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "shipper           = chrome", "shipper           = edge", "shipper must name chrome, firefox or safari" },
        .{ "shipper           = chrome", "shipper           = chrome, firefox", "shipper must name chrome, firefox or safari" },
        .{ "6479119966273536: 0/1", "6479119966273536: 1/1", "the browsers that do not ship the feature need the same result (Firefox 0/1, Safari 1/1)" },
        .{ "revisit           = when Firefox or Safari ships the feature", "revisit           = when the browsers change", "revisit must read \"when <a second browser> ships <the feature>\"" },
        .{ "spec              = https://", "spec              = html.spec.whatwg.org/", "spec must be an http(s) URL" },
        .{ "why               = ", "matches = chrome\nwhy = ", "\"matches\" is not a key of a single-shipper exemption" },
        .{ "why               = ", "upstream = https://github.com/web-platform-tests/wpt/issues/1\nwhy = ", "\"upstream\" is not a key of a single-shipper exemption" },
        .{ "kind              = single-shipper", "kind              = one-shipper", "kind must be intentional, test-bug, needs-renderer, follows-majority, needs-decoder or single-shipper" },
    };
    for (cases) |c| {
        try testing.expect(std.mem.indexOf(u8, entry, c[0]) != null);
        const text = try std.mem.replaceOwned(u8, a, entry, c[0], c[1]);
        defer a.free(text);
        try expectInvalid(text, c[2]);
    }
    // Its shipper and mechanism belong to no other kind.
    const others = [_]struct { []const u8, []const u8 }{
        .{ fixture_exemption, "an intentional" },
        .{ fixture_test_bug, "a test-bug" },
        .{ fixture_needs_renderer, "a needs-renderer" },
        .{ fixture_follows_majority, "a follows-majority" },
    };
    for (others) |o| {
        for ([_][]const u8{ "shipper = chrome\n", "mechanism = a\n" }) |line| {
            const with = try std.mem.concat(a, u8, &.{ line, "why = " });
            defer a.free(with);
            const text = try std.mem.replaceOwned(u8, a, o[0], "why = ", with);
            defer a.free(text);
            const key = line[0..std.mem.indexOfScalar(u8, line, ' ').?];
            const needle = try std.fmt.allocPrint(a, "\"{s}\" is not a key of {s} exemption", .{ key, o[1] });
            defer a.free(needle);
            try expectInvalid(text, needle);
        }
    }
}

// The fifth kind (the user, 2026-11-18 2:53 PM ET): like needs-renderer, a file
// that fails ONLY because the platform WPT runs on has no decoder for its media.
// Its keys: kind, why, media (the media file(s) and their type) and the failing
// assertion.
const fixture_needs_decoder =
    \\[html/x/plays-video.html]
    \\kind = needs-decoder
    \\why = the test waits for canplay on a WebM video; the default platform decodes WAV only, so canplay never fires
    \\media = /media/movie_5.webm (video/webm; VP8 + Vorbis)
    \\assertion = TIMEOUT: video plays - Test timed out
    \\
;

test "exemptions: a needs-decoder entry parses, with why, the media and the failing assertion and nothing else" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_needs_decoder, &diag);
    try testing.expectEqual(@as(usize, 1), list.len);
    const e = list[0];
    try testing.expectEqual(ExemptionKind.needs_decoder, e.kind);
    try testing.expectEqualStrings("needs-decoder", e.kind.word());
    try testing.expectEqualStrings("html/x/plays-video.html", e.path);
    try testing.expectEqualStrings("/media/movie_5.webm (video/webm; VP8 + Vorbis)", e.media);
    try testing.expectEqualStrings("TIMEOUT: video plays - Test timed out", e.assertion);
    try testing.expectEqualStrings("", e.revisit);
    try testing.expectEqualStrings("", e.ruling);
    for (0..3) |i| try testing.expectEqualStrings("", e.result[i]);
    // All five kinds in one file, in the file's order.
    const five = try std.mem.concat(arena.allocator(), u8, &.{ fixture_exemption, fixture_test_bug, fixture_needs_renderer, fixture_follows_majority, fixture_needs_decoder });
    const kinds = try parseExemptions(arena.allocator(), five, &diag);
    try testing.expectEqual(@as(usize, 5), kinds.len);
    try testing.expectEqual(ExemptionKind.needs_decoder, kinds[4].kind);
    try testing.expectEqualStrings("", kinds[2].media);
}

test "exemptions: a needs-decoder entry missing a key, or with any other, is invalid" {
    const needs = "a needs-decoder exemption needs the media the test plays, the failing assertion and why it needs a decoder";
    const missing = [_]struct { []const u8, []const u8 }{
        .{ "kind =", "is not a key of an intentional exemption" },
        .{ "why =", "missing \"why\" - " ++ needs },
        .{ "media =", "missing \"media\" - " ++ needs },
        .{ "assertion =", "missing \"assertion\" - " ++ needs },
    };
    for (missing) |m| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(testing.allocator);
        var it = std.mem.splitScalar(u8, fixture_needs_decoder, '\n');
        while (it.next()) |line| {
            if (std.mem.startsWith(u8, line, m[0])) continue;
            try buf.appendSlice(testing.allocator, line);
            try buf.append(testing.allocator, '\n');
        }
        try expectInvalid(buf.items, m[1]);
    }
    const a = testing.allocator;
    const cases = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "why = ", "spec = https://example.org/spec#step\nwhy = ", "\"spec\" is not a key of a needs-decoder exemption" },
        .{ "why = ", "chrome.result = wpt.fyi run 5070179567140864: 0/2\nwhy = ", "\"chrome.result\" is not a key of a needs-decoder exemption" },
        .{ "why = ", "matches = chrome, firefox\nwhy = ", "\"matches\" is not a key of a needs-decoder exemption" },
        .{ "why = ", "decoder = vp8\nwhy = ", "unknown key \"decoder\"" },
        .{ "kind = needs-decoder", "kind = needs-a-decoder", "kind must be intentional, test-bug, needs-renderer, follows-majority, needs-decoder or single-shipper" },
        .{ "kind = needs-decoder", "kind = needs-decoder\nkind = needs-decoder", "twice" },
        .{ "media = /media", "media = \nmedia_ = /media", "\"media\" is empty" },
    };
    for (cases) |c| {
        try testing.expect(std.mem.indexOf(u8, fixture_needs_decoder, c[0]) != null);
        const text = try std.mem.replaceOwned(u8, a, fixture_needs_decoder, c[0], c[1]);
        defer a.free(text);
        try expectInvalid(text, c[2]);
    }
    // Its media belongs to no other kind.
    const others = [_]struct { []const u8, []const u8 }{
        .{ fixture_exemption, "an intentional" },
        .{ fixture_test_bug, "a test-bug" },
        .{ fixture_needs_renderer, "a needs-renderer" },
        .{ fixture_follows_majority, "a follows-majority" },
    };
    for (others) |o| {
        const text = try std.mem.replaceOwned(u8, a, o[0], "why = ", "media = /media/a.webm (video/webm)\nwhy = ");
        defer a.free(text);
        const needle = try std.fmt.allocPrint(a, "\"media\" is not a key of {s} exemption", .{o[1]});
        defer a.free(needle);
        try expectInvalid(text, needle);
    }
}

test "exemptions: a needs-decoder exempt file counts as exempt, never as blocking" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseExemptions(arena.allocator(), fixture_needs_decoder, &diag);
    var known: std.StringHashMapUnmanaged(void) = .empty;
    defer known.deinit(testing.allocator);
    try known.put(testing.allocator, "css/x/other.html", {});
    try testing.expectError(error.InvalidExemption, checkExemptionPaths(list, &known, &diag));
    try known.put(testing.allocator, "html/x/plays-video.html", {});
    try checkExemptionPaths(list, &known, &diag);
    try testing.expectEqual(Gate.exempt, gateOf("TIMEOUT", .{ .timed_out = 1 }).exempted());
}

// ============================================================================
// Where each generation was swept (tests)
// ============================================================================

const fixture_hosts =
    \\# label host os-arch runners
    \\
    \\sweep-f7853e77e9  chat.local  macos-arm64   8
    \\sweep-9053db756e  server1     linux-x86_64  32
    \\
;

test "hosts: each line names a run's host, OS and runner count" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseSweepHosts(arena.allocator(), fixture_hosts, &diag);
    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqualStrings("sweep-f7853e77e9", list[0].label);
    try testing.expectEqualStrings("chat.local", list[0].host);
    try testing.expectEqualStrings("macos-arm64", list[0].os);
    try testing.expectEqual(@as(u32, 8), list[0].runners);
    try testing.expectEqualStrings("sweep-9053db756e", list[1].label);
    try testing.expectEqualStrings("server1", list[1].host);
    try testing.expectEqualStrings("linux-x86_64", list[1].os);
    try testing.expectEqual(@as(u32, 32), list[1].runners);
    // Nothing listed: no host is known, which is not an error.
    try testing.expectEqual(@as(usize, 0), (try parseSweepHosts(arena.allocator(), "", &diag)).len);
    try testing.expectEqual(@as(usize, 0), (try parseSweepHosts(arena.allocator(), "# only a comment\n", &diag)).len);
}

fn expectInvalidHosts(text: []const u8, needle: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    try testing.expectError(error.InvalidHosts, parseSweepHosts(arena.allocator(), text, &diag));
    if (std.mem.indexOf(u8, diag.message, needle) == null) {
        std.debug.print("diag {d}: \"{s}\" lacks \"{s}\"\n", .{ diag.line, diag.message, needle });
        return error.TestUnexpectedDiagnostic;
    }
}

test "hosts: a malformed or repeated line is invalid" {
    try expectInvalidHosts("sweep-a server1 linux-x86_64\n", "expected <label> <host> <os>-<arch> <runners>");
    try expectInvalidHosts("sweep-a server1 linux-x86_64 32 extra\n", "the fifth field must read fonts=<hash>");
    try expectInvalidHosts("sweep-a server1 linux-x86_64 32 fonts=ab extra\n", "expected <label> <host> <os>-<arch> <runners>");
    try expectInvalidHosts("sweep-a server1 Linux 32\n", "<os>-<arch>");
    try expectInvalidHosts("sweep-a server1 freebsd-x86_64 32\n", "<os>-<arch>");
    try expectInvalidHosts("sweep-a server1 linux- 32\n", "<os>-<arch>");
    try expectInvalidHosts("sweep-a server1 linux-x86_64 0\n", "runners");
    try expectInvalidHosts("sweep-a server1 linux-x86_64 many\n", "runners");
    try expectInvalidHosts("sweep-a server1 linux-x86_64 32\nsweep-a chat.local macos-arm64 8\n", "listed twice");
    // The line number is the offending line's.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    try testing.expectError(error.InvalidHosts, parseSweepHosts(arena.allocator(), "# c\nsweep-a server1 linux-x86_64 32\nsweep-b x\n", &diag));
    try testing.expectEqual(@as(usize, 3), diag.line);
}

test "hosts: a run may name its host's font set, as a hash" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: ExemptionDiag = .{};
    const list = try parseSweepHosts(arena.allocator(), "sweep-a server1 linux-x86_64 32 fonts=1a2b3c4d\nsweep-b chat.local macos-arm64 8\n", &diag);
    try testing.expectEqualStrings("1a2b3c4d", list[0].fonts.?);
    try testing.expect(list[1].fonts == null);
    try testing.expectError(error.InvalidHosts, parseSweepHosts(arena.allocator(), "sweep-a server1 linux-x86_64 32 fonts=\n", &diag));
    try testing.expectError(error.InvalidHosts, parseSweepHosts(arena.allocator(), "sweep-a server1 linux-x86_64 32 production\n", &diag));
    try testing.expectError(error.InvalidHosts, parseSweepHosts(arena.allocator(), "sweep-a server1 linux-x86_64 32 fonts=xyz\n", &diag));
}

test "hosts: an OS as the site says it" {
    const cases = [_]struct { []const u8, []const u8 }{
        .{ "linux-x86_64", "Linux x86-64" },
        .{ "macos-arm64", "macOS arm64" },
        .{ "linux-arm64", "Linux arm64" },
    };
    for (cases) |c| {
        var aw: std.Io.Writer.Allocating = .init(testing.allocator);
        defer aw.deinit();
        try osLabel(&aw.writer, c[0]);
        try testing.expectEqualStrings(c[1], aw.written());
    }
}
