//! Values 5 Appendix A: a pending-substitution value. A declaration whose
//! value contains an arbitrary substitution function (var(), env(),
//! random-item(), substitution.zig) is valid at parse time and is stored as
//! this: its original text and component value tree, shared by every
//! longhand a shorthand sets, and substituted at computed-value time - then
//! parsed with the property's grammar ("replace substitution functions in a
//! property"). A custom property's value with such a function is one too,
//! with no grammar to parse against.
//!
//! The declaration's source survives; no resolver or DOM does. WebKit
//! StyleSubstitutionResolver supplies the selected-branch design; Blink's
//! CSSPendingSubstitutionValue the shorthand sharing.
const std = @import("std");
const tokens = @import("tokenizer.zig");
const properties = @import("properties.zig");
const resources = @import("resource_values.zig");
const substitution = @import("substitution.zig");
const Allocator = std.mem.Allocator;
const Node = substitution.Node;
const NamespaceMap = @import("namespace_map.zig").NamespaceMap;

const CapturedUrl = struct { raw: []const u8, resolved: ?[]const u8 };

/// Resolves a url() substituted into a value against the CONSUMING
/// declaration's base URL (CSS Variables 1 §2.1: a relative URL in a custom
/// property resolves where var() substitutes it; Blink parses substituted
/// tokens with the consuming value's parser context). Supplied by the DOM;
/// borrowed for the cascade call.
pub const BaseUrlResolver = struct {
    context: *const anyopaque,
    resolve: *const fn (context: *const anyopaque, allocator: Allocator, base: []const u8, url: []const u8) ?[]u8,
};

