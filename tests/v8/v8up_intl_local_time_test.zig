//! Intl's local time does not come from the page.
//!
//! Lane v8up b8 (2026-11-13). Intl.DateTimeFormat.prototype.format and
//! formatToParts, and Date.prototype.toLocaleString / toLocaleDateString /
//! toLocaleTimeString, show an instant in the host's local time zone
//! (ECMA-402 11.1.2: a DateTimeFormat with no timeZone option has the
//! DefaultTimeZone(); ECMA-262 21.4.1.25, LocalTime(t) = t + the zone's
//! offset AT t). The V8 adapter found that offset by compiling and running
//! `new Date().getTimezoneOffset()` in the page's realm
//! (intl_binding.zig getLocalTimezoneOffset), which was wrong three ways:
//!
//! - It read the page's globals. A page that replaced `Date`, or
//!   `Date.prototype.getTimezoneOffset`, changed what Intl answered. No
//!   browser's Intl can be reached that way: V8's own Intl asks ICU's default
//!   time zone, and Blink's embedder sets that zone from the OS.
//! - It was the offset NOW, applied to whatever instant was formatted: a
//!   July date formatted in November came out an hour off wherever daylight
//!   saving time is observed.
//! - It compiled a script on every call (V8 15.7 runs without its
//!   compilation cache; tests/infra/v8up_adapter_script_compiles_test.zig).
//!
//! The local time is the platform's now (the platform protocol's
//! localDateTime, the OS's zone and its rules, which document.lastModified
//! reads too), asked for the instant being formatted.

const std = @import("std");
const rounds_lib = @import("handle_rounds.zig");

/// The three callers' answers for `t` (a time value, defined by the script
/// before it), joined: format, formatToParts, and toLocaleString called on a
/// Date made before anything was replaced.
const answers =
    \\[dtf.format(t), JSON.stringify(dtf.formatToParts(t)), toLocale.call(day, 'en-US'), toLocaleDate.call(day, 'en-US'), toLocaleTime.call(day, 'en-US')].join(' | ')
;

test "a page that replaces Date and Date.prototype.getTimezoneOffset does not change what Intl formats" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://intl.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm,
        \\globalThis.t = Date.UTC(2026, 0, 15, 12, 30, 45);
        \\globalThis.dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeStyle: 'medium' });
        \\globalThis.day = new Date(t);
        \\globalThis.RealDate = Date;
        \\globalThis.toLocale = Date.prototype.toLocaleString;
        \\globalThis.toLocaleDate = Date.prototype.toLocaleDateString;
        \\globalThis.toLocaleTime = Date.prototype.toLocaleTimeString;
        \\'ok'
    , "ok");
    try rounds_lib.expectEval(page.realm, "globalThis.before = " ++ answers ++ "; String(before.length > 20)", "true");

    // The method the adapter's script called, then the constructor it
    // called it on: each alone, and both.
    try rounds_lib.expectEval(page.realm,
        \\RealDate.prototype.getTimezoneOffset = () => 600;
        \\String(
    ++ answers ++
        \\ === before)
    , "true");
    try rounds_lib.expectEval(page.realm,
        \\globalThis.Date = function () { return { getTimezoneOffset() { return -840; } }; };
        \\String(
    ++ answers ++
        \\ === before)
    , "true");
    // A Date that throws, and one that is not callable at all: Intl still
    // answers, and as before.
    try rounds_lib.expectEval(page.realm,
        \\globalThis.Date = function () { throw new Error('the page\'s Date'); };
        \\String(
    ++ answers ++
        \\ === before)
    , "true");
    try rounds_lib.expectEval(page.realm,
        \\globalThis.Date = 7;
        \\String(
    ++ answers ++
        \\ === before)
    , "true");
}

