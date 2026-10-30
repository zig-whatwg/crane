//! Permissions Policy Implementation
//!
//! W3C Permissions Policy Specification
//! https://www.w3.org/TR/permissions-policy/
//!
//! Permissions Policy (formerly Feature Policy) allows web developers to selectively
//! enable, disable, or modify the behavior of certain APIs and web features in the
//! browser. It provides a mechanism to explicitly declare what functionality can be
//! used in a document and its child frames.
//!
//! ## Features
//!
//! - **Policy-controlled features**: APIs like geolocation, camera, microphone
//! - **Allowlist-based control**: Features can be allowed/denied per origin
//! - **Inheritance**: Child frames inherit policies from parents
//! - **Headers and attributes**: Policies via HTTP headers or iframe allow attribute
//!
//! ## Usage
//!
//! ```zig
//! const policy = @import("html").permissions_policy;
//!
//! // Parse a Permissions-Policy header
//! var pp = try policy.PermissionsPolicy.fromHeader(allocator,
//!     "geolocation=(), camera=(self \"https://example.com\")"
//! );
//! defer pp.deinit();
//!
//! // Check if a feature is allowed for an origin
//! const allowed = pp.isFeatureAllowed(.geolocation, origin);
//! ```
//!
//! ## Specification References
//!
//! - Permissions Policy: https://www.w3.org/TR/permissions-policy/
//! - HTML Standard § 7.10.2: Permissions Policy
//! - Feature Policy (predecessor): https://w3c.github.io/webappsec-feature-policy/

const std = @import("std");
const Allocator = std.mem.Allocator;
const origins = @import("dom").origin_record;
const fetch = @import("fetch");
const csp = @import("csp");
const basic_parser = @import("basic_parser");
const url_origin = @import("origin");

// ============================================================================
// Policy-Controlled Features
// ============================================================================

/// Policy-controlled features
/// Spec: https://www.w3.org/TR/permissions-policy/#features
pub const Feature = enum {
    // Sensors
    accelerometer,
    ambient_light_sensor,
    gyroscope,
    magnetometer,

    // Media
    autoplay,
    camera,
    display_capture,
    microphone,
    speaker_selection,

    // Power
    battery,

    // Device APIs
    bluetooth,
    hid,
    serial,
    usb,

    // Location
    geolocation,

    // Screen
    fullscreen,
    picture_in_picture,
    screen_wake_lock,

    // WebXR
    xr_spatial_tracking,

    // Payments
    payment,

    // Clipboard
    clipboard_read,
    clipboard_write,

    // Document/DOM
    document_domain,
    encrypted_media,
    execution_while_not_rendered,
    execution_while_out_of_viewport,
    focus_without_user_activation,
    gamepad,
    idle_detection,
    interest_cohort, // deprecated/removed
    local_fonts,
    midi,
    navigation_override,
    otp_credentials,
    publickey_credentials_get,
    screen_wake_lock_2, // Alternative name
    sync_xhr,
    unload,
    web_share,

    // Fetch deferred fetching (Fetch §5.6).
    deferred_fetch,
    deferred_fetch_minimal,

    // HTML 7.1.4's "cross-origin-isolated" feature: a policy-controlled
    // feature whose default allowlist is 'self', which a window's
    // cross-origin isolated capability requires its document to be allowed
    // to use.
    cross_origin_isolated,

    // Display
    browsing_topics, // Privacy Sandbox

    /// Get the string name of the feature (lowercase with hyphens)
    pub fn toString(self: Feature) []const u8 {
        return switch (self) {
            .accelerometer => "accelerometer",
            .ambient_light_sensor => "ambient-light-sensor",
            .gyroscope => "gyroscope",
            .magnetometer => "magnetometer",
            .autoplay => "autoplay",
            .camera => "camera",
            .display_capture => "display-capture",
            .microphone => "microphone",
            .speaker_selection => "speaker-selection",
            .battery => "battery",
            .bluetooth => "bluetooth",
            .hid => "hid",
            .serial => "serial",
            .usb => "usb",
            .geolocation => "geolocation",
            .fullscreen => "fullscreen",
            .picture_in_picture => "picture-in-picture",
            .screen_wake_lock, .screen_wake_lock_2 => "screen-wake-lock",
            .xr_spatial_tracking => "xr-spatial-tracking",
            .payment => "payment",
            .clipboard_read => "clipboard-read",
            .clipboard_write => "clipboard-write",
            .document_domain => "document-domain",
            .encrypted_media => "encrypted-media",
            .execution_while_not_rendered => "execution-while-not-rendered",
            .execution_while_out_of_viewport => "execution-while-out-of-viewport",
            .focus_without_user_activation => "focus-without-user-activation",
            .gamepad => "gamepad",
            .idle_detection => "idle-detection",
            .interest_cohort => "interest-cohort",
            .local_fonts => "local-fonts",
            .midi => "midi",
            .navigation_override => "navigation-override",
            .otp_credentials => "otp-credentials",
            .publickey_credentials_get => "publickey-credentials-get",
            .sync_xhr => "sync-xhr",
            .unload => "unload",
            .web_share => "web-share",
            .browsing_topics => "browsing-topics",
            .deferred_fetch => "deferred-fetch",
            .deferred_fetch_minimal => "deferred-fetch-minimal",
            .cross_origin_isolated => "cross-origin-isolated",
        };
    }

    /// Parse a feature name from a string
    pub fn fromString(name: []const u8) ?Feature {
        // Normalize by lowercasing
        inline for (std.meta.fields(Feature)) |field| {
            const feature: Feature = @enumFromInt(field.value);
            if (std.ascii.eqlIgnoreCase(name, feature.toString())) {
                return feature;
            }
        }
        return null;
    }

    /// Get the default allowlist for this feature
    /// Spec: https://www.w3.org/TR/permissions-policy/#default-allowlist
    pub fn defaultAllowlist(self: Feature) DefaultAllowlist {
        return switch (self) {
            // Features that default to self (most restrictive common default)
            .camera,
            .microphone,
            .geolocation,
            .display_capture,
            .battery,
            .bluetooth,
            .usb,
            .hid,
            .serial,
            .midi,
            .xr_spatial_tracking,
            .idle_detection,
            .otp_credentials,
            .publickey_credentials_get,
            .local_fonts,
            => .self_origin,

            // Features that default to * (most permissive)
            .autoplay,
            .deferred_fetch_minimal,
            .fullscreen,
            .picture_in_picture,
            .document_domain,
            .encrypted_media,
            .gamepad,
            .sync_xhr,
            .web_share,
            => .all,

            // Features that default to self
            else => .self_origin,
        };
    }
};

