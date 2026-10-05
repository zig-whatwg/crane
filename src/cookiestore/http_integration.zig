//! The cookie store's algorithms, as its users call them: "Parse a Cookie",
//! "Store a Cookie", "Parse and Store a Cookie", "Retrieve Cookies",
//! "Serialize Cookies" and "Parse a Date" (layered cookies, the RFC 6265bis
//! successor Fetch and HTML now cite).
//!
//! Fetch parses and stores a response's `Set-Cookie` and sends a `Cookie`
//! header (HTTP APIs: httpOnlyAllowed); document.cookie does both for a
//! document (a "non-HTTP" API). Every one goes through here, so a cookie is
//! the same cookie whoever set it.
//!
//! Spec: https://httpwg.org/http-extensions/draft-ietf-httpbis-layered-cookies.html

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const jar_mod = @import("jar.zig");
const CookieJar = jar_mod.CookieJar;
const RetrieveOptions = jar_mod.RetrieveOptions;
const domain_matching = @import("domain_matching.zig");
const clock = @import("clock");

/// The user agent's cookie age limit: 400 days.
pub const cookie_age_limit_ms: i64 = 400 * 24 * 60 * 60 * 1000;
/// A cookie's name and value together may be at most this long.
pub const max_name_value_size: usize = 4096;
/// An attribute value longer than this is ignored.
pub const max_attribute_value_size: usize = 1024;

/// What "Parse a Cookie" returns: a new cookie, whose `domain` is the
/// Domain attribute's host (null when there was none).
pub const ParsedCookie = struct {
    cookie: Cookie,
    /// The last Domain attribute did not host-parse: the cookie's host is
    /// "failure", and "Store a Cookie" stores nothing.
    host_failure: bool = false,

    pub fn deinit(self: *ParsedCookie) void {
        self.cookie.deinit();
    }
};

/// Layered cookies "Parse a Cookie" given `input` and the request URL's
/// path (serialized) - isSecure and host are only Store a Cookie's
/// concern. Null for failure.
pub fn parseCookie(allocator: std.mem.Allocator, input: []const u8, request_path: []const u8) !?ParsedCookie {
    // 1. A CTL byte other than HTAB is failure.
    for (input) |byte| {
        if ((byte <= 0x08) or (byte >= 0x0A and byte <= 0x1F) or byte == 0x7F) return null;
    }
    // 2-6. The name-value pair is everything before the first `;`, the
    //      attributes the rest (with that `;`).
    const semicolon = std.mem.indexOfScalar(u8, input, ';');
    const name_value_input = if (semicolon) |i| input[0..i] else input;
    var attributes_input = if (semicolon) |i| input[i..] else "";
    // 7-10. No `=`: a nameless cookie whose value is the whole pair.
    var name: []const u8 = "";
    var value: []const u8 = name_value_input;
    if (std.mem.indexOfScalar(u8, name_value_input, '=')) |eq| {
        name = name_value_input[0..eq];
        value = name_value_input[eq + 1 ..];
    }
    // 11. Remove leading and trailing WSP from both.
    name = trimWsp(name);
    value = trimWsp(value);
    // 12. Empty, or longer than 4096 bytes together: failure.
    if (name.len + value.len == 0 or name.len + value.len > max_name_value_size) return null;

    // 13. A new cookie with that name and value.
    var parsed: ParsedCookie = .{ .cookie = try Cookie.init(allocator, name, value) };
    errdefer parsed.deinit();
    parsed.cookie.same_site = .unset;
    // 14. Its path is the Cookie Default Path of the request path.
    try parsed.cookie.setPath(domain_matching.getDefaultPath(request_path));

    // Max-Age takes precedence over Expires whichever comes first: an
    // Expires after a Max-Age is ignored (15.13.1), and a Max-Age after an
    // Expires overwrites it. (The draft declares maxAgeSeen inside the loop,
    // which would forget it at every attribute; it has to outlive them.)
    var max_age_seen = false;
    // 15. While attributesInput is not empty:
    while (attributes_input.len > 0) {
        // 15.2-15.3. Consume the `;`.
        attributes_input = attributes_input[1..];
        // 15.5-15.6. The attribute runs to the next `;`.
        const end = std.mem.indexOfScalar(u8, attributes_input, ';') orelse attributes_input.len;
        const attribute = attributes_input[0..end];
        attributes_input = attributes_input[end..];
        // 15.7-15.11. Its name is before the first `=`, its value after.
        var attribute_name: []const u8 = attribute;
        var attribute_value: []const u8 = "";
        if (std.mem.indexOfScalar(u8, attribute, '=')) |eq| {
            attribute_name = attribute[0..eq];
            attribute_value = attribute[eq + 1 ..];
        }
        attribute_name = trimWsp(attribute_name);
        attribute_value = trimWsp(attribute_value);
        // 15.12. An over-long value is ignored.
        if (attribute_value.len > max_attribute_value_size) continue;

        const cookie = &parsed.cookie;
        if (std.ascii.eqlIgnoreCase(attribute_name, "Expires")) {
            // 15.13.
            if (max_age_seen) continue;
            const expiry = parseDate(attribute_value) orelse continue;
            cookie.expiry_time = @min(expiry, clock.wallMillis() +| cookie_age_limit_ms);
        } else if (std.ascii.eqlIgnoreCase(attribute_name, "Max-Age")) {
            // 15.14.
            const delta_seconds = parseMaxAge(attribute_value) orelse continue;
            const limit_seconds = @divTrunc(cookie_age_limit_ms, 1000);
            const capped = @min(delta_seconds, limit_seconds);
            cookie.expiry_time = if (capped <= 0) earliest_representable_ms else clock.wallMillis() +| (capped * 1000);
            max_age_seen = true;
        } else if (std.ascii.eqlIgnoreCase(attribute_name, "Domain")) {
            // 15.15. The host the value host-parses to, or failure.
            if (try parseDomainAttribute(allocator, attribute_value)) |host| {
                defer allocator.free(host);
                try cookie.setDomain(host);
                parsed.host_failure = false;
            } else {
                if (cookie.domain) |d| allocator.free(d);
                cookie.domain = null;
                parsed.host_failure = true;
            }
        } else if (std.ascii.eqlIgnoreCase(attribute_name, "Path")) {
            // 15.16. Only a value starting with `/`.
            if (attribute_value.len > 0 and attribute_value[0] == '/') {
                try cookie.setPath(attribute_value);
                cookie.has_path = true;
            }
        } else if (std.ascii.eqlIgnoreCase(attribute_name, "Secure")) {
            // 15.17.
            cookie.secure = true;
        } else if (std.ascii.eqlIgnoreCase(attribute_name, "HttpOnly")) {
            // 15.18.
            cookie.http_only = true;
        } else if (std.ascii.eqlIgnoreCase(attribute_name, "SameSite")) {
            // 15.19. Anything else leaves it as it was.
            if (std.ascii.eqlIgnoreCase(attribute_value, "None")) cookie.same_site = .none;
            if (std.ascii.eqlIgnoreCase(attribute_value, "Strict")) cookie.same_site = .strict;
            if (std.ascii.eqlIgnoreCase(attribute_value, "Lax")) cookie.same_site = .lax;
        }
    }
    // setDomain marks a cookie not host-only; whether it is, is Store a
    // Cookie's to decide (steps 5-7) - until then, no Domain means null.
    parsed.cookie.host_only = parsed.cookie.domain == null;
    // 16.
    return parsed;
}

