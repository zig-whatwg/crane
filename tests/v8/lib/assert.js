// Minimal assertion library for V8 integration tests
// Provides clear failure messages for debugging

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
            try {
                return JSON.stringify(val);
            } catch (e) {
                return Object.prototype.toString.call(val);
            }
        }
        return String(val);
    }

    const assert = function(value, message) {
        if (!value) {
            throw new AssertionError(
                message || `Expected truthy value, got ${formatValue(value)}`,
                value,
                true,
                '=='
            );
        }
        return true;
    };

    assert.ok = function(value, message) {
        return assert(value, message);
    };

    assert.equal = function(actual, expected, message) {
        if (actual != expected) {
            throw new AssertionError(
                message || `Expected ${formatValue(expected)}, got ${formatValue(actual)}`,
                actual,
                expected,
                '=='
            );
        }
        return true;
    };

    assert.strictEqual = function(actual, expected, message) {
        if (actual !== expected) {
            throw new AssertionError(
                message || `Expected ${formatValue(expected)} (===), got ${formatValue(actual)}`,
                actual,
                expected,
                '==='
            );
        }
        return true;
    };

    assert.notEqual = function(actual, expected, message) {
        if (actual == expected) {
            throw new AssertionError(
                message || `Expected ${formatValue(actual)} to not equal ${formatValue(expected)}`,
                actual,
                expected,
                '!='
            );
        }
        return true;
    };

    assert.notStrictEqual = function(actual, expected, message) {
        if (actual === expected) {
            throw new AssertionError(
                message || `Expected ${formatValue(actual)} to not strictly equal ${formatValue(expected)}`,
                actual,
                expected,
                '!=='
            );
        }
        return true;
    };

    assert.deepEqual = function(actual, expected, message) {
        const actualStr = JSON.stringify(actual);
        const expectedStr = JSON.stringify(expected);
        if (actualStr !== expectedStr) {
            throw new AssertionError(
                message || `Expected deep equal:\n  actual: ${actualStr}\n  expected: ${expectedStr}`,
                actual,
                expected,
                'deepEqual'
            );
        }
        return true;
    };

    assert.throws = function(fn, expectedError, message) {
        let threw = false;
        let error = null;
        try {
            fn();
        } catch (e) {
            threw = true;
            error = e;
        }
        
        if (!threw) {
            throw new AssertionError(
                message || 'Expected function to throw',
                undefined,
                expectedError || 'an error',
                'throws'
            );
        }

        if (expectedError) {
            if (typeof expectedError === 'function') {
                if (!(error instanceof expectedError)) {
                    throw new AssertionError(
                        message || `Expected error to be instance of ${expectedError.name}, got ${error.constructor.name}`,
                        error,
                        expectedError,
                        'throws'
                    );
                }
            } else if (expectedError instanceof RegExp) {
                if (!expectedError.test(error.message)) {
                    throw new AssertionError(
                        message || `Expected error message to match ${expectedError}, got "${error.message}"`,
                        error.message,
                        expectedError,
                        'throws'
                    );
                }
            }
        }
        return true;
    };

    assert.doesNotThrow = function(fn, message) {
        try {
            fn();
        } catch (e) {
            throw new AssertionError(
                message || `Expected function not to throw, but it threw: ${e.message}`,
                e,
                undefined,
                'doesNotThrow'
            );
        }
        return true;
    };

    assert.isNull = function(value, message) {
        if (value !== null) {
            throw new AssertionError(
                message || `Expected null, got ${formatValue(value)}`,
                value,
                null,
                '=== null'
            );
        }
        return true;
    };

    assert.isNotNull = function(value, message) {
        if (value === null) {
            throw new AssertionError(
                message || 'Expected non-null value',
                value,
                'non-null',
                '!== null'
            );
        }
        return true;
    };

    assert.isUndefined = function(value, message) {
        if (value !== undefined) {
            throw new AssertionError(
                message || `Expected undefined, got ${formatValue(value)}`,
                value,
                undefined,
                '=== undefined'
            );
        }
        return true;
    };

    assert.isDefined = function(value, message) {
        if (value === undefined) {
            throw new AssertionError(
                message || 'Expected defined value',
                value,
                'defined',
                '!== undefined'
            );
        }
        return true;
    };

    assert.isFunction = function(value, message) {
        if (typeof value !== 'function') {
            throw new AssertionError(
                message || `Expected function, got ${typeof value}`,
                typeof value,
                'function',
                'typeof'
            );
        }
        return true;
    };

    assert.isObject = function(value, message) {
        if (typeof value !== 'object' || value === null) {
            throw new AssertionError(
                message || `Expected object, got ${value === null ? 'null' : typeof value}`,
                typeof value,
                'object',
                'typeof'
            );
        }
        return true;
    };

    assert.isString = function(value, message) {
        if (typeof value !== 'string') {
            throw new AssertionError(
                message || `Expected string, got ${typeof value}`,
                typeof value,
                'string',
                'typeof'
            );
        }
        return true;
    };

    assert.isNumber = function(value, message) {
        if (typeof value !== 'number') {
            throw new AssertionError(
                message || `Expected number, got ${typeof value}`,
                typeof value,
                'number',
                'typeof'
            );
        }
        return true;
    };

    assert.isBoolean = function(value, message) {
        if (typeof value !== 'boolean') {
            throw new AssertionError(
                message || `Expected boolean, got ${typeof value}`,
                typeof value,
                'boolean',
                'typeof'
            );
        }
        return true;
    };

    assert.instanceOf = function(value, constructor, message) {
        if (!(value instanceof constructor)) {
            throw new AssertionError(
                message || `Expected instance of ${constructor.name}, got ${value?.constructor?.name || typeof value}`,
                value,
                constructor,
                'instanceof'
            );
        }
        return true;
    };

    assert.match = function(value, regexp, message) {
        if (!regexp.test(value)) {
            throw new AssertionError(
                message || `Expected "${value}" to match ${regexp}`,
                value,
                regexp,
                'match'
            );
        }
        return true;
    };

    assert.includes = function(haystack, needle, message) {
        const includes = Array.isArray(haystack) 
            ? haystack.includes(needle)
            : String(haystack).includes(needle);
        if (!includes) {
            throw new AssertionError(
                message || `Expected ${formatValue(haystack)} to include ${formatValue(needle)}`,
                haystack,
                needle,
                'includes'
            );
        }
        return true;
    };

    // Expose AssertionError
    assert.AssertionError = AssertionError;

    // Export to global
    global.assert = assert;
    global.AssertionError = AssertionError;

})(globalThis);