/// Default allowlist type
pub const DefaultAllowlist = enum {
    /// "*" - All origins allowed
    all,
    /// "self" - Only same-origin allowed
    self_origin,
    /// "()" - No origins allowed
    none,
};

// ============================================================================
// Allowlist
// ============================================================================

/// Permissions Policy §4.7. Retains every origin record it stores; the
/// inherited-policy map never retains a parent Document or policy.
pub const Allowlist = struct {
    allow_all: bool = false,
    // Compatibility for the string-only allowSelf API. Parsed declarations
    // always capture their self-origin explicitly instead.
    allow_self: bool = false,
    self_origin: ?*origins.OriginRecord = null,
    src_origin: ?*origins.OriginRecord = null,
    exact_origins: std.ArrayListUnmanaged(*origins.OriginRecord) = .empty,
    expressions: std.ArrayListUnmanaged(csp.SourceExpression) = .empty,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Allowlist {
        return .{ .allocator = allocator };
    }
    pub fn allowAll(allocator: Allocator) Allowlist {
        return .{ .allocator = allocator, .allow_all = true };
    }
    pub fn allowSelf(allocator: Allocator) Allowlist {
        return .{ .allocator = allocator, .allow_self = true };
    }
    pub fn allowNone(allocator: Allocator) Allowlist {
        return init(allocator);
    }
    pub fn setSelfOrigin(self: *Allowlist, origin: *origins.OriginRecord) void {
        const retained = origin.retain();
        if (self.self_origin) |old| old.release();
        self.self_origin = retained;
    }
    pub fn setSrcOrigin(self: *Allowlist, origin: *origins.OriginRecord) void {
        const retained = origin.retain();
        if (self.src_origin) |old| old.release();
        self.src_origin = retained;
    }
    pub fn addOrigin(self: *Allowlist, text: []const u8) !void {
        // §9.2 accepts only permissions-source-expression. Ports larger
        // than a URL can hold are valid grammar but match no URL (Q20).
        const validity = csp.parsing.classifyPermissionsSourceExpression(text);
        if (isExactOriginExpression(text, validity)) {
            var url = basic_parser.parse(self.allocator, text, null) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return,
            };
            defer url.deinit();
            var parsed_origin = url_origin.getOrigin(self.allocator, &url) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return,
            };
            defer parsed_origin.deinit(self.allocator);
            // ipv4_serializer.zig:26 inserts each octet at idx <= the
            // current length, and separators at 0; bounds cannot fail (Q53).
            const serialized = parsed_origin.serialize(self.allocator) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.IndexOutOfBounds => unreachable,
            };
            defer self.allocator.free(serialized);
            if (!std.mem.eql(u8, serialized, "null")) try self.addExactOrigin(serialized);
            return;
        }
        if (validity != .valid) return;
        var expression = try csp.parseSourceExpression(self.allocator, text);
        errdefer expression.deinit();
        try self.expressions.append(self.allocator, expression);
    }
    /// §4.7: a canonical origin entry uses same-origin equality, including
    /// IP literals. It does not use CSP's HTTP-to-HTTPS scheme upgrade.
    fn addExactOrigin(self: *Allowlist, serialized: []const u8) !void {
        const origin = try origins.OriginRecord.create(self.allocator, serialized);
        errdefer origin.release();
        try self.exact_origins.append(self.allocator, origin);
    }
    pub fn isAllowed(self: *const Allowlist, origin: []const u8, self_origin: []const u8) bool {
        return self.matches(.{ .serialized = origin }, .{ .serialized = self_origin });
    }
    /// A construction-time copy for deferred inheritance. Tuple domains are
    /// frozen; an opaque record supplies identity only and retains no realm.
    fn frozenCopy(self: *const Allowlist, allocator: Allocator) !Allowlist {
        var copy: Allowlist = .{ .allocator = allocator, .allow_all = self.allow_all, .allow_self = self.allow_self };
        errdefer copy.deinit();
        if (self.self_origin) |origin| copy.self_origin = try frozenOrigin(allocator, origin);
        if (self.src_origin) |origin| copy.src_origin = try frozenOrigin(allocator, origin);
        for (self.exact_origins.items) |origin| try copy.addExactOrigin(origin.serialized.?);
        for (self.expressions.items) |expression| try copy.addOrigin(expression.raw_value);
        return copy;
    }
    pub fn matches(self: *const Allowlist, origin: origins.Origin, document_origin: origins.Origin) bool {
        // §4.7 steps 1-4. A wildcard includes opaque origins, whereas a
        // serialized "null" has no identity. self/src compare origin-domain.
        if (self.allow_all) return true;
        if (self.self_origin) |self_record| {
            if (origins.sameOriginDomain(originView(self_record), origin)) return true;
        } else if (self.allow_self and origins.sameOriginDomain(document_origin, origin)) return true;
        if (self.src_origin) |src| if (origins.sameOriginDomain(originView(src), origin)) return true;
        if (std.mem.eql(u8, origin.serialized, "null")) return false;
        // 5. Exact origin entries compare their canonical tuples. Attribute
        // URLs and exact header origins use this path (Q33-Q35).
        for (self.exact_origins.items) |entry| if (origins.sameOrigin(originView(entry), origin)) return true;
        // 5-6. Other source expressions retain CSP's existing matcher.
        // Origin serializations are canonical URLs.
        const url = fetch.algorithms.csp_check.urlParts(origin.serialized);
        const host = url.host orelse "";
        const path = if (url.path.len == 0) "/" else url.path;
        const self_url: csp.types.Origin = .{ .scheme = url.scheme, .host = host, .port = url.port };
        for (self.expressions.items) |*expression| {
            if (csp.doesUrlMatchExpression(url.scheme, host, url.port, path, expression, &self_url, 0)) return true;
        }
        return false;
    }
    pub fn deinit(self: *Allowlist) void {
        if (self.self_origin) |origin| origin.release();
        if (self.src_origin) |origin| origin.release();
        for (self.exact_origins.items) |origin| origin.release();
        self.exact_origins.deinit(self.allocator);
        for (self.expressions.items) |*expression| expression.deinit();
        self.expressions.deinit(self.allocator);
        self.self_origin = null;
        self.src_origin = null;
    }
};