/// "The earliest representable date": an expiry-time every clock is past.
const earliest_representable_ms: i64 = 0;

/// 15.14.1-15.14.4: a Max-Age value is a DIGIT, or `-` then a DIGIT, and
/// DIGITs after; its seconds (saturating), or null to ignore it.
fn parseMaxAge(value: []const u8) ?i64 {
    if (value.len == 0) return null;
    const negative = value[0] == '-';
    const digits = if (negative) value[1..] else value;
    if (digits.len == 0) return null;
    var seconds: i64 = 0;
    for (digits) |c| {
        if (!std.ascii.isDigit(c)) return null;
        seconds = seconds *| 10 +| (c - '0');
    }
    return if (negative) -seconds else seconds;
}

/// 15.15.2: an ASCII value, less a leading `.`, host-parsed. The host,
/// lowercased (OWNED), or null for failure: a non-ASCII value, or one no
/// host parses from - empty, or with a forbidden domain code point.
fn parseDomainAttribute(allocator: std.mem.Allocator, value: []const u8) !?[]u8 {
    for (value) |c| if (c >= 0x80) return null;
    var host_input = value;
    if (host_input.len > 0 and host_input[0] == '.') host_input = host_input[1..];
    if (host_input.len == 0) return null;
    for (host_input) |c| {
        // URL Standard forbidden domain code points: the forbidden host
        // code points, C0 controls, `%` and DEL.
        if (c <= 0x20 or c == 0x7F) return null;
        if (std.mem.indexOfScalar(u8, "#%/:<>?@[\\]^|", c) != null) return null;
    }
    // TODO: domain to ASCII (IDNA), and IPv4 canonicalization, for a value
    //       the URL host parser would rewrite.
    return try std.ascii.allocLowerString(allocator, host_input);
}

/// Remove leading and trailing WSP (SP and HTAB).
fn trimWsp(bytes: []const u8) []const u8 {
    return std.mem.trim(u8, bytes, " \t");
}

/// How "Store a Cookie" is called: the request it arrived with, and what
/// that API may do.
pub const StoreOptions = struct {
    /// The request URL's scheme is secure (https, wss).
    is_secure: bool,
    /// The request URL's host, serialized and lowercase.
    host: []const u8,
    /// An HTTP API (a response's `Set-Cookie`), not document.cookie or the
    /// Cookie Store API.
    http_only_allowed: bool,
    allow_non_host_only_cookie_for_public_suffix: bool = false,
    /// The same-site mode of the request was "strict-or-less".
    same_site_strict_or_lax_allowed: bool = true,
};

