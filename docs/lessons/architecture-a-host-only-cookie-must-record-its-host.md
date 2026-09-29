# Architecture: A host-only cookie must record its host

**Date**: 2026-09-28
**Lesson**: A cookie with no Domain attribute belongs to the host that set it. If the store leaves its domain null and matching reads `cookie.domain orelse request.host`, the cookie matches every host it is asked about.

**Why**: When a cookie is stored, "no Domain attribute" means "the request host", and the store knows that host. When cookies are retrieved, it knows only the host of the request being answered. A null written at store time as shorthand for "the setter's host" reads at retrieve time as "whoever is asking". Layered cookies' "Store a Cookie" step 6 says so outright: a cookie whose host is null becomes host-only, and its host is set to the request host.

**What Happened**: `cookiestore.http_integration.parseSetCookieHeader` never set a domain for a host-only cookie. `CookieJar.cookieMatches` compared host-only cookies with `eqlIgnoreCase(options.host, cookie.domain orelse options.host)`, which is always true. The unit tests used a single host, so they passed. The bug showed once c29 put every realm on one Browser-owned jar, and Crane's own test (`crane/net-cookies.html`) set a cookie on `www1.` and read it back from the main host.

Two related gaps turned up in the same code:
- Identity ignored the host-only flag, so `id=1` (host-only) and `id=1; Domain=example.com` replaced each other. They are two cookies.
- Identity compared domains byte for byte, where hosts are compared host-equal (case-insensitively).

**Fix** (c29, then c31's layered-cookies rewrite):
1. Store a Cookie step 6: a cookie with no host gets the request host, lowercased, and `host_only = true`.
2. Retrieve Cookies: a host-only cookie matches when the host is host-equal to its host. A cookie with a null domain matches nothing (`cookie.domain orelse return false`).
3. `Cookie.hasSameIdentity` compares name, host (host-equal), the host-only flag, path and partition key.

**Takeaway**: **When a record's field is "whoever made it", write down who that was when it is made. A null default that is resolved at read time gets resolved against the reader.**
