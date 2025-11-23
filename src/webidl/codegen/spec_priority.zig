//! Spec Priority Resolution
//!
//! Resolves conflicts when multiple specifications define the same interface.
//! Implements a priority system to choose the "canonical" definition.

const std = @import("std");

/// Priority level for a spec (lower number = higher priority)
pub const Priority = enum(u8) {
    canonical = 0, // Official, current spec for this interface
    modern = 1, // Modern spec (e.g., cssom vs DOM-Style)
    versioned = 2, // Versioned spec (e.g., web-animations-2)
    standard = 3, // Standard spec with no special priority
    legacy = 4, // Legacy/deprecated spec (e.g., DOM-Style, SVG)
    unknown = 5, // Unknown spec, lowest priority
};

/// Spec priority rules
pub const SpecPriority = struct {
    allocator: std.mem.Allocator,
    /// Legacy specs that should be deprioritized
    legacy_specs: std.StringHashMap(void),
    /// Manual overrides: interface name -> preferred spec file
    overrides: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) SpecPriority {
        return .{
            .allocator = allocator,
            .legacy_specs = std.StringHashMap(void).init(allocator),
            .overrides = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *SpecPriority) void {
        self.legacy_specs.deinit();
        var iter = self.overrides.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.overrides.deinit();
    }

    /// Initialize with default legacy specs
    pub fn initDefault(allocator: std.mem.Allocator) !SpecPriority {
        var priority = SpecPriority.init(allocator);
        errdefer priority.deinit();

        // Mark legacy specs
        try priority.addLegacySpec("DOM-Style.idl");
        try priority.addLegacySpec("SVG.idl");

        return priority;
    }

    /// Add a legacy spec to deprioritize
    pub fn addLegacySpec(self: *SpecPriority, spec_name: []const u8) !void {
        try self.legacy_specs.put(spec_name, {});
    }

    /// Add manual override for an interface
    pub fn addOverride(self: *SpecPriority, interface_name: []const u8, preferred_spec: []const u8) !void {
        const name_copy = try self.allocator.dupe(u8, interface_name);
        errdefer self.allocator.free(name_copy);
        const spec_copy = try self.allocator.dupe(u8, preferred_spec);
        errdefer self.allocator.free(spec_copy);

        try self.overrides.put(name_copy, spec_copy);
    }

    /// Get priority for a spec file
    pub fn getPriority(self: *SpecPriority, interface_name: []const u8, spec_file: []const u8) Priority {
        // 1. Check manual overrides first
        if (self.overrides.get(interface_name)) |preferred_spec| {
            if (std.mem.eql(u8, spec_file, preferred_spec)) {
                return .canonical;
            }
        }

        // 2. Check if it's a legacy spec
        if (self.legacy_specs.contains(spec_file)) {
            return .legacy;
        }

        // 3. Check for versioned specs (prefer higher version)
        if (isVersionedSpec(spec_file)) {
            return .versioned;
        }

        // 4. Check for modern specs (prefer modern over legacy)
        if (isModernSpec(spec_file)) {
            return .modern;
        }

        // 5. Standard spec
        return .standard;
    }

    /// Choose which spec to use when there's a duplicate
    /// Returns true if spec_a should be preferred over spec_b
    pub fn shouldPrefer(self: *SpecPriority, interface_name: []const u8, spec_a: []const u8, spec_b: []const u8) bool {
        const priority_a = self.getPriority(interface_name, spec_a);
        const priority_b = self.getPriority(interface_name, spec_b);

        // Lower priority value = higher priority
        if (@intFromEnum(priority_a) != @intFromEnum(priority_b)) {
            return @intFromEnum(priority_a) < @intFromEnum(priority_b);
        }

        // Same priority level - use version comparison
        const version_a = extractVersion(spec_a);
        const version_b = extractVersion(spec_b);
        if (version_a != version_b) {
            return version_a > version_b; // Higher version wins
        }

        // Same priority and version - prefer alphabetically later (usually more specific)
        return std.mem.lessThan(u8, spec_b, spec_a);
    }
};

/// Check if a spec is a modern spec (vs legacy DOM-Style)
fn isModernSpec(spec_file: []const u8) bool {
    return std.mem.indexOf(u8, spec_file, "cssom") != null or
        std.mem.indexOf(u8, spec_file, "css-") != null and !std.mem.eql(u8, spec_file, "DOM-Style.idl");
}

/// Check if a spec has version numbers
fn isVersionedSpec(spec_file: []const u8) bool {
    return std.mem.indexOf(u8, spec_file, "-2") != null or
        std.mem.indexOf(u8, spec_file, "-3") != null;
}

/// Extract version number from spec file (e.g., "web-animations-2.idl" -> 2)
fn extractVersion(spec_file: []const u8) u32 {
    // Look for pattern "-N" where N is a number
    var i: usize = spec_file.len;
    while (i > 0) {
        i -= 1;
        if (spec_file[i] == '-' and i + 1 < spec_file.len) {
            const c = spec_file[i + 1];
            if (c >= '0' and c <= '9') {
                return @as(u32, c - '0');
            }
        }
    }
    return 0; // No version
}

test "spec priority: legacy specs deprioritized" {
    const allocator = std.testing.allocator;
    var priority = try SpecPriority.initDefault(allocator);
    defer priority.deinit();

    try std.testing.expect(priority.getPriority("CSSRule", "DOM-Style.idl") == .legacy);
    try std.testing.expect(priority.getPriority("CSSRule", "cssom.idl") == .modern);
}

test "spec priority: versioned specs preferred" {
    const allocator = std.testing.allocator;
    var priority = try SpecPriority.initDefault(allocator);
    defer priority.deinit();

    try std.testing.expect(priority.shouldPrefer("AnimationPlaybackEvent", "web-animations-2.idl", "web-animations.idl"));
}

test "spec priority: manual overrides" {
    const allocator = std.testing.allocator;
    var priority = try SpecPriority.initDefault(allocator);
    defer priority.deinit();

    try priority.addOverride("SVGPathElement", "svg-paths.idl");

    try std.testing.expect(priority.getPriority("SVGPathElement", "svg-paths.idl") == .canonical);
    try std.testing.expect(priority.shouldPrefer("SVGPathElement", "svg-paths.idl", "SVG.idl"));
}