/// What "Store a Cookie" did.
pub const StoreResult = enum {
    /// It returned null: nothing changed.
    ignored,
    /// A cookie identical to the one already stored: nothing changed.
    unchanged,
    /// The cookie is in the store - replacing one of the same identity, if
    /// there was one - or, if it had already expired, removed that one.
    stored,
};

/// Layered cookies "Store a Cookie": `parsed`'s cookie into `jar`, as
/// `options` says it arrived. Reads the jar's cookies, then stores: call with
/// the jar locked (`jar.lock()`) - parseAndStoreCookie and the Cookie Store's
/// setCookieObserved do - wherever another thread can reach it.
pub fn storeCookie(allocator: std.mem.Allocator, jar: *CookieJar, parsed: *ParsedCookie, options: StoreOptions) !StoreResult {
    const cookie = &parsed.cookie;
    // 3. A host that failed to parse stores nothing.
    if (parsed.host_failure) return .ignored;
    // 4. Its creation-time and last-access-time are now (Cookie.init).
    // The cookie's host is null - it had no Domain attribute - while it is
    // host-only: parseCookie marks it so, and so does the Cookie Store API's
    // "set a cookie" given no domain.
    var has_host = !cookie.host_only and cookie.domain != null;
    // 5. A public suffix is a host only for itself, host-only.
    if (has_host and !options.allow_non_host_only_cookie_for_public_suffix) {
        const domain = cookie.domain.?;
        if (try domain_matching.isPublicSuffix(allocator, domain)) {
            if (!std.ascii.eqlIgnoreCase(domain, options.host)) return .ignored;
            has_host = false;
        }
    }
    if (has_host) {
        // 7. Otherwise host must Domain-Match it.
        if (!domain_matching.domainMatches(options.host, cookie.domain.?)) return .ignored;
        cookie.host_only = false;
    } else {
        // 6. A cookie with no host is host-only, for host.
        const host = try std.ascii.allocLowerString(allocator, options.host);
        defer allocator.free(host);
        try cookie.setDomain(host);
        cookie.host_only = true;
    }
    // 9. An HttpOnly cookie only from an HTTP API.
    if (!options.http_only_allowed and cookie.http_only) return .ignored;
    // 10. From an insecure URL: no Secure cookie, and none that would
    //     overlay a Secure one.
    if (!options.is_secure) {
        if (cookie.secure) return .ignored;
        if (overlaysSecureCookie(jar, cookie.*)) return .ignored;
    }
    // 11. A SameSite cookie only where the same-site mode allowed it.
    if (cookie.same_site != .none and !options.same_site_strict_or_lax_allowed) return .ignored;
    // 12. SameSite=None needs Secure.
    if (cookie.same_site == .none and !cookie.secure) return .ignored;
    // 13-16. The name prefixes (byte-lowercased).
    if (startsWithLower(cookie.name, "__secure-") and !cookie.secure) return .ignored;
    if (startsWithLower(cookie.name, "__host-") and !hostPrefixCompatible(cookie.*)) return .ignored;
    if (startsWithLower(cookie.name, "__http-") and !httpPrefixCompatible(cookie.*)) return .ignored;
    if (startsWithLower(cookie.name, "__host-http-") and !(hostPrefixCompatible(cookie.*) and httpPrefixCompatible(cookie.*))) return .ignored;
    // 17. A nameless cookie's value may not pose as a prefixed name.
    if (cookie.name.len == 0) {
        for ([_][]const u8{ "__secure-", "__host-", "__http-", "__host-http-" }) |prefix| {
            if (startsWithLower(cookie.value, prefix)) return .ignored;
        }
    }
    // 18. The cookie it replaces: name, host, host-only and path the same.
    if (jar.findIdentity(cookie.*)) |index| {
        const old = jar.cookies.items[index];
        // 18.1. Only an HTTP API replaces an HttpOnly cookie.
        if (!options.http_only_allowed and old.http_only) return .ignored;
        // 18.2. Nothing to change. (The draft omits the value; a new value
        //       is a change.)
        if (std.mem.eql(u8, old.value, cookie.value) and old.secure == cookie.secure and old.same_site == cookie.same_site and
            old.http_only == cookie.http_only and std.meta.eql(old.expiry_time, cookie.expiry_time))
        {
            return .unchanged;
        }
        // 18.3-18.4: the jar keeps its creation-time and removes it.
    }
    // 19. Insert it (and garbage collect its host).
    try jar.store(cookie.*);
    return .stored;
}

/// Store a Cookie step 10.2: a Secure cookie of the same name whose host
/// Domain-Matches `cookie`'s or the reverse, and whose path `cookie`'s
/// Path-Matches, is not overlaid by a non-secure one.
fn overlaysSecureCookie(jar: *const CookieJar, cookie: Cookie) bool {
    const domain = cookie.domain orelse return false;
    for (jar.cookies.items) |existing| {
        if (!existing.secure or !std.mem.eql(u8, existing.name, cookie.name)) continue;
        const existing_domain = existing.domain orelse continue;
        if (!domain_matching.domainMatches(existing_domain, domain) and !domain_matching.domainMatches(domain, existing_domain)) continue;
        if (domain_matching.pathMatches(cookie.path, existing.path)) return true;
    }
    return false;
}

