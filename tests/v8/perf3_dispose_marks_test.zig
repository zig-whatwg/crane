//! A handle says, on its own V8 node, whether either process-wide map has an
//! entry for it.
//!
//! Every release of a Global (fifty-odd `v8_*_Dispose` sites) consults two
//! maps the process shares: the weak arms (`releaseWeakArm`: `weakDataLock`
//! and `armedWeakData`) and the realm tags (`untagRealmHandle`: `realmTagLock`
//! and `realmTaggedHandles`). perf3's profile put their mutexes, hashes and
//! finds at 13-37% of every perf row (tmp/plans/perf3-design.md 1.3): a
//! release has nothing but the handle, so each one paid both lookups to find,
//! nearly always, nothing. Part 1a marks the handle instead: a flag in the
//! node's wrapper class id (V8's public `PersistentBase::WrapperClassId`, an
//! inline load) set when the entry is made and cleared when it goes, so a
//! release of a handle with no flag skips both maps. Debug builds check the
//! flag against the maps at every release.
//!
//! These tests pin the flag's life: set by an arm or a tag, gone with it;
//! carried by a take's moved node; never confusing the class-id ledger
//! (`live_object_globals`, which reads the low byte); and V8's own reset of
//! a freed node's class id, which a reused node relies on.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

const armed_flag: u16 = 0x8000;
const realm_tagged_flag: u16 = 0x4000;

fn noopFinalizer(_: ?*anyopaque, _: usize) callconv(.c) void {}

var test_agent: test_process.TestAgent = .{};

fn classId(handle: anytype) u16 {
    return ffi.v8_Debug_HandleClassId(@ptrCast(handle));
}

test "a freed global-handle node comes back with a clean class id" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    // A number's Global carries no ledger mark; give it every bit, free it,
    // and make Globals until V8 hands the same node out again (its free list
    // is last-in first-out, so the next one usually is).
    var reused = false;
    for (0..64) |_| {
        const first = ffi.v8_Number_New(isolate, 1.5);
        ffi.v8_Debug_SetHandleClassId(@ptrCast(first), 0x3FFF);
        try testing.expectEqual(@as(u16, 0x3FFF), classId(first));
        const node = ffi.v8_Debug_HandleNode(@ptrCast(first));
        ffi.v8_Global_Dispose(@ptrCast(first));
        const second = ffi.v8_Number_New(isolate, 2.5);
        defer ffi.v8_Global_Dispose(@ptrCast(second));
        if (ffi.v8_Debug_HandleNode(@ptrCast(second)) == node) {
            try testing.expectEqual(@as(u16, 0), classId(second));
            reused = true;
            break;
        }
    }
    try testing.expect(reused);
}

test "an arm sets the flag, and a dispose ends the arm with the ledger exact" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    const records = ffi.v8_Debug_LiveWeakCallbackData();
    const objects = ffi.v8_Debug_LiveObjectGlobals();
    const obj = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    try testing.expectEqual(objects + 1, ffi.v8_Debug_LiveObjectGlobals());
    try testing.expectEqual(@as(u16, 0), classId(obj) & (armed_flag | realm_tagged_flag));
    var user_data: u32 = 7;
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    try testing.expect(classId(obj) & armed_flag != 0);
    try testing.expectEqual(records + 1, ffi.v8_Debug_LiveWeakCallbackData());
    // The ledger reads the kind under the flag: one object, still counted.
    try testing.expectEqual(objects + 1, ffi.v8_Debug_LiveObjectGlobals());
    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(records, ffi.v8_Debug_LiveWeakCallbackData());
    try testing.expectEqual(objects, ffi.v8_Debug_LiveObjectGlobals());
}

