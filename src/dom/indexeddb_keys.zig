//! IndexedDB ED 7.3-7.4: engine-neutral key conversions.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const storage = @import("storage");
const Key = storage.indexeddb.IDBKey;
pub const Result = union(enum) { key: Key, invalid_value, invalid_type };
const Seen = struct {
    allocator: std.mem.Allocator,
    values: std.ArrayList(engine.Owned) = .empty,
    fn deinit(self: *Seen) void {
        for (self.values.items) |value| value.release();
        self.values.deinit(self.allocator);
    }
    fn add(self: *Seen, realm: runtime.Context, value: runtime.JSValue) engine.Error!void {
        const root = try engine.retainValue(realm, value);
        errdefer root.release();
        try self.values.append(self.allocator, root);
    }
};

pub fn convert(realm: runtime.Context, input: runtime.JSValue, allocator: std.mem.Allocator) engine.Error!Result {
    // Step 1: new seen set. Its temporary roots last for the whole conversion.
    var seen = Seen{ .allocator = allocator };
    defer seen.deinit();
    return convertSeen(realm, input, &seen);
}
pub fn require(realm: runtime.Context, input: runtime.JSValue, allocator: std.mem.Allocator) !Key {
    return switch (try convert(realm, input, allocator)) {
        .key => |key| key,
        else => error.DataError,
    };
}
fn convertSeen(realm: runtime.Context, input: runtime.JSValue, seen: *Seen) engine.Error!Result {
    // Step 2: seen is never popped; repeated nested arrays are invalid too.
    for (seen.values.items) |value| if (engine.sameValue(realm, input, value.value)) return .invalid_value;
    // Step 3, Number.
    if (engine.typeOf(realm, input) == .number) {
        const number = try engine.convertToUnrestrictedDouble(realm, input);
        return if (std.math.isNan(number)) .invalid_value else .{ .key = Key.number(number) };
    }
    // Step 3, Date: read the internal slot, never a user-overridden valueOf.
    if (thisTimeValue(realm, input)) |time| {
        return if (std.math.isNan(time)) .invalid_value else .{ .key = Key.date(@intFromFloat(time)) };
    }
    if (engine.typeOf(realm, input) == .string) {
        const bytes = try engine.convertToDOMString(realm, input, seen.allocator);
        return .{ .key = .{ .key_type = .string, .value = .{ .string = bytes }, .allocator = seen.allocator } };
    }
    // Step 3, buffer source: reject a detached ArrayBuffer before copying.
    // For a view, step 1 applies to its viewed ArrayBuffer.
    if (engine.describeArrayBufferView(realm, input)) |_| {
        const buffer = try engine.getViewedArrayBuffer(realm, input);
        defer buffer.release();
        if (engine.isDetachedBuffer(realm, buffer.value)) return .invalid_value;
    } else if (engine.isDetachedBuffer(realm, input)) return .invalid_value;
    if (try copyBufferSourceBytes(realm, input, seen.allocator)) |bytes| {
        return .{ .key = .{ .key_type = .binary, .value = .{ .binary = bytes }, .allocator = seen.allocator } };
    }
    if (!isArrayExoticObject(realm, input)) return .invalid_type;
    // Array steps 1-6.
    const length = try arrayLength(realm, input);
    try seen.add(realm, input);
    var keys: std.ArrayList(Key) = .empty;
    defer {
        for (keys.items) |*key| key.deinit();
        keys.deinit(seen.allocator);
    }
    var index: u64 = 0;
    while (index < length) : (index += 1) {
        var name: [24]u8 = undefined;
        const property = std.fmt.bufPrint(&name, "{d}", .{index}) catch unreachable;
        if (!try hasOwnProperty(realm, input, property)) return .invalid_value;
        const entry = try engine.getProperty(realm, input, property);
        defer entry.release();
        switch (try convertSeen(realm, entry.value, seen)) {
            .key => |key| {
                var owned = key;
                errdefer owned.deinit();
                try keys.append(seen.allocator, owned);
            },
            else => return .invalid_value,
        }
    }
    return .{ .key = .{ .key_type = .array, .value = .{ .array = try keys.toOwnedSlice(seen.allocator) }, .allocator = seen.allocator } };
}
fn arrayLength(realm: runtime.Context, input: runtime.JSValue) engine.Error!u64 {
    const value = try engine.getProperty(realm, input, "length");
    defer value.release();
    const number = try engine.convertToUnrestrictedDouble(realm, value.value);
    if (std.math.isNan(number) or number <= 0) return 0;
    return @intFromFloat(@min(@floor(number), 9007199254740991));
}