/// "Host-prefix compatible": Secure, host-only, and a Path attribute of
/// `/`.
fn hostPrefixCompatible(cookie: Cookie) bool {
    return cookie.secure and cookie.host_only and cookie.has_path and std.mem.eql(u8, cookie.path, "/");
}

/// "Http-prefix compatible": Secure and HttpOnly.
fn httpPrefixCompatible(cookie: Cookie) bool {
    return cookie.secure and cookie.http_only;
}

fn startsWithLower(bytes: []const u8, prefix: []const u8) bool {
    return bytes.len >= prefix.len and std.ascii.eqlIgnoreCase(bytes[0..prefix.len], prefix);
}

/// Layered cookies "Parse and Store a Cookie": `input` - a `Set-Cookie`
/// value, or what document.cookie was set to - for a request whose URL
/// path is `request_path`. Then "Garbage Collect Cookies" for its host
/// (the jar does, as it stores).
pub fn parseAndStoreCookie(allocator: std.mem.Allocator, jar: *CookieJar, input: []const u8, request_path: []const u8, options: StoreOptions) !StoreResult {
    // 1-2. Parse it; failure stores nothing.
    var parsed = (try parseCookie(allocator, input, request_path)) orelse return .ignored;
    defer parsed.deinit();
    // 3. Store it - its checks and the store under one hold of the jar: a
    // worker's fetch stores on the worker's thread.
    jar.lock();
    defer jar.unlock();
    return storeCookie(allocator, jar, &parsed, options);
}

/// Layered cookies "Serialize Cookies": `name=value` pairs joined by `; `,
/// a nameless cookie as its value alone. OWNED.
pub fn serializeCookies(allocator: std.mem.Allocator, cookies: []const Cookie) ![]u8 {
    var output: std.ArrayListUnmanaged(u8) = .empty;
    errdefer output.deinit(allocator);
    for (cookies) |cookie| {
        if (output.items.len > 0) try output.appendSlice(allocator, "; ");
        if (cookie.name.len > 0) {
            try output.appendSlice(allocator, cookie.name);
            try output.append(allocator, '=');
        }
        try output.appendSlice(allocator, cookie.value);
    }
    return output.toOwnedSlice(allocator);
}

/// "Retrieve Cookies" with `options`, then "Serialize Cookies": the
/// cookie-string - a `Cookie` header's value, or document.cookie's. Empty
/// when no cookie matches. OWNED.
pub fn generateCookieHeader(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    options: RetrieveOptions,
) ![]u8 {
    // The cookies come back as copies: owned once the jar is released.
    var cookies = blk: {
        jar.lock();
        defer jar.unlock();
        break :blk try jar.retrieve(options);
    };
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }
    return serializeCookies(allocator, cookies.items);
}

/// WebDriver "all associated cookies" of a document whose URL is `url` (a
/// serialized URL): the cookies RFC 6265's cookie-string step 1 selects for
/// an HTTP API - its host's, whose path the URL's path-matches, a Secure one
/// only for a secure scheme, HttpOnly ones included, no same-site filter -
/// only those named `name` when it is given. Copies, sorted; the list and
/// its cookies are the caller's. Empty for a URL cookies are not kept for.
pub fn webdriverAssociatedCookies(jar: *CookieJar, url: []const u8, name: ?[]const u8) !std.ArrayListUnmanaged(Cookie) {
    const options = webdriverOptions(url, name) orelse return .empty;
    jar.lock();
    defer jar.unlock();
    return jar.retrieve(options);
}

/// WebDriver "delete cookies" for the document whose URL is `url`: every one
/// of its associated cookies (only those named `name` when it is given) gets
/// an expiry time in the past, and so leaves the store. Returns how many.
pub fn webdriverDeleteCookies(jar: *CookieJar, url: []const u8, name: ?[]const u8) usize {
    const options = webdriverOptions(url, name) orelse return 0;
    jar.lock();
    defer jar.unlock();
    return jar.expireMatching(options);
}

fn webdriverOptions(url: []const u8, name: ?[]const u8) ?RetrieveOptions {
    const parts = RequestUrl.of(url) orelse return null;
    return .{
        .host = parts.host,
        .path = parts.path,
        .is_http = true,
        .is_secure = parts.secure,
        .same_site = .strict_or_less,
        .name = name,
    };
}

/// Parse and store each of a response's `Set-Cookie` values - each on its
/// own: they never combine.
pub fn processSetCookieHeaders(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    headers: []const []const u8,
    request_path: []const u8,
    options: StoreOptions,
) !void {
    for (headers) |header| {
        _ = try parseAndStoreCookie(allocator, jar, header, request_path, options);
    }
}

