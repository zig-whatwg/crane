# Spec Compliance: Created Blob types do not use constructor normalization

**Date**: 2026-10-16
**Lesson**: An algorithm creating a Blob with an already serialized MIME type must preserve that type, even though the public Blob constructor lowercases its input.

**Why**: The MIME parser normalizes type, subtype and parameter names, but preserves parameter values. Blob constructor normalization is a separate algorithm. Reusing a constructor-oriented byte helper silently changes a type that another specification already computed.

**What Happened**: XHR correctly serialized `text/plain;charset=GBK`, then its Blob byte helper lowercased the parameter value. Browser results split three ways: Chrome dropped parameters, Firefox lowercased them, and Safari preserved them, so the spec settled the case. A second boundary confused DOMString's WTF-8 with isomorphic-encoded header bytes.

**Fix**: Give Blob's existing hook table a separate step for an exact serialized type. Keep constructor normalization intact. Parse overrideMimeType as a string, and decode serialized MIME bytes to UTF-8 before storing the Blob's DOMString type. FormData's "create an entry" must also keep that type when making a File: restore it before exposing the fresh File, refuse shared BlobData, and allocate the new type before freeing the old. Deserialization uses the exact-type step too, since its record already contains the computed type. Test parameter case, Latin-1 values, cloning, sharing, and allocation failures.

**Takeaway**: **Follow the creating algorithm's type rules, and name whether each MIME value is a string or header bytes.**