test "a disarm clears the flag, a re-arm sets it again, and a dispose released as a Value ends it" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    const records = ffi.v8_Debug_LiveWeakCallbackData();
    const objects = ffi.v8_Debug_LiveObjectGlobals();
    const obj = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    var user_data: u32 = 7;
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    ffi.v8_Global_ClearWeak(@ptrCast(obj));
    try testing.expectEqual(@as(u16, 0), classId(obj) & armed_flag);
    try testing.expectEqual(records, ffi.v8_Debug_LiveWeakCallbackData());
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    try testing.expect(classId(obj) & armed_flag != 0);
    try testing.expectEqual(records + 1, ffi.v8_Debug_LiveWeakCallbackData());
    // The binding releases what it gets as a Value (v8_Global_Dispose).
    ffi.v8_Global_Dispose(@ptrCast(obj));
    try testing.expectEqual(records, ffi.v8_Debug_LiveWeakCallbackData());
    try testing.expectEqual(objects, ffi.v8_Debug_LiveObjectGlobals());
}

test "an armed handle the collector takes leaves no record and an exact ledger" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    const records = ffi.v8_Debug_LiveWeakCallbackData();
    const objects = ffi.v8_Debug_LiveObjectGlobals();
    const scope = ffi.v8_HandleScope_New(isolate);
    const obj = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    var user_data: u32 = 7;
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    try testing.expectEqual(records, ffi.v8_Debug_LiveWeakCallbackData());
    // Reset by the weak callback, which took it out of the ledger.
    try testing.expectEqual(objects, ffi.v8_Debug_LiveObjectGlobals());
    // Empty now, and still its owner's to dispose: no entry, no count.
    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(records, ffi.v8_Debug_LiveWeakCallbackData());
    try testing.expectEqual(objects, ffi.v8_Debug_LiveObjectGlobals());
}

test "a realm tag sets the flag; a dispose, a take and a weakening each end it with the tag" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    const tags = ffi.v8_Debug_RealmTaggedHandleCount();

    // Untagged by its dispose.
    const a = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    ffi.v8_Global_TagRealm(@ptrCast(a), 0x1230);
    try testing.expect(classId(a) & realm_tagged_flag != 0);
    try testing.expect(ffi.v8_Debug_IsRealmTagged(@ptrCast(a)));
    ffi.v8_Global_Dispose(@ptrCast(a));
    try testing.expectEqual(tags, ffi.v8_Debug_RealmTaggedHandleCount());

    // A take moves the node, and the flag with it, to the taker's box.
    const b = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    ffi.v8_Global_TagRealm(@ptrCast(b), 0x1230);
    const taken = ffi.v8_Global_TakeOver(@ptrCast(b)) orelse return error.TakeFailed;
    try testing.expect(ffi.v8_Debug_IsRealmTagged(taken));
    try testing.expect(classId(taken) & realm_tagged_flag != 0);
    ffi.v8_Global_DisposeCallbackValue(@ptrCast(b));
    ffi.v8_Global_Dispose(taken);
    try testing.expectEqual(tags, ffi.v8_Debug_RealmTaggedHandleCount());

    // A weakening takes the tag out and arms the handle instead.
    const records = ffi.v8_Debug_LiveWeakCallbackData();
    const holder = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    defer ffi.v8_Object_Dispose(holder);
    const c = ffi.v8_Object_New(isolate) orelse return error.ObjectCreationFailed;
    ffi.v8_Global_TagRealm(@ptrCast(c), 0x4560);
    const key = "perf3:weakened";
    try testing.expectEqual(@as(c_int, 1), ffi.v8_Object_WeakenTaggedHandles(@ptrCast(holder), 0x4560, key.ptr, @intCast(key.len)));
    try testing.expectEqual(@as(u16, 0), classId(c) & realm_tagged_flag);
    try testing.expect(classId(c) & armed_flag != 0);
    try testing.expectEqual(tags, ffi.v8_Debug_RealmTaggedHandleCount());
    ffi.v8_Object_Dispose(c);
    try testing.expectEqual(records, ffi.v8_Debug_LiveWeakCallbackData());
}
