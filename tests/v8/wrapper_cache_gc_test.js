// V8 Wrapper Cache GC Integration Tests
// 
// Tests that verify the wrapper cache correctly integrates with V8's garbage collector.
// These tests verify wrapper identity is preserved across repeated queries and after GC cycles.
//
// Run with: zig build test-v8
// Or with V8 --expose-gc flag: node --expose-gc wrapper_cache_gc_test.js
//
// Test format: Each test is an expression that evaluates to true/false.

// ============================================================================
// TEST 1: Basic Wrapper Identity (No GC)
// ============================================================================

// querySelector should return same wrapper for same element
(() => {
    const div = document.createElement("div");
    div.id = "test-basic-identity";
    document.body.appendChild(div);
    
    const e1 = document.querySelector("#test-basic-identity");
    const e2 = document.querySelector("#test-basic-identity");
    
    // Cleanup
    document.body.removeChild(div);
    
    return e1 === e2;
})()

// Multiple queries return same wrapper
(() => {
    const span = document.createElement("span");
    span.className = "test-class";
    document.body.appendChild(span);
    
    const refs = [];
    for (let i = 0; i < 5; i++) {
        refs.push(document.querySelector(".test-class"));
    }
    
    // All refs should be identical
    const allSame = refs.every(ref => ref === refs[0]);
    
    // Cleanup
    document.body.removeChild(span);
    
    return allSame;
})()

// ============================================================================
// TEST 2: Wrapper Identity Across Different Query Methods
// ============================================================================

// getElementById and querySelector return same wrapper
(() => {
    const div = document.createElement("div");
    div.id = "multi-query-test";
    document.body.appendChild(div);
    
    const byId = document.getElementById("multi-query-test");
    const bySelector = document.querySelector("#multi-query-test");
    
    const same = byId === bySelector;
    
    // Cleanup
    document.body.removeChild(div);
    
    return same;
})()

// getElementsByTagName and querySelector return same wrapper (first element)
(() => {
    const article = document.createElement("article");
    article.id = "tagname-test";
    document.body.appendChild(article);
    
    const byTagName = document.getElementsByTagName("article")[0];
    const bySelector = document.querySelector("article");
    
    const same = byTagName === bySelector;
    
    // Cleanup
    document.body.removeChild(article);
    
    return same;
})()

// ============================================================================
// TEST 3: Constructor vs Query Identity
// ============================================================================

// Element created via constructor should match when queried
(() => {
    const section = document.createElement("section");
    section.id = "constructor-query-test";
    document.body.appendChild(section);
    
    const queried = document.querySelector("#constructor-query-test");
    
    const same = section === queried;
    
    // Cleanup
    document.body.removeChild(section);
    
    return same;
})()

// appendChild and querySelector return same wrapper
(() => {
    const p = document.createElement("p");
    p.id = "append-test";
    document.body.appendChild(p);
    
    const appended = p;
    const queried = document.querySelector("#append-test");
    
    const same = appended === queried;
    
    // Cleanup
    document.body.removeChild(p);
    
    return same;
})()

// ============================================================================
// TEST 4: Wrapper Identity After Element Removal and Re-insertion
// ============================================================================

// Same wrapper after remove and re-insert
(() => {
    const div = document.createElement("div");
    div.id = "removal-test";
    document.body.appendChild(div);
    
    const ref1 = document.querySelector("#removal-test");
    
    // Remove from DOM
    document.body.removeChild(div);
    
    // Re-insert
    document.body.appendChild(div);
    
    const ref2 = document.querySelector("#removal-test");
    
    const same = ref1 === ref2;
    
    // Cleanup
    document.body.removeChild(div);
    
    return same;
})()

// ============================================================================
// TEST 5: Multiple Elements Identity
// ============================================================================

// Each unique element gets unique wrapper
(() => {
    const div1 = document.createElement("div");
    const div2 = document.createElement("div");
    div1.id = "div1";
    div2.id = "div2";
    document.body.appendChild(div1);
    document.body.appendChild(div2);
    
    const query1 = document.querySelector("#div1");
    const query2 = document.querySelector("#div2");
    
    const different = query1 !== query2;
    const match1 = div1 === query1;
    const match2 = div2 === query2;
    
    // Cleanup
    document.body.removeChild(div1);
    document.body.removeChild(div2);
    
    return different && match1 && match2;
})()

// ============================================================================
// TEST 6: Nested Elements Identity
// ============================================================================

// Parent and child maintain separate wrapper identity
(() => {
    const parent = document.createElement("div");
    const child = document.createElement("span");
    parent.id = "parent";
    child.id = "child";
    
    parent.appendChild(child);
    document.body.appendChild(parent);
    
    const parentQuery = document.querySelector("#parent");
    const childQuery = document.querySelector("#child");
    
    const parentMatch = parent === parentQuery;
    const childMatch = child === childQuery;
    const different = parent !== child;
    
    // Cleanup
    document.body.removeChild(parent);
    
    return parentMatch && childMatch && different;
})()

