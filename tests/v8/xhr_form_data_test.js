// XMLHttpRequest FormData Tests
//
// Tests for FormData API used with XHR.
// Spec: https://xhr.spec.whatwg.org/#interface-formdata
//
// Run with: zig build test-v8

// ============================================================================
// FORMDATA INTERFACE TESTS
// ============================================================================

// FormData constructor exists
assert.isFunction(FormData, "FormData should be a function")
assert.isNotNull(FormData.prototype, "FormData.prototype should exist")

// FormData constructor - creates instance
assert.isTrue((() => {
    const fd = new FormData();
    return fd instanceof FormData;
})(), "new FormData() should create FormData instance")

// ============================================================================
// FORMDATA APPEND METHOD
// ============================================================================

assert.isFunction(FormData.prototype.append, "FormData.prototype.append should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('name', 'value');
    return fd.get('name') === 'value';
})(), "append() should add entry retrievable by get()")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('name', 'value1');
    fd.append('name', 'value2');
    const all = fd.getAll('name');
    return all.length === 2 && all[0] === 'value1' && all[1] === 'value2';
})(), "append() should allow multiple values for same name")

// ============================================================================
// FORMDATA SET METHOD
// ============================================================================

assert.isFunction(FormData.prototype.set, "FormData.prototype.set should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('name', 'value1');
    fd.append('name', 'value2');
    fd.set('name', 'newvalue');
    const all = fd.getAll('name');
    return all.length === 1 && all[0] === 'newvalue';
})(), "set() should replace all existing values")

// ============================================================================
// FORMDATA DELETE METHOD
// ============================================================================

assert.isFunction(FormData.prototype.delete, "FormData.prototype.delete should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('name', 'value');
    fd.delete('name');
    return fd.get('name') === null;
})(), "delete() should remove all entries with name")

// ============================================================================
// FORMDATA GET METHOD
// ============================================================================

assert.isFunction(FormData.prototype.get, "FormData.prototype.get should exist")

assert.isTrue((() => {
    const fd = new FormData();
    return fd.get('nonexistent') === null;
})(), "get() should return null for nonexistent key")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('name', 'first');
    fd.append('name', 'second');
    return fd.get('name') === 'first';
})(), "get() should return first value for key with multiple values")

// ============================================================================
// FORMDATA GETALL METHOD
// ============================================================================

assert.isFunction(FormData.prototype.getAll, "FormData.prototype.getAll should exist")

assert.isTrue((() => {
    const fd = new FormData();
    const all = fd.getAll('nonexistent');
    return Array.isArray(all) && all.length === 0;
})(), "getAll() should return empty array for nonexistent key")

// ============================================================================
// FORMDATA HAS METHOD
// ============================================================================

assert.isFunction(FormData.prototype.has, "FormData.prototype.has should exist")

assert.isTrue((() => {
    const fd = new FormData();
    return fd.has('name') === false;
})(), "has() should return false for nonexistent key")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('name', 'value');
    return fd.has('name') === true;
})(), "has() should return true for existing key")

// ============================================================================
// FORMDATA ITERATION - ENTRIES
// ============================================================================

assert.isFunction(FormData.prototype.entries, "FormData.prototype.entries should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('a', '1');
    fd.append('b', '2');
    const entries = [...fd.entries()];
    return entries.length === 2 && 
           entries[0][0] === 'a' && entries[0][1] === '1' &&
           entries[1][0] === 'b' && entries[1][1] === '2';
})(), "entries() should iterate key-value pairs")

// ============================================================================
// FORMDATA ITERATION - KEYS
// ============================================================================

assert.isFunction(FormData.prototype.keys, "FormData.prototype.keys should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('a', '1');
    fd.append('b', '2');
    const keys = [...fd.keys()];
    return keys.length === 2 && keys[0] === 'a' && keys[1] === 'b';
})(), "keys() should iterate keys")

// ============================================================================
// FORMDATA ITERATION - VALUES
// ============================================================================

assert.isFunction(FormData.prototype.values, "FormData.prototype.values should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('a', '1');
    fd.append('b', '2');
    const values = [...fd.values()];
    return values.length === 2 && values[0] === '1' && values[1] === '2';
})(), "values() should iterate values")

// ============================================================================
// FORMDATA ITERATION - FOREACH
// ============================================================================

assert.isFunction(FormData.prototype.forEach, "FormData.prototype.forEach should exist")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('a', '1');
    fd.append('b', '2');
    const collected = [];
    fd.forEach((value, key) => collected.push([key, value]));
    return collected.length === 2 &&
           collected[0][0] === 'a' && collected[0][1] === '1' &&
           collected[1][0] === 'b' && collected[1][1] === '2';
})(), "forEach() should call callback for each entry")

// ============================================================================
// FORMDATA ITERATION - SYMBOL.ITERATOR
// ============================================================================

assert.isTrue((() => {
    const fd = new FormData();
    return typeof fd[Symbol.iterator] === 'function';
})(), "FormData should have Symbol.iterator")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('a', '1');
    fd.append('b', '2');
    const entries = [...fd];
    return entries.length === 2;
})(), "FormData should be iterable with spread operator")

// ============================================================================
// FORMDATA WITH BLOB
// ============================================================================

assert.isTrue((() => {
    const fd = new FormData();
    const blob = new Blob(['content'], { type: 'text/plain' });
    fd.append('file', blob);
    const entry = fd.get('file');
    return entry instanceof Blob;
})(), "FormData should accept Blob values")

assert.isTrue((() => {
    const fd = new FormData();
    const blob = new Blob(['content'], { type: 'text/plain' });
    fd.append('file', blob, 'custom-name.txt');
    const entry = fd.get('file');
    // When a filename is provided, the Blob should become a File
    return entry instanceof Blob;
})(), "FormData.append() should accept filename parameter")

// ============================================================================
// FORMDATA WITH FILE
// ============================================================================

assert.isTrue((() => {
    // File constructor may not be available in all environments
    if (typeof File === 'undefined') return true;
    const fd = new FormData();
    const file = new File(['content'], 'test.txt', { type: 'text/plain' });
    fd.append('file', file);
    const entry = fd.get('file');
    return entry instanceof File;
})(), "FormData should accept File values")

// ============================================================================
// FORMDATA STRING COERCION
// ============================================================================

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('number', 123);
    return fd.get('number') === '123';
})(), "FormData should coerce non-string values to strings")

assert.isTrue((() => {
    const fd = new FormData();
    fd.append('bool', true);
    return fd.get('bool') === 'true';
})(), "FormData should coerce boolean to string")