/// §9.2's grammar still gates header entries. Q35 permits bracketed IPv6
/// origins as the sole grammar exception; URL parsing validates their host.
/// An explicit path, even "/", remains a CSP source expression (Q34).
fn isExactOriginExpression(text: []const u8, validity: csp.parsing.PermissionsSourceValidity) bool {
    const scheme_end = std.mem.indexOf(u8, text, "://") orelse return false;
    const authority = text[scheme_end + 3 ..];
    if (authority.len == 0 or std.mem.indexOfAny(u8, authority, "*/?@#%\\ \t\n\r\x0c") != null) return false;
    if (authority[0] != '[') return validity == .valid;
    if (csp.parsing.classifyPermissionsSourceExpression(text[0 .. scheme_end + 1]) != .valid) return false;
    const close = std.mem.indexOfScalar(u8, authority, ']') orelse return false;
    const suffix = authority[close + 1 ..];
    if (suffix.len != 0) {
        if (suffix[0] != ':' or suffix.len == 1) return false;
        for (suffix[1..]) |digit| if (!std.ascii.isDigit(digit)) return false;
        _ = std.fmt.parseInt(u16, suffix[1..], 10) catch return false;
    }
    return true;
}

fn originView(origin: *const origins.OriginRecord) origins.Origin {
    return .{ .serialized = origin.serialized orelse "null", .record = origin };
}

fn frozenOrigin(allocator: Allocator, origin: *origins.OriginRecord) !*origins.OriginRecord {
    // Identity is the whole meaning of an opaque origin; no mutable domain
    // participates. The native hold cannot keep a Document or realm alive.
    if (origin.isOpaque()) return origin.retain();
    const copy = if (origin.serialized) |serialized|
        try origins.OriginRecord.create(allocator, serialized)
    else
        try origins.OriginRecord.createOwn(allocator);
    errdefer copy.release();
    if (origin.domain) |domain| try copy.setDomain(domain);
    return copy;
}

// ============================================================================
// Policy Directive
// ============================================================================

