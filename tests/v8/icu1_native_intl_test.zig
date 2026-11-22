//! V8's own Intl and Unicode support, from ICU (lane icu1; the user's ruling,
//! 2026-11-22 ~7:39 AM ET: "Rebuild with ICU").
//!
//! Crane's V8 15.7.112.43 archive was built with v8_enable_i18n_support =
//! false, and without ICU V8 has no Unicode property escapes (`\p{...}` is a
//! SyntaxError, so Puppeteer's injected query handlers and the Monaco editor
//! could not load), String.prototype.normalize returns its receiver,
//! toLocaleUpperCase / toLocaleLowerCase / localeCompare ignore the locale, and
//! there is no Intl at all - the adapter installed Crane's own (CLDR tables in
//! Zig) on window realms only, so a worker had none. Chrome, Firefox and Safari
//! all ship ICU. The archive is now built with ICU and its data linked in
//! (scripts/build-v8-15.7.sh, "ICU"), and the adapter leaves V8's Intl alone.
//!
//! Every expected answer here is Chrome 157's (157.0.8103.51, headless, in
//! America/Los_Angeles like the test launcher: tmp/probes/icu1/chrome-157.json,
//! 2026-11-22), whose ICU data the archive carries (Chromium's
//! third_party/icu/common/icudtl.dat).

const std = @import("std");
const test_process = @import("test_process.zig");
const rounds_lib = @import("handle_rounds.zig");
/// Every worker realm has an event loop; these tests drive none.
const inline_task_loop = @import("inline_task_loop.zig");
const v8 = @import("v8");
const protocol = @import("engine");

test "Unicode property escapes compile and match under the u and v flags" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\[/\p{L}/u.test("\u00e9"), /\P{L}/u.test("1"), /^\p{Script=Greek}+$/u.test("\u03b1\u03b2"), /\p{RGI_Emoji}/v.test("\u{1F600}")].join()
    , "true,true,true,true");
}

test "String.prototype.normalize composes and decomposes" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\["\u00e9".normalize("NFD").length, "e\u0301".normalize("NFC") === "\u00e9", "\ufb01".normalize("NFKC"), "\u00e9".normalize().length].join()
    , "2,true,fi,1");
}

test "toLocaleUpperCase and toLocaleLowerCase follow the locale's case mapping" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    // Turkish dotted and dotless i (U+0130, U+0131); a locale list's first
    // supported entry decides.
    try rounds_lib.expectEval(page.realm,
        \\["i".toLocaleUpperCase("tr") === "\u0130", "I".toLocaleLowerCase("tr") === "\u0131", "i".toLocaleUpperCase("en"), "\u00df".toUpperCase(), "i".toLocaleUpperCase(["tr", "en"]) === "\u0130"].join()
    , "true,true,I,SS,true");
}

test "localeCompare compares in the locale's collation, with its options" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    // U+00E4 sorts with a in German and after z in Swedish; sensitivity
    // "base" makes a and A equal; with no options lowercase sorts first.
    try rounds_lib.expectEval(page.realm,
        \\["a".localeCompare("b"), "\u00e4".localeCompare("z", "de"), "\u00e4".localeCompare("z", "sv"), "a".localeCompare("A", "en", { sensitivity: "base" }), "a".localeCompare("A")].join()
    , "-1,-1,1,0,-1");
}

test "Intl.Collator sorts by the locale's collation and its numeric option" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\[["z", "\u00e4", "a", "Z"].sort(new Intl.Collator("de").compare).map((c) => c.codePointAt(0)).join(" "),
        \\ ["z", "\u00e4", "a"].sort(new Intl.Collator("sv").compare).map((c) => c.codePointAt(0)).join(" "),
        \\ ["10", "9", "1"].sort(new Intl.Collator("en", { numeric: true }).compare).join(" "),
        \\ new Intl.Collator("de").resolvedOptions().locale].join("|")
    , "97 228 122 90|97 122 228|1 9 10|de");
}

test "Intl.DateTimeFormat formats in the timeZone it is given, with its options and the locale's patterns" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\[new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Tokyo", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(Date.UTC(2026, 0, 1, 0, 0)),
        \\ new Intl.DateTimeFormat("en-US", { timeZone: "America/New_York" }).resolvedOptions().timeZone,
        \\ new Intl.DateTimeFormat("de-DE", { timeZone: "UTC", dateStyle: "long" }).format(0),
        \\ new Intl.DateTimeFormat("en-GB", { timeZone: "UTC", weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(Date.UTC(2026, 10, 22)),
        \\ new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", dateStyle: "medium" }).format(Date.UTC(2026, 0, 1)),
        \\ new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Tokyo", dateStyle: "full", timeStyle: "long" }).format(Date.UTC(2026, 0, 1, 0, 0)),
        \\ new Date(Date.UTC(2026, 0, 1, 15, 4, 5)).toLocaleString("en-GB", { timeZone: "UTC" })].join("|")
    , "01/01/2026, 09:00|America/New_York|1. Januar 1970|Sunday, 22 November 2026|2026/01/01|Thursday, January 1, 2026 at 9:00:00 AM GMT+9|01/01/2026, 15:04:05");
    // A time zone ICU does not know is a RangeError (ECMA-402 11.1.2 step 34).
    try rounds_lib.expectEval(page.realm,
        \\(() => { try { new Intl.DateTimeFormat("en", { timeZone: "Not/AZone" }); return "no throw"; } catch (e) { return e.constructor.name; } })()
    , "RangeError");
}

