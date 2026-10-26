//! CSS Properties and Values API §§2.1, 3, 4.1: immutable registrations.
//! Script registrations and stylesheet declarations have separate ownership;
//! replacing a sheet set is transactional and never erases a script entry.
const std = @import("std");
const syntax_definitions = @import("syntax_definitions.zig");
const syntax_values = @import("syntax_values.zig");
const properties = @import("properties.zig");
const rules = @import("rules.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

/// Dictionary conversion is the binding's job; all strings here are borrowed.
pub const Definition = struct {
    name: []const u8,
    syntax: []const u8 = "*",
    inherits: bool,
    initial_value: ?[]const u8 = null,
};

pub const Registration = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    name: []const u8,
    syntax_text: []const u8,
    syntax: syntax_definitions.Definition,
    inherits: bool,
    initial_value: ?syntax_values.Value,
    initial_text: ?[]const u8,

    /// §4.1 steps 2–6. The registry performs step 2's duplicate check first.
    pub fn create(options: properties.ParseOptions, definition: Definition) (Allocator.Error || error{SyntaxError})!*Registration {
        if (!isName(definition.name)) return error.SyntaxError;
        const allocator = options.allocator;
        var syntax = syntax_definitions.parse(allocator, definition.syntax) catch |err| switch (err) {
            error.InvalidSyntax => return error.SyntaxError,
            error.OutOfMemory => return error.OutOfMemory,
        };
        errdefer syntax.deinit();
        // Current-browser validity seam: a typed registration needs an initial
        // value; the newer optional-descriptor draft is not shipped (Q2).
        if (definition.initial_value == null and !syntax.universal) return error.SyntaxError;
        var initial: ?syntax_values.Value = null;
        errdefer if (initial) |*value| value.deinit();
        if (definition.initial_value) |text| {
            // Properties and Values §§3, 4.1: an initial value cannot be a
            // CSS-wide keyword, even when its universal syntax matches it.
            // Both scripted and stylesheet registrations use this validator.
            var stream = properties.Stream.init(text);
            const first = stream.next();
            if (first.token_type == .ident and stream.atEnd()) {
                const decoded = try tokenizer.decode(allocator, first.value);
                defer allocator.free(decoded);
                if (@import("style_values.zig").CssWide.parse(decoded) != null) return error.SyntaxError;
            }
            initial = try syntax.parseValue(options, text) orelse return error.SyntaxError;
            if (!initial.?.isComputationallyIndependent(text)) return error.SyntaxError;
        }
        const name = try allocator.dupe(u8, definition.name);
        errdefer allocator.free(name);
        const syntax_text = try allocator.dupe(u8, definition.syntax);
        errdefer allocator.free(syntax_text);
        const initial_text = if (definition.initial_value) |text| try allocator.dupe(u8, text) else null;
        errdefer if (initial_text) |text| allocator.free(text);
        const record = try allocator.create(Registration);
        record.* = .{ .allocator = allocator, .name = name, .syntax_text = syntax_text, .syntax = syntax, .inherits = definition.inherits, .initial_value = initial, .initial_text = initial_text };
        return record;
    }

    /// §3: invalid descriptors are ignored, then the complete rule is checked.
    /// Q10's browser ruling validates syntax/inherits per descriptor, but checks
    /// the last declaration-value against the final syntax only at rule build.
    pub fn fromRule(options: properties.ParseOptions, rule: *const rules.Rule) Allocator.Error!?*Registration {
        if (rule.kind != .at_rule or !std.mem.eql(u8, rule.name, "property") or !rule.has_block) return null;
        const allocator = options.allocator;
        var prelude = properties.Stream.init(rule.prelude);
        const name_token = prelude.next();
        if (name_token.token_type != .ident or !prelude.atEnd()) return null;
        const name = try tokenizer.decode(allocator, name_token.value);
        defer allocator.free(name);
        if (!isName(name)) return null;
        var syntax_text: ?[]u8 = null;
        defer if (syntax_text) |text| allocator.free(text);
        var inherits: ?bool = null;
        var initial: ?[]const u8 = null;
        for (rule.declarations) |declaration| {
            if (declaration.important) continue;
            if (std.mem.eql(u8, declaration.name, "syntax")) {
                var stream = properties.Stream.init(declaration.value);
                const token = stream.next();
                if (token.token_type != .string or !stream.atEnd()) continue;
                const text = try tokenizer.decode(allocator, token.stringContents());
                var parsed = syntax_definitions.parse(allocator, text) catch |err| {
                    allocator.free(text);
                    switch (err) {
                        error.InvalidSyntax => continue,
                        error.OutOfMemory => return error.OutOfMemory,
                    }
                };
                parsed.deinit();
                if (syntax_text) |old| allocator.free(old);
                syntax_text = text;
            } else if (std.mem.eql(u8, declaration.name, "inherits")) {
                var stream = properties.Stream.init(declaration.value);
                const token = stream.next();
                if (!stream.atEnd()) continue;
                if (token.isIdent("true")) inherits = true else if (token.isIdent("false")) inherits = false;
            } else if (std.mem.eql(u8, declaration.name, "initial-value") and rules.isDeclarationValue(declaration.value)) {
                initial = declaration.value;
            }
        }
        // Current-browser seam (Q2): syntax and inherits are mandatory.
        return create(options, .{ .name = name, .syntax = syntax_text orelse return null, .inherits = inherits orelse return null, .initial_value = initial }) catch |err| switch (err) {
            error.SyntaxError => null,
            error.OutOfMemory => return error.OutOfMemory,
        };
    }

    pub fn ref(self: *Registration) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Registration) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        if (self.initial_value) |*value| value.deinit();
        if (self.initial_text) |text| allocator.free(text);
        self.syntax.deinit();
        allocator.free(self.syntax_text);
        allocator.free(self.name);
        allocator.destroy(self);
    }

    /// §6.1: CSSOM keeps the authored syntax and declaration-value spelling.
    pub fn serializeRule(self: *const Registration, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        const escaped = try @import("serialize.zig").serializeIdentifier(allocator, self.name);
        defer allocator.free(escaped);
        try out.appendSlice(allocator, "@property ");
        try out.appendSlice(allocator, escaped);
        try out.appendSlice(allocator, " { syntax: ");
        try @import("style_values.zig").appendString(self.syntax_text, out, allocator);
        try out.appendSlice(allocator, if (self.inherits) "; inherits: true; " else "; inherits: false; ");
        if (self.initial_text) |initial| {
            try out.appendSlice(allocator, "initial-value: ");
            try out.appendSlice(allocator, initial);
            try out.appendSlice(allocator, "; ");
        }
        try out.append(allocator, '}');
    }
};