pub fn multiEntry(realm: runtime.Context, input: runtime.JSValue, allocator: std.mem.Allocator) engine.Error!Result {
    if (!isArrayExoticObject(realm, input)) return convert(realm, input, allocator);
    // Steps 1.1-1.4: length failures propagate, and seen begins with input.
    const length = try arrayLength(realm, input);
    var seen = Seen{ .allocator = allocator };
    defer seen.deinit();
    try seen.add(realm, input);
    var keys: std.ArrayList(Key) = .empty;
    defer {
        for (keys.items) |*key| key.deinit();
        keys.deinit(allocator);
    }
    var index: u64 = 0;
    while (index < length) : (index += 1) {
        var name: [24]u8 = undefined;
        const property = std.fmt.bufPrint(&name, "{d}", .{index}) catch unreachable;
        var entry = EntryConversion{ .realm = realm, .input = input, .property = property, .seen = &seen };
        // Steps 1.5.1-2: consume an abrupt Get OR recursive conversion.
        if (try engine.completionOf(realm, EntryConversion.steps, &entry)) |thrown| {
            thrown.release();
            continue;
        }
        if (entry.result == .key) {
            var key = entry.result.key;
            defer key.deinit();
            var duplicate = false;
            for (keys.items) |existing| if (storage.indexeddb.compareKeys(existing, key) == 0) {
                duplicate = true;
                break;
            };
            if (!duplicate) {
                var copy = try key.clone(allocator);
                errdefer copy.deinit();
                try keys.append(allocator, copy);
            }
        }
    }
    return .{ .key = .{ .key_type = .array, .value = .{ .array = try keys.toOwnedSlice(allocator) }, .allocator = allocator } };
}
const EntryConversion = struct {
    realm: runtime.Context,
    input: runtime.JSValue,
    property: []const u8,
    seen: *Seen,
    result: Result = .invalid_value,
    fn steps(data: ?*anyopaque) engine.Error!void {
        const self: *EntryConversion = @ptrCast(@alignCast(data.?));
        const value = try engine.getProperty(self.realm, self.input, self.property);
        defer value.release();
        self.result = try convertSeen(self.realm, value.value, self.seen);
    }
};

pub fn toValue(realm: runtime.Context, key: Key) engine.Error!engine.Owned {
    // ED 7.3 steps 1-3: built-in constructors in the target realm.
    return switch (key.key_type) {
        .number => engine.retainValue(realm, .{ .number = key.value.number }),
        .string => engine.retainValue(realm, runtime.JSValue.fromStringRef(key.value.string)),
        .date => createDate(realm, @floatFromInt(key.value.date)),
        .binary => engine.createArrayBuffer(realm, key.value.binary),
        .array => arrayValue(realm, key.value.array),
    };
}
fn arrayValue(realm: runtime.Context, keys: []const Key) engine.Error!engine.Owned {
    const values = try realm.allocator.alloc(runtime.JSValue, keys.len);
    defer realm.allocator.free(values);
    var made: usize = 0;
    defer for (values[0..made]) |value| (engine.Owned{ .value = value }).release();
    for (keys, 0..) |key, index| {
        values[index] = (try toValue(realm, key)).take();
        made += 1;
    }
    return engine.createSequenceOfValues(realm, values);
}

// Q3 accepted interims until ADAPTER CONVERSIONS ON MAIN: each missing
// protocol concept has exactly one helper. Date/Array tests remain red.
fn thisTimeValue(realm: runtime.Context, value: runtime.JSValue) ?f64 {
    _ = realm;
    _ = value;
    return null;
}
fn isArrayExoticObject(realm: runtime.Context, value: runtime.JSValue) bool {
    _ = realm;
    _ = value;
    return false;
}
fn hasOwnProperty(realm: runtime.Context, object: runtime.JSValue, property: []const u8) engine.Error!bool {
    _ = realm;
    _ = object;
    _ = property;
    return error.NotSupported;
}
fn createDate(realm: runtime.Context, time: f64) engine.Error!engine.Owned {
    _ = realm;
    _ = time;
    return error.NotSupported;
}