test "Intl.ListFormat joins by the locale's list patterns" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\[new Intl.ListFormat("en", { type: "conjunction" }).format(["a", "b"]),
        \\ new Intl.ListFormat("en").format(["a", "b", "c"]),
        \\ new Intl.ListFormat("en-GB").format(["a", "b", "c"]),
        \\ new Intl.ListFormat("de").format(["a", "b", "c"]),
        \\ new Intl.ListFormat("en", { type: "disjunction" }).format(["a", "b", "c"]),
        \\ new Intl.ListFormat("en", { style: "narrow", type: "unit" }).format(["a", "b", "c"])].join("|")
    , "a and b|a, b, and c|a, b and c|a, b und c|a, b, or c|a b c");
}

test "the other Intl services answer from ICU's data" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\[new Intl.NumberFormat("de-DE").format(1234.5), (1234.5).toLocaleString("de-DE"), new Intl.NumberFormat("en-IN").format(1234567.891),
        \\ new Intl.NumberFormat("en-US", { style: "currency", currency: "EUR" }).format(12.5), new Intl.NumberFormat("ar-EG").format(123),
        \\ new Intl.PluralRules("en").select(1), new Intl.PluralRules("ar").select(3), new Intl.PluralRules("en", { type: "ordinal" }).select(22),
        \\ new Intl.RelativeTimeFormat("en", { numeric: "auto" }).format(-1, "day"), new Intl.DisplayNames(["en"], { type: "region" }).of("DE"),
        \\ [...new Intl.Segmenter("en", { granularity: "word" }).segment("Hello, world")].filter((s) => s.isWordLike).map((s) => s.segment).join("+")].join("|")
    , "1.234,5|1.234,5|12,34,567.891|\u{20AC}12.50|\u{0661}\u{0662}\u{0663}|one|few|two|yesterday|Germany|Hello+world");
}

test "Intl is V8's own: its global property, its toStringTag and a constructor's shape" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    // ECMA-402 8: Intl is writable, configurable, not enumerable, with
    // @@toStringTag "Intl" (8.1.1); a constructor's prototype methods are
    // the spec's (format is a getter on DateTimeFormat.prototype, 11.3.3).
    try rounds_lib.expectEval(page.realm,
        \\(() => {
        \\  const d = Object.getOwnPropertyDescriptor(globalThis, "Intl");
        \\  const format = Object.getOwnPropertyDescriptor(Intl.DateTimeFormat.prototype, "format");
        \\  return [d.writable, d.enumerable, d.configurable, Object.prototype.toString.call(Intl), Intl.DateTimeFormat.length,
        \\    typeof format.get, typeof Intl.DurationFormat, Intl.supportedValuesOf("timeZone").includes("Asia/Tokyo")].join();
        \\})()
    , "true,false,true,[object Intl],0,function,function,true");
}

test "the default locale is the platform's preferred language, en-US" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://icu.test");
    defer page.end();
    // The adapter sets ICU's default locale from the platform's first
    // preferred language (platform.preferredLanguages, "en-US" today) when
    // V8 starts, as Chrome sets it to the browser's locale - never the host
    // process's LANG.
    try rounds_lib.expectEval(page.realm,
        \\[new Intl.DateTimeFormat().resolvedOptions().locale, new Intl.NumberFormat().resolvedOptions().locale, new Intl.Collator().resolvedOptions().locale].join()
    , "en-US,en-US,en-US");
}

test "a worker realm has V8's Intl and Unicode support too" {
    test_process.start();
    const agent = try protocol.createAgent(.{
        .can_block = true,
        .from_snapshot = false,
        .hooks = &.{},
        .allocator = std.heap.c_allocator,
    });
    defer protocol.destroyAgent(agent);
    const made = try v8.worker_realm.createWorkerRealm(agent, .{
        .agent_cluster_cross_origin_isolated = true,
        .url = "http://web-platform.test:8000/workers/icu.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.c_allocator,
    });
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
    // Crane's own Intl was installed on window realms only: a worker had no
    // Intl at all. V8's is in every realm.
    try rounds_lib.expectEval(made.realm,
        \\[typeof Intl, new Intl.NumberFormat("de-DE").format(1234.5), new Intl.ListFormat("en").format(["a", "b", "c"]), /\p{Lu}/u.test("\u00c9"), "\u00e9".normalize("NFD").length].join("|")
    , "object|1.234,5|a, b, and c|true|2");
}