/// The parts of a request URL the cookie store is keyed on: its host, its
/// path, and whether its scheme is secure. The URL is a SERIALIZED one - a
/// request's current URL, a document's URL - so it is already canonical:
/// "scheme://[userinfo@]host[:port]/path...", with a lowercase host and
/// userinfo's own `@` and `/` percent-encoded.
pub const RequestUrl = struct {
    host: []const u8,
    path: []const u8,
    /// https or wss.
    secure: bool,

    /// Null for a URL cookies are not kept for: anything but http(s) and
    /// ws(s).
    pub fn of(url: []const u8) ?RequestUrl {
        const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
        const scheme = url[0..scheme_end];
        const secure = std.ascii.eqlIgnoreCase(scheme, "https") or std.ascii.eqlIgnoreCase(scheme, "wss");
        if (!secure and !std.ascii.eqlIgnoreCase(scheme, "http") and !std.ascii.eqlIgnoreCase(scheme, "ws")) return null;
        const after_scheme = url[scheme_end + 3 ..];
        const authority_end = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
        var authority = after_scheme[0..authority_end];
        if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];
        // An IPv6 host keeps its brackets, as the host serializer writes it.
        const host_end = if (authority.len > 0 and authority[0] == '[')
            (std.mem.indexOfScalar(u8, authority, ']') orelse return null) + 1
        else
            std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
        const rest = after_scheme[authority_end..];
        const path_end = std.mem.indexOfAny(u8, rest, "?#") orelse rest.len;
        return .{
            .host = authority[0..host_end],
            .path = if (path_end == 0) "/" else rest[0..path_end],
            .secure = secure,
        };
    }
};

// ============================================================================
// Parse a Date
// ============================================================================

/// Layered cookies "Parse a Date": a cookie-date's time, in wall-clock
/// milliseconds since the epoch (negative before 1970), or null for
/// failure.
pub fn parseDate(input: []const u8) ?i64 {
    var found_time = false;
    var found_day_of_month = false;
    var found_month = false;
    var found_year = false;
    var hour: u32 = 0;
    var minute: u32 = 0;
    var second: u32 = 0;
    var day_of_month: u32 = 0;
    var month: u32 = 0;
    var year: u32 = 0;

    // 1. Divide the cookie-date into date-tokens: runs of non-delimiters.
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and isDateDelimiter(input[i])) i += 1;
        const start = i;
        while (i < input.len and !isDateDelimiter(input[i])) i += 1;
        if (start == i) break;
        const token = input[start..i];
        // 2. Each token is the first of time, day-of-month, month and year
        //    not yet found that it matches.
        if (!found_time) {
            if (parseTimeToken(token)) |t| {
                found_time = true;
                hour = t[0];
                minute = t[1];
                second = t[2];
                continue;
            }
        }
        if (!found_day_of_month) {
            if (leadingNumber(token, 1, 2)) |d| {
                found_day_of_month = true;
                day_of_month = d;
                continue;
            }
        }
        if (!found_month) {
            if (monthOf(token)) |m| {
                found_month = true;
                month = m;
                continue;
            }
        }
        if (!found_year) {
            if (leadingNumber(token, 2, 4)) |y| {
                found_year = true;
                year = y;
                continue;
            }
        }
    }
    // 3-4. Two-digit years: 70-99 are 19xx, 0-69 are 20xx.
    if (year >= 70 and year <= 99) year += 1900;
    if (year <= 69) year += 2000;
    // 5. Failure without all four, or out of range.
    if (!found_time or !found_day_of_month or !found_month or !found_year) return null;
    if (day_of_month < 1 or day_of_month > 31 or year < 1601 or hour > 23 or minute > 59 or second > 59) return null;
    // 6. The date must exist (no 30 February).
    if (day_of_month > daysInMonth(year, month)) return null;
    // 7.
    const days = daysFromCivil(year, month, day_of_month);
    return (days * 86_400 + @as(i64, hour) * 3600 + @as(i64, minute) * 60 + second) * 1000;
}

/// delimiter = %x09 / %x20-2F / %x3B-40 / %x5B-60 / %x7B-7E
fn isDateDelimiter(c: u8) bool {
    return c == 0x09 or (c >= 0x20 and c <= 0x2F) or (c >= 0x3B and c <= 0x40) or
        (c >= 0x5B and c <= 0x60) or (c >= 0x7B and c <= 0x7E);
}

/// `min`-`max` DIGITs, then the end or a non-digit (and anything): their
/// number. The day-of-month and year productions.
fn leadingNumber(token: []const u8, min: usize, max: usize) ?u32 {
    var n: usize = 0;
    var value: u32 = 0;
    while (n < token.len and std.ascii.isDigit(token[n])) : (n += 1) {
        if (n == max) return null;
        value = value * 10 + (token[n] - '0');
    }
    if (n < min) return null;
    return value;
}