/// Typed OM's custom property NAME STRING, not a parsed identifier.
fn isName(name: []const u8) bool {
    return name.len > 2 and std.mem.startsWith(u8, name, "--");
}

/// An owning set, built in stylesheet order before a transactional swap.
pub const Declared = struct {
    allocator: Allocator,
    entries: std.StringHashMapUnmanaged(*Registration) = .empty,

    pub fn init(allocator: Allocator) Declared {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Declared) void {
        var iterator = self.entries.valueIterator();
        while (iterator.next()) |record| record.*.unref();
        self.entries.deinit(self.allocator);
        self.entries = .empty;
    }

    pub fn add(self: *Declared, record: *Registration) Allocator.Error!void {
        const entry = try self.entries.getOrPut(self.allocator, record.name);
        const old = if (entry.found_existing) entry.value_ptr.* else null;
        record.ref();
        // A replaced key must not keep pointing into the old registration.
        entry.key_ptr.* = record.name;
        entry.value_ptr.* = record;
        if (old) |value| value.unref();
    }
};

pub const Registry = struct {
    allocator: Allocator,
    scripted: Declared,
    declared: Declared,
    version: u64 = 0,

    pub fn init(allocator: Allocator) Registry {
        return .{ .allocator = allocator, .scripted = .init(allocator), .declared = .init(allocator) };
    }

    pub fn deinit(self: *Registry) void {
        self.scripted.deinit();
        self.declared.deinit();
    }

    /// §2.1: script wins, otherwise the last active stylesheet declaration.
    /// Borrowed until the next registry mutation; no DOM or realm is retained.
    pub fn lookup(self: *const Registry, name: []const u8) ?*const Registration {
        return self.scripted.entries.get(name) orelse self.declared.entries.get(name);
    }

    pub fn register(self: *Registry, options: properties.ParseOptions, definition: Definition) (Allocator.Error || error{ SyntaxError, InvalidModificationError })!void {
        if (!isName(definition.name)) return error.SyntaxError;
        if (self.scripted.entries.contains(definition.name)) return error.InvalidModificationError;
        const record = try Registration.create(options, definition);
        defer record.unref();
        try self.scripted.add(record);
        self.version +%= 1;
    }

    /// Consumes the replacement; a failed build never touches the old set.
    pub fn replaceDeclared(self: *Registry, replacement: *Declared) void {
        var changed = false;
        var old = self.declared.entries.iterator();
        while (old.next()) |entry| {
            if (self.scripted.entries.contains(entry.key_ptr.*)) continue;
            if (replacement.entries.get(entry.key_ptr.*) != entry.value_ptr.*) {
                changed = true;
                break;
            }
        }
        if (!changed) {
            var fresh = replacement.entries.iterator();
            while (fresh.next()) |entry| {
                if (self.scripted.entries.contains(entry.key_ptr.*)) continue;
                if (self.declared.entries.get(entry.key_ptr.*) != entry.value_ptr.*) {
                    changed = true;
                    break;
                }
            }
        }
        self.declared.deinit();
        self.declared = replacement.*;
        replacement.* = .init(replacement.allocator);
        if (changed) self.version +%= 1;
    }
};
