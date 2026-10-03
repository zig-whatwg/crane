# Spec Compliance: Parsing a key is not validating its mathematics

**Date**: 2026-10-02
**Lesson**: Check what a cryptographic library's import function actually validates before using it for a specification's key-validity step.

**Why**: DER syntax, an accepted algorithm identifier, and mathematically consistent key components are separate requirements. A library parser may accept optimization parameters without checking that they describe the same private key.

**What Happened**: WebCrypto RSA Import Key requires a valid RFC 3447 private key. Reading curl's linked mbedTLS 3.6.4 parser showed that it imports the CRT integers but finishes by checking the public key. Treating parse success as complete validation would miss inconsistent private CRT values. The WebCrypto tests now mutate a private key's CRT coefficient and require DataError. They also check that the valid JWK form with only n/e/d is accepted and completes to the same signing key.

**Fix**: Validate canonical PKCS#1 structure, parse into a transient native context, and explicitly call the library's private-key consistency check before retaining the bytes. For n/e/d-only JWK inputs, complete the missing CRT values, validate the completed key, and export it to Crane-owned bytes. Free the context within the call and erase temporary private buffers on every exit.

**Takeaway**: **A successful parser is evidence of accepted syntax; prove the separate mathematical validation contract.**
