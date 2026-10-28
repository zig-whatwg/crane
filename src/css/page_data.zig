//! Page-only descriptor storage beside an ordinary declaration block.
//! CSSOM §§6.4.7/6.6; Paged Media 3 §§4.3/7; liaison Q47/Q49.
const std = @import("std");
const declarations = @import("declarations.zig");
const properties = @import("properties.zig");
const rules = @import("rules.zig");
const page = @import("page_values.zig");
const substitution = @import("substitution.zig");
const Pending = @import("pending_values.zig").Pending;
const Allocator = std.mem.Allocator;
const Block = declarations.DeclarationBlock;

pub const Data = struct {
    block: Block,
    // Q49: descriptor-tagged real pending values. They never enter typed
    // DeclarationBlock entries or the style cascade, and resolve() is never
    // called on them. A future page consumer must substituteCustom(name),
    // then use the same page descriptor grammar; no element is invented.
    pending: [@typeInfo(page.Descriptor).@"enum".fields.len]?*Pending = @splat(null),

    pub fn init(allocator: Allocator) Data {
        return .{ .block = Block.init(allocator) };
    }

    pub fn deinit(self: *Data) void {
        for (self.pending) |value| if (value) |held| held.unref();
        self.pending = @splat(null);
        self.block.deinit();
    }

    fn descriptorIndex(self: *const Data, kind: page.Descriptor) ?usize {
        for (self.block.entries.items, 0..) |entry, i| {
            if (entry == .unparsed and std.mem.eql(u8, entry.unparsed.name, kind.name())) return i;
        }
        return null;
    }

    pub fn descriptorValue(self: *const Data, kind: page.Descriptor) []const u8 {
        const index = self.descriptorIndex(kind) orelse return "";
        return self.block.entries.items[index].unparsed.value;
    }

    pub fn getPropertyValue(self: *const Data, name: []const u8, out: *std.ArrayList(u8)) Allocator.Error!void {
        if (page.Descriptor.parse(name)) |kind| {
            try out.appendSlice(self.block.allocator, self.descriptorValue(kind));
            return;
        }
        try self.block.getPropertyValue(name, out);
    }

    pub fn getPropertyPriority(self: *const Data, name: []const u8) bool {
        if (page.Descriptor.parse(name)) |kind| {
            const index = self.descriptorIndex(kind) orelse return false;
            return self.block.entries.items[index].important();
        }
        return self.block.getPropertyPriority(name);
    }

    fn releaseEntry(self: *Data, entry: declarations.Entry) void {
        switch (entry) {
            .typed => |value| value.value.release(),
            .custom => |value| {
                value.name.release();
                value.value.release();
            },
            .unparsed => |value| {
                self.block.allocator.free(value.name);
                self.block.allocator.free(value.value);
            },
        }
    }

    fn removeDescriptor(self: *Data, kind: page.Descriptor) bool {
        const index = self.descriptorIndex(kind) orelse return false;
        self.releaseEntry(self.block.entries.orderedRemove(index));
        const slot = &self.pending[@intFromEnum(kind)];
        if (slot.*) |held| held.unref();
        slot.* = null;
        return true;
    }

    pub fn removeProperty(self: *Data, name: []const u8, out: *std.ArrayList(u8)) Allocator.Error!bool {
        if (page.Descriptor.parse(name)) |kind| {
            try out.appendSlice(self.block.allocator, self.descriptorValue(kind));
            return self.removeDescriptor(kind);
        }
        return self.block.removeProperty(name, out);
    }

    fn setDescriptor(self: *Data, options: properties.ParseOptions, kind: page.Descriptor, text: []const u8, important: bool, parsed: bool) Allocator.Error!bool {
        // Q47: all three browsers reject these unshipped descriptors,
        // including CSS-wide and pending values.
        if (kind == .marks or kind == .bleed) return false;
        const allocator = self.block.allocator;
        var held: ?*Pending = null;
        defer if (held) |value| value.unref();
        const canonical = if (substitution.mentionsFunction(text)) blk: {
            held = try Pending.create(options, null, text) orelse return false;
            // rules.zig already applies its source-context EOF policy:
            // stylesheet values close; cssText keeps authored pending text.
            break :blk try allocator.dupe(u8, held.?.text);
        } else try page.descriptor(allocator, kind, text) orelse return false;
        var owned = true;
        defer if (owned) allocator.free(canonical);
        const previous = self.descriptorIndex(kind);
        if (previous) |index| {
            const current = &self.block.entries.items[index].unparsed;
            if (parsed and current.important and !important) return false;
            if (!parsed and current.important == important and std.mem.eql(u8, current.value, canonical)) return false;
        }

        // Allocate before changing an existing descriptor or its Pending.
        const owned_name = if (previous == null or parsed) try allocator.dupe(u8, kind.name()) else null;
        errdefer if (owned_name) |name| allocator.free(name);
        if (previous == null) try self.block.entries.ensureUnusedCapacity(allocator, 1);
        if (previous) |index| {
            if (parsed) {
                self.releaseEntry(self.block.entries.orderedRemove(index));
                self.block.entries.appendAssumeCapacity(.{ .unparsed = .{ .name = owned_name.?, .value = canonical, .important = important } });
            } else {
                const current = &self.block.entries.items[index].unparsed;
                allocator.free(current.value);
                current.value = canonical;
                current.important = important;
            }
        } else self.block.entries.appendAssumeCapacity(.{ .unparsed = .{ .name = owned_name.?, .value = canonical, .important = important } });
        owned = false;
        const slot = &self.pending[@intFromEnum(kind)];
        if (slot.*) |old| old.unref();
        slot.* = held;
        held = null;
        return true;
    }

    pub fn setProperty(self: *Data, options: properties.ParseOptions, name: []const u8, text: []const u8, priority: []const u8) Allocator.Error!bool {
        const kind = page.Descriptor.parse(name) orelse return self.block.setProperty(options, name, text, priority);
        // CSSOM setProperty steps 3–4: removal precedes priority validation.
        if (text.len == 0) return self.removeDescriptor(kind);
        if (priority.len != 0 and !std.ascii.eqlIgnoreCase(priority, "important")) return false;
        return self.setDescriptor(options, kind, text, priority.len != 0, false);
    }

    /// Consume a parsed entry, preserving DeclarationBlock's parsed-order
    /// and importance rules without reimplementing any property grammar.
    fn takeParsed(self: *Data, entry: declarations.Entry) Allocator.Error!void {
        var taken = false;
        defer if (!taken) self.releaseEntry(entry);
        var previous: ?usize = null;
        for (self.block.entries.items, 0..) |*old, i| {
            if (std.mem.eql(u8, old.name(), entry.name())) {
                if (old.important() and !entry.important()) return;
                previous = i;
                break;
            }
        }
        if (previous == null) try self.block.entries.ensureUnusedCapacity(self.block.allocator, 1);
        if (previous) |index| {
            const old = self.block.entries.orderedRemove(index);
            if (old == .custom) self.block.custom_count -= 1;
            self.releaseEntry(old);
        }
        self.block.entries.appendAssumeCapacity(entry);
        if (entry == .custom) self.block.custom_count += 1;
        taken = true;
    }

    pub fn fromDeclarations(options: properties.ParseOptions, parsed: []const rules.Declaration) Allocator.Error!Data {
        var self = Data.init(options.allocator);
        errdefer self.deinit();
        for (parsed) |declaration| {
            if (page.Descriptor.parse(declaration.name)) |kind| {
                _ = try self.setDescriptor(options, kind, declaration.value, declaration.important, true);
                continue;
            }
            var one = try Block.fromDeclarations(options, &.{declaration});
            defer one.deinit();
            while (one.entries.items.len != 0) {
                const entry = one.entries.orderedRemove(0);
                if (entry == .custom) one.custom_count -= 1;
                try self.takeParsed(entry);
            }
        }
        return self;
    }

    pub fn parse(options: properties.ParseOptions, text: []const u8) Allocator.Error!Data {
        const parsed = try rules.parseDeclarationList(options.allocator, text);
        defer rules.freeDeclarationList(options.allocator, parsed);
        return fromDeclarations(options, parsed);
    }

    pub fn setCssText(self: *Data, options: properties.ParseOptions, text: []const u8) Allocator.Error!void {
        const replacement = try parse(options, text);
        self.deinit();
        self.* = replacement;
    }
};
