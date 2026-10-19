//! Cookie Store "process cookie changes" step 2.2 for one change: whether a
//! service worker registration with a cookie change subscription list
//! observes it - in the observable changes for its scope url, and for some
//! subscription's url whose name is null or the cookie's name.
//!
//! https://cookiestore.spec.whatwg.org/#process-cookie-changes

const std = @import("std");
const testing = std.testing;
const cookiestore = @import("cookiestore");
const Cookie = cookiestore.Cookie;
const ChangeSubscription = cookiestore.ChangeSubscription;

const scope = "https://example.com/app/";

/// A cookie as `cookieStore.set(name, value)` from https://example.com
/// stores it: host-only, path "/", secure.
fn hostCookie(name: []const u8, value: []const u8) !Cookie {
    var cookie = try Cookie.init(testing.allocator, name, value);
    errdefer cookie.deinit();
    try cookie.setDomain("example.com");
    cookie.host_only = true;
    try cookie.setPath("/");
    cookie.secure = true;
    return cookie;
}

test "a subscription with no name observes every cookie its url and the scope observe" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    const subscriptions = [_]ChangeSubscription{.{ .name = null, .url = scope }};
    try testing.expect(cookiestore.registrationObserves(scope, &subscriptions, &cookie));
}

test "a named subscription observes only that name" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    const other = [_]ChangeSubscription{.{ .name = "other", .url = scope }};
    try testing.expect(!cookiestore.registrationObserves(scope, &other, &cookie));
    const named = [_]ChangeSubscription{.{ .name = "session", .url = scope }};
    try testing.expect(cookiestore.registrationObserves(scope, &named, &cookie));
}

test "any one matching subscription is enough (step 2.2.2's break)" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    const subscriptions = [_]ChangeSubscription{
        .{ .name = "other", .url = scope },
        .{ .name = null, .url = "https://example.com/app/deeper" },
        .{ .name = "session", .url = scope },
    };
    try testing.expect(cookiestore.registrationObserves(scope, &subscriptions, &cookie));
}

test "no subscription observes nothing" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    try testing.expect(!cookiestore.registrationObserves(scope, &.{}, &cookie));
}

test "a cookie whose path the scope url does not path-match is not observable for the registration" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    try cookie.setPath("/elsewhere");
    const subscriptions = [_]ChangeSubscription{.{ .name = null, .url = "https://example.com/elsewhere/x" }};
    // Observable for the subscription's url, but not for the scope url.
    try testing.expect(cookiestore.observableFor("https://example.com/elsewhere/x", &cookie));
    try testing.expect(!cookiestore.registrationObserves(scope, &subscriptions, &cookie));
}

test "a cookie the subscription's url does not observe is not matched by it" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    try cookie.setPath("/app/a");
    // The scope url /app/ does not path-match /app/a either: a cookie under
    // the scope but deeper than it is not in the scope's observable changes.
    try testing.expect(!cookiestore.observableFor(scope, &cookie));
    const subscriptions = [_]ChangeSubscription{.{ .name = null, .url = "https://example.com/app/b" }};
    try testing.expect(!cookiestore.registrationObserves(scope, &subscriptions, &cookie));
}

test "an HttpOnly cookie is never observable: script cannot see it" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    cookie.http_only = true;
    const subscriptions = [_]ChangeSubscription{.{ .name = null, .url = scope }};
    try testing.expect(!cookiestore.observableFor(scope, &cookie));
    try testing.expect(!cookiestore.registrationObserves(scope, &subscriptions, &cookie));
}

test "a Secure cookie is not observable for an http url" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    try testing.expect(!cookiestore.observableFor("http://example.com/app/", &cookie));
}

test "a host-only cookie is not observable for a subdomain; a Domain cookie is" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    try testing.expect(!cookiestore.observableFor("https://www.example.com/app/", &cookie));
    cookie.host_only = false;
    try testing.expect(cookiestore.observableFor("https://www.example.com/app/", &cookie));
    try testing.expect(!cookiestore.observableFor("https://example.org/app/", &cookie));
}

test "a url cookies are not kept for observes nothing" {
    var cookie = try hostCookie("session", "1");
    defer cookie.deinit();
    try testing.expect(!cookiestore.observableFor("data:text/plain,x", &cookie));
}

test "subscriptions are equal when both their names (null included) and urls are" {
    const a: ChangeSubscription = .{ .name = "session", .url = scope };
    try testing.expect(a.eql(.{ .name = "session", .url = scope }));
    try testing.expect(!a.eql(.{ .name = "other", .url = scope }));
    try testing.expect(!a.eql(.{ .name = null, .url = scope }));
    try testing.expect(!a.eql(.{ .name = "session", .url = "https://example.com/app/x" }));
    const unnamed: ChangeSubscription = .{ .name = null, .url = scope };
    try testing.expect(unnamed.eql(.{ .name = null, .url = scope }));
    try testing.expect(!unnamed.eql(.{ .name = "", .url = scope }));
}
