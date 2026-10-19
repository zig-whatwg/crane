//! Lane partition1: Web Storage's areas are found by storage key - the
//! origin, the top-level site and the has-cross-site-ancestor bit - so one
//! origin embedded under two top-level sites has two localStorage areas, and
//! a popup's session storage copy (HTML "create a new top-level traversable"
//! step 10, Storage "legacy-clone a traversable storage shed") keeps every
//! copied shelf under its own key: a popup on another top-level site reads
//! none of the opener's third-party data, a same-site popup reads its copy.

const std = @import("std");
const testing = std.testing;
const web_storage = @import("html_core").web_storage;

const StorageKey = web_storage.StorageKey;

const origin = "http://web-platform.test:8000";
const first_party = StorageKey.initBorrowed(origin, "http://web-platform.test", false);
/// The same origin in an iframe of a page on another site.
const third_party = StorageKey.initBorrowed(origin, "http://not-web-platform.test", true);

test "localStorage: one origin under two top-level sites has two areas" {
    var store = web_storage.UserAgentStorage.init(testing.allocator);
    defer store.deinit();

    var first = try web_storage.getLocalStorage(testing.allocator, &store, first_party);
    defer first.deinit();
    try first.setItem("userID", "first");

    var third = try web_storage.getLocalStorage(testing.allocator, &store, third_party);
    defer third.deinit();
    try testing.expect(third.getItem("userID") == null);
    try third.setItem("userID", "third");

    var first_again = try web_storage.getLocalStorage(testing.allocator, &store, first_party);
    defer first_again.deinit();
    try testing.expectEqualStrings("first", first_again.getItem("userID").?);
    // The Storage object reports its origin, not its key.
    try testing.expectEqualStrings(origin, third.origin);
}

test "localStorage and sessionStorage: a key obtain-a-storage-key refuses is a SecurityError" {
    var store = web_storage.UserAgentStorage.init(testing.allocator);
    defer store.deinit();
    try testing.expectError(error.SecurityError, web_storage.getLocalStorage(testing.allocator, &store, StorageKey.initBorrowed("null", "http://web-platform.test", true)));
    try testing.expectError(error.SecurityError, web_storage.getLocalStorage(testing.allocator, &store, StorageKey.initBorrowed(origin, "null", true)));
    try testing.expectError(error.SecurityError, web_storage.getSessionStorage(testing.allocator, &store, 1, StorageKey.initBorrowed(origin, "null", true)));
}

test "sessionStorage: a popup's copy keeps each shelf's key, so only an equal key reads it" {
    var store = web_storage.UserAgentStorage.init(testing.allocator);
    defer store.deinit();

    // The opener's tab: its own first-party area, and a third-party frame of
    // the same origin under another page (an earlier page of the tab).
    var opener_first = try web_storage.getSessionStorage(testing.allocator, &store, 1, first_party);
    defer opener_first.deinit();
    try opener_first.setItem("userID", "first");
    var opener_third = try web_storage.getSessionStorage(testing.allocator, &store, 1, third_party);
    defer opener_third.deinit();
    try opener_third.setItem("userID", "third");

    try web_storage.web_storage.cloneSessionStorage(&store, 1, 2);

    // A same-site popup reads its copy of the first-party shelf.
    var popup_first = try web_storage.getSessionStorage(testing.allocator, &store, 2, first_party);
    defer popup_first.deinit();
    try testing.expectEqualStrings("first", popup_first.getItem("userID").?);

    // The origin framed under the popup's other top-level site gets the copy
    // of the shelf with ITS key - here the opener's third-party one - and a
    // key the opener never used starts empty.
    var popup_third = try web_storage.getSessionStorage(testing.allocator, &store, 2, third_party);
    defer popup_third.deinit();
    try testing.expectEqualStrings("third", popup_third.getItem("userID").?);
    var popup_other = try web_storage.getSessionStorage(testing.allocator, &store, 2, StorageKey.initBorrowed(origin, "http://third-site.test", true));
    defer popup_other.deinit();
    try testing.expect(popup_other.getItem("userID") == null);

    // Copies, not shares.
    try popup_first.setItem("userID", "popup");
    try testing.expectEqualStrings("first", opener_first.getItem("userID").?);
}