test "the local time Intl formats is the realm's own Date's, in January and in July" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://intl-dst.test");
    defer page.end();
    // Where daylight saving time is observed the two instants have
    // different offsets, and the offset in force today is one of them at
    // most: the offset must be the instant's own. (In a zone with no
    // daylight saving time this holds trivially.)
    try rounds_lib.expectEval(page.realm,
        \\(() => {
        \\  const dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'short', timeStyle: 'medium' });
        \\  const out = [];
        \\  for (const t of [Date.UTC(2026, 0, 15, 12, 7, 9), Date.UTC(2026, 6, 15, 12, 7, 9), Date.UTC(1999, 11, 31, 23, 59, 59), 0]) {
        \\    const d = new Date(t);
        \\    const part = {};
        \\    for (const p of dtf.formatToParts(t)) part[p.type] = Number(p.value);
        \\    out.push(part.year === d.getFullYear() && part.month === d.getMonth() + 1 && part.day === d.getDate() &&
        \\      part.hour === d.getHours() && part.minute === d.getMinutes() && part.second === d.getSeconds());
        \\  }
        \\  return String(out);
        \\})()
    , "true,true,true,true");
}

test "one second either side of a daylight saving transition: Intl's local time is the realm's own Date's" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://intl-transition.test");
    defer page.end();
    // The launcher runs every test child in America/Los_Angeles
    // (tools/test_launcher/child.zig testEnvironment; fixture_test.zig pins
    // it), which V8's ICU and the platform's libc both read from TZ. Its
    // 2026 transitions: 8 March 10:00 UTC (02:00 PST becomes 03:00 PDT) and
    // 1 November 09:00 UTC (02:00 PDT becomes 01:00 PST). The offsets on the
    // two sides must differ, or this test would pass without testing: run
    // outside the launcher, in a zone with no such transition, it fails here
    // and says why.
    try rounds_lib.expectEval(page.realm,
        \\[new Date(Date.UTC(2026, 2, 8, 9, 59, 59)).getTimezoneOffset(), new Date(Date.UTC(2026, 2, 8, 10, 0, 0)).getTimezoneOffset(),
        \\  new Date(Date.UTC(2026, 10, 1, 8, 59, 59)).getTimezoneOffset(), new Date(Date.UTC(2026, 10, 1, 9, 0, 0)).getTimezoneOffset()].join()
    , "480,420,420,480");
    try rounds_lib.expectEval(page.realm,
        \\(() => {
        \\  const dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'short', timeStyle: 'medium' });
        \\  const out = [];
        \\  for (const t of [Date.UTC(2026, 2, 8, 9, 59, 59), Date.UTC(2026, 2, 8, 10, 0, 0), Date.UTC(2026, 10, 1, 8, 59, 59), Date.UTC(2026, 10, 1, 9, 0, 0)]) {
        \\    const d = new Date(t);
        \\    const part = {};
        \\    for (const p of dtf.formatToParts(t)) part[p.type] = Number(p.value);
        \\    out.push([part.day === d.getDate(), part.hour === d.getHours(), part.minute === d.getMinutes(), part.second === d.getSeconds()].join(''));
        \\  }
        \\  return out.join();
        \\})()
    , "truetruetruetrue,truetruetruetrue,truetruetruetrue,truetruetruetrue");
    // The same four through the other two callers: the hour each prints is
    // the Date's.
    try rounds_lib.expectEval(page.realm,
        \\(() => {
        \\  const out = [];
        \\  for (const t of [Date.UTC(2026, 2, 8, 9, 59, 59), Date.UTC(2026, 2, 8, 10, 0, 0), Date.UTC(2026, 10, 1, 8, 59, 59), Date.UTC(2026, 10, 1, 9, 0, 0)]) {
        \\    const d = new Date(t);
        \\    const dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeStyle: 'medium' });
        \\    out.push(dtf.format(t) === d.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'medium' }));
        \\  }
        \\  return String(out);
        \\})()
    , "true,true,true,true");
}

test "an instant outside the platform clock's range is still formatted, in the nearest representable instant's offset" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://intl-range.test");
    defer page.end();
    // The platform's wall time is nanoseconds in 64 bits (1677 to 2262);
    // ECMAScript's time values reach 275,760 years either way. The year an
    // out-of-range instant is formatted with is its own.
    try rounds_lib.expectEval(page.realm,
        \\(() => {
        \\  const dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'short', timeStyle: 'medium' });
        \\  const out = [];
        \\  for (const t of [Date.UTC(3000, 5, 15, 12, 0, 0), Date.UTC(1500, 5, 15, 12, 0, 0)]) {
        \\    const part = {};
        \\    for (const p of dtf.formatToParts(t)) part[p.type] = Number(p.value);
        \\    out.push(part.year);
        \\  }
        \\  return String(out);
        \\})()
    , "3000,1500");
}