pub const Path = struct {
    allocator: std.mem.Allocator,
    value: storage.indexeddb.KeyPath,
    pub fn deinit(self: *Path) void {
        switch (self.value) {
            .single => |path| self.allocator.free(path),
            .array => |paths| {
                for (paths) |path| self.allocator.free(path);
                self.allocator.free(paths);
            },
        }
    }
};
pub fn keyPath(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) !Path {
    // WebIDL's string/sequence union: object iterables select sequence.
    if (engine.typeOf(realm, value) == .object) {
        if (try engine.convertToSequenceOfDOMStrings(realm, value, allocator)) |paths| {
            errdefer {
                for (paths) |path| allocator.free(path);
                allocator.free(paths);
            }
            return .{ .allocator = allocator, .value = .{ .array = paths } };
        }
    }
    const path = try engine.convertToDOMString(realm, value, allocator);
    errdefer allocator.free(path);
    return .{ .allocator = allocator, .value = .{ .single = path } };
}

/// ED 4.5/4.6 keyPath: each handle keeps one mutable Array for a list path.
pub fn keyPathValue(owner: *runtime.Instance, path: ?storage.indexeddb.KeyPath) !runtime.JSValue {
    const actual = path orelse return .jsNull;
    if (actual == .single) return runtime.JSValue.fromStringRef(actual.single);
    const slot: engine.TracedSlot = .{ .name = "idb.keyPath" };
    if (engine.tracedValue(owner, slot)) |value| return value.take();
    const values = try owner.ctx.allocator.alloc(runtime.JSValue, actual.array.len);
    defer owner.ctx.allocator.free(values);
    for (actual.array, 0..) |part, index| values[index] = runtime.JSValue.fromStringRef(part);
    const result = try engine.createSequenceOfValues(owner.ctx, values);
    engine.traceValue(owner, result.value, slot);
    return result.take();
}

/// ED 7.1: only run on StructuredDeserialize's output, never the original value.
pub fn evaluatePath(realm: runtime.Context, value: runtime.JSValue, path: storage.indexeddb.KeyPath) anyerror!?engine.Owned {
    if (path == .array) {
        // Steps 1.1-4: evaluate every scalar member into a new Array.
        const values = try realm.allocator.alloc(runtime.JSValue, path.array.len);
        defer realm.allocator.free(values);
        var made: usize = 0;
        defer for (values[0..made]) |entry| (engine.Owned{ .value = entry }).release();
        for (path.array, 0..) |member, index| {
            const entry = try evaluatePath(realm, value, .{ .single = member }) orelse return null;
            values[index] = entry.take();
            made += 1;
        }
        return try engine.createSequenceOfValues(realm, values);
    }
    // Steps 2-3: empty path is the whole value; otherwise strictly split.
    var current = try engine.retainValue(realm, value);
    errdefer current.release();
    if (path.single.len == 0) return current;
    var identifiers = std.mem.splitScalar(u8, path.single, '.');
    while (identifiers.next()) |identifier| {
        const next = try pathMember(realm, current.value, identifier) orelse {
            current.release();
            return null;
        };
        current.release();
        current = next;
    }
    return current;
}
fn pathMember(realm: runtime.Context, value: runtime.JSValue, identifier: []const u8) anyerror!?engine.Owned {
    // Step 4's String, Array, Blob and File intrinsic property cases.
    if (engine.typeOf(realm, value) == .string and std.mem.eql(u8, identifier, "length")) {
        const string = try engine.convertToDOMString(realm, value, realm.allocator);
        defer realm.allocator.free(string);
        var points = std.unicode.Wtf8View.initUnchecked(string).iterator();
        var length: usize = 0;
        while (points.nextCodepoint()) |point| length += if (point > 0xffff) @as(usize, 2) else 1;
        return try engine.retainValue(realm, .{ .number = @floatFromInt(length) });
    }
    if (isArrayExoticObject(realm, value) and std.mem.eql(u8, identifier, "length")) {
        return try engine.retainValue(realm, .{ .number = @floatFromInt(try arrayLength(realm, value)) });
    }
    const interfaces = @import("interfaces");
    if (engine.convertToPlatformObject(realm, value)) |instance| {
        if (instance.stateAs(interfaces.File.State) != null) {
            if (std.mem.eql(u8, identifier, "name")) {
                var name = try interfaces.File.get_name(instance);
                defer name.deinit(instance.ctx.allocator);
                return try engine.retainValue(realm, runtime.JSValue.fromStringRef(name.asSlice()));
            }
            if (std.mem.eql(u8, identifier, "lastModified")) return try engine.retainValue(realm, .{ .number = @floatFromInt(try interfaces.File.get_lastModified(instance)) });
        }
        if (instance.stateAs(interfaces.Blob.State) != null) {
            if (std.mem.eql(u8, identifier, "size")) return try engine.retainValue(realm, .{ .number = @floatFromInt(try interfaces.Blob.get_size(instance)) });
            if (std.mem.eql(u8, identifier, "type")) {
                var name = try interfaces.Blob.get_type(instance);
                defer name.deinit(instance.ctx.allocator);
                return try engine.retainValue(realm, runtime.JSValue.fromStringRef(name.asSlice()));
            }
        }
    }
    // Otherwise steps 1-5: own properties only; undefined is failure.
    if (engine.typeOf(realm, value) != .object or !try hasOwnProperty(realm, value, identifier)) return null;
    const property = try engine.getProperty(realm, value, identifier);
    if (engine.typeOf(realm, property.value) == .undefined) {
        property.release();
        return null;
    }
    return property;
}

