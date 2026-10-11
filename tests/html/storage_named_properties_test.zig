//! HTML 12.2.1 Storage is a legacy platform object (WebIDL 3.9) whose named
//! property getter, setter and deleter are `getItem`, `setItem` and
//! `removeItem`, and whose supported property names are its map's keys. The
//! binding found named properties by function name and knew none of these,
//! so `localStorage[k] = v` made an ordinary property, the map stayed empty
//! and `length` 0 (webstorage/: 1,176 subtests not passing). It binds them
//! from codegen's Meta.special_operations now.
//!
//! Each test drives a Browser's page through script - the values the
//! binding makes - on a thread of its own (a Browser's per-thread state).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://so-storage.test/page.html";

fn onThread(comptime function: anytype, args: anytype) !void {
    const Run = struct {
        fn run(failure: *?anyerror, call_args: @TypeOf(args)) void {
            @call(.auto, function, call_args) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ &failure, args });
    thread.join();
    if (failure) |err| return err;
}

/// A Browser showing a page of the test's origin (no network: its markup is
/// given), with an empty localStorage.
fn openPage() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    return browser;
}

/// Run `body` - script ending in `problems`, an array of what went wrong -
/// against both storage areas, and fail with every problem printed.
fn expectStorage(comptime body: []const u8) !void {
    const browser = try openPage();
    defer browser.deinit();
    const source =
        \\(() => {
        \\  const problems = [];
        \\  const check = (what, got, want) => { if (got !== want) problems.push(what + ': ' + String(got)); };
        \\  const throwsTypeError = (f) => { try { f(); return false; } catch (e) { return e instanceof TypeError; } };
        \\  for (const name of ['localStorage', 'sessionStorage']) {
        \\    const storage = window[name];
        \\    storage.clear();
        \\    const at = (what) => name + ' ' + what;
        \\
    ++ body ++
        \\
        \\  }
        \\  return problems.length ? problems.join('; ') : 'ok';
        \\})()
    ;
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const got = try engine.convertToDOMString(realm, held.borrow(), testing.allocator);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("ok", got);
}

fn namedGetter() !void {
    try expectStorage(
        \\    storage.setItem('k', 'v');
        \\    check(at('storage.k'), storage.k, 'v');
        \\    check(at("storage['k']"), storage['k'], 'v');
        \\    check(at('in'), 'k' in storage, true);
        \\    check(at('missing'), storage.missing, undefined);
        \\    check(at('missing in'), 'missing' in storage, false);
        \\    check(at('Object.keys'), Object.keys(storage).join(), 'k');
        \\    const desc = Object.getOwnPropertyDescriptor(storage, 'k');
        \\    check(at('desc'), desc !== undefined, true);
        \\    if (desc) {
        \\      check(at('desc.value'), desc.value, 'v');
        \\      check(at('desc.writable'), desc.writable, true);
        \\      check(at('desc.enumerable'), desc.enumerable, true);
        \\      check(at('desc.configurable'), desc.configurable, true);
        \\    }
        \\    // A prototype member hides a key of its name (the named property
        \\    // visibility algorithm), and is no enumerable own key.
        \\    storage.setItem('key', 'not a function');
        \\    check(at('key is the method'), typeof storage.key, 'function');
        \\    check(at('keys without key'), Object.keys(storage).sort().join(), 'k');
    );
}

test "Storage: a key is a named property - get, in, keys and its descriptor" {
    try onThread(namedGetter, .{});
}

