//! A database's schema as its backing store keeps it (backing_store.zig;
//! lane prof1, D6 step 4): the database record - its version and its next
//! object store id - and one record per object store - its name, key path,
//! key generator, and its indexes' definitions - which the server reads
//! back into a database's in-memory schema (Chromium keeps the same pieces
//! as IndexedDBDatabaseMetadata / IndexedDBObjectStoreMetadata /
//! IndexedDBIndexMetadata, written under its DatabaseMetaDataKey and
//! ObjectStoreMetaDataKey). Records and index entries are never here.

const std = @import("std");
const Allocator = std.mem.Allocator;
const database_mod = @import("database.zig");
const IDBDatabase = database_mod.IDBDatabase;
const ObjectStoreMetadata = database_mod.ObjectStoreMetadata;
const RecordData = @import("object_store.zig").RecordData;
const IndexData = @import("index.zig").IndexData;
const key_path_mod = @import("key_path.zig");
const backing_store = @import("backing_store.zig");
const Reader = backing_store.Reader;

const record_version: u8 = 1;

fn appendU32(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, value: u32) Allocator.Error!void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .big);
    try out.appendSlice(allocator, &bytes);
}

fn appendString(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, text: []const u8) Allocator.Error!void {
    try appendU32(out, allocator, @intCast(text.len));
    try out.appendSlice(allocator, text);
}

fn readString(reader: *Reader) error{Corrupt}![]const u8 {
    return reader.take(try reader.u32Be());
}

fn appendKeyPath(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, single: ?[]const u8, compound: ?[]const []const u8) Allocator.Error!void {
    if (compound) |paths| {
        try out.append(allocator, 2);
        try appendU32(out, allocator, @intCast(paths.len));
        for (paths) |path| try appendString(out, allocator, path);
    } else if (single) |path| {
        try out.append(allocator, 1);
        try appendString(out, allocator, path);
    } else try out.append(allocator, 0);
}

/// A key path read back: borrowed from the record's bytes.
const ReadPath = struct {
    single: ?[]const u8 = null,
    compound: ?[]const []const u8 = null,
    /// The compound list's slice of slices, made with the decode's allocator.
    list: ?[][]const u8 = null,

    fn deinit(self: *ReadPath, allocator: Allocator) void {
        if (self.list) |list| allocator.free(list);
    }
};

fn readKeyPath(reader: *Reader, allocator: Allocator) (error{Corrupt} || Allocator.Error)!ReadPath {
    switch (try reader.byte()) {
        0 => return .{},
        1 => return .{ .single = try readString(reader) },
        2 => {
            const count = try reader.u32Be();
            if (count > reader.bytes.len) return error.Corrupt;
            const list = try allocator.alloc([]const u8, count);
            errdefer allocator.free(list);
            for (list) |*path| path.* = try readString(reader);
            return .{ .compound = list, .list = list };
        },
        else => return error.Corrupt,
    }
}

/// The database record: version, next object store id.
pub fn encodeDatabase(allocator: Allocator, version: u64, next_store_id: u64) Allocator.Error![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, record_version);
    try backing_store.appendU64(&out, allocator, version);
    try backing_store.appendU64(&out, allocator, next_store_id);
    return out.toOwnedSlice(allocator);
}

pub const DatabaseRecord = struct { version: u64, next_store_id: u64 };

pub fn decodeDatabase(bytes: []const u8) error{Corrupt}!DatabaseRecord {
    var reader: Reader = .{ .bytes = bytes };
    if (try reader.byte() != record_version) return error.Corrupt;
    const version = try reader.u64Be();
    const next_store_id = try reader.u64Be();
    if (!reader.done()) return error.Corrupt;
    return .{ .version = version, .next_store_id = next_store_id };
}