/// A policy directive is a feature-allowlist pair
/// Spec: https://www.w3.org/TR/permissions-policy/#policy-directive
pub const PolicyDirective = struct {
    feature: Feature,
    allowlist: Allowlist,

    const Self = @This();

    pub fn init(allocator: Allocator, feature: Feature) Self {
        return .{
            .feature = feature,
            .allowlist = Allowlist.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allowlist.deinit();
    }
};

// ============================================================================
// Permissions Policy
// ============================================================================

/// Permissions Policy §§9.1-9.9. Inherited enabled bits are a VALUE
/// snapshot. Declared allowlists and reporting endpoints are independently
/// owned. Chromium PermissionsPolicy::CreateFromParentPolicy and
/// GetFeatureValueForOrigin (33aa7cdb) use this separation; no code copied.
pub const PermissionsPolicy = struct {
    disabled_inherited: std.enums.EnumSet(Feature) = .initEmpty(),
    // tombstones: bounded by Feature; populated at construction, then the
    // one-time lazy inheritance resolution only removes, never reinserts.
    declared_policy: std.AutoHashMap(Feature, Allowlist),
    reporting: std.AutoHashMap(Feature, []const u8),
    origin_record: *origins.OriginRecord,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, serialized_origin: []const u8) !Self {
        const record = try origins.OriginRecord.create(allocator, serialized_origin);
        defer record.release();
        return initWithOrigin(allocator, record);
    }
    /// BORROWS origin; the new policy keeps its own hold.
    pub fn initWithOrigin(allocator: Allocator, record: *origins.OriginRecord) Self {
        return .{
            .declared_policy = std.AutoHashMap(Feature, Allowlist).init(allocator),
            .reporting = std.AutoHashMap(Feature, []const u8).init(allocator),
            .origin_record = record.retain(),
            .allocator = allocator,
        };
    }
    pub fn origin(self: *const Self) origins.Origin {
        return originView(self.origin_record);
    }
    pub fn fromHeader(allocator: Allocator, header: []const u8, serialized_origin: []const u8) !Self {
        var policy = try init(allocator, serialized_origin);
        errdefer policy.deinit();
        try policy.parseHeader(header);
        return policy;
    }
    /// §§9.5-9.6. Every parameter is borrowed; no parent/container pointer
    /// remains in the returned policy. Headers are fully parsed before return.
    pub fn fromNavigable(allocator: Allocator, document_origin: *origins.OriginRecord, parent: ?*const Self, container: ?*const Self, header: ?[]const u8) !Self {
        var policy = initWithOrigin(allocator, document_origin);
        errdefer policy.deinit();
        inline for (std.meta.fields(Feature)) |field| {
            const feature: Feature = @enumFromInt(field.value);
            if (!inheritedValue(feature, parent, container, policy.origin())) policy.disabled_inherited.insert(feature);
        }
        if (header) |value| try policy.parseHeader(value);
        return policy;
    }
    /// §9.7: inherited policy for a feature in a container at origin.
    pub fn inheritedValue(feature: Feature, parent: ?*const Self, container: ?*const Self, target: origins.Origin) bool {
        // 1. A top-level navigable starts enabled.
        const parent_policy = parent orelse return true;
        // 2-3. Parent feature values do NOT apply its default allowlist.
        if (!parent_policy.featureValueForOrigin(feature, parent_policy.origin()) or
            !parent_policy.featureValueForOrigin(feature, target)) return false;
        // 4-5. A declared container allowlist overrides only the default.
        if (container) |policy| if (policy.declared_policy.getPtr(feature)) |allowlist| {
            return allowlist.matches(target, parent_policy.origin());
        };
        // 6-8. Defaults are applied here, independently of parent declarations.
        return switch (feature.defaultAllowlist()) {
            .all => true,
            .self_origin => origins.sameOrigin(target, parent_policy.origin()),
            .none => false,
        };
    }
    /// §§9.1-9.2. A malformed dictionary makes the entire header absent.
    fn parseHeader(self: *Self, header: []const u8) !void {
        var dictionary = fetch.internal.structured_fields.parsePolicyDictionary(self.allocator, header) catch |err| switch (err) {
            error.InvalidField => return,
            else => return err,
        };
        defer dictionary.deinit(self.allocator);
        for (dictionary.members.items) |member| {
            const feature = recognizedFeature(member.key) orelse continue;
            // §9.2.3.3; §9.6.4 keeps reporting configuration even when the
            // feature is already disabled by inheritance.
            if (member.report_to) |endpoint| {
                const copy = try self.allocator.dupe(u8, endpoint);
                errdefer self.allocator.free(copy);
                const entry = try self.reporting.getOrPut(feature);
                if (entry.found_existing) self.allocator.free(entry.value_ptr.*);
                entry.value_ptr.* = copy;
            }
            if (self.disabled_inherited.contains(feature)) continue;
            var allowlist = Allowlist.init(self.allocator);
            errdefer allowlist.deinit();
            // A scalar String is a one-item list, per §5.2 and Chromium's
            // ParsePermissionsPolicyToIR at 33aa7cdb (liaison Q20).
            for (member.items) |item| switch (item) {
                .token => |token| {
                    if (std.mem.eql(u8, token, "*")) allowlist.allow_all = true else if (std.mem.eql(u8, token, "self")) allowlist.setSelfOrigin(self.origin_record);
                },
                .string => |value| try allowlist.addOrigin(value),
            };
            const entry = try self.declared_policy.getOrPut(feature);
            if (entry.found_existing) entry.value_ptr.deinit();
            entry.value_ptr.* = allowlist;
        }
    }
    pub fn fromAllowAttribute(allocator: Allocator, value: []const u8, container_origin: []const u8, content_origin: []const u8) !Self {
        const container = try origins.OriginRecord.create(allocator, container_origin);
        defer container.release();
        const content = try origins.OriginRecord.create(allocator, content_origin);
        defer content.release();
        return fromAllowAttributeOrigins(allocator, value, container, content);
    }
    /// §9.3. BORROWS the records; declarations retain those they refer to.
    pub fn fromAllowAttributeOrigins(allocator: Allocator, value: []const u8, container_origin: *origins.OriginRecord, target_origin: ?*origins.OriginRecord) !Self {
        var policy = initWithOrigin(allocator, target_origin orelse container_origin);
        errdefer policy.deinit();
        var declarations = std.mem.splitScalar(u8, value, ';');
        while (declarations.next()) |declaration| {
            var tokens = std.mem.tokenizeAny(u8, declaration, " \t\n\r\x0c");
            const feature = recognizedFeature(tokens.next() orelse continue) orelse continue;
            // 2.6: the FIRST declaration of a feature wins in an attribute.
            if (policy.declared_policy.contains(feature)) continue;
            var allowlist = Allowlist.init(allocator);
            errdefer allowlist.deinit();
            var probe = tokens;
            while (probe.next()) |token| if (std.mem.eql(u8, token, "*")) {
                allowlist.allow_all = true;
                break;
            };
            if (!allowlist.allow_all) {
                var any = false;
                while (tokens.next()) |token| {
                    any = true;
                    if (std.ascii.eqlIgnoreCase(token, "'self'")) {
                        allowlist.setSelfOrigin(container_origin);
                    } else if (std.ascii.eqlIgnoreCase(token, "'src'")) {
                        if (target_origin) |target| allowlist.setSrcOrigin(target);
                    } else {
                        // 2.10.2.3-7: parse a URL, reject blob and credentials,
                        // and retain only its nonopaque origin serialization.
                        var url = basic_parser.parse(allocator, token, null) catch |err| switch (err) {
                            error.OutOfMemory => return error.OutOfMemory,
                            else => continue,
                        };
                        defer url.deinit();
                        if (std.mem.eql(u8, url.scheme(), "blob") or url.username().len != 0 or url.password().len != 0) continue;
                        var parsed_origin = url_origin.getOrigin(allocator, &url) catch |err| switch (err) {
                            error.OutOfMemory => return error.OutOfMemory,
                            else => continue,
                        };
                        defer parsed_origin.deinit(allocator);
                        // ipv4_serializer.zig:26 inserts each octet at idx <= the
                        // current length, and separators at 0; bounds cannot fail (Q53).
                        const serialized = parsed_origin.serialize(allocator) catch |err| switch (err) {
                            error.OutOfMemory => return error.OutOfMemory,
                            error.IndexOutOfBounds => unreachable,
                        };
                        defer allocator.free(serialized);
                        if (!std.mem.eql(u8, serialized, "null")) try allowlist.addExactOrigin(serialized);
                    }
                }
                // 2.10.1: a missing allowlist means the target/src origin.
                if (!any) if (target_origin) |target| allowlist.setSrcOrigin(target);
            }
            try policy.declared_policy.put(feature, allowlist);
        }
        return policy;
    }
    /// §9.8. No declaration means Enabled, regardless of default allowlist.
    pub fn featureValueForOrigin(self: *const Self, feature: Feature, target: origins.Origin) bool {
        if (self.disabled_inherited.contains(feature)) return false;
        if (self.declared_policy.getPtr(feature)) |allowlist| return allowlist.matches(target, self.origin());
        return true;
    }
    /// §9.9. The default allowlist applies only after inherited/declared checks.
    pub fn isFeatureAllowedForOrigin(self: *const Self, feature: Feature, target: origins.Origin) bool {
        if (self.disabled_inherited.contains(feature)) return false;
        if (self.declared_policy.getPtr(feature)) |allowlist| return allowlist.matches(target, self.origin());
        return switch (feature.defaultAllowlist()) {
            .all => true,
            .self_origin => origins.sameOrigin(target, self.origin()),
            .none => false,
        };
    }
    pub fn isFeatureAllowed(self: *const Self, feature: Feature, serialized_origin: []const u8) bool {
        return self.isFeatureAllowedForOrigin(feature, .{ .serialized = serialized_origin });
    }
    pub fn isFeatureAllowedForSelf(self: *const Self, feature: Feature) bool {
        return self.isFeatureAllowedForOrigin(feature, self.origin());
    }
    /// Compatibility for native callers: snapshot inheritance with no container
    /// declaration. A later change/destruction of parent cannot affect this.
    pub fn setInheritedPolicy(self: *Self, parent: *const Self) void {
        self.disabled_inherited = .initEmpty();
        inline for (std.meta.fields(Feature)) |field| {
            const feature: Feature = @enumFromInt(field.value);
            if (!inheritedValue(feature, parent, null, self.origin())) self.disabled_inherited.insert(feature);
        }
    }
    /// Only feature values are needed by a child's inherited-policy
    /// snapshot. Reporting endpoints stay with their original Document.
    fn frozenCopy(self: *const Self, allocator: Allocator) !Self {
        const record = try frozenOrigin(allocator, self.origin_record);
        defer record.release();
        var copy = initWithOrigin(allocator, record);
        errdefer copy.deinit();
        copy.disabled_inherited = self.disabled_inherited;
        var entries = self.declared_policy.iterator();
        while (entries.next()) |entry| {
            var allowlist = try entry.value_ptr.frozenCopy(allocator);
            errdefer allowlist.deinit();
            try copy.declared_policy.put(entry.key_ptr.*, allowlist);
        }
        return copy;
    }
    pub fn deinit(self: *Self) void {
        var declared = self.declared_policy.valueIterator();
        while (declared.next()) |allowlist| allowlist.deinit();
        self.declared_policy.deinit();
        var endpoints = self.reporting.valueIterator();
        while (endpoints.next()) |endpoint| self.allocator.free(endpoint.*);
        self.reporting.deinit();
        self.origin_record.release();
    }
};

