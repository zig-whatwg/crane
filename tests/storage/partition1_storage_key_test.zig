//! Lane partition1: the storage key carries the top-level site and the
//! has-cross-site-ancestor bit (whatwg/storage PR 182; Chromium
//! blink::StorageKey, Gecko OriginAttributes.partitionKey), and the storage
//! shed keys shelves by all three - so one origin under two top-level sites,
//! or embedded with and without a cross-site ancestor, has two shelves.

const std = @import("std");
const testing = std.testing;
const storage = @import("storage");

const StorageKey = storage.StorageKey;
const UserAgentStorage = storage.UserAgentStorage;

const origin = "https://web-platform.test:8443";
const first_party = StorageKey.initBorrowed(origin, "https://web-platform.test", false);
const third_party = StorageKey.initBorrowed(origin, "https://not-web-platform.test", true);
/// A-in-B-in-A: the top-level site is the origin's own, but an ancestor is
/// cross-site (Chromium kCrossSite ancestor chain bit, Gecko's "f").
const aba = StorageKey.initBorrowed(origin, "https://web-platform.test", true);

test "storage keys are equal only when the origin, the top-level site and the ancestor bit are" {
    try testing.expect(first_party.equals(StorageKey.initBorrowed(origin, "https://web-platform.test", false)));
    try testing.expect(!first_party.equals(third_party));
    try testing.expect(!first_party.equals(aba));
    try testing.expect(!first_party.equals(StorageKey.initBorrowed("https://www1.web-platform.test:8443", "https://web-platform.test", false)));
    try testing.expect(first_party.hash() != third_party.hash());
    try testing.expect(first_party.hash() != aba.hash());
}

test "an owned storage key copies its parts and frees them" {
    var key = try StorageKey.init(testing.allocator, origin, "https://not-web-platform.test", true);
    defer key.deinit();
    try testing.expect(key.equals(third_party));
    var copy = try key.clone(testing.allocator);
    defer copy.deinit();
    try testing.expect(copy.equals(key));
    try testing.expect(copy.origin.ptr != key.origin.ptr);
}

test "a storage key's serialization is canonical: equal keys, equal bytes; parsed back, the same key" {
    const bytes = try third_party.serialize(testing.allocator);
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("https://web-platform.test:8443 https://not-web-platform.test 1", bytes);
    const parsed = StorageKey.parse(bytes) orelse return error.TestUnexpectedNull;
    try testing.expect(parsed.equals(third_party));

    const first = try first_party.serialize(testing.allocator);
    defer testing.allocator.free(first);
    try testing.expectEqualStrings("https://web-platform.test:8443 https://web-platform.test 0", first);

    try testing.expect(StorageKey.parse("https://a.test") == null);
    try testing.expect(StorageKey.parse("https://a.test https://a.test 2") == null);
    try testing.expect(StorageKey.parse("https://a.test https://a.test 0 extra") == null);
}

test "obtain a storage key: failure for an opaque origin, and for an opaque top-level site Crane cannot tell apart" {
    try testing.expect(storage.obtainStorageKey(first_party) != null);
    try testing.expect(storage.obtainStorageKey(StorageKey.initBorrowed("null", "https://web-platform.test", true)) == null);
    try testing.expect(storage.obtainStorageKey(StorageKey.initBorrowed(origin, "null", true)) == null);
    try testing.expect(storage.obtainStorageKey(StorageKey.initBorrowed("", "", false)) == null);
}

test "a storage shed holds one shelf per storage key: one origin, two partitions, two shelves" {
    var shed = storage.StorageShed.init(testing.allocator, .local);
    defer shed.deinit();
    const a = try shed.obtainShelf(first_party);
    const b = try shed.obtainShelf(third_party);
    const c = try shed.obtainShelf(aba);
    try testing.expect(a != b and a != c and b != c);
    try testing.expect(a == try shed.obtainShelf(StorageKey.initBorrowed(origin, "https://web-platform.test", false)));
    try testing.expectEqual(@as(usize, 3), shed.count());
}

test "local storage bottle maps of one origin under two top-level sites share nothing" {
    var user_agent_storage = UserAgentStorage.init(testing.allocator);
    defer user_agent_storage.deinit();

    const first = (try storage.obtainLocalStorageBottleMap(&user_agent_storage, first_party, .localStorage)) orelse return error.TestUnexpectedNull;
    try first.set("userID", "first-party");
    const third = (try storage.obtainLocalStorageBottleMap(&user_agent_storage, third_party, .localStorage)) orelse return error.TestUnexpectedNull;
    try testing.expect(third.get("userID") == null);
    try third.set("userID", "third-party");
    const again = (try storage.obtainLocalStorageBottleMap(&user_agent_storage, first_party, .localStorage)) orelse return error.TestUnexpectedNull;
    try testing.expectEqualStrings("first-party", again.get("userID").?);

    // Failure for a key "obtain a storage key" fails.
    try testing.expect(try storage.obtainLocalStorageBottleMap(&user_agent_storage, StorageKey.initBorrowed("null", "https://web-platform.test", true), .localStorage) == null);
}

test "session storage: each top-level traversable has a shed of its own, keyed by storage key" {
    var user_agent_storage = UserAgentStorage.init(testing.allocator);
    defer user_agent_storage.deinit();

    const tab_one = (try storage.obtainSessionStorageBottleMap(&user_agent_storage, 1, first_party, .sessionStorage)) orelse return error.TestUnexpectedNull;
    try tab_one.set("k", "one");
    const tab_one_third = (try storage.obtainSessionStorageBottleMap(&user_agent_storage, 1, third_party, .sessionStorage)) orelse return error.TestUnexpectedNull;
    try testing.expect(tab_one_third.get("k") == null);
    const tab_two = (try storage.obtainSessionStorageBottleMap(&user_agent_storage, 2, first_party, .sessionStorage)) orelse return error.TestUnexpectedNull;
    try testing.expect(tab_two.get("k") == null);
    // The local shed holds none of it.
    const local = (try storage.obtainLocalStorageBottleMap(&user_agent_storage, first_party, .localStorage)) orelse return error.TestUnexpectedNull;
    try testing.expect(local.get("k") == null);
}
