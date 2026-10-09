//! HTML 4.10.7: the list of options, shared by selects, options and submission.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const associated = @import("../form_associated.zig");

/// No script runs during this borrowed tree walk. Each caller owns its result.
pub fn forEach(select: *runtime.Instance, context: anytype, comptime visit: fn (@TypeOf(context), *runtime.Instance) anyerror!void) !void {
    // Steps 1–2: start at the select's first child.
    var node = try interfaces.Node.get_firstChild(select);
    while (node) |element| {
        // Step 3.1: append HTML options in tree order. Brand checks borrow
        // state; localName getters would allocate for every node on every read.
        const option = element.stateAs(interfaces.HTMLOptionElement.State) != null;
        if (option) try visit(context, element);
        // Step 3.2: exclude descendants of these elements, including an
        // optgroup with another optgroup between it and this select.
        const skip = option or element.stateAs(interfaces.HTMLSelectElement.State) != null or
            element.stateAs(interfaces.HTMLHRElement.State) != null or element.stateAs(interfaces.HTMLDataListElement.State) != null or
            (element.stateAs(interfaces.HTMLOptGroupElement.State) != null and hasOptgroupAncestor(element, select));
        node = associated.nextInTree(element, select, skip);
    }
}

fn hasOptgroupAncestor(node: *runtime.Instance, select: *runtime.Instance) bool {
    var ancestor = associated.parentOf(node);
    while (ancestor) |element| : (ancestor = associated.parentOf(element)) {
        if (element == select) return false;
        if (element.stateAs(interfaces.HTMLOptGroupElement.State) != null) return true;
    }
    return false;
}

pub fn collect(select: *runtime.Instance, allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(*runtime.Instance)) !void {
    const Collector = struct {
        allocator: std.mem.Allocator,
        out: *std.ArrayListUnmanaged(*runtime.Instance),
        fn append(self: @This(), option: *runtime.Instance) anyerror!void {
            try self.out.append(self.allocator, option);
        }
    };
    try forEach(select, Collector{ .allocator = allocator, .out = out }, Collector.append);
}

const dom = @import("dom");
const engine = @import("engine");
const webidl = @import("webidl");
const NodeBase = dom.NodeBase;

fn nodeBase(node: *runtime.Instance) !*NodeBase {
    return dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse error.InvalidStateError;
}