/// time = hms-time [ non-digit *OCTET ]; hms-time = time-field ":"
/// time-field ":" time-field; time-field = 1*2DIGIT.
fn parseTimeToken(token: []const u8) ?[3]u32 {
    var fields: [3]u32 = undefined;
    var pos: usize = 0;
    for (0..3) |f| {
        if (f > 0) {
            if (pos >= token.len or token[pos] != ':') return null;
            pos += 1;
        }
        const start = pos;
        var value: u32 = 0;
        while (pos < token.len and std.ascii.isDigit(token[pos]) and pos - start < 2) : (pos += 1) {
            value = value * 10 + (token[pos] - '0');
        }
        if (pos == start) return null;
        fields[f] = value;
    }
    // A third DIGIT is not a non-digit.
    if (pos < token.len and std.ascii.isDigit(token[pos])) return null;
    return fields;
}

/// month = ( "jan" / ... / "dec" ) *OCTET, case-insensitively: 1-12.
fn monthOf(token: []const u8) ?u32 {
    if (token.len < 3) return null;
    const names = [_][]const u8{ "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" };
    for (names, 1..) |name, number| {
        if (std.ascii.eqlIgnoreCase(token[0..3], name)) return @intCast(number);
    }
    return null;
}

fn daysInMonth(year: u32, month: u32) u32 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        else => if ((year % 4 == 0 and year % 100 != 0) or year % 400 == 0) 29 else 28,
    };
}

/// Days from 1970-01-01 to the proleptic Gregorian `year`-`month`-`day`.
fn daysFromCivil(year: u32, month: u32, day: u32) i64 {
    const y: i64 = @as(i64, year) - @intFromBool(month <= 2);
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const m: i64 = month;
    const mp = @mod(m + 9, 12);
    const doy = @divFloor(153 * mp + 2, 5) + day - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146_097 + doe - 719_468;
}

// ============================================================================
// Tests
// ============================================================================

fn testStore(jar: *CookieJar, input: []const u8, options: StoreOptions) !StoreResult {
    return parseAndStoreCookie(std.testing.allocator, jar, input, "/", options);
}

const http_options: StoreOptions = .{ .is_secure = false, .host = "example.com", .http_only_allowed = true };

fn cookieString(jar: *CookieJar, options: RetrieveOptions) ![]u8 {
    return generateCookieHeader(std.testing.allocator, jar, options);
}

test "Parse a Date: the forms cookies are expired with, and failures" {
    const Case = struct { input: []const u8, ms: ?i64 };
    const cases = [_]Case{
        .{ .input = "Thu, 01 Jan 1970 00:00:00 GMT", .ms = 0 },
        .{ .input = "Sun, 06 Nov 1994 08:49:37 GMT", .ms = 784111777000 },
        .{ .input = "Sunday, 06-Nov-94 08:49:37 GMT", .ms = 784111777000 },
        .{ .input = "Sun Nov  6 08:49:37 1994", .ms = 784111777000 },
        .{ .input = "09 Jun 2021 10:18:14 GMT", .ms = 1623233894000 },
        .{ .input = "Wed, 29 Feb 2012 00:00:00 GMT", .ms = 1330473600000 },
        .{ .input = "Mon, 01 Jan 1601 00:00:00 GMT", .ms = -11644473600000 },
        // Two-digit years: 70-99 are 19xx, 0-69 20xx.
        .{ .input = "01 Jan 69 00:00:00", .ms = 3124224000000 },
        .{ .input = "Thu, 30 Feb 2012 00:00:00 GMT", .ms = null },
        .{ .input = "Thu, 01 Jan 1600 00:00:00 GMT", .ms = null },
        .{ .input = "Thu, 01 Jan 1970 24:00:00 GMT", .ms = null },
        .{ .input = "Thu, 01 Jan 1970", .ms = null },
        .{ .input = "", .ms = null },
    };
    for (cases) |case| try std.testing.expectEqual(case.ms, parseDate(case.input));
}

test "Parse a Cookie: CTLs, the name-value pair, and nameless cookies" {
    const allocator = std.testing.allocator;
    try std.testing.expect(try parseCookie(allocator, "b=A\x00Z", "/") == null);
    try std.testing.expect(try parseCookie(allocator, "a=\x7F", "/") == null);
    try std.testing.expect(try parseCookie(allocator, "=", "/") == null);
    try std.testing.expect(try parseCookie(allocator, " ; Path=/", "/") == null);

    var tab = (try parseCookie(allocator, " a\t=\tb c ; x=y=z", "/")).?;
    defer tab.deinit();
    try std.testing.expectEqualStrings("a", tab.cookie.name);
    try std.testing.expectEqualStrings("b c", tab.cookie.value);

    var nameless = (try parseCookie(allocator, "just-a-value", "/")).?;
    defer nameless.deinit();
    try std.testing.expectEqualStrings("", nameless.cookie.name);
    try std.testing.expectEqualStrings("just-a-value", nameless.cookie.value);

    var equals = (try parseCookie(allocator, "=value", "/")).?;
    defer equals.deinit();
    try std.testing.expectEqualStrings("", equals.cookie.name);
    try std.testing.expectEqualStrings("value", equals.cookie.value);

    // 1 + 4095 bytes fit; 1 + 4096 do not.
    const long = "a=" ++ "x" ** 4095;
    try std.testing.expect(try parseCookie(allocator, long ++ "x", "/") == null);
    var fits = (try parseCookie(allocator, long, "/")).?;
    fits.deinit();
}

