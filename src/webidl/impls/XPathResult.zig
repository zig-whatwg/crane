//! DOM Level 3 XPath §1.4: typed results, snapshots and mutation-sensitive iterators.
//! Native node holds keep result nodes alive, including detached trees. The
//! iterator also holds its document, whose existing version invalidates iteration.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const Node = runtime.Instance;
const document_slot: engine.TracedSlot = .{ .name = "xpath:document" };

pub const State = interfaces.XPathResult.State;
pub const ImplError = error{ TypeError, InvalidStateError, OutOfMemory };
pub const construction_args = .{ "result_type", "number_value", "string_value", "boolean_value", "nodes", "document" };
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    result_type: u16 = 0,
    number_value: f64 = 0,
    string_value: []const u8 = &.{},
    boolean_value: bool = false,
    nodes: dom.node_holds.Holder,
    document: dom.node_holds.MemberHold = .{},
    version: ?u64 = null,
    position: usize = 0,
};

pub fn initOwn(instance: *Node, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator, .nodes = dom.node_holds.Holder.init(allocator, instance) };
    errdefer internal.nodes.release();
    errdefer internal.document.release(instance, document_slot);
    if (comptime @hasField(@TypeOf(args), "result_type")) internal.result_type = args.result_type;
    if (comptime @hasField(@TypeOf(args), "number_value")) internal.number_value = args.number_value;
    if (comptime @hasField(@TypeOf(args), "boolean_value")) internal.boolean_value = args.boolean_value;
    if (comptime @hasField(@TypeOf(args), "string_value")) internal.string_value = try allocator.dupe(u8, args.string_value);
    errdefer allocator.free(internal.string_value);
    if (comptime @hasField(@TypeOf(args), "nodes")) try internal.nodes.hold(*Node, args.nodes, null);
    if (internal.result_type == 4 or internal.result_type == 5) {
        if (comptime @hasField(@TypeOf(args), "document")) {
            if (args.document) |document| {
                internal.document.take(instance, document, document_slot);
                internal.version = dom.live_collections.treeVersion(document);
            }
        }
    }
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *Node) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.nodes.release();
    internal.document.release(instance, document_slot);
    internal.allocator.free(internal.string_value);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn data(instance: *Node) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}
fn invalid(internal: *const InternalState) bool {
    if (internal.result_type != 4 and internal.result_type != 5) return false;
    const document = internal.document.get() orelse return internal.version != null;
    return internal.version != dom.live_collections.treeVersion(document);
}
pub fn get_resultType(instance: *Node) anyerror!u16 {
    return (try data(instance)).result_type;
}
pub fn get_numberValue(instance: *Node) anyerror!f64 {
    const internal = try data(instance);
    if (internal.result_type != 1) return error.TypeError;
    return internal.number_value;
}
pub fn get_stringValue(instance: *Node) anyerror!runtime.DOMString {
    const internal = try data(instance);
    if (internal.result_type != 2) return error.TypeError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.string_value);
}
pub fn get_booleanValue(instance: *Node) anyerror!bool {
    const internal = try data(instance);
    if (internal.result_type != 3) return error.TypeError;
    return internal.boolean_value;
}
pub fn get_singleNodeValue(instance: *Node) anyerror!?*Node {
    const internal = try data(instance);
    if (internal.result_type != 8 and internal.result_type != 9) return error.TypeError;
    return internal.nodes.get(0);
}
pub fn get_invalidIteratorState(instance: *Node) anyerror!bool {
    return invalid(try data(instance));
}
pub fn get_snapshotLength(instance: *Node) anyerror!u32 {
    const internal = try data(instance);
    if (internal.result_type != 6 and internal.result_type != 7) return error.TypeError;
    return @intCast(internal.nodes.holds.len);
}
pub fn call_snapshotItem(instance: *Node, index: u32) anyerror!?*Node {
    const internal = try data(instance);
    if (internal.result_type != 6 and internal.result_type != 7) return error.TypeError;
    return internal.nodes.get(index);
}
pub fn call_iterateNext(instance: *Node) anyerror!?*Node {
    const internal = try data(instance);
    if (internal.result_type != 4 and internal.result_type != 5) return error.TypeError;
    if (invalid(internal)) return error.InvalidStateError;
    const node = internal.nodes.get(internal.position) orelse return null;
    internal.position += 1;
    return node;
}