fn mutationError(err: anyerror) anyerror {
    return switch (err) {
        error.HierarchyRequestError => error.HierarchyRequestError,
        error.NotFoundError => error.NotFoundError,
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

fn insert(parent: *runtime.Instance, node: *runtime.Instance, before: ?*runtime.Instance) !void {
    const child_base: ?*NodeBase = if (before) |child| try nodeBase(child) else null;
    _ = dom.mutation.preInsert(try nodeBase(node), try nodeBase(parent), child_base) catch |err| return mutationError(err);
}

fn removeNode(node: *runtime.Instance) !void {
    if ((try interfaces.Node.get_parentNode(node)) == null) return;
    dom.mutation.remove(try nodeBase(node), false) catch |err| return mutationError(err);
}

/// HTML 2.6.4.3 "append new option elements", steps 1–3. The fragment
/// gives observers one insertion record; internal mutations keep the
/// calling select/collection member's outer CEReactions scope.
fn appendBlank(select: *runtime.Instance, count: u32) !void {
    if (count == 0) return;
    const document = (try interfaces.Node.get_ownerDocument(select)) orelse return error.InvalidStateError;
    const fragment = try interfaces.Document.call_createDocumentFragment(document);
    const generation = runtime.SlabAllocator.generationOf(fragment);
    defer fragment.releaseIfUnwrapped(generation);
    for (0..count) |_| {
        const option = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("option"), .notPassed());
        errdefer dom.node_creation.destroyUninserted(option);
        try insert(fragment, option, null);
    }
    try insert(select, fragment, null);
}

/// HTML 2.6.4.3 length setter, steps 1–3.
pub fn setLength(select: *runtime.Instance, length: u32) !void {
    const allocator = select.ctx.allocator;
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(allocator);
    try collect(select, allocator, &options);
    const current: u32 = @intCast(options.items.len);
    if (length > current) {
        if (length > 100_000) return;
        return appendBlank(select, length - current);
    }
    if (length >= current) return;
    // As in Blink HTMLSelectElement::setLength, snapshot before removals
    // and use each option's current parent. Reactions do not run mid-loop.
    const Removed = struct { instance: *runtime.Instance, generation: u64 };
    const removed = try allocator.alloc(Removed, current - length);
    defer allocator.free(removed);
    for (options.items[length..], removed) |option, *saved| saved.* = .{ .instance = option, .generation = runtime.SlabAllocator.generationOf(option) };
    for (removed) |saved| {
        const option = @import("root.zig").liveChild(saved.instance, saved.generation) orelse continue;
        try removeNode(option);
    }
}

fn item(select: *runtime.Instance, index: u32) !?*runtime.Instance {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collect(select, select.ctx.allocator, &options);
    return if (index < options.items.len) options.items[index] else null;
}

/// HTML 2.6.4.3 "remove an option", steps 1–4.
pub fn remove(select: *runtime.Instance, index: i64) !void {
    if (index < 0 or index > std.math.maxInt(u32)) return;
    try removeNode((try item(select, @intCast(index))) orelse return);
}

/// HTML 2.6.4.3 indexed setter, steps 1–5.
pub fn setIndex(select: *runtime.Instance, index: u32, option: ?*runtime.Instance) !void {
    const value = option orelse return remove(select, index);
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collect(select, select.ctx.allocator, &options);
    // Deviation from HTML 2.6.4.3 indexed setter step 4: cap sparse growth
    // before creating dummy options. Blink HTMLSelectElement::SetOption
    // (third_party/blink/renderer/core/html/forms/html_select_element.cc)
    // and WebKit HTMLSelectElement::setItem (Source/WebCore/html/) reject
    // index > length && index >= 100000. Gecko HTMLOptionsCollection::
    // IndexedSetter delegates to HTMLSelectElement::SetLength (dom/html/),
    // whose growth cap is also 100000; it reports an error above the cap.
    // Follow Blink/WebKit's no-op majority, while allowing replacements
    // and append-at-length in an already large, explicitly built select.
    if (index > options.items.len and index >= 100_000) return;
    if (index >= options.items.len) {
        try appendBlank(select, index - @as(u32, @intCast(options.items.len)));
        return insert(select, value, null);
    }
    const old = options.items[index];
    const parent = (try interfaces.Node.get_parentNode(old)) orelse return;
    _ = dom.mutation.replace(try nodeBase(old), try nodeBase(value), try nodeBase(parent)) catch |err| return mutationError(err);
}

fn isInclusiveAncestor(ancestor: *runtime.Instance, descendant: *runtime.Instance) bool {
    var node: ?*runtime.Instance = descendant;
    while (node) |current| : (node = associated.parentOf(current)) {
        if (current == ancestor) return true;
    }
    return false;
}

fn convertToLong(realm: runtime.Context, value: runtime.JSValue) !i32 {
    // WebIDL 3.2.4.8, steps 1–8: default long conversion, no clamp/range.
    const number = try engine.convertToUnrestrictedDouble(realm, value);
    if (std.math.isNan(number) or std.math.isInf(number)) return 0;
    const unsigned: u32 = @intFromFloat(@mod(@trunc(number), 4294967296.0));
    return @bitCast(unsigned);
}

/// HTML 2.6.4.3 add(element, before), steps 1–7.
pub fn add(select: *runtime.Instance, option: *runtime.Instance, before: webidl.Opt(?runtime.JSValue)) !void {
    if (isInclusiveAncestor(option, select)) return error.HierarchyRequestError;
    var reference: ?*runtime.Instance = null;
    if (before.was_passed) if (before.value) |value| {
        switch (value) {
            .undefined, .null => {},
            else => {
                const realm = engine.currentRealm() orelse select.ctx;
                const object = engine.convertToPlatformObject(realm, value);
                if (object != null and object.?.stateAs(interfaces.HTMLElement.State) != null) {
                    if (object.? == select or !isInclusiveAncestor(select, object.?)) return error.NotFoundError;
                    reference = object;
                } else {
                    const index = try convertToLong(realm, value);
                    if (index >= 0) reference = try item(select, @intCast(index));
                }
            },
        }
    };
    if (reference == option) return;
    const parent = if (reference) |ref| (try interfaces.Node.get_parentNode(ref)) orelse return error.NotFoundError else select;
    try insert(parent, option, reference);
}
