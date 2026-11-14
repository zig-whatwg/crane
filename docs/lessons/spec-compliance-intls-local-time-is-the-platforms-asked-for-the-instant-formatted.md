# Spec Compliance: Intl's local time is the platform's, asked for the instant being formatted

**Date**: 2026-11-13
**Lesson**: A local-time offset belongs to an instant, not to "now", and the zone it comes from is the host's, never something read through the page's objects.

**Why**: ECMA-262 21.4.1.25 defines LocalTime(t) as t plus the zone's offset AT t, and ECMA-402 gives a DateTimeFormat with no `timeZone` option the DefaultTimeZone(). Wherever daylight saving time is observed the offset changes twice a year, so an offset taken once and applied to every date is wrong for about half of them. And the default zone is a fact about the host: V8's own Intl takes it from ICU's default time zone, which Blink's embedder sets from the OS; nothing a page can replace is consulted.

**What Happened**: Crane's Intl is its own (CLDR data, no ICU). Its DateTimeFormat and the `toLocale*String` methods got the offset from `new Date().getTimezoneOffset()`, evaluated in the page's realm at the time of the call. In a test process run in America/Los_Angeles, `formatToParts` gave the wrong hour for 8 March 2026 10:00:00 UTC and 1 November 2026 08:59:59 UTC - the two instants in daylight time - when run in November, and the right hour for the two in standard time; a page that set `Date.prototype.getTimezoneOffset = () => 600` changed every answer.

**Fix**: The offset is the difference between the platform's local calendar fields for the instant (`platform.localDateTime`, the operation document.lastModified already reads) and the instant's UTC fields, computed per call for the instant formatted. Tests assert Intl's fields equal the realm's own Date's one second either side of both 2026 transitions, with the two offsets required to differ so the test cannot pass in a zone without one; the test launcher already runs every test child with `TZ=America/Los_Angeles` (tools/test_launcher/child.zig), so no test sets process state.

One caveat stays open. The platform's zone rules are libc's (`localtime_r`), and V8's Date uses ICU's. They agree for every zone's current rules; they can differ for dates decades back when the two zone databases are of different vintages, and where the platform cannot name the zone at all (`platform.defaultTimeZone` answers "UTC" for a host whose /etc/localtime is a regular file, while `localDateTime` still uses the OS zone). The repair is to make the platform's zone the one V8's Date is given, so one source decides both.

**Takeaway**: **Compute a local offset for the instant you are formatting, from the host's zone, through the platform - and test it on both sides of a real transition, in a zone the test process is known to run in, with an assertion that the two sides differ.**
