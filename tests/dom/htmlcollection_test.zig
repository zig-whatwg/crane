//! HTMLCollection Tests (DOM Standard §4.3.5)
//! Tests for HTMLCollection interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");


// Type aliases
const Document = dom.Document;
const HTMLCollection = dom.HTMLCollection;

const testing = std.testing;

test "HTMLCollection: init creates empty collection" {
    const allocator = testing.allocator;
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    try testing.expectEqual(@as(u32, 0), collection.get_length());
}

test "HTMLCollection: length returns element count" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    // Add elements
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
    
    try collection.addElement(elem1);
    try collection.addElement(elem2);
    
    try testing.expectEqual(@as(u32, 2), collection.get_length());
}

test "HTMLCollection: item returns element at index" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
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
    
    try collection.addElement(elem1);
    try collection.addElement(elem2);
    
    // Access by index
    const first = collection.call_item(0);
    try testing.expect(first != null);
    try testing.expectEqualStrings("div", first.?.get_tagName());
    
    const second = collection.call_item(1);
    try testing.expect(second != null);
    try testing.expectEqualStrings("span", second.?.get_tagName());
}

test "HTMLCollection: item returns null for out of bounds index" {
    const allocator = testing.allocator;
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    try testing.expect(collection.call_item(0) == null);
    try testing.expect(collection.call_item(999) == null);
}

test "HTMLCollection: namedItem finds element by id" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    try elem.set_id("myDiv");
    try collection.addElement(elem);
    
    const found = collection.call_namedItem("myDiv");
    try testing.expect(found != null);
    try testing.expectEqualStrings("div", found.?.get_tagName());
    try testing.expectEqualStrings("myDiv", found.?.get_id());
}

test "HTMLCollection: namedItem finds element by name attribute" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    const elem = try doc.call_createElement("input");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    try elem.call_setAttribute("name", "username");
    try collection.addElement(elem);
    
    const found = collection.call_namedItem("username");
    try testing.expect(found != null);
    try testing.expectEqualStrings("input", found.?.get_tagName());
}

test "HTMLCollection: namedItem returns null for non-existent name" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    try elem.set_id("myDiv");
    try collection.addElement(elem);
    
    try testing.expect(collection.call_namedItem("nonExistent") == null);
}

test "HTMLCollection: namedItem returns first matching element" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
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
    
    try elem1.call_setAttribute("name", "test");
    try elem2.call_setAttribute("name", "test");
    
    try collection.addElement(elem1);
    try collection.addElement(elem2);
    
    const found = collection.call_namedItem("test");
    try testing.expect(found != null);
    try testing.expectEqualStrings("div", found.?.get_tagName()); // First one
}

test "HTMLCollection: clear removes all elements" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    try collection.addElement(elem);
    try testing.expectEqual(@as(u32, 1), collection.get_length());
    
    collection.clear();
    try testing.expectEqual(@as(u32, 0), collection.get_length());
}

test "HTMLCollection: multiple elements of same type" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    var collection = try HTMLCollection.init(allocator);
    defer collection.deinit();
    
    // Create multiple div elements
    const div1 = try doc.call_createElement("div");
    defer {
        div1.deinit();
        allocator.destroy(div1);
    }
    
    const div2 = try doc.call_createElement("div");
    defer {
        div2.deinit();
        allocator.destroy(div2);
    }
    
    const div3 = try doc.call_createElement("div");
    defer {
        div3.deinit();
        allocator.destroy(div3);
    }
    
    try div1.set_id("div1");
    try div2.set_id("div2");
    try div3.set_id("div3");
    
    try collection.addElement(div1);
    try collection.addElement(div2);
    try collection.addElement(div3);
    
    try testing.expectEqual(@as(u32, 3), collection.get_length());
    
    // Access each by index
    try testing.expectEqualStrings("div1", collection.call_item(0).?.get_id());
    try testing.expectEqualStrings("div2", collection.call_item(1).?.get_id());
    try testing.expectEqualStrings("div3", collection.call_item(2).?.get_id());
    
    // Access by name
    try testing.expectEqualStrings("div2", collection.call_namedItem("div2").?.get_id());
}