test "Parse a Cookie: attributes" {
    const allocator = std.testing.allocator;
    var parsed = (try parseCookie(allocator, "id=abc; Path=/p; Secure; HttpOnly; SameSite=Strict; Domain=.Example.COM", "/dir/page")).?;
    defer parsed.deinit();
    const cookie = parsed.cookie;
    try std.testing.expectEqualStrings("/p", cookie.path);
    try std.testing.expect(cookie.has_path);
    try std.testing.expect(cookie.secure and cookie.http_only);
    try std.testing.expectEqual(.strict, cookie.same_site);
    try std.testing.expectEqualStrings("example.com", cookie.domain.?);
    try std.testing.expect(!cookie.host_only);

    // The default path is the request path's directory; a Path not
    // starting with `/` is ignored; no SameSite is "unset".
    var defaults = (try parseCookie(allocator, "id=abc; Path=relative; SameSite=bogus", "/dir/page")).?;
    defer defaults.deinit();
    try std.testing.expectEqualStrings("/dir", defaults.cookie.path);
    try std.testing.expect(!defaults.cookie.has_path);
    try std.testing.expectEqual(.unset, defaults.cookie.same_site);
    try std.testing.expect(defaults.cookie.host_only);

    // Max-Age wins over Expires either way round; a bad Max-Age is ignored.
    var max_age_first = (try parseCookie(allocator, "a=b; Max-Age=0; Expires=Wed, 01 Jan 2100 00:00:00 GMT", "/")).?;
    defer max_age_first.deinit();
    try std.testing.expectEqual(earliest_representable_ms, max_age_first.cookie.expiry_time.?);
    var bad_max_age = (try parseCookie(allocator, "a=b; Max-Age=+5; Max-Age=1x", "/")).?;
    defer bad_max_age.deinit();
    try std.testing.expect(bad_max_age.cookie.expiry_time == null);
    // An Expires past the age limit is capped at it.
    var capped = (try parseCookie(allocator, "a=b; Expires=Fri, 01 Jan 9999 00:00:00 GMT", "/")).?;
    defer capped.deinit();
    try std.testing.expect(capped.cookie.expiry_time.? <= clock.wallMillis() + cookie_age_limit_ms);

    // A Domain that does not host-parse is failure, unless a later one does.
    var failed = (try parseCookie(allocator, "a=b; Domain=exa mple.com", "/")).?;
    defer failed.deinit();
    try std.testing.expect(failed.host_failure);
    var recovered = (try parseCookie(allocator, "a=b; Domain=; Domain=example.com", "/")).?;
    defer recovered.deinit();
    try std.testing.expect(!recovered.host_failure);
}

test "Store a Cookie: host-only cookies record their host, and match no other" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try std.testing.expectEqual(.stored, try testStore(&jar, "id=abc", .{ .is_secure = false, .host = "www.example.com", .http_only_allowed = true }));
    try std.testing.expectEqualStrings("www.example.com", jar.cookies.items[0].domain.?);
    try std.testing.expect(jar.cookies.items[0].host_only);
    for ([_][]const u8{ "example.com", "sub.www.example.com", "other.test" }) |host| {
        const header = try cookieString(&jar, .{ .host = host, .is_http = true });
        defer allocator.free(header);
        try std.testing.expectEqualStrings("", header);
    }
    const header = try cookieString(&jar, .{ .host = "WWW.example.com", .is_http = true });
    defer allocator.free(header);
    try std.testing.expectEqualStrings("id=abc", header);
}

test "Store a Cookie: Domain must be domain-matched, and a public suffix is host-only" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const www: StoreOptions = .{ .is_secure = false, .host = "www.example.com", .http_only_allowed = true };
    try std.testing.expectEqual(.ignored, try testStore(&jar, "id=abc; Domain=other.test", www));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "id=abc; Domain=exa mple.com", www));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "id=abc; Domain=com", www));
    try std.testing.expectEqual(.stored, try testStore(&jar, "id=abc; Domain=example.com", www));
    try std.testing.expect(!jar.cookies.items[0].host_only);
    try std.testing.expectEqual(.stored, try testStore(&jar, "ps=1; Domain=com", .{ .is_secure = false, .host = "com", .http_only_allowed = true }));
    try std.testing.expect(jar.cookies.items[1].host_only);
}

test "Store a Cookie: a host-only and a domain cookie of one name are two cookies" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try processSetCookieHeaders(allocator, &jar, &.{ "id=host", "id=domain; Domain=example.com" }, "/", http_options);
    try std.testing.expectEqual(2, jar.count());
    // Max-Age=0 removes the host-only one alone.
    try processSetCookieHeaders(allocator, &jar, &.{"id=; Max-Age=0"}, "/", http_options);
    try std.testing.expectEqual(1, jar.count());
    const header = try cookieString(&jar, .{ .host = "sub.example.com", .is_http = true });
    defer allocator.free(header);
    try std.testing.expectEqualStrings("id=domain", header);
}

