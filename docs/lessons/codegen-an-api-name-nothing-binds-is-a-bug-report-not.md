# Codegen: An API name nothing binds is a bug report, not only dead code

**Date**: 2026-09-23
**Lesson**: Of 130 public `get_`/`set_`/`call_` functions that no generated
file called, 124 were stale - and six were the only visible trace of two real
defects.

**Why**: the name is the map (see "Names are the binding map"). An API-named
function nothing binds means the map and the implementation disagree, and
either side can be the wrong one.

**What Happened**: 96 were instance copies of static operations
(`URL.call_parse`, a weaker copy of the bound `call_static_parse`); the rest of
the stale ones re-implemented a parent's members (XMLHttpRequestUpload's
fourteen handlers, Range's and StaticRange's AbstractRange getters). The six
that were not stale:

* DOMRect's `set_x`, `set_y`, `set_width`, `set_height`: the IDL parser read
  `inherit attribute` as read only, so no setter was bound and `rect.x = 5`
  did nothing. WebIDL §2.5.2 uses `inherit` to make a read-only parent
  attribute WRITABLE.
* File's `get_size` and `get_type`: `size` and `type` are Blob's, answered
  from Blob's state, which File never wrote - `File.init` did not chain to
  Blob. Every File was a Blob with no bytes.

Along the way: codegen had put the seven static attributes in the instance
tables, so `MediaSource.canConstructInDedicatedWorker` lived on the prototype
and read `undefined` on the interface object.

**Fix**: the stale copies are deleted; the parser, File and static attributes
are fixed; the lint fails on any new unbound API name.

**Takeaway**: **Before deleting an unbound function, ask why the map does not
reach it.** A stale copy and a correct implementation behind a broken map
look identical in the file.
