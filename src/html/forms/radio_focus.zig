//! Radio-group eligibility in HTML 6.6.5 sequential focus navigation.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const associated = @import("../form_associated.zig");
const focus = @import("../focus.zig");

fn isRadio(element: *runtime.Instance) bool {
    if (!associated.isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    return std.mem.eql(u8, associated.inputType(element, &buffer), "radio");
}

/// Borrowed only during this read-only walk; no script or mutation runs.
fn nameOf(element: *runtime.Instance) []const u8 {
    const data = dom.element_data.of(element) orelse return "";
    const index = data.indexOfQualifiedName("name") orelse return "";
    return (data.attributeAt(index) orelse return "").value;
}

/// HTML 4.10.5.1.15 defines a group by non-empty name, form owner and tree.
/// HTML 6.6.3 leaves sequential eligibility to platform conventions; 6.6.5's
/// sequential-navigation search chooses only eligible areas. Chrome/Firefox
/// pass the radio-focus-navigation-group-* WPTs (23b0b89b1a), Safari differs.
/// Blink RadioInputType::IsKeyboardFocusableSlow prioritizes the eligible
/// checked member, then the focused member; Gecko HTMLInputElement::
/// IsHTMLFocusable chooses checked-or-first. Keep these decisions out of
/// general focusability: script and arrow navigation can focus other members.
///
/// This stateless policy uses the current designation, not Blink's persistent
/// LastFocusedButtonForGroup. Remembering an unchecked member after focus
/// leaves the group needs a separately owned lifetime mechanism (row72 Q3).
pub fn isSequentialRepresentative(element: *runtime.Instance) bool {
    if (!isRadio(element)) return true;
    const name = nameOf(element);
    if (name.len == 0) return true;
    // The caller already established this element's sequential eligibility.
    if (interfaces.HTMLInputElement.get_checked(element) catch false) return true;
    const root = associated.rootOf(element);
    const owner = associated.formOwner(element);
    const document = interfaces.Node.get_ownerDocument(element) catch null;
    const designated = if (document) |doc| focus.designatedAreaOf(doc) else null;
    var first: ?*runtime.Instance = null;
    var focused: ?*runtime.Instance = null;
    var node: ?*runtime.Instance = root;
    while (node) |candidate| : (node = associated.nextInTree(candidate, root, false)) {
        if (!isRadio(candidate) or !std.mem.eql(u8, nameOf(candidate), name) or
            associated.formOwner(candidate) != owner) continue;
        if (!focus.isFocusableArea(candidate)) continue;
        if (candidate == designated) focused = candidate;
        if ((focus.tabindexValue(candidate) orelse 0) < 0) continue;
        if (interfaces.HTMLInputElement.get_checked(candidate) catch false) return candidate == element;
        if (first == null) first = candidate;
    }
    return (focused orelse first) == element;
}

/// A summary borrowed ONLY by one synchronous sequentialOrder call. There
/// is no script entry here: attributes, interface getters and focusability
/// are native reads, with no dispatch, callback or queue. Destroy this map
/// before entering script or focusing anything. The native parity test also
/// asserts that event listeners and script accessors are never invoked.
/// That checks this helper's paths, not an engine-wide guarantee; extend the
/// test if a new interface call can reach script.
///
/// This is not persistent group state: rebuilding for each navigation keeps
/// checkedness, focus, names, form owners and eligibility current. Q15's
/// measured Tab timeout showed why scanning every group for every radio in
/// both order passes is unacceptable; summarize each radio once instead.
pub const Navigation = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    groups: Groups = .{},
    attempted: bool = false,
    failed: bool = false,

    const Key = struct { name: []const u8, owner: ?*runtime.Instance };
    const Group = struct {
        checked: ?*runtime.Instance = null,
        focused: ?*runtime.Instance = null,
        first: ?*runtime.Instance = null,

        fn representative(self: Group) ?*runtime.Instance {
            return self.checked orelse self.focused orelse self.first;
        }
    };
    const KeyContext = struct {
        pub fn hash(_: @This(), key: Key) u64 {
            return std.hash.Wyhash.hash(if (key.owner) |owner| @intFromPtr(owner) else 0, key.name);
        }
        pub fn eql(_: @This(), a: Key, b: Key) bool {
            return a.owner == b.owner and std.mem.eql(u8, a.name, b.name);
        }
    };
    const Groups = std.HashMapUnmanaged(Key, Group, KeyContext, std.hash_map.default_max_load_percentage);

    pub fn init(allocator: std.mem.Allocator, document: *runtime.Instance) Navigation {
        return .{ .allocator = allocator, .document = document };
    }

    pub fn deinit(self: *Navigation) void {
        self.groups.deinit(self.allocator);
    }

    /// Null requests the ordinary eligibility path (including the existing
    /// radio scan on OOM). Non-radio pages never build or allocate a map.
    pub fn eligibility(self: *Navigation, element: *runtime.Instance) ?bool {
        if (!isRadio(element)) return null;
        const name = nameOf(element);
        if (name.len == 0) return null;
        if ((focus.tabindexValue(element) orelse 0) < 0) return false;
        if (!self.attempted) {
            self.attempted = true;
            self.populate() catch {
                self.groups.deinit(self.allocator);
                self.groups = .{};
                self.failed = true;
            };
        }
        if (self.failed) return null;
        const group = self.groups.get(.{ .name = name, .owner = associated.formOwner(element) }) orelse return false;
        return group.representative() == element;
    }

    fn populate(self: *Navigation) std.mem.Allocator.Error!void {
        const designated = focus.designatedAreaOf(self.document);
        // Every candidate is in this document's tree, the third group key.
        var node = associated.nextInTree(self.document, self.document, false);
        while (node) |candidate| : (node = associated.nextInTree(candidate, self.document, false)) {
            if (!isRadio(candidate)) continue;
            const name = nameOf(candidate);
            if (name.len == 0 or !focus.isFocusableArea(candidate)) continue;
            const sequential = (focus.tabindexValue(candidate) orelse 0) >= 0;
            if (!sequential and candidate != designated) continue;
            const entry = try self.groups.getOrPut(self.allocator, .{ .name = name, .owner = associated.formOwner(candidate) });
            if (!entry.found_existing) entry.value_ptr.* = .{};
            const group = entry.value_ptr;
            if (candidate == designated) group.focused = candidate;
            if (!sequential) continue;
            if (group.first == null) group.first = candidate;
            if (group.checked == null and (interfaces.HTMLInputElement.get_checked(candidate) catch false)) group.checked = candidate;
        }
    }
};
