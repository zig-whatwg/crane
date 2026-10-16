# Debugging: A signature range error is not an operation failure

**Date**: 2026-10-13
**Lesson**: Check the RSA representative range explicitly when a library maps malformed signatures to a general argument error.

**Why**: RFC3447 §8.2.2 step 2b classifies s >= n as an invalid signature. WebCrypto verification must resolve false, but the linked mbedTLS 3.6.6's PSA wrapper can propagate RSA's MPI bad-input status as PSA_ERROR_INVALID_ARGUMENT, which Crane translates to OperationError. See [mbedtls_psa_rsa_verify_hash](https://github.com/Mbed-TLS/mbedtls/blob/v3.6.6/library/psa_crypto_rsa.c) and [mbedtls_to_psa_error](https://github.com/Mbed-TLS/mbedtls/blob/v3.6.6/library/psa_crypto.c).

**What Happened**: A SHA-256 WPT signature mutation crossed the modulus. Valid-signature tests and common padding failures worked, hiding the different error path.

**Fix**: After checking the encoded length, compare the signature with the already validated modulus and return false for s >= n. Keep ordinary PSA failures distinct, so allocation or backend errors are still operation failures. Test n, n-1, all-ones, zero, truncation, the original mutation and known-answer success.

**Takeaway**: **Classify the algorithm's invalid inputs before broadly translating a backend's error codes.**
