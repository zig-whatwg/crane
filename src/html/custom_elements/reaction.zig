//! Owned data for HTML §4.13.6 custom element reactions.
const std = @import("std");

pub const State = enum { undefined, failed, uncustomized, precustomized, custom };
pub const ReactionType = enum { upgrade, callback };
pub const CallbackType = enum {
    connected,
    disconnected,
    adopted,
    connected_move,
    attribute_changed,
    form_associated,
    form_reset,
    form_disabled,
    form_state_restore,
};

pub fn Reaction(comptime runtime: type, comptime engine: type) type {
    const Definition = @import("definition.zig").Definition(runtime, engine);
    return struct {
        const Self = @This();
        reaction_type: ReactionType,
        definition: ?*Definition = null,
        callback_type: ?CallbackType = null,
        callback_args: ?CallbackArgs = null,
        owned: ?*OwnedData = null,

        pub const AttributeChangedArgs = struct {
            local_name: []const u8,
            old_value: ?[]const u8,
            new_value: ?[]const u8,
            namespace: ?[]const u8,
        };
        pub const AdoptedArgs = struct { old_document: *runtime.Instance, new_document: *runtime.Instance };
        pub const CallbackArgs = union(enum) {
            none: void,
            attribute_changed: AttributeChangedArgs,
            adopted: AdoptedArgs,
        };

        const OwnedData = struct {
            allocator: std.mem.Allocator,
            callback: ?engine.CallbackFunction = null,
            definition: ?*Definition = null,
            args: CallbackArgs = .none,
            old_document: ?engine.Owned = null,
            new_document: ?engine.Owned = null,

            fn deinit(self: *OwnedData) void {
                if (self.callback) |callback| callback.release();
                if (self.definition) |definition| definition.deinit();
                if (self.old_document) |document| document.release();
                if (self.new_document) |document| document.release();
                if (self.args == .attribute_changed) {
                    const args = self.args.attribute_changed;
                    self.allocator.free(args.local_name);
                    if (args.old_value) |value| self.allocator.free(value);
                    if (args.new_value) |value| self.allocator.free(value);
                    if (args.namespace) |value| self.allocator.free(value);
                }
                self.allocator.destroy(self);
            }
        };

        pub fn initUpgrade(allocator: std.mem.Allocator, definition: *Definition) !Self {
            const owned = try allocator.create(OwnedData);
            owned.* = .{ .allocator = allocator, .definition = definition.retain() };
            return .{ .reaction_type = .upgrade, .definition = definition, .owned = owned };
        }

        /// Takes independent copies of callback and every argument before the
        /// mutation that enqueued them can invalidate their original storage.
        pub fn initCallback(allocator: std.mem.Allocator, realm: runtime.Context, callback: engine.CallbackFunction, kind: CallbackType, args: CallbackArgs) !Self {
            const owned = try allocator.create(OwnedData);
            owned.* = .{ .allocator = allocator };
            errdefer owned.deinit();
            owned.callback = .{
                .function = try engine.retainValue(realm, callback.function.value),
                .context = callback.context,
            };
            switch (args) {
                .none => {},
                .adopted => |adopted| {
                    owned.old_document = try engine.retainValue(realm, .{ .instance = adopted.old_document });
                    owned.new_document = try engine.retainValue(realm, .{ .instance = adopted.new_document });
                    owned.args = args;
                },
                .attribute_changed => |attribute| owned.args = .{ .attribute_changed = try copyAttributeArgs(allocator, attribute) },
            }
            return .{
                .reaction_type = .callback,
                .callback_type = kind,
                .callback_args = owned.args,
                .owned = owned,
            };
        }

        pub fn callbackFunction(self: *const Self) ?*const engine.CallbackFunction {
            const owned = self.owned orelse return null;
            return if (owned.callback) |*function| function else null;
        }

        /// Borrow the wrapped document values captured at enqueue time. A
        /// document's realm can end while the adopted element's realm lives;
        /// retaining its wrapper does not preserve the native Instance.
        pub fn adoptedValues(self: *const Self) ?[2]runtime.JSValue {
            const owned = self.owned orelse return null;
            return .{
                (owned.old_document orelse return null).value,
                (owned.new_document orelse return null).value,
            };
        }

        pub fn deinit(self: *Self) void {
            const owned = self.owned orelse return;
            self.owned = null;
            owned.deinit();
        }

        fn copyAttributeArgs(allocator: std.mem.Allocator, args: AttributeChangedArgs) !AttributeChangedArgs {
            const local_name = try allocator.dupe(u8, args.local_name);
            errdefer allocator.free(local_name);
            const old_value = if (args.old_value) |value| try allocator.dupe(u8, value) else null;
            errdefer if (old_value) |value| allocator.free(value);
            const new_value = if (args.new_value) |value| try allocator.dupe(u8, value) else null;
            errdefer if (new_value) |value| allocator.free(value);
            return .{
                .local_name = local_name,
                .old_value = old_value,
                .new_value = new_value,
                .namespace = if (args.namespace) |value| try allocator.dupe(u8, value) else null,
            };
        }
    };
}