// ============================================================================
// TEST 7: Document Body Identity
// ============================================================================

// document.body returns same wrapper
(() => {
    const body1 = document.body;
    const body2 = document.body;
    
    return body1 === body2;
})()

// ============================================================================
// TEST 8: GC Integration (if gc() is available)
// ============================================================================

// Test wrapper identity after forced GC
// Note: This requires node --expose-gc or d8 --expose-gc
(() => {
    if (typeof gc !== "function") {
        // Skip test if gc() not available
        return true;
    }
    
    const div = document.createElement("div");
    div.id = "gc-test-basic";
    document.body.appendChild(div);
    
    const ref1 = document.querySelector("#gc-test-basic");
    
    // Force garbage collection
    gc();
    
    const ref2 = document.querySelector("#gc-test-basic");
    
    const same = ref1 === ref2;
    
    // Cleanup
    document.body.removeChild(div);
    
    return same;
})()

// Test wrapper resurrection after dropping all JS references and GC
(() => {
    if (typeof gc !== "function") {
        // Skip test if gc() not available
        return true;
    }
    
    const div = document.createElement("div");
    div.id = "gc-resurrection-test";
    document.body.appendChild(div);
    
    // Create wrapper
    let ref1 = document.querySelector("#gc-resurrection-test");
    
    // Drop reference (in JS)
    ref1 = null;
    
    // Force GC (should collect the wrapper if no other references exist)
    gc();
    
    // Query again (should create new wrapper or return cached one)
    const ref2 = document.querySelector("#gc-resurrection-test");
    
    const exists = ref2 !== null && ref2 !== undefined;
    const hasId = ref2.id === "gc-resurrection-test";
    
    // Cleanup
    document.body.removeChild(div);
    
    return exists && hasId;
})()

// Test cache handles many elements with GC
(() => {
    if (typeof gc !== "function") {
        // Skip test if gc() not available
        return true;
    }
    
    const elements = [];
    const count = 100;
    
    // Create many elements
    for (let i = 0; i < count; i++) {
        const div = document.createElement("div");
        div.id = `gc-stress-${i}`;
        div.className = "gc-stress-test";
        document.body.appendChild(div);
        elements.push(div);
    }
    
    // Query all elements (should cache wrappers)
    const queried = [];
    for (let i = 0; i < count; i++) {
        queried.push(document.querySelector(`#gc-stress-${i}`));
    }
    
    // Verify identity
    let allMatch = true;
    for (let i = 0; i < count; i++) {
        if (elements[i] !== queried[i]) {
            allMatch = false;
            break;
        }
    }
    
    // Force GC
    gc();
    
    // Query again - should still return same wrappers
    const queriedAgain = [];
    for (let i = 0; i < count; i++) {
        queriedAgain.push(document.querySelector(`#gc-stress-${i}`));
    }
    
    // Verify identity after GC
    let allMatchAfterGC = true;
    for (let i = 0; i < count; i++) {
        if (elements[i] !== queriedAgain[i]) {
            allMatchAfterGC = false;
            break;
        }
    }
    
    // Cleanup
    for (const elem of elements) {
        document.body.removeChild(elem);
    }
    
    return allMatch && allMatchAfterGC;
})()

// ============================================================================
// TEST 9: Wrapper Cache Statistics
// ============================================================================

// Cache size increases as elements are queried
(() => {
    // This test would require exposing cache statistics to JavaScript
    // For now, we just verify that querying works correctly
    
    const div1 = document.createElement("div");
    const div2 = document.createElement("div");
    const div3 = document.createElement("div");
    
    div1.id = "cache-stat-1";
    div2.id = "cache-stat-2";
    div3.id = "cache-stat-3";
    
    document.body.appendChild(div1);
    document.body.appendChild(div2);
    document.body.appendChild(div3);
    
    // Query each element
    const q1 = document.querySelector("#cache-stat-1");
    const q2 = document.querySelector("#cache-stat-2");
    const q3 = document.querySelector("#cache-stat-3");
    
    // Verify all match
    const allMatch = (div1 === q1) && (div2 === q2) && (div3 === q3);
    
    // Cleanup
    document.body.removeChild(div1);
    document.body.removeChild(div2);
    document.body.removeChild(div3);
    
    return allMatch;
})()

// ============================================================================
// TEST 10: Edge Cases
// ============================================================================

// querySelector with non-existent selector returns null
(() => {
    const result = document.querySelector("#this-id-does-not-exist-12345");
    return result === null;
})()

// Multiple queries for non-existent element return null consistently
(() => {
    const r1 = document.querySelector("#nonexistent-abc");
    const r2 = document.querySelector("#nonexistent-abc");
    
    return r1 === null && r2 === null;
})()

// Empty query selector throws (or returns null)
(() => {
    try {
        const result = document.querySelector("");
        // If no exception, should return null
        return result === null;
    } catch (e) {
        // Exception is also acceptable behavior
        return true;
    }
})()