pub const Extraction = union(enum) { key: Key, invalid, failure };
pub fn extract(realm: runtime.Context, value: runtime.JSValue, path: storage.indexeddb.KeyPath, multi_entry: bool, allocator: std.mem.Allocator) anyerror!Extraction {
    // 7.1 steps 1-5: propagate throws; distinguish missing path from invalid key.
    const entry = try evaluatePath(realm, value, path) orelse return .failure;
    defer entry.release();
    return switch (if (multi_entry) try multiEntry(realm, entry.value, allocator) else try convert(realm, entry.value, allocator)) {
        .key => |key| .{ .key = key },
        else => .invalid,
    };
}

pub fn canInject(realm: runtime.Context, value: runtime.JSValue, path: []const u8) engine.Error!bool {
    var current = try engine.retainValue(realm, value);
    defer current.release();
    var identifiers = std.mem.splitScalar(u8, path, '.');
    var identifier = identifiers.next().?;
    // 7.2 steps 1-4: ignore last component, stop at first missing intermediate.
    while (identifiers.next()) |next| {
        if (engine.typeOf(realm, current.value) != .object) return false;
        if (!try hasOwnProperty(realm, current.value, identifier)) return true;
        const child = try engine.getProperty(realm, current.value, identifier);
        current.release();
        current = child;
        identifier = next;
    }
    return engine.typeOf(realm, current.value) == .object;
}
pub fn inject(realm: runtime.Context, value: runtime.JSValue, key: Key, path: []const u8) engine.Error!void {
    var current = try engine.retainValue(realm, value);
    defer current.release();
    var identifiers = std.mem.splitScalar(u8, path, '.');
    var identifier = identifiers.next().?;
    // 7.2 steps 1-4: create absent intermediate objects with data properties.
    while (identifiers.next()) |next| {
        if (!try hasOwnProperty(realm, current.value, identifier)) {
            const object = try engine.createDictionaryObject(realm, &.{});
            defer object.release();
            try engine.defineOwnProperty(realm, current.value, identifier, object.value, .{ .writable = true, .enumerable = true, .configurable = true });
        }
        const child = try engine.getProperty(realm, current.value, identifier);
        current.release();
        current = child;
        identifier = next;
    }
    // Steps 5-8: caller proved injection possible on the deserialized value.
    const converted = try toValue(realm, key);
    defer converted.release();
    try engine.defineOwnProperty(realm, current.value, identifier, converted.value, .{ .writable = true, .enumerable = true, .configurable = true });
}