fn recognizedFeature(name: []const u8) ?Feature {
    const feature = Feature.fromString(name) orelse return null;
    return if (std.mem.eql(u8, name, feature.toString())) feature else null;
}

/// Borrowed response header values, parsed before a Document's scripts run.
pub const Headers = struct {
    enforce: ?[]const u8 = null,
    report_only: ?[]const u8 = null,
};

/// The response-to-document handoff owns both header values together.
/// This is not a Fetch policy container: Permissions Policy is a separate
/// Document construction fact (HTML create-and-initialize step 9).
pub const OwnedHeaders = struct {
    values: Headers = .{},
    allocator: Allocator,

    pub fn fromValues(allocator: Allocator, values: Headers) !OwnedHeaders {
        var result: OwnedHeaders = .{ .allocator = allocator };
        errdefer result.deinit();
        if (values.enforce) |value| result.values.enforce = try allocator.dupe(u8, value);
        if (values.report_only) |value| result.values.report_only = try allocator.dupe(u8, value);
        return result;
    }

    pub fn fromResponse(allocator: Allocator, response: *const fetch.internal.InternalResponse) !OwnedHeaders {
        var result: OwnedHeaders = .{ .allocator = allocator };
        errdefer result.deinit();
        result.values.enforce = try response.header_list.get(allocator, "Permissions-Policy");
        result.values.report_only = try response.header_list.get(allocator, "Permissions-Policy-Report-Only");
        return result;
    }

    pub fn deinit(self: *OwnedHeaders) void {
        if (self.values.enforce) |value| self.allocator.free(value);
        if (self.values.report_only) |value| self.allocator.free(value);
        self.values = .{};
    }
};

