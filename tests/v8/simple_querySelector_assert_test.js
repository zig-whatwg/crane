// Simple querySelector test using assert library
// This demonstrates the improved assertion framework

// Load assert library
(function(global) {
    'use strict';

    class AssertionError extends Error {
        constructor(message, actual, expected, operator) {
            super(message);
            this.name = 'AssertionError';
            this.actual = actual;
            this.expected = expected;
            this.operator = operator;
        }
    }

    function formatValue(val) {
        if (val === null) return 'null';
        if (val === undefined) return 'undefined';
        if (typeof val === 'string') return JSON.stringify(val);
        if (typeof val === 'function') return val.name || '[Function]';
        if (typeof val === 'object') {
            try { return JSON.stringify(val); } catch (e) { return Object.prototype.toString.call(val); }
        }
        return String(val);
    }

    const assert = function(value, message) {
        if (!value) throw new AssertionError(message || `Expected truthy, got ${formatValue(value)}`, value, true, '==');
        return true;
    };
    assert.ok = assert;
    assert.strictEqual = function(actual, expected, message) {
        if (actual !== expected) throw new AssertionError(message || `Expected ${formatValue(expected)}, got ${formatValue(actual)}`, actual, expected, '===');
        return true;
    };
    assert.isNotNull = function(value, message) {
        if (value === null) throw new AssertionError(message || 'Expected non-null', value, 'non-null', '!== null');
        return true;
    };
    assert.isFunction = function(value, message) {
        if (typeof value !== 'function') throw new AssertionError(message || `Expected function, got ${typeof value}`, typeof value, 'function', 'typeof');
        return true;
    };
    assert.AssertionError = AssertionError;
    global.assert = assert;
})(globalThis);
true // Mark IIFE setup as successful

// Setup
var doc = new Document();
var body = doc.createElement("body");
var header = doc.createElement("header");
var _setup = body.appendChild(header);

// Test 1: querySelector exists and is a function
assert.isFunction(body.querySelector, "querySelector should be a function")

// Test 2: querySelector finds the element
assert.isNotNull(body.querySelector("header"), "querySelector('header') should find element")

// Test 3: querySelector returns the correct element (identity)
assert.strictEqual(body.querySelector("header"), header, "querySelector should return the appended header element")

// Test 4: querySelector returns consistent results
assert.strictEqual(body.querySelector("header"), body.querySelector("header"), "querySelector should return same object on repeated calls")

// Test 5: Test with dynamically created element
var div = doc.createElement("div");
var _appended = body.appendChild(div);
assert.strictEqual(body.querySelector("div"), div, "querySelector should find dynamically added div")

// Test 6: querySelector returns null for non-existent element
assert.strictEqual(body.querySelector("span"), null, "querySelector for non-existent element should return null")