/// ED convert a value to a key range: range instances are copied through
/// their owning hook; ordinary values become an owned single-key range.
pub fn queryRange(realm: runtime.Context, value: runtime.JSValue, allow_unbounded: bool, allocator: std.mem.Allocator) !storage.indexeddb.IDBKeyRange {
    if (value.isNullOrUndefined()) {
        if (!allow_unbounded) return error.DataError;
        return storage.indexeddb.IDBKeyRange.unbounded();
    }
    if (engine.convertToPlatformObject(realm, value)) |instance| {
        if (instance.stateAs(@import("interfaces").IDBKeyRange.State) != null) return @import("indexeddb.zig").copyKeyRange(instance, allocator);
    }
    var key = try require(realm, value, allocator);
    errdefer key.deinit();
    const upper = try key.clone(allocator);
    return .{ .lower = key, .upper = upper, .lower_open = false, .upper_open = false, .allocator = allocator };
}

// Interim non-[AllowShared] copy, pending the integrator's adapter merge signal.
// Shared keys stay red until the AllowSharedBufferSource operation is available.
fn copyBufferSourceBytes(realm: runtime.Context, input: runtime.JSValue, allocator: std.mem.Allocator) engine.Error!?[]u8 {
    return engine.getCopyOfBufferSourceBytes(realm, input, allocator);
}

pub fn cursorDirection(direction: anytype) storage.indexeddb.IDBCursorDirection {
    return switch (direction) {
        ._next_ => .next,
        ._nextunique_ => .nextunique,
        ._prev_ => .prev,
        ._prevunique_ => .prevunique,
    };
}

/// ED 5.12: select the range form or convert the options dictionary, after
/// the owning handle has checked deletion and transaction state.
pub fn multipleItems(realm: runtime.Context, kind: @import("indexeddb.zig").OperationKind, query_or_options: runtime.JSValue, count: ?u32, allocator: std.mem.Allocator) !@import("indexeddb.zig").Operation {
    var operation = @import("indexeddb.zig").Operation{ .allocator = allocator, .kind = kind, .limit = count };
    errdefer operation.deinit();
    var range_form = false;
    if (engine.convertToPlatformObject(realm, query_or_options)) |object| {
        range_form = object.stateAs(@import("interfaces").IDBKeyRange.State) != null;
    }
    if (!range_form and !query_or_options.isNullOrUndefined()) {
        var converted = try convert(realm, query_or_options, allocator);
        range_form = converted != .invalid_type;
        if (converted == .key) converted.key.deinit();
    }
    if (range_form) {
        operation.range = try queryRange(realm, query_or_options, true, allocator);
        return operation;
    }
    // WebIDL dictionary members convert in lexical order: count, direction,
    // query. Null and undefined mean an empty dictionary.
    if (query_or_options.isNullOrUndefined()) return operation;
    if (engine.typeOf(realm, query_or_options) != .object) return error.TypeError;
    const count_value = try engine.getProperty(realm, query_or_options, "count");
    defer count_value.release();
    operation.limit = null;
    if (!count_value.value.isUndefined()) {
        const number = try engine.convertToUnrestrictedDouble(realm, count_value.value);
        const integer = @trunc(number);
        if (!std.math.isFinite(number) or integer < 0 or integer > 4294967295) return error.TypeError;
        operation.limit = @intFromFloat(integer);
    }
    const direction_value = try engine.getProperty(realm, query_or_options, "direction");
    defer direction_value.release();
    if (!direction_value.value.isUndefined()) {
        const direction = try engine.convertToDOMString(realm, direction_value.value, allocator);
        defer allocator.free(direction);
        operation.direction = if (std.mem.eql(u8, direction, "next")) .next else if (std.mem.eql(u8, direction, "nextunique")) .nextunique else if (std.mem.eql(u8, direction, "prev")) .prev else if (std.mem.eql(u8, direction, "prevunique")) .prevunique else return error.TypeError;
    }
    const query = try engine.getProperty(realm, query_or_options, "query");
    defer query.release();
    operation.range = try queryRange(realm, query.value, true, allocator);
    return operation;
}
