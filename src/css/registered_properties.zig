//! Registered custom properties as the cascade reads them (CSS Properties
//! and Values API 1 §§2.4, 3; lane vars1b2's design, wpt-results/lanes/
//! vars1b2-unit1-c53b90634d/cascade-design.md section 2).
//!
//! A `Snapshot` is the document's registrations at one registry version:
//! for each, its name, `inherits`, its syntax, and its initial value
//! COMPUTED ONCE and serialized - the form var() substitutes and
//! getComputedStyle returns. Every element styled at that version shares
//! the snapshot (each ComputedStyle retains it), so an initial value is
//! never computed or stored per element: Blink's StyleInitialData, built
//! lazily per document by StyleEngine::MaybeCreateAndGetInitialData and
//! dropped by PropertyRegistryChanged, and read by ComputedStyle::
//! GetVariableData as the fallback for a name its maps lack.
//!
//! Initial values are computationally independent (CSS.registerProperty and
//! @property reject anything else), so the only input besides the value is
//! global: the viewport, for viewport units. The owner rebuilds the snapshot
//! when the registry's version or the viewport changes.
//!
//! Reference counts are not atomic: a snapshot lives on its Browser's thread
//! (docs/instances.md), as custom_properties.Text does.
const std = @import("std");
const syntax = @import("syntax_definitions.zig");
const syntax_values = @import("syntax_values.zig");
const custom = @import("custom_properties.zig");
const Allocator = std.mem.Allocator;

/// The global inputs an initial value's computation may read.
pub const Environment = struct {
    viewport_width: f64 = 1024,
    viewport_height: f64 = 768,
};

/// One registration, as the registry holds it. Borrowed for `create`.
pub const Source = struct {
    name: []const u8,
    /// The registration's syntax string; parsed again into the snapshot's
    /// own definition, so the snapshot outlives the registry's records.
    syntax_text: []const u8,
    inherits: bool,
    /// The parsed (specified) initial value, or null: a universal
    /// registration without one, whose initial value is guaranteed-invalid.
    initial_value: ?*const syntax_values.Value,
};

pub const Snapshot = struct {
    refs: u32 = 1,
    allocator: Allocator,
    /// Sorted by name (code units): the first entries of `storage`.
    entries: []Entry,
    storage: []Entry,

    pub const Entry = struct {
        name: []u8,
        inherits: bool,
        syntax: syntax.Definition,
        /// The computed initial value's serialization; null is the
        /// guaranteed-invalid value.
        initial: ?*custom.Text,

        fn deinit(self: *Entry, allocator: Allocator) void {
            allocator.free(self.name);
            self.syntax.deinit();
            if (self.initial) |t| t.release();
        }
    };

    pub fn create(allocator: Allocator, environment: Environment, sources: []const Source) Allocator.Error!*Snapshot {
        const self = try allocator.create(Snapshot);
        errdefer allocator.destroy(self);
        const storage = try allocator.alloc(Entry, sources.len);
        var made: usize = 0;
        errdefer {
            for (storage[0..made]) |*e| e.deinit(allocator);
            allocator.free(storage);
        }
        for (sources) |source| {
            storage[made] = try makeEntry(allocator, environment, source) orelse continue;
            made += 1;
        }
        std.mem.sort(Entry, storage[0..made], {}, struct {
            fn lessThan(_: void, a: Entry, b: Entry) bool {
                return std.mem.order(u8, a.name, b.name) == .lt;
            }
        }.lessThan);
        self.* = .{ .allocator = allocator, .storage = storage, .entries = storage[0..made] };
        return self;
    }

    /// An entry for `source`, or null when its syntax does not parse (the
    /// registry accepted it, so this does not happen; such a name is then
    /// treated as unregistered rather than failing the whole snapshot).
    fn makeEntry(allocator: Allocator, environment: Environment, source: Source) Allocator.Error!?Entry {
        var definition = syntax.parse(allocator, source.syntax_text) catch |err| switch (err) {
            error.InvalidSyntax => return null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        errdefer definition.deinit();
        const name = try allocator.dupe(u8, source.name);
        errdefer allocator.free(name);
        const initial: ?*custom.Text = if (source.initial_value) |value| try computeInitial(allocator, environment, value) else null;
        return .{ .name = name, .inherits = source.inherits, .syntax = definition, .initial = initial };
    }

    /// §2.4 / §3: the initial value's computed value, serialized - with
    /// the initial font and line height (it is computationally independent,
    /// so neither is read) and the document's viewport.
    fn computeInitial(allocator: Allocator, environment: Environment, value: *const syntax_values.Value) Allocator.Error!*custom.Text {
        var computed = try value.compute(allocator, .{ .math = .{
            .viewport_width = environment.viewport_width,
            .viewport_height = environment.viewport_height,
        } });
        defer computed.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try computed.serialize(&out, allocator);
        return custom.Text.create(allocator, out.items);
    }

    pub fn retain(self: *Snapshot) void {
        self.refs += 1;
    }

    pub fn release(self: *Snapshot) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        for (self.entries) |*e| e.deinit(self.allocator);
        self.allocator.free(self.storage);
        self.allocator.destroy(self);
    }

    pub fn isEmpty(self: *const Snapshot) bool {
        return self.entries.len == 0;
    }

    /// The registration of `name`, or null when it is unregistered.
    pub fn find(self: *const Snapshot, name: []const u8) ?*const Entry {
        var lo: usize = 0;
        var hi = self.entries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            switch (std.mem.order(u8, self.entries[mid].name, name)) {
                .eq => return &self.entries[mid],
                .lt => lo = mid + 1,
                .gt => hi = mid,
            }
        }
        return null;
    }
};