fn namedSetter() !void {
    try expectStorage(
        \\    storage.name = 'user1';
        \\    check(at('getItem'), storage.getItem('name'), 'user1');
        \\    check(at('length'), storage.length, 1);
        \\    storage['name'] = 'user2';
        \\    check(at('replaced'), storage.getItem('name'), 'user2');
        \\    check(at('one key'), storage.length, 1);
        \\    storage.age = null;
        \\    check(at('null'), storage.getItem('age'), 'null');
        \\    // [[Set]] step 1.2: a builtin's name is a key too; the builtin stays.
        \\    storage.key = 'key';
        \\    check(at('builtin key'), storage.getItem('key'), 'key');
        \\    check(at('builtin kept'), typeof storage.key, 'function');
        \\    check(at('no own property'), Object.getOwnPropertyNames(storage).indexOf('key'), -1);
        \\    // [[DefineOwnProperty]] step 2.2.2: a data descriptor's value is set.
        \\    check(at('defineProperty'), Object.defineProperty(storage, 'x', { value: 'value' }), storage);
        \\    check(at('defined'), storage.getItem('x'), 'value');
        \\    Object.defineProperty(storage, 'x', { value: { toString() { return 'new'; } } });
        \\    check(at('redefined'), storage.getItem('x'), 'new');
        \\    check(at('accessor throws'), throwsTypeError(() => Object.defineProperty(storage, 'y', { get() { return 1; } })), true);
        \\    check(at('no accessor key'), storage.getItem('y'), null);
        \\    // Receiver another object: an ordinary property of it.
        \\    const heir = Object.create(storage);
        \\    heir.own = 'mine';
        \\    check(at('heir own'), Object.getOwnPropertyDescriptor(heir, 'own').value, 'mine');
        \\    check(at('heir set no key'), storage.getItem('own'), null);
    );
}

test "Storage: assigning or defining a named property is setItem" {
    try onThread(namedSetter, .{});
}

fn namedDeleter() !void {
    try expectStorage(
        \\    storage.setItem('gone', '1');
        \\    check(at('delete'), delete storage.gone, true);
        \\    check(at('removed'), storage.getItem('gone'), null);
        \\    check(at('length'), storage.length, 0);
        \\    check(at('delete missing'), delete storage.never, true);
        \\    storage.setItem('key', 'k');
        \\    // A key a builtin hides is not visible: delete leaves it (3.9.4 step 3).
        \\    check(at('delete hidden'), delete storage.key, true);
        \\    check(at('hidden kept'), storage.getItem('key'), 'k');
    );
}

test "Storage: deleting a named property is removeItem" {
    try onThread(namedDeleter, .{});
}

fn indexKeys() !void {
    try expectStorage(
        \\    storage[42] = 'beta';
        \\    check(at('getItem'), storage.getItem('42'), 'beta');
        \\    check(at('read'), storage[42], 'beta');
        \\    check(at('in'), 42 in storage, true);
        \\    storage.setItem(0, 'alpha');
        \\    check(at('setItem(0)'), storage[0], 'alpha');
        \\    check(at('keys'), Object.keys(storage).sort().join(), '0,42');
        \\    Object.defineProperty(storage, 9, { value: 'nine' });
        \\    check(at('defineProperty 9'), storage.getItem('9'), 'nine');
        \\    check(at('delete'), delete storage[42], true);
        \\    check(at('deleted'), storage.getItem('42'), null);
        \\    check(at('no own element'), Object.getOwnPropertyNames(storage).sort().join(), '0,9');
    );
}

test "Storage: an array index is a key like any other string" {
    try onThread(indexKeys, .{});
}

fn keyText() !void {
    try expectStorage(
        \\    const long = 'k'.repeat(300);
        \\    storage[long] = 'v';
        \\    check(at('long'), storage.getItem(long), 'v');
        \\    check(at('long read'), storage[long], 'v');
        \\    for (const key of ['\uD800', 'a\uDF4D', '🍍', 'é']) {
        \\      storage[key] = key;
        \\      check(at('key ' + escape(key)), storage.getItem(key), key);
        \\      check(at('read ' + escape(key)), storage[key], key);
        \\    }
        \\    check(at('empty key'), (storage[''] = 'e', storage.getItem('')), 'e');
        \\    check(at('empty read'), storage[''], 'e');
    );
}

test "Storage: a key keeps its text - long, with lone surrogates, or empty" {
    try onThread(keyText, .{});
}
