# Debugging: A token's attribute slice dies with the element's creation

**Date**: 2026-10-18
**Lesson**: A slice into a TagToken's attribute value read before "create an element for the token" can dangle once the element is created; read the value from the element (TreeNode.getAttribute) instead.

**Why**: The tree builder copies a token's attributes into the new TreeNode and the token's own attribute storage is then reused or freed. A `[]const u8` taken from `tag.attributes` before `createElementForToken` points into storage that no longer holds the value.

**What Happened**: `<template for="p">` (lane parser1) read the `for` value from the token, created the template, then used the value to find its markers. The live parser happened to keep the bytes, so every navigation test passed; the tree-then-convert path (DOMParser, innerHTML) found no markers at all. A tree-builder unit test printed the marker name as `'�'`.

**Fix**: Pass nothing from the token past the element's creation: `template.getAttribute("for")` on the created TreeNode, whose attributes it owns.

**Takeaway**: **A slice into a token is valid only until the token's element exists; a path that passes in one driver and fails in the other is the first sign of a dangling borrow, not of a missing feature.**
