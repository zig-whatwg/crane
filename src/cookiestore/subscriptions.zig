//! Cookie change subscriptions: what a service worker registration's cookie
//! change subscription list holds, and "process cookie changes" step 2.2 -
//! whether one change is one the registration observes.
//!
//! WHATWG Cookie Store Standard 2.3 (the list), 7.4 (process changes):
//! https://cookiestore.spec.whatwg.org/#cookie-change-subscription-list
//! https://cookiestore.spec.whatwg.org/#process-cookie-changes
//!
//! Engine-free: the service worker registry keeps the lists, and its manager
//! asks these questions on its job thread for every change the Browser's jar
//! reports while any registration subscribes.

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const CookieJar = @import("jar.zig").CookieJar;
const RequestUrl = @import("http_integration.zig").RequestUrl;

/// A cookie change subscription (2.3): a tuple of name (a string or null)
/// and url (serialized). Its strings are its owner's.
pub const ChangeSubscription = struct {
    name: ?[]const u8,
    url: []const u8,

    /// Infra tuple equality: both items equal (unsubscribe() step 4.2.7,
    /// subscribe()'s "does not already contain").
    pub fn eql(self: ChangeSubscription, other: ChangeSubscription) bool {
        if (!std.mem.eql(u8, self.url, other.url)) return false;
        const a = self.name orelse return other.name == null;
        const b = other.name orelse return false;
        return std.mem.eql(u8, a, b);
    }
};

/// Whether `cookie` is in "the observable changes for `url`": it meets step
/// 1 of the cookie-string retrieval for a "non-HTTP" API with `url` as
/// request-uri.
///
/// Those conditions are the jar's own retrieval match for a non-HTTP
/// request (`CookieJar.cookieMatches`): the host (host-only: equal; else
/// domain-matched), the path, Secure only for a secure scheme, no HttpOnly.
/// The same-site mode is "strict or less", as for the window's CookieStore
/// change events (CookieStore.fireChangeEvent) and document.cookie's
/// same-site top-level documents; no partition key, as cookieStore.set()
/// stores none.
pub fn observableFor(url: []const u8, cookie: *const Cookie) bool {
    const request = RequestUrl.of(url) orelse return false;
    return CookieJar.cookieMatches(cookie, .{
        .host = request.host,
        .path = request.path,
        .is_secure = request.secure,
        .is_http = false,
        .same_site = .strict_or_less,
    });
}

/// Process cookie changes step 2.2 for one change of `cookie`: it is in the
/// observable changes for `scope_url` (2.2's list), and for some
/// subscription's url (2.2.2.1) whose name is null or the cookie's name
/// (2.2.2.3).
///
/// The cookie's name is compared as the jar keeps it: names are stored as
/// UTF-8 (createCookieListItem decodes nothing either), and a subscription's
/// name is a normalized USVString.
pub fn registrationObserves(scope_url: []const u8, subscriptions: []const ChangeSubscription, cookie: *const Cookie) bool {
    // 2.2. Only a change in the observable changes for the scope url.
    if (!observableFor(scope_url, cookie)) return false;
    // 2.2.2. For each subscription:
    for (subscriptions) |subscription| {
        // 2.2.2.1. The change must be observable for its url.
        if (!observableFor(subscription.url, cookie)) continue;
        // 2.2.2.2-3. A null name matches every cookie; otherwise the
        // cookie's name must be it. One match appends the change: break.
        const name = subscription.name orelse return true;
        if (std.mem.eql(u8, cookie.name, name)) return true;
    }
    return false;
}
