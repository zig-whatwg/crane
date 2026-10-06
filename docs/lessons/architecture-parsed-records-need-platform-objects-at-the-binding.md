# Architecture: Parsed Records Need Platform Objects at the Binding

**Date**: 2026-10-06
**Lesson**: A parser's native byte record must become a platform object before an IDL return or iterator exposes it.

**Why**: Native records and runtime instances have different layouts and ownership. Casting one pointer to the other invents a vtable and interface name from payload bytes.

**What Happened**: Fetch's multipart parser returned native file records. FormData.get cast those records to runtime.Instance, so a worker crashed while the binding treated the body text `contents` as a pointer. The full sweep journal classified the worker failure as TIMEOUT and reported zero CRASH records; its piped log contained the actual segmentation fault. A direct multipart probe reproduced the same invalid address. Allocation-failure tests also found leaks in partial headers and cloned native files.

**Fix**: Preserve multipart bytes, filename and Content-Type through parsing. At FormData construction, use the File interface constructor, temporarily root each prepared File with an owned engine value, and prepare the retained entry array before replacing native records. Transfer the caller's entry list only after all fallible preparation succeeds. Test exact bytes, duplicate names, empty filenames, metadata, identity, GC and every native allocation failure. Inspect sweep logs alongside journals, and use the prescribed paired preceding-list comparison before claiming a sweep-only crash fixed.

**Takeaway**: **Convert representations at their owner boundary; a pointer cast cannot create a platform object or its lifetime.**
