//! NodeList Tests (DOM Standard §4.3.6)
//! Tests for NodeList interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Node = dom.Node;

const testing = std.testing;

test "NodeList: init creates empty list" {
    const allocator = testing.allocator;
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    try testing.expectEqual(@as(u32, 0), list.get_length());
}

test "NodeList: length returns node count" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    // NodeList holds Node*, Element is a Node
    try list.addNode(@ptrCast(elem));
    
    try testing.expectEqual(@as(u32, 1), list.get_length());
}

test "NodeList: item returns node at index" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    const elem1 = try doc.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }
    
    const elem2 = try doc.call_createElement("span");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }
    
    try list.addNode(@ptrCast(elem1));
    try list.addNode(@ptrCast(elem2));
    
    const first = list.call_item(0);
    try testing.expect(first != null);
    
    const second = list.call_item(1);
    try testing.expect(second != null);
}

test "NodeList: item returns null for out of bounds" {
    const allocator = testing.allocator;
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    try testing.expect(list.call_item(0) == null);
    try testing.expect(list.call_item(999) == null);
}

test "NodeList: can hold mixed node types" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    // Create different node types
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    const text = try doc.call_createTextNode("text content");
    defer {
        text.deinit();
        allocator.destroy(text);
    }
    
    const comment = try doc.call_createComment("comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }
    
    // Add all to NodeList
    try list.addNode(@ptrCast(elem));
    try list.addNode(@ptrCast(text));
    try list.addNode(@ptrCast(comment));
    
    try testing.expectEqual(@as(u32, 3), list.get_length());
}

test "NodeList: clear removes all nodes" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    try list.addNode(@ptrCast(elem));
    try testing.expectEqual(@as(u32, 1), list.get_length());
    
    list.clear();
    try testing.expectEqual(@as(u32, 0), list.get_length());
}

test "NodeList: maintains insertion order" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    const div = try doc.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }
    
    const span = try doc.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }
    
    const p = try doc.call_createElement("p");
    defer {
        p.deinit();
        allocator.destroy(p);
    }
    
    try list.addNode(@ptrCast(div));
    try list.addNode(@ptrCast(span));
    try list.addNode(@ptrCast(p));
    
    // Check order is preserved
    const first = list.call_item(0);
    const second = list.call_item(1);
    const third = list.call_item(2);
    
    try testing.expect(first == @as(*Node, @ptrCast(div)));
    try testing.expect(second == @as(*Node, @ptrCast(span)));
    try testing.expect(third == @as(*Node, @ptrCast(p)));
}

test "NodeList: multiple elements can be accessed" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var list = try NodeList.init(allocator);
    defer list.deinit();
    
    // Add 5 elements
    var elements: [5]*Element = undefined;
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        elements[i] = try doc.call_createElement("div");
        try list.addNode(@ptrCast(elements[i]));
    }
    defer {
        for (elements) |elem| {
            elem.deinit();
            allocator.destroy(elem);
        }
    }
    
    try testing.expectEqual(@as(u32, 5), list.get_length());
    
    // Access each by index
    i = 0;
    while (i < 5) : (i += 1) {
        const node = list.call_item(@intCast(i));
        try testing.expect(node != null);
    }
}
