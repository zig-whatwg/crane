//! WebIDL conversions for the WebCrypto key-data union and usage sequences.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const keys = @import("key.zig");
const jwk = @import("jwk.zig");

pub fn usages(realm: runtime.Context, value: runtime.JSValue) engine.Error!keys.Usages {
    const Sequence = struct {
        realm: runtime.Context,
        result: keys.Usages = keys.Usages.initEmpty(),

        fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const text = try engine.convertToDOMString(self.realm, item, self.realm.allocator);
            defer self.realm.allocator.free(text);
            // Convert each enum before asking the iterator for its next item.
            self.result.insert(std.meta.stringToEnum(keys.Usage, text) orelse return error.TypeError);
        }
    };
    if (engine.typeOf(realm, value) != .object) return error.TypeError;
    var sequence: Sequence = .{ .realm = realm };
    if (!try engine.iterate(realm, value, Sequence.each, &sequence)) return error.TypeError;
    return sequence.result;
}

pub const Import = union(enum) {
    /// Borrowed only until the call's synchronous steps have copied it.
    buffer: runtime.JSValue,
    dictionary: jwk.Owned,

    pub fn deinit(self: *Import, allocator: std.mem.Allocator) void {
        if (self.* == .dictionary) self.dictionary.deinit(allocator);
    }
};

pub fn keyData(realm: runtime.Context, value: runtime.JSValue) engine.Error!Import {
    // WebIDL union conversion validates BufferSource first; this validation
    // copy is discarded. §14.3.9 step 4 copies again AFTER normalization,
    // because a name getter can mutate or detach the original buffer.
    if (try engine.getCopyOfBufferSourceBytes(realm, value, realm.allocator)) |bytes| {
        std.crypto.secureZero(u8, bytes);
        realm.allocator.free(bytes);
        return .{ .buffer = value };
    }
    return .{ .dictionary = try dictionary(realm, value) };
}

pub fn dictionary(realm: runtime.Context, value: runtime.JSValue) engine.Error!jwk.Owned {
    var result: jwk.Owned = .{};
    errdefer result.deinit(realm.allocator);
    switch (engine.typeOf(realm, value)) {
        .undefined, .null => return result,
        .object => {},
        else => return error.TypeError,
    }
    // WebIDL dictionary conversion visits members in lexicographic order.
    // Data's fields use that order, including the installed modern members.
    inline for (std.meta.fields(jwk.Data)) |field| {
        const member = try engine.getProperty(realm, value, field.name);
        defer member.release();
        if (engine.typeOf(realm, member.borrow()) != .undefined) {
            if (field.type == ?[]const u8) {
                @field(result.data, field.name) = try engine.convertToDOMString(realm, member.borrow(), realm.allocator);
            } else if (comptime std.mem.eql(u8, field.name, "ext")) {
                result.data.ext = engine.toBoolean(realm, member.borrow());
            } else if (comptime std.mem.eql(u8, field.name, "key_ops")) {
                result.data.key_ops = try strings(realm, member.borrow());
            } else if (comptime std.mem.eql(u8, field.name, "oth")) {
                result.data.oth = try otherPrimes(realm, member.borrow());
            }
        }
    }
    return result;
}

fn strings(realm: runtime.Context, value: runtime.JSValue) engine.Error![]const []const u8 {
    const Sequence = struct {
        realm: runtime.Context,
        list: std.ArrayList([]const u8) = .empty,

        fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const text = try engine.convertToDOMString(self.realm, item, self.realm.allocator);
            errdefer erase(self.realm.allocator, text);
            try self.list.append(self.realm.allocator, text);
        }
    };
    if (engine.typeOf(realm, value) != .object) return error.TypeError;
    var sequence: Sequence = .{ .realm = realm };
    errdefer for (sequence.list.items) |text| erase(realm.allocator, text);
    defer sequence.list.deinit(realm.allocator);
    if (!try engine.iterate(realm, value, Sequence.each, &sequence)) return error.TypeError;
    return sequence.list.toOwnedSlice(realm.allocator);
}

fn otherPrimes(realm: runtime.Context, value: runtime.JSValue) engine.Error![]const jwk.OtherPrime {
    const Sequence = struct {
        realm: runtime.Context,
        list: std.ArrayList(jwk.OtherPrime) = .empty,

        fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            var result: jwk.OtherPrime = .{};
            errdefer freePrime(self.realm.allocator, result);
            switch (engine.typeOf(self.realm, item)) {
                .undefined, .null => {},
                .object => {
                    inline for (std.meta.fields(jwk.OtherPrime)) |field| {
                        const member = try engine.getProperty(self.realm, item, field.name);
                        defer member.release();
                        if (engine.typeOf(self.realm, member.borrow()) != .undefined) {
                            @field(result, field.name) = try engine.convertToDOMString(self.realm, member.borrow(), self.realm.allocator);
                        }
                    }
                },
                else => return error.TypeError,
            }
            try self.list.append(self.realm.allocator, result);
        }
    };
    if (engine.typeOf(realm, value) != .object) return error.TypeError;
    var sequence: Sequence = .{ .realm = realm };
    errdefer for (sequence.list.items) |prime| freePrime(realm.allocator, prime);
    defer sequence.list.deinit(realm.allocator);
    if (!try engine.iterate(realm, value, Sequence.each, &sequence)) return error.TypeError;
    return sequence.list.toOwnedSlice(realm.allocator);
}

fn freePrime(allocator: std.mem.Allocator, prime: jwk.OtherPrime) void {
    inline for (std.meta.fields(jwk.OtherPrime)) |field| {
        if (@field(prime, field.name)) |text| erase(allocator, text);
    }
}

fn erase(allocator: std.mem.Allocator, bytes: []const u8) void {
    std.crypto.secureZero(u8, @constCast(bytes));
    allocator.free(bytes);
}