pub const Pending = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    /// The declaration's property; null for a custom property's value.
    property: ?properties.Property,
    /// The original text (rules.zig keeps the source segment).
    text: []const u8 = "",
    nodes: []const Node = &.{},
    quirks: bool,
    /// SVG2 §4.2: a presentation attribute's value re-parses in that mode.
    svg_presentation: bool,
    source: ?*resources.ResourceSource,
    /// The declaring sheet's namespace prefixes (attr()), retained; null for
    /// a declaration outside a sheet, and for every declaration until Codex
    /// row 122 fills ParseOptions.namespaces.
    namespaces: ?*NamespaceMap,
    urls: []const CapturedUrl = &.{},
    had_resolver: bool,

    /// The pending value of `text` for `property` (null for a custom
    /// property), or null when the value is invalid at parse time: not a
    /// <declaration-value>, or a function whose arguments do not match its
    /// argument grammar.
    pub fn create(options: properties.ParseOptions, property: ?properties.Property, text: []const u8) Allocator.Error!?*Pending {
        const self = try options.allocator.create(Pending);
        self.* = .{
            .allocator = options.allocator,
            .arena = std.heap.ArenaAllocator.init(options.allocator),
            .property = property,
            .quirks = options.quirks,
            .svg_presentation = options.svg_presentation,
            .source = options.resource_source,
            .namespaces = options.namespaces,
            .had_resolver = options.url_resolver != null,
        };
        if (self.source) |source| source.ref();
        if (self.namespaces) |map| map.retain();
        var success = false;
        defer if (!success) self.unref();
        const arena = self.arena.allocator();
        self.text = try arena.dupe(u8, substitution.originalText(text));
        self.nodes = substitution.parse(arena, self.text) catch |err| switch (err) {
            error.Invalid, error.Unavailable => return null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        // Capture possible URL strings while the original resolver is alive.
        // An image-set string can become a URL only AFTER substitution, so
        // capture strings too; none is exposed as a resource before selection.
        var captured: std.ArrayList(CapturedUrl) = .empty;
        var tokenizer = tokens.Tokenizer.init(self.text);
        while (true) {
            const token = tokenizer.next();
            if (token.token_type == .eof) break;
            const encoded = switch (token.token_type) {
                .url => token.value,
                .string => token.stringContents(),
                else => continue,
            };
            const raw = try tokens.decode(arena, encoded);
            const resolved = if (options.url_resolver) |resolver|
                resolver.resolve(resolver.context, arena, raw)
            else
                null;
            try captured.append(arena, .{ .raw = raw, .resolved = resolved });
        }
        self.urls = try captured.toOwnedSlice(arena);
        success = true;
        return self;
    }

    pub fn ref(self: *Pending) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Pending) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.source) |source| source.unref();
        if (self.namespaces) |map| map.release();
        const allocator = self.allocator;
        self.arena.deinit();
        allocator.destroy(self);
    }
    pub fn eql(self: *const Pending, other: *const Pending) bool {
        if (self == other) return true;
        if (!std.mem.eql(u8, self.text, other.text)) return false;
        if (self.property == null or other.property == null) return self.property == null and other.property == null;
        return std.meta.eql(self.property.?, other.property.?);
    }

    fn propertyName(self: *const Pending) []const u8 {
        return switch (self.property orelse return "") {
            .longhand => |l| l.name(),
            .shorthand => |s| s.name(),
        };
    }

    /// Q88's three outcomes are distinct: missing input skips a candidate;
    /// invalid substitution remains the winning declaration, as unset.
    /// Values 5 "replace substitution functions in a property": substitute
    /// (1, 2: a guaranteed-invalid result is invalid at computed-value
    /// time), then parse the result with the property's grammar (3: failure
    /// is invalid at computed-value time). The assignments are the
    /// caller's (Outcome.deinit).
    pub fn resolve(self: *const Pending, allocator: Allocator, host: substitution.Host, url_resolver: ?BaseUrlResolver) Allocator.Error!Outcome {
        const property = self.property orelse return .invalid;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const rendered = substitution.substituteAndRender(arena.allocator(), self.nodes, host, self.propertyName(), self.namespaces) catch |err| switch (err) {
            error.Invalid => return .invalid,
            error.Unavailable => return .unavailable,
            error.OutOfMemory => return error.OutOfMemory,
        };
        var assignments: std.ArrayList(properties.Assignment) = .empty;
        errdefer {
            for (assignments.items) |a| a.value.release();
            assignments.deinit(allocator);
        }
        var urls: UrlContext = .{ .pending = self, .fallback = url_resolver };
        // The normal numeric ordinal scope is built here, AFTER selection.
        const options = properties.ParseOptions{
            .allocator = allocator,
            .quirks = self.quirks,
            .svg_presentation = self.svg_presentation,
            .resource_source = self.source,
            .url_resolver = if (self.had_resolver or url_resolver != null) .{ .context = &urls, .resolve = UrlContext.resolve } else null,
            .tainted_ranges = rendered.taint,
        };
        if (!try properties.parseDeclaration(options, property, rendered.text, &assignments)) {
            assignments.deinit(allocator);
            return .invalid;
        }
        // Appendix A: what substitution gives is fully substituted. Text that
        // still names a function (a host's environment value, say) does not
        // pend again: the value is invalid at computed-value time.
        for (assignments.items) |a| if (a.value == .value and a.value.value == .pending) {
            for (assignments.items) |b| b.value.release();
            assignments.deinit(allocator);
            return .invalid;
        };
        return .{ .resolved = try assignments.toOwnedSlice(allocator) };
    }

    /// A custom property's value substituted (CSS Variables 1 §2: "specified
    /// value with variables substituted, or the guaranteed-invalid value"):
    /// its text and taint ranges owned by `allocator`, or the
    /// guaranteed-invalid value.
    pub fn substituteCustom(self: *const Pending, allocator: Allocator, host: substitution.Host, name: []const u8) Allocator.Error!CustomOutcome {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const rendered = substitution.substituteAndRender(arena.allocator(), self.nodes, host, name, self.namespaces) catch |err| switch (err) {
            error.Invalid => return .invalid,
            error.Unavailable => return .unavailable,
            error.OutOfMemory => return error.OutOfMemory,
        };
        const text = try allocator.dupe(u8, rendered.text);
        errdefer allocator.free(text);
        const taint = try allocator.dupe(substitution.TaintRange, rendered.taint);
        return .{ .substituted = .{ .text = text, .taint = taint } };
    }

    const UrlContext = struct {
        pending: *const Pending,
        fallback: ?BaseUrlResolver,

        fn resolve(raw_context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
            const self: *const UrlContext = @ptrCast(@alignCast(raw_context));
            // A url() of the declaration's own text: the one captured at parse
            // time, while its resolver was alive.
            for (self.pending.urls) |entry| if (std.mem.eql(u8, raw, entry.raw)) {
                return allocator.dupe(u8, entry.resolved orelse return null) catch null;
            };
            // A url() substitution brought in: the consuming declaration's base.
            const fallback = self.fallback orelse return null;
            const source = self.pending.source orelse return null;
            return fallback.resolve(fallback.context, allocator, source.base_url, raw);
        }
    };
};

pub const Outcome = union(enum) {
    resolved: []properties.Assignment,
    unavailable,
    invalid,

    pub fn deinit(self: Outcome, allocator: Allocator) void {
        if (self == .resolved) {
            for (self.resolved) |a| a.value.release();
            allocator.free(self.resolved);
        }
    }
};

pub const CustomOutcome = union(enum) {
    substituted: struct { text: []u8, taint: []substitution.TaintRange },
    unavailable,
    invalid,
};