/// An object store's schema record.
pub fn encodeStore(allocator: Allocator, metadata: *const ObjectStoreMetadata) Allocator.Error![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    const data = metadata.record_data;
    try out.append(allocator, record_version);
    try appendString(&out, allocator, metadata.name);
    try appendKeyPath(&out, allocator, metadata.key_path, metadata.compound_key_path);
    try out.append(allocator, @intFromBool(metadata.auto_increment));
    try backing_store.appendU64(&out, allocator, data.key_generator);
    try backing_store.appendU64(&out, allocator, data.next_index_id);
    try appendU32(&out, allocator, @intCast(metadata.index_names.items.len));
    for (metadata.index_names.items) |name| try appendString(&out, allocator, name);
    try appendU32(&out, allocator, @intCast(data.indexes.count()));
    var indexes = data.indexes.valueIterator();
    while (indexes.next()) |index| {
        try backing_store.appendU64(&out, allocator, index.*.definition_id);
        try appendString(&out, allocator, index.*.name);
        try appendKeyPath(&out, allocator, index.*.key_path, index.*.compound_key_path);
        try out.append(allocator, @intFromBool(index.*.unique));
        try out.append(allocator, @intFromBool(index.*.multi_entry));
    }
    return out.toOwnedSlice(allocator);
}

/// The object store `definition_id`'s schema, read back into `database`'s
/// schema map (made with its allocator).
pub fn decodeStoreInto(database: *IDBDatabase, definition_id: u64, bytes: []const u8) (error{Corrupt} || Allocator.Error)!void {
    const allocator = database.allocator;
    var reader: Reader = .{ .bytes = bytes };
    if (try reader.byte() != record_version) return error.Corrupt;
    const name = try readString(&reader);
    var path = try readKeyPath(&reader, allocator);
    defer path.deinit(allocator);
    const auto_increment = try reader.byte() != 0;
    const key_generator = try reader.u64Be();
    const next_index_id = try reader.u64Be();

    const data = try allocator.create(RecordData);
    data.* = .{ .allocator = allocator, .definition_id = definition_id, .key_generator = key_generator, .next_index_id = next_index_id };
    errdefer data.release();
    var index_names: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer {
        for (index_names.items) |index_name| allocator.free(index_name);
        index_names.deinit(allocator);
    }
    const name_count = try reader.u32Be();
    if (name_count > bytes.len) return error.Corrupt;
    for (0..name_count) |_| {
        const copy = try allocator.dupe(u8, try readString(&reader));
        index_names.append(allocator, copy) catch |err| {
            allocator.free(copy);
            return err;
        };
    }
    const index_count = try reader.u32Be();
    if (index_count > bytes.len) return error.Corrupt;
    for (0..index_count) |_| {
        const index_id = try reader.u64Be();
        const index_name = try readString(&reader);
        var index_path = try readKeyPath(&reader, allocator);
        defer index_path.deinit(allocator);
        const unique = try reader.byte() != 0;
        const multi_entry = try reader.byte() != 0;
        const key_path: key_path_mod.KeyPath = if (index_path.compound) |paths| .{ .array = paths } else .{ .single = index_path.single orelse return error.Corrupt };
        const index = try IndexData.createWithKeyPath(allocator, index_name, key_path, unique, multi_entry);
        index.definition_id = index_id;
        data.indexes.put(allocator, index.name, index) catch |err| {
            index.release();
            return err;
        };
    }
    if (!reader.done()) return error.Corrupt;

    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const key_path = if (path.single) |single| try allocator.dupe(u8, single) else null;
    errdefer if (key_path) |single| allocator.free(single);
    const compound = if (path.compound) |paths| try key_path_mod.copyPathList(allocator, paths) else null;
    errdefer if (compound) |paths| key_path_mod.freePathList(allocator, paths);
    try database.object_stores.put(owned_name, .{
        .record_data = data,
        .name = owned_name,
        .key_path = key_path,
        .compound_key_path = compound,
        .auto_increment = auto_increment,
        .key_generator = key_generator,
        .index_names = index_names,
    });
}
