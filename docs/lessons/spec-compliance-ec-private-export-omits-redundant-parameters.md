# Spec Compliance: EC private export omits redundant parameters

**Date**: 2026-10-13
**Lesson**: Canonical browser PKCS8 exports put the EC curve in PrivateKeyInfo and omit its redundant copy in ECPrivateKey.

**Why**: WebCrypto §§23.7.5/24.4.4 explicitly call for inner parameters, but browsers and their crypto libraries omit them. An export can be mathematically correct and valid DER while still failing byte-for-byte browser conformance.

**What Happened**: All curves failed full and private-only PKCS8 round trips because Crane inserted the inner parameters. Chrome, Firefox and Safari passed ordinary EC round trips. BoringSSL's `crypto/evp/p_ec.cc:eckey_priv_encode` sets `EC_PKEY_NO_PARAMETERS` and explains its agreement with OpenSSL and NSS. Private-only import has a three-way browser split, so it remains supported according to the spec.

**Fix**: Keep outer namedCurve and inner publicKey, omit only the redundant inner parameters, and retain validation of explicit parameters on import. Test ordinary and private-only inputs, export as PKCS8 and JWK, and mismatch rejection when import supplies two curve identifiers.

**Takeaway**: **Import validation and export canonicalization are separate rules; relaxing one to match the other loses validation.**