test "Store a Cookie: HttpOnly is for HTTP APIs, Secure for secure URLs" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const script: StoreOptions = .{ .is_secure = false, .host = "example.com", .http_only_allowed = false };
    try std.testing.expectEqual(.ignored, try testStore(&jar, "h=1; HttpOnly", script));
    try std.testing.expectEqual(.stored, try testStore(&jar, "h=1; HttpOnly", http_options));
    // A non-HTTP API cannot overwrite it either.
    try std.testing.expectEqual(.ignored, try testStore(&jar, "h=2", script));
    // Nor can a script see it.
    const seen = try cookieString(&jar, .{ .host = "example.com" });
    defer allocator.free(seen);
    try std.testing.expectEqualStrings("", seen);

    try std.testing.expectEqual(.ignored, try testStore(&jar, "s=1; Secure", http_options));
    const secure: StoreOptions = .{ .is_secure = true, .host = "example.com", .http_only_allowed = true };
    try std.testing.expectEqual(.stored, try testStore(&jar, "s=1; Secure; Path=/login", secure));
    // An insecure cookie may not overlay it where it applies...
    try std.testing.expectEqual(.ignored, try parseAndStoreCookie(allocator, &jar, "s=2; Path=/login/en", "/", http_options));
    // ...but may beside it.
    try std.testing.expectEqual(.stored, try parseAndStoreCookie(allocator, &jar, "s=2; Path=/", "/", http_options));
}

test "Store a Cookie: SameSite=None needs Secure, and the name prefixes" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const secure: StoreOptions = .{ .is_secure = true, .host = "example.com", .http_only_allowed = true };
    try std.testing.expectEqual(.ignored, try testStore(&jar, "n=1; SameSite=None", secure));
    try std.testing.expectEqual(.stored, try testStore(&jar, "n=1; SameSite=None; Secure", secure));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "__Secure-a=1", secure));
    try std.testing.expectEqual(.stored, try testStore(&jar, "__Secure-a=1; Secure", secure));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "__Host-a=1; Secure", secure));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "__Host-a=1; Secure; Path=/; Domain=example.com", secure));
    try std.testing.expectEqual(.stored, try testStore(&jar, "__HOST-a=1; Secure; Path=/", secure));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "__Http-a=1; Secure", secure));
    try std.testing.expectEqual(.stored, try testStore(&jar, "__Http-a=1; Secure; HttpOnly", secure));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "__Host-a=1", secure));
    try std.testing.expectEqual(.ignored, try testStore(&jar, "=__Secure-a", secure));
}

test "Store a Cookie: an identical cookie changes nothing; a new value replaces, keeping creation-time" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try std.testing.expectEqual(.stored, try testStore(&jar, "a=1", http_options));
    jar.cookies.items[0].creation_time = 42;
    try std.testing.expectEqual(.unchanged, try testStore(&jar, "a=1", http_options));
    try std.testing.expectEqual(.stored, try testStore(&jar, "a=2", http_options));
    try std.testing.expectEqual(1, jar.count());
    try std.testing.expectEqualStrings("2", jar.cookies.items[0].value);
    try std.testing.expectEqual(42, jar.cookies.items[0].creation_time);
}

test "Serialize Cookies: longest path first, a nameless cookie as its value" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try processSetCookieHeaders(allocator, &jar, &.{ "short=1; Path=/", "long=2; Path=/a/b", "bare" }, "/", http_options);
    const header = try cookieString(&jar, .{ .host = "example.com", .path = "/a/b/c", .is_http = true });
    defer allocator.free(header);
    try std.testing.expectEqualStrings("long=2; short=1; bare", header);
}

test "a request URL's cookie parts: host without port or userinfo, path without query" {
    const Case = struct { url: []const u8, host: []const u8, path: []const u8, secure: bool };
    const cases = [_]Case{
        .{ .url = "http://example.com/a/b?q#f", .host = "example.com", .path = "/a/b", .secure = false },
        .{ .url = "https://u:p@example.com:8443/", .host = "example.com", .path = "/", .secure = true },
        .{ .url = "http://[::1]:8000/x", .host = "[::1]", .path = "/x", .secure = false },
        .{ .url = "http://127.0.0.1?q", .host = "127.0.0.1", .path = "/", .secure = false },
        .{ .url = "wss://example.com/socket", .host = "example.com", .path = "/socket", .secure = true },
        .{ .url = "ws://example.com", .host = "example.com", .path = "/", .secure = false },
    };
    for (cases) |case| {
        const parts = RequestUrl.of(case.url).?;
        try std.testing.expectEqualStrings(case.host, parts.host);
        try std.testing.expectEqualStrings(case.path, parts.path);
        try std.testing.expectEqual(case.secure, parts.secure);
    }
    try std.testing.expect(RequestUrl.of("data:text/plain,x") == null);
    try std.testing.expect(RequestUrl.of("file:///tmp/x") == null);
}