pub const Disposition = enum { enforce, report };
pub const Violation = struct {
    disposition: Disposition,
    /// BORROWED from the policy until it is destroyed.
    endpoint: ?[]const u8,
};
pub const Check = struct { enabled: bool, violation: ?Violation = null };

/// A Document's enforcing and report-only policies (Permissions Policy §9.6).
/// Each owns its origin holds, declarations and reporting configuration.
pub const Policies = struct {
    enforce: PermissionsPolicy,
    report_only: PermissionsPolicy,
    pending_inheritance: ?*InheritedSnapshot = null,

    /// A fresh, parentless policy with no response declarations. Does not
    /// allocate; each policy retains the BORROWED origin record.
    pub fn init(allocator: Allocator, origin: *origins.OriginRecord) Policies {
        return .{
            .enforce = PermissionsPolicy.initWithOrigin(allocator, origin),
            .report_only = PermissionsPolicy.initWithOrigin(allocator, origin),
        };
    }

    pub fn fromHeaders(allocator: Allocator, origin: *origins.OriginRecord, parent: ?*Policies, container: ?*const PermissionsPolicy, headers: Headers) !Policies {
        // §9.7.1 enables every inherited value for a parentless document;
        // without response declarations this is exactly the empty pair.
        if (parent == null and headers.enforce == null and headers.report_only == null) return init(allocator, origin);
        // §9.6.1 -> §9.5.3 -> §9.7: report-only defaults to False in BOTH
        // constructions. Only §9.6.2 selects a different response header.
        // The child report-only policy therefore inherits the parent's
        // ENFORCED values, not the parent's report-only declarations (Q23).
        if (parent) |policies| if (policies.pending_inheritance != null) {
            // The Document-side caller resolves the parent with its actual
            // origin before capturing it. Never invent an opaque origin for
            // an unresolved parent or retain recursive policy ancestry.
            if (policies.enforce.origin_record.serialized == null) return error.UnresolvedParentPolicy;
            try policies.resolveOrigin(policies.enforce.origin());
        };
        const deferred = parent != null and origin.serialized == null;
        const inherited = if (!deferred) (if (parent) |policies| &policies.enforce else null) else null;
        var enforcing = try PermissionsPolicy.fromNavigable(allocator, origin, inherited, container, headers.enforce);
        errdefer enforcing.deinit();
        var result: Policies = .{
            .enforce = enforcing,
            .report_only = try PermissionsPolicy.fromNavigable(allocator, origin, inherited, container, headers.report_only),
        };
        // Once the pair owns enforcing, only the report-only half belongs
        // to this new errdefer; the earlier one still unwinds enforcing.
        errdefer result.report_only.deinit();
        if (deferred) result.pending_inheritance = try InheritedSnapshot.capture(allocator, &parent.?.enforce, container, origin);
        return result;
    }

    /// §§9.10-9.11: compute both policy answers; enforcing denial wins the
    /// reporting choice. The caller queues the report only for actual use.
    pub fn check(self: *Policies, feature: Feature, origin: origins.Origin) error{OutOfMemory}!Check {
        try self.resolveOrigin(origin);
        const enabled = self.enforce.isFeatureAllowedForOrigin(feature, origin);
        const report_enabled = self.report_only.isFeatureAllowedForOrigin(feature, origin);
        if (!enabled) return .{ .enabled = false, .violation = .{
            .disposition = .enforce,
            .endpoint = self.enforce.reporting.get(feature),
        } };
        if (!report_enabled) return .{ .enabled = true, .violation = .{
            .disposition = .report,
            .endpoint = self.report_only.reporting.get(feature),
        } };
        return .{ .enabled = true };
    }

    /// Known-origin construction already did this. The exceptional lazy
    /// path completes the saved target's serialization, computes §9.7 ONCE,
    /// and frees the independent snapshot (Q24/Q25).
    pub fn resolveOrigin(self: *Policies, origin: origins.Origin) error{OutOfMemory}!void {
        const snapshot = self.pending_inheritance orelse return;
        try snapshot.child_origin.resolve(origin.serialized);
        // Opaque identity comes from the actual origin; tuple comparison
        // uses the construction-time domain copied into child_origin.
        const target = if (std.mem.eql(u8, origin.serialized, "null")) origin else originView(snapshot.child_origin);
        var disabled: std.enums.EnumSet(Feature) = .initEmpty();
        inline for (std.meta.fields(Feature)) |field| {
            const feature: Feature = @enumFromInt(field.value);
            if (!PermissionsPolicy.inheritedValue(feature, &snapshot.parent, if (snapshot.container) |*container| container else null, target)) disabled.insert(feature);
        }
        self.enforce.disabled_inherited = disabled;
        self.report_only.disabled_inherited = disabled;
        // §9.6.3: declarations disabled by inherited policy are omitted in
        // both policies. The lazy path must do the same as parseHeader;
        // §9.6.4 still retains both reporting configurations.
        var features = disabled.iterator();
        while (features.next()) |feature| {
            if (self.enforce.declared_policy.fetchRemove(feature)) |entry| {
                var removed = entry.value;
                removed.deinit();
            }
            if (self.report_only.declared_policy.fetchRemove(feature)) |entry| {
                var removed = entry.value;
                removed.deinit();
            }
        }
        self.pending_inheritance = null;
        snapshot.destroy();
    }

    pub fn deinit(self: *Policies) void {
        if (self.pending_inheritance) |snapshot| snapshot.destroy();
        self.pending_inheritance = null;
        self.enforce.deinit();
        self.report_only.deinit();
    }
};

const InheritedSnapshot = struct {
    allocator: Allocator,
    parent: PermissionsPolicy,
    container: ?PermissionsPolicy,
    child_origin: *origins.OriginRecord,

    fn capture(allocator: Allocator, parent: *const PermissionsPolicy, container: ?*const PermissionsPolicy, child_origin: *origins.OriginRecord) !*InheritedSnapshot {
        var captured_parent = try parent.frozenCopy(allocator);
        errdefer captured_parent.deinit();
        var captured_container: ?PermissionsPolicy = null;
        if (container) |policy| captured_container = try policy.frozenCopy(allocator);
        errdefer if (captured_container) |*policy| policy.deinit();
        const captured_origin = try frozenOrigin(allocator, child_origin);
        errdefer captured_origin.release();
        const result = try allocator.create(InheritedSnapshot);
        result.* = .{ .allocator = allocator, .parent = captured_parent, .container = captured_container, .child_origin = captured_origin };
        return result;
    }

    fn destroy(self: *InheritedSnapshot) void {
        self.parent.deinit();
        if (self.container) |*policy| policy.deinit();
        self.child_origin.release();
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Policy Enforcement
// ============================================================================

/// Error for policy violations
pub const PermissionsPolicyError = error{
    /// Feature is not allowed by the policy
    NotAllowedError,
};

/// Check if a feature is enabled and throw if not
pub fn requireFeature(policy: *const PermissionsPolicy, feature: Feature) PermissionsPolicyError!void {
    if (!policy.isFeatureAllowedForSelf(feature)) {
        return error.NotAllowedError;
    }
}

/// Report a policy violation (for console/DevTools)
pub const PolicyViolation = struct {
    feature: Feature,
    policy_origin: []const u8,
    requesting_origin: []const u8,
    message: []const u8,
};

/// Create a violation report for a blocked feature
pub fn createViolationReport(
    allocator: Allocator,
    feature: Feature,
    policy_origin: []const u8,
    requesting_origin: []const u8,
) !PolicyViolation {
    const message = try std.fmt.allocPrint(
        allocator,
        "Feature '{s}' is not allowed in this document. " ++
            "Origin '{s}' is not in the allowlist for origin '{s}'.",
        .{ feature.toString(), requesting_origin, policy_origin },
    );

    return .{
        .feature = feature,
        .policy_origin = policy_origin,
        .requesting_origin = requesting_origin,
        .message = message,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "Feature.fromString" {
    try std.testing.expectEqual(Feature.geolocation, Feature.fromString("geolocation").?);
    try std.testing.expectEqual(Feature.camera, Feature.fromString("camera").?);
    try std.testing.expectEqual(Feature.ambient_light_sensor, Feature.fromString("ambient-light-sensor").?);
    try std.testing.expect(Feature.fromString("nonexistent-feature") == null);
}

test "Allowlist - basic operations" {
    const allocator = std.testing.allocator;

    var allow_all = Allowlist.allowAll(allocator);
    defer allow_all.deinit();
    try std.testing.expect(allow_all.isAllowed("https://example.com", "https://self.com"));

    var allow_self = Allowlist.allowSelf(allocator);
    defer allow_self.deinit();
    try std.testing.expect(allow_self.isAllowed("https://self.com", "https://self.com"));
    try std.testing.expect(!allow_self.isAllowed("https://other.com", "https://self.com"));

    var allow_none = Allowlist.allowNone(allocator);
    defer allow_none.deinit();
    try std.testing.expect(!allow_none.isAllowed("https://example.com", "https://self.com"));
}

test "Allowlist - specific origins" {
    const allocator = std.testing.allocator;

    var allowlist = Allowlist.init(allocator);
    defer allowlist.deinit();

    try allowlist.addOrigin("https://allowed.com");
    try allowlist.addOrigin("https://also-allowed.com");

    try std.testing.expect(allowlist.isAllowed("https://allowed.com", "https://self.com"));
    try std.testing.expect(allowlist.isAllowed("https://also-allowed.com", "https://self.com"));
    try std.testing.expect(!allowlist.isAllowed("https://not-allowed.com", "https://self.com"));
}

test "PermissionsPolicy - default allowlists" {
    const allocator = std.testing.allocator;

    var policy = try PermissionsPolicy.init(allocator, "https://example.com");
    defer policy.deinit();

    // Geolocation defaults to self
    try std.testing.expect(policy.isFeatureAllowed(.geolocation, "https://example.com"));
    try std.testing.expect(!policy.isFeatureAllowed(.geolocation, "https://other.com"));

    // Fullscreen defaults to *
    try std.testing.expect(policy.isFeatureAllowed(.fullscreen, "https://example.com"));
    try std.testing.expect(policy.isFeatureAllowed(.fullscreen, "https://other.com"));
}

test "PermissionsPolicy - fromHeader" {
    const allocator = std.testing.allocator;

    var policy = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(), camera=(self)",
        "https://example.com",
    );
    defer policy.deinit();

    // Geolocation is disabled (empty allowlist)
    try std.testing.expect(!policy.isFeatureAllowed(.geolocation, "https://example.com"));

    // Camera is allowed for self only
    try std.testing.expect(policy.isFeatureAllowed(.camera, "https://example.com"));
    try std.testing.expect(!policy.isFeatureAllowed(.camera, "https://other.com"));
}

test "PermissionsPolicy - fromHeader with specific origins" {
    const allocator = std.testing.allocator;

    var policy = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(self \"https://trusted.com\")",
        "https://example.com",
    );
    defer policy.deinit();

    try std.testing.expect(policy.isFeatureAllowed(.geolocation, "https://example.com"));
    try std.testing.expect(policy.isFeatureAllowed(.geolocation, "https://trusted.com"));
    try std.testing.expect(!policy.isFeatureAllowed(.geolocation, "https://untrusted.com"));
}

test "PermissionsPolicy - inheritance" {
    const allocator = std.testing.allocator;

    // Parent policy allows geolocation only for self
    var parent = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(self)",
        "https://parent.com",
    );
    defer parent.deinit();

    // Child policy allows geolocation for all
    var child = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(*)",
        "https://child.com",
    );
    defer child.deinit();

    child.setInheritedPolicy(&parent);

    // Child can't grant more than parent allows
    // Parent only allows "self" (parent.com), so child.com is not allowed
    try std.testing.expect(!child.isFeatureAllowed(.geolocation, "https://child.com"));
    // §9.7 disables the child feature itself, for every queried origin.
    try std.testing.expect(!child.isFeatureAllowed(.geolocation, "https://parent.com"));
}
