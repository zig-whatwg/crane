
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Web Cryptography API Level 2

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 11 August
2026

More details about this document

This version:
: [https://w3c.github.io/webcrypto/](https://w3c.github.io/webcrypto/)

Latest published version:
: <https://www.w3.org/TR/webcrypto-2/>

Latest editor\'s draft:
: <https://w3c.github.io/webcrypto/>

History:
: <https://www.w3.org/standards/history/webcrypto-2/>
: [Commit history](https://github.com/w3c/webcrypto/commits/)

Editor:
: [Daniel Huigens](mailto:daniel.huigens@proton.ch) ([Proton AG](https://proton.me/))

Former editors:
: [Mark Watson] - Until 01 November 2016
: [Ryan Sleevi] - Until 21 January 2016

Feedback:
: [GitHub w3c/webcrypto](https://github.com/w3c/webcrypto/) ([pull
 requests](https://github.com/w3c/webcrypto/pulls/), [new
 issue](https://github.com/w3c/webcrypto/issues/new/choose), [open
 issues](https://github.com/w3c/webcrypto/issues/))

[Copyright](https://www.w3.org/policies/#copyright) © 2026 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This specification describes a JavaScript API for performing basic
cryptographic operations in web applications, such as hashing, signature
generation and verification, and encryption and decryption.
Additionally, it describes an API for applications to generate and/or
manage the keying material necessary to perform these operations. Uses
for this API range from user or service authentication, document or code
signing, and the confidentiality and integrity of communications.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This document was published by the [Web Application Security Working
Group](https://www.w3.org/groups/wg/webappsec) as an Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/webappsec/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#introduction)
4. [2. Use Cases](#use-cases)
 1. [2.1 Multi-factor
 Authentication](#multifactor-authentication)
 2. [2.2 Protected Document Exchange](#protected-document)
 3. [2.3 Cloud Storage](#cloud-storage)
 4. [2.4 Document Signing](#document-signing)
 5. [2.5 Data Integrity
 Protection](#data-integrity-protection)
 6. [2.6 Secure Messaging](#secure-messaging)
 7. [2.7 JavaScript Object Signing and Encryption
 (JOSE)](#jose)
5. [3. Conformance](#conformance)
 1. [3.1 Extensibility](#extensibility)
6. [4. Scope](#scope)
 1. [4.1 Level of abstraction](#scope-abstraction)
 2. [4.2 Cryptographic algorithms](#scope-algorithms)
 3. [4.3 Out of scope](#scope-out-of-scope)
7. [5. Concepts](#concepts)
 1. [5.1 Underlying Cryptographic
 Implementation](#concepts-underlying-implementation)
 2. [5.2 Key Storage](#concepts-key-storage)
8. [6. Security considerations](#security-considerations)
 1. [6.1 Security considerations for
 implementers](#security-implementers)
 2. [6.2 Security considerations for
 authors](#security-developers)
 3. [6.3 Security considerations for
 users](#security-users)
9. [7. Privacy considerations](#privacy)
10. [8. Dependencies](#dependencies)
11. [9. Terminology](#terminology)
12. [10. Crypto interface](#crypto-interface)
 1. [10.1 Methods and
 Parameters](#Crypto-interface-methods)
 1. [10.1.1 The getRandomValues
 method](#Crypto-method-getRandomValues)
 2. [10.1.2 The randomUUID
 method](#Crypto-method-randomUUID)
 2. [10.2 Attributes](#Crypto-interface-attributes)
 1. [10.2.1 The subtle
 attribute](#Crypto-attribute-subtle)
13. [11. Algorithm dictionary](#algorithm-dictionary)
 1. [11.1 [`Algorithm`] Dictionary
 Members](#algorithm-dictionary-members)
14. [12. KeyAlgorithm dictionary](#key-algorithm-dictionary)
 1. [12.1
 Description](#key-algorithm-dictionary-description)
 2. [12.2 KeyAlgorithm dictionary
 members](#key-algorithm-dictionary-members)
15. [13. CryptoKey interface](#cryptokey-interface)
 1. [13.1 Description](#cryptokey-interface-description)
 2. [13.2 Key interface data
 types](#cryptokey-interface-types)
 3. [13.3 CryptoKey internal
 slots](#cryptokey-interface-internal-slots)
 4. [13.4 CryptoKey interface
 members](#cryptokey-interface-members)
 5. [13.5 Serialization and deserialization
 steps](#cryptokey-interface-serializable)
16. [14. SubtleCrypto interface](#subtlecrypto-interface)
 1. [14.1 Data Types](#subtlecrypto-interface-datatypes)
 2. [14.2 Task Source](#subtlecrypto-interface-tasksource)
 3. [14.3 Methods and
 Parameters](#subtlecrypto-interface-methods)
 1. [14.3.1 The encrypt
 method](#SubtleCrypto-method-encrypt)
 2. [14.3.2 The decrypt
 method](#SubtleCrypto-method-decrypt)
 3. [14.3.3 The sign
 method](#SubtleCrypto-method-sign)
 4. [14.3.4 The verify
 method](#SubtleCrypto-method-verify)
 5. [14.3.5 The digest
 method](#SubtleCrypto-method-digest)
 6. [14.3.6 The generateKey
 method](#SubtleCrypto-method-generateKey)
 7. [14.3.7 The deriveKey
 method](#SubtleCrypto-method-deriveKey)
 8. [14.3.8 The deriveBits
 method](#SubtleCrypto-method-deriveBits)
 9. [14.3.9 The importKey
 method](#SubtleCrypto-method-importKey)
 10. [14.3.10 The exportKey
 method](#SubtleCrypto-method-exportKey)
 11. [14.3.11 The wrapKey
 method](#SubtleCrypto-method-wrapKey)
 12. [14.3.12 The unwrapKey
 method](#SubtleCrypto-method-unwrapKey)
 4. [14.4 Exceptions](#SubtleCrypto-Exceptions)
17. [15. JsonWebKey dictionary](#JsonWebKey-dictionary)
18. [16. BigInteger](#big-integer)
19. [17. CryptoKeyPair dictionary](#keypair)
20. [18. Algorithms](#algorithms)
 1. [18.1 Overview](#algorithms-section-overview)
 2. [18.2 Concepts](#algorithm-concepts)
 1. [18.2.1 Naming](#algorithm-concepts-naming)
 2. [18.2.2 Supported
 Operations](#algorithm-concepts-operations)
 3. [18.2.3
 Normalization](#algorithm-concepts-normalization)
 3. [18.3 Specification
 Conventions](#algorithm-conventions)
 4. [18.4 Algorithm
 Normalization](#algorithm-normalization)
 1. [18.4.1
 Description](#algorithm-normalization-description)
 2. [18.4.2 Internal State
 Objects](#algorithm-normalization-internal)
 3. [18.4.3 Defining an
 Algorithm](#algorithm-normalization-define-an-algorithm)
 4. [18.4.4 Normalizing an
 algorithm](#algorithm-normalization-normalize-an-algorithm)
 5. [18.5 Recommendations](#algorithm-recommendations)
 1. [18.5.1 For
 Authors](#algorithm-recommendations-authors)
 2. [18.5.2 For
 Implementers](#algorithm-recommendations-implementers)
21. [19. Algorithm Overview](#algorithm-overview)
22. [20. RSASSA-PKCS1-v1_5](#rsassa-pkcs1)
 1. [20.1 Description](#rsassa-pkcs1-description)
 2. [20.2 Registration](#rsassa-pkcs1-registration)
 3. [20.3 [`RsaKeyGenParams`]{idl="dictionary"
 }
 dictionary](#RsaKeyGenParams-dictionary)
 4. [20.4 [`RsaHashedKeyGenParams`]{idl="dictionary"

 }
 dictionary](#RsaHashedKeyGenParams-dictionary)
 5. [20.5 RSA key generation parameter
 validation](#rsa-key-generation-parameter-validation)
 6. [20.6 [`RsaKeyAlgorithm`]{idl="dictionary"
 }
 dictionary](#RsaKeyAlgorithm-dictionary)
 7. [20.7 [`RsaHashedKeyAlgorithm`]{idl="dictionary"

 }
 dictionary](#RsaHashedKeyAlgorithm-dictionary)
 8. [20.8 [`RsaHashedImportParams`]{idl="dictionary"

 }
 dictionary](#RsaHashedImportParams-dictionary)
 9. [20.9 Operations](#rsassa-pkcs1-operations)
 1. [20.9.1 Sign](#rsassa-pkcs1-operations-sign)
 2. [20.9.2 Verify](#rsassa-pkcs1-operations-verify)
 3. [20.9.3 Generate
 Key](#rsassa-pkcs1-operations-generate-key)
 4. [20.9.4 Import
 Key](#rsassa-pkcs1-operations-import-key)
 5. [20.9.5 Export
 Key](#rsassa-pkcs1-operations-export-key)
23. [21. RSA-PSS](#rsa-pss)
 1. [21.1 Description](#rsa-pss-description)
 2. [21.2 Registration](#rsa-pss-registration)
 3. [21.3 [`RsaPssParams`]{idl="dictionary"
 }
 dictionary](#RsaPssParams-dictionary)
 4. [21.4 Operations](#rsa-pss-operations)
 1. [21.4.1 Sign](#rsa-pss-operations-sign)
 2. [21.4.2 Verify](#rsa-pss-operations-verify)
 3. [21.4.3 Generate
 Key](#rsa-pss-operations-generate-key)
 4. [21.4.4 Import
 Key](#rsa-pss-operations-import-key)
 5. [21.4.5 Export
 Key](#rsa-pss-operations-export-key)
24. [22. RSA-OAEP](#rsa-oaep)
 1. [22.1 Description](#rsa-oaep-description)
 2. [22.2 Registration](#rsa-oaep-registration)
 3. [22.3 [`RsaOaepParams`]{idl="dictionary"
 }
 dictionary](#rsa-oaep-params)
 4. [22.4 Operations](#rsa-oaep-operations)
 1. [22.4.1 Encrypt](#rsa-oaep-operations-encrypt)
 2. [22.4.2 Decrypt](#rsa-oaep-operations-decrypt)
 3. [22.4.3 Generate
 Key](#rsa-oaep-operations-generate-key)
 4. [22.4.4 Import
 Key](#rsa-oaep-operations-import-key)
 5. [22.4.5 Export
 Key](#rsa-oaep-operations-export-key)
25. [23. ECDSA](#ecdsa)
 1. [23.1 Description](#ecdsa-description)
 2. [23.2 Registration](#ecdsa-registration)
 3. [23.3 [`EcdsaParams`]{idl="dictionary"
 }
 dictionary](#EcdsaParams-dictionary)
 4. [23.4 [`EcKeyGenParams`]{idl="dictionary"
 }
 dictionary](#EcKeyGenParams-dictionary)
 5. [23.5 [`EcKeyAlgorithm`]{idl="dictionary"
 }
 dictionary](#EcKeyAlgorithm-dictionary)
 6. [23.6 [`EcKeyImportParams`]{idl="dictionary"
 }
 dictionary](#EcKeyImportParams-dictionary)
 7. [23.7 Operations](#ecdsa-operations)
 1. [23.7.1 Sign](#ecdsa-operations-sign)
 2. [23.7.2 Verify](#ecdsa-operations-verify)
 3. [23.7.3 Generate
 Key](#ecdsa-operations-generate-key)
 4. [23.7.4 Import Key](#ecdsa-operations-import-key)
 5. [23.7.5 Export Key](#ecdsa-operations-export-key)
26. [24. ECDH](#ecdh)
 1. [24.1 Description](#ecdh-description)
 2. [24.2 Registration](#ecdh-registration)
 3. [24.3 [`EcdhKeyDeriveParams`]{idl="dictionary"

 } dictionary](#dh-EcdhKeyDeriveParams)
 4. [24.4 Operations](#ecdh-operations)
 1. [24.4.1 Generate
 Key](#ecdh-operations-generate-key)
 2. [24.4.2 Derive Bits](#ecdh-operations-derive-bits)
 3. [24.4.3 Import Key](#ecdh-operations-import-key)
 4. [24.4.4 Export Key](#ecdh-operations-export-key)
27. [25. Ed25519](#ed25519)
 1. [25.1 Description](#ed25519-description)
 2. [25.2 Registration](#ed25519-registration)
 3. [25.3 Operations](#ed25519-operations)
 1. [25.3.1 Sign](#ed25519-operations-sign)
 2. [25.3.2 Verify](#ed25519-operations-verify)
 3. [25.3.3 Generate
 Key](#ed25519-operations-generate-key)
 4. [25.3.4 Import
 Key](#ed25519-operations-import-key)
 5. [25.3.5 Export
 Key](#ed25519-operations-export-key)
28. [26. X25519](#x25519)
 1. [26.1 Description](#x25519-description)
 2. [26.2 Registration](#x25519-registration)
 3. [26.3 Operations](#x25519-operations)
 1. [26.3.1 Derive
 Bits](#x25519-operations-derive-bits)
 2. [26.3.2 Generate
 Key](#x25519-operations-generate-key)
 3. [26.3.3 Import Key](#x25519-operations-import-key)
 4. [26.3.4 Export Key](#x25519-operations-export-key)
29. [27. AES-CTR](#aes-ctr)
 1. [27.1 Description](#aes-ctr-description)
 2. [27.2 Registration](#aes-ctr-registration)
 3. [27.3 [`AesCtrParams`]{idl="dictionary"
 }
 dictionary](#aes-ctr-params)
 4. [27.4 [`AesKeyAlgorithm`]{idl="dictionary"
 }
 dictionary](#AesKeyAlgorithm-dictionary)
 5. [27.5 [`AesKeyGenParams`]{idl="dictionary"
 }
 dictionary](#aes-keygen-params)
 6. [27.6 [`AesDerivedKeyParams`]{idl="dictionary"

 } dictionary](#aes-derivedkey-params)
 7. [27.7 Operations](#aes-ctr-operations)
 1. [27.7.1 Encrypt](#aes-ctr-operations-encrypt)
 2. [27.7.2 Decrypt](#aes-ctr-operations-decrypt)
 3. [27.7.3 Generate
 Key](#aes-ctr-operations-generate-key)
 4. [27.7.4 Import
 Key](#aes-ctr-operations-import-key)
 5. [27.7.5 Export
 Key](#aes-ctr-operations-export-key)
 6. [27.7.6 Get key
 length](#aes-ctr-operations-get-key-length)
30. [28. AES-CBC](#aes-cbc)
 1. [28.1 Description](#aes-cbc-description)
 2. [28.2 Registration](#aes-cbc-registration)
 3. [28.3 [`AesCbcParams`]{idl="dictionary"
 }
 dictionary](#aes-cbc-params)
 4. [28.4 Operations](#aes-cbc-operations)
 1. [28.4.1 Encrypt](#aes-cbc-operations-encrypt)
 2. [28.4.2 Decrypt](#aes-cbc-operations-decrypt)
 3. [28.4.3 Generate
 Key](#aes-cbc-operations-generate-key)
 4. [28.4.4 Import
 Key](#aes-cbc-operations-import-key)
 5. [28.4.5 Export
 Key](#aes-cbc-operations-export-key)
 6. [28.4.6 Get key
 length](#aes-cbc-operations-get-key-length)
31. [29. AES-GCM](#aes-gcm)
 1. [29.1 Description](#aes-gcm-description)
 2. [29.2 Registration](#aes-gcm-registration)
 3. [29.3 [`AesGcmParams`]{idl="dictionary"
 }
 dictionary](#aes-gcm-params)
 4. [29.4 Operations](#aes-gcm-operations)
 1. [29.4.1 Encrypt](#aes-gcm-operations-encrypt)
 2. [29.4.2 Decrypt](#aes-gcm-operations-decrypt)
 3. [29.4.3 Generate
 Key](#aes-gcm-operations-generate-key)
 4. [29.4.4 Import
 Key](#aes-gcm-operations-import-key)
 5. [29.4.5 Export
 Key](#aes-gcm-operations-export-key)
 6. [29.4.6 Get key
 length](#aes-gcm-operations-get-key-length)
32. [30. AES-KW](#aes-kw)
 1. [30.1 Description](#aes-kw-description)
 2. [30.2 Registration](#aes-kw-registration)
 3. [30.3 Operations](#aes-kw-operations)
 1. [30.3.1 Wrap Key](#aes-kw-operations-wrap-key)
 2. [30.3.2 Unwrap Key](#aes-kw-operations-unwrap-key)
 3. [30.3.3 Generate
 Key](#aes-kw-operations-generate-key)
 4. [30.3.4 Import Key](#aes-kw-operations-import-key)
 5. [30.3.5 Export Key](#aes-kw-operations-export-key)
 6. [30.3.6 Get key
 length](#aes-kw-operations-get-key-length)
33. [31. HMAC](#hmac)
 1. [31.1 Description](#hmac-description)
 2. [31.2 Registration](#hmac-registration)
 3. [31.3 [`HmacImportParams`]{idl="dictionary"
 }
 dictionary](#hmac-importparams)
 4. [31.4 [`HmacKeyAlgorithm`]{idl="dictionary"
 }
 dictionary](#HmacKeyAlgorithm-dictionary)
 5. [31.5 [`HmacKeyGenParams`]{idl="dictionary"
 }
 dictionary](#hmac-keygen-params)
 6. [31.6 Operations](#hmac-operations)
 1. [31.6.1 Sign](#hmac-operations-sign)
 2. [31.6.2 Verify](#hmac-operations-verify)
 3. [31.6.3 Generate
 Key](#hmac-operations-generate-key)
 4. [31.6.4 Import Key](#hmac-operations-import-key)
 5. [31.6.5 Export Key](#hmac-operations-export-key)
 6. [31.6.6 Get key
 length](#hmac-operations-get-key-length)
34. [32. SHA](#sha)
 1. [32.1 Description](#sha-description)
 2. [32.2 Registration](#sha-registration)
 3. [32.3 Operations](#sha-operations)
 1. [32.3.1 Digest](#sha-operations-digest)
35. [33. HKDF](#hkdf)
 1. [33.1 Description](#hkdf-description)
 2. [33.2 Registration](#hkdf-registration)
 3. [33.3 [`HkdfParams`]{idl="dictionary"
 }
 dictionary](#hkdf-params)
 4. [33.4 Operations](#hkdf-operations)
 1. [33.4.1 Derive Bits](#hkdf-operations-derive-bits)
 2. [33.4.2 Import key](#hkdf-operations-import-key)
 3. [33.4.3 Get key
 length](#hkdf-operations-get-key-length)
36. [34. PBKDF2](#pbkdf2)
 1. [34.1 Description](#pbkdf2-description)
 2. [34.2 Registration](#pbkdf2-registration)
 3. [34.3 [`Pbkdf2Params`]{idl="dictionary"
 }
 dictionary](#pbkdf2-params)
 4. [34.4 Operations](#pbkdf2-operations)
 1. [34.4.1 Derive
 Bits](#pbkdf2-operations-derive-bits)
 2. [34.4.2 Import key](#pbkdf2-operations-import-key)
 3. [34.4.3 Get key
 length](#pbkdf2-operations-get-key-length)
37. [35. JavaScript Example Code](#examples-section)
 1. [35.1 Generate two key pairs, derive a shared key, encrypt some
 data](#example-key-exchange)
 2. [35.2 Generate a signing key pair, sign some
 data](#examples-signing)
 3. [35.3 Generate a symmetric key, encrypt some
 data](#examples-symmetric-encryption)
 4. [35.4 Generate unique name for
 download](#examples-random-uuid)
38. [36. IANA Considerations](#iana-section)
 1. [36.1 JSON Web Signature and Encryption Algorithms
 Registration](#iana-section-jws-jwa)
 2. [36.2 JSON Web Key Parameters
 Registration](#iana-section-jwk)
39. [37. Acknowledgments](#acknowledgements-section)
40. [A. Mapping between JSON Web Key / JSON Web
 Algorithm](#jwk-mapping)
 1. [A.1 Algorithm mappings](#jwk-mapping-alg)
41. [B. Mapping between Algorithm and
 SubjectPublicKeyInfo](#spki-mapping)
42. [C. Mapping between Algorithm and PKCS#8
 PrivateKeyInfo](#pkcs8-mapping)
43. [D. References](#references)
 1. [D.1 Normative references](#normative-references)
 2. [D.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

The Web Cryptography API defines a low-level interface to interacting
with cryptographic key material that is managed or exposed by user
agents. The API itself is agnostic of the underlying implementation of
key storage, but provides a common set of interfaces that allow rich web
applications to perform operations such as signature generation and
verification, hashing and verification, encryption and decryption,
without requiring access to the raw keying material.

Cryptographic transformations are exposed via the
[`SubtleCrypto`](#dfn-SubtleCrypto) interface, which defines
a set of methods for performing common cryptographic operations. In
addition to operations such as signature generation and verification,
hashing and verification, and encryption and decryption, the API
provides interfaces for key generation, key derivation and key import
and export.

::: header-wrapper
## 2. Use Cases

*This section is non-normative.*

::: header-wrapper
### 2.1 Multi-factor Authentication

A web application may wish to extend or replace existing
username/password based authentication schemes with authentication
methods based on proving that the user has access to some secret keying
material. Rather than using transport-layer authentication, such as TLS
client certificates, the web application may prefer the richer user
experience provided by authenticating within the application itself.

Using the Web Cryptography API, the application could locate suitable
client keys, which may have been previously generated via the user agent
or pre-provisioned out-of-band by the web application. It could then
perform cryptographic operations such as decrypting an authentication
challenge followed by signing an authentication response.

This exchange could be further strengthened by binding the
authentication to the TLS session over which the client is
authenticating, by deriving a key based on properties of the underlying
transport.

If a user does not already have a key associated with their account, the
web application could direct the user agent to either generate a new key
or to re-use an existing key of the user\'s choice.

::: header-wrapper
### 2.2 Protected Document Exchange

A web application may wish to limit the viewership of documents that
contain sensitive or personal information, even when these documents
have been securely received, such as over TLS.

Using the Web Cryptography API, the application could do so by
encrypting the documents with a secret key, and then wrapping that key
with the public keys associated with the authorized viewers. When a user
agent navigates to such a web application, the application would send
the encrypted form of the document. The user agent is then instructed to
unwrap the encryption key, using the user\'s private key, and from
there, decrypt and display the document.

::: header-wrapper
### 2.3 Cloud Storage

A web application may wish to permit users to protect the
confidentiality of data and documents stored with remote service
providers prior to uploading.

Using the Web Cryptography API, the application may have a user select a
private or secret key, optionally derive an encryption key from the
selected key, encrypt the document, and then upload the encrypted data
to the service provider using existing APIs.

This use case is similar to the [Protected Document
Exchange](#protected-document) use case, with viewership of the document
limited to the user themself.

::: header-wrapper
### 2.4 Document Signing

A web application may wish to accept electronic signatures on documents,
in lieu of requiring physical signatures.

Using the Web Cryptography API, the application may direct the user to
select a key, which may have been pre-provisioned out-of-band, or
generated specifically for the web application. Using this key, the
application may perform a signing operation over some data, as proof
that the user accepts the document.

::: header-wrapper
### 2.5 Data Integrity Protection

A web application may wish to cache data locally, while ensuring that
this data cannot be modified in an offline attack.

Using the Web Cryptography API, the application may use a public key
contained within the application to verify the contents of the data
cache. Previously, when data was added to the cache, it would have been
signed by the server with the corresponding private key. By validating
the signature when restoring data from the cache, the client ensures
that the cached data has not been tampered with.

::: header-wrapper
### 2.6 Secure Messaging

A web application may wish to employ message layer security using
schemes such as off-the-record (OTR) messaging, even when these messages
have been securely received, such as over TLS.

The Web Cryptography API enables OTR and similar message signing
schemes, by allowing key agreement to be performed. The two parties can
negotiate shared encryption keys and message authentication code (MAC)
keys, to allow encryption and decryption of messages, and to prevent
tampering.

::: header-wrapper
### 2.7 JavaScript Object Signing and Encryption (JOSE)

A web application may wish to interact with the structures and message
formats defined by the IETF JavaScript Object Signing and Encryption
(JOSE) Working Group.

Using the Web Cryptography API, the application may read and import keys
encoded in the JSON key format (JWK), validate messages that have been
integrity protected using digital signatures or MACs (JWS), or decrypt
messages that have been encrypted (JWE).

::: header-wrapper
## 3. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MUST*, *REQUIRED*, and *SHALL* in this document are to be
interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

The following conformance classes are defined by this specification:

[conforming user agent]

: A user agent is considered to be a [conforming user
 agent](#dfn-conforming-implementation) if it satisfies all of the
 *MUST*-, *REQUIRED*- and *SHALL*-level criteria in this
 specification that apply to implementations. This specification uses
 both the terms \"conforming user agent\" and \"user agent\" to refer
 to this product class.

Conformance requirements phrased as algorithms or specific steps may be
implemented in any manner, so long as the end result is equivalent. (In
particular, the algorithms defined in this specification are intended to
be easy to follow, and not intended to be performant.)

User agents that use ECMAScript to implement the APIs defined in this
specification *MUST* implement them in a manner consistent with the
ECMAScript Bindings defined in the Web IDL specification
\[[WebIDL](#bib-webidl "Web IDL Standard")\]
as this specification uses that specification and terminology.

Unless otherwise stated, string comparisons are done in a
[case-sensitive](#case-sensitive) manner. String literals in this
specification written in monospace font like \"`this`\" do not include
the enclosing quotes.

::: header-wrapper
### 3.1 Extensibility

Vendor-specific proprietary extensions to this specification are
strongly discouraged. Authors must not use such extensions, as doing so
reduces interoperability and fragments the user base, allowing only
users of specific user agents to access the content in question.

If vendor-specific extensions are needed, the members should be prefixed
by vendor-specific strings to prevent clashes with future versions of
this specification. Extensions must be defined so that the use of
extensions neither contradicts nor causes the non-conformance of
functionality defined in the specification.

When vendor-neutral extensions to this specification are needed, either
this specification can be updated accordingly, or an extension
specification can be written that overrides the requirements in this
specification. When someone applying this specification to their
activities decides that they will recognize the requirements of such an
extension specification, it becomes an [applicable
specification] for the purposes of conformance
requirements in this specification. Applicable specifications defined by
the [W3C] Web Cryptography
Working Group are listed in the table below.

 --------------- -----------
 Specification Reference
 --------------- -----------

Readers are advised to consult the errata to this specification for
updates to the table above.

::: header-wrapper
## 4. Scope

*This section is non-normative.*

::: header-wrapper
### 4.1 Level of abstraction

The specification attempts to focus on the common functionality and
features between various platform-specific or standardized cryptographic
APIs, and avoid features and functionality that are specific to one or
two implementations. As such this API allows key generation, management,
and exchange with a level of abstraction that avoids developers needing
to care about the implementation of the underlying key storage. The API
is focused specifically around CryptoKey objects, as an abstraction for
the underlying raw cryptographic keying material. The intent behind this
is to allow an API that is generic enough to allow conforming user
agents to expose keys that are stored and managed directly by the user
agent, that may be stored or managed using isolated storage APIs such as
per-user key stores provided by some operating systems, or within key
storage devices such as secure elements, while allowing rich web
applications to manipulate the keys and without requiring the web
application be aware of the nature of the underlying key storage.

::: header-wrapper
### 4.2 Cryptographic algorithms

Because the underlying cryptographic implementations will vary between
conforming user agents, and may be subject to local policy, including
but not limited to concerns such as government or industry regulation,
security best practices, intellectual property concerns, and constrained
operational environments, this specification does not dictate a
mandatory set of algorithms that *MUST* be implemented. Instead, it
defines a common set of bindings that can be used in an
algorithm-independent manner, a common framework for discovering if a
user agent or key handle supports the underlying algorithm, and a set of
conformance requirements for the behaviors of individual algorithms, if
implemented.

::: header-wrapper
### 4.3 Out of scope

This API, while allowing applications to generate, retrieve, and
manipulate keying material, does not specifically address the
provisioning of keys in particular types of key storage, such as secure
elements or smart cards. This is due to such provisioning operations
often being burdened with vendor-specific details that make defining a
vendor-agnostic interface an unsuitably unbounded task. Additionally,
this API does not deal with or address the discovery of cryptographic
modules, as such concepts are dependent upon the underlying user agent
and are not concepts that are portable between common operating systems,
cryptographic libraries, and implementations.

::: header-wrapper
## 5. Concepts

*This section is non-normative.*

::: header-wrapper
### 5.1 Underlying Cryptographic Implementation

This specification assumes, but does not require, that conforming user
agents do not and will not be directly implementing cryptographic
operations within the user agent itself. Historically, many user agents
have deferred cryptographic operations, such as those used within TLS,
to existing APIs that are available as part of the underlying operating
system or to third-party modules that are managed independently of the
user agent.

The [`CryptoKey`](#dfn-CryptoKey) object represents the bridge between the
JavaScript execution environment and these underlying libraries, through
the use of the internal slot named
[`[[handle]]`](#dfn-CryptoKey-slot-handle). The handle
represents an opaque type that is implementation specific, which may not
be represented within a JavaScript type, nor is it ever exposed to
script authors. In this way, the
[`CryptoKey`](#dfn-CryptoKey) object is the conceptual equivalent to
the JavaScript executing environment as the
[`[[handle]]`](#dfn-CryptoKey-slot-handle) is to the underlying
cryptographic implementation.

These APIs are traditionally built around a notion of cryptographic
providers, an abstraction for a specific implementation of a set of
algorithms. The operating system or library may come with a default
provider, and users are frequently allowed to add additional providers,
reconfigure the set of enabled algorithms, or otherwise customize how
cryptographic services are provided.

While it is assumed that most user agents will be interacting with a
cryptographic provider that is implemented purely in software, it is not
required by this specification. As a result, the capabilities of some
implementations may be limited by the capabilities of the underlying
hardware, and, depending on how the user has configured the underlying
cryptographic library, this may be entirely opaque to the User Agent.

::: header-wrapper
### 5.2 Key Storage

This specification does not explicitly provide any new storage
mechanisms for [`CryptoKey`](#dfn-CryptoKey) objects. Instead, by
defining [serialization and deserialization
steps](#cryptokey-interface-serializable) for
[`CryptoKey`](#dfn-CryptoKey) objects, any existing or future web
storage mechanisms that support storing [serializable
objects](#dfn-serializable-objects) can be used to store
[`CryptoKey`](#dfn-CryptoKey) objects.

In practice, it is expected that most authors will make use of the
Indexed Database API
\[[INDEXEDDB](#bib-indexeddb "Indexed Database API")\], which allows associative storage of key/value
pairs, where the key is some string identifier meaningful to the
application, and the value is a
[`CryptoKey`](#dfn-CryptoKey) object. This allows the storage and
retrieval of key material, without ever exposing that key material to
the application or the JavaScript environment. Additionally, this allows
authors the full flexibility to store any additional metadata with the
[`CryptoKey`](#dfn-CryptoKey) itself.

::: header-wrapper
## 6. Security considerations

*This section is non-normative.*

::: header-wrapper
### 6.1 Security considerations for implementers

By not providing an explicit storage mechanism, this specification
assumes that [`CryptoKey`](#dfn-CryptoKey) objects are scoped to the
current execution environment and any storage mechanisms available to
that environment (e.g. Indexed Database API). Application authors rely
upon this for the security of their applications; two origins with the
same [`CryptoKey`](#dfn-CryptoKey) object have full access to the
underlying key, and as such, messages from these applications cannot be
distinguished, and messages sent to these applications can be fully
recovered. Implementors should ensure that no
[`CryptoKey`](#dfn-CryptoKey) objects are shared between two origins
unless the author has explicitly chosen to share (e.g., such as through
the use of postMessage)

A number of algorithms specified within this specification perform
computationally intensive work, such as the generation of significantly
large prime numbers, or through repeated iterations of a particular
operation. As such, hostile applications may attempt to misuse this API
and attempt to cause significant amount of work to be performed by an
implementation, denying access or services to other applications that
are executing. Implementations should take steps to mitigate these
risks, such as limiting the amount of operations an implementation
performs concurrently, requiring user consent for operations that may be
known to be disruptive for the executing environment, or defining
device-specific limits on attributes such as key sizes or iteration
counts.

::: header-wrapper
### 6.2 Security considerations for authors

This specification includes descriptions for a variety of cryptographic
operations, some of which have known weaknesses when used
inappropriately. Application developers must take care and review
appropriate and current cryptographic literature, to understand and
mitigate such issues. In general, application developers are
**strongly** discouraged from inventing new cryptographic protocols; as
with all applications, users of this specification will be best served
through the use of existing protocols, of which this specification
provides the necessary building blocks to implement.

In order to use the APIs defined in this specification to provide any
meaningful cryptographic assurances, authors must be familiar with
existing threats to web applications, as well as the underlying security
model employed. Conceptually, issues such as script injection are the
equivalent to remote code execution in other operating environments, and
allowing hostile script to be injected may allow for the exfiltration of
keys or data. Script injection may come from other applications, for
which the judicious use of Content Security Policy may mitigate, or it
may come from hostile network intermediaries, for which the use of
Transport Layer Security may mitigate.

This specification does not define any specific mechanisms for the
storage of cryptographic keys. By default, unless specific effort is
taken by the author to persist keys, such as through the use of the
Indexed Database API, keys created with this API will only be valid for
the duration of the current page (e.g. until a navigation event).
Authors that wish to use the same key across different pages or multiple
browsing sessions must employ existing web storage technologies. Authors
should be aware of the security assumptions of these technologies, such
as the same-origin security model; that is, any application that shares
the same scheme, host, and port have access to the same storage
partition, even if other information, such as the path, may differ.
Authors may explicitly choose to relax this security through the use of
inter-origin sharing, such as `postMessage`.

Authors should be aware that this specification places no normative
requirements on implementations as to how the underlying cryptographic
key material is stored. The only requirement is that key material is not
exposed to script, except through the use of the
[`exportKey`](#dfn-SubtleCrypto-method-exportKey) and
[`wrapKey`](#dfn-SubtleCrypto-method-wrapKey) operations. In particular, it does not
guarantee that the underlying cryptographic key material will not be
persisted to disk, possibly unencrypted, nor that it will be
inaccessible to users or other applications running with the same
privileges as the User Agent. Any application or user that has access to
the device storage may be able to recover the key material, even through
scripts may be prohibited.

This specification places no normative requirements on how
implementations handle key material once all references to it go away.
That is, conforming user agents are not required to zeroize key
material, and it may still be accessible on device storage or device
memory, even after all references to the
[`CryptoKey`](#dfn-CryptoKey) have gone away.

Applications may share a
[`CryptoKey`](#dfn-CryptoKey) object across security boundaries, such
as origins, through the use of the structured clone algorithm and APIs
such as `postMessage`. While access to the underlying cryptographic key
material may be restricted, based upon the
[`extractable`](#dom-cryptokey-extractable) attribute, once a key is shared with a
destination origin, the source origin can not later restrict or revoke
access to the key. As such, authors must be careful to ensure they trust
the destination origin to take the same mitigations against hostile
script that the source origin employs. Further, in the event of script
injection on the source origin, attackers may post the key to an origin
under attacker control. Any time that the user agent visits the
attacker\'s origin, the user agent may be directed to perform
cryptographic operations using that key, such as the decryption of
existing messages or the creation of new, fraudulent messages.

Authors should be aware that users may, at any time, choose to clear the
storage associated with an origin, potentially destroying keys.
Applications that are meant to provide long-term storage, such as on the
server, should consider techniques such as key escrow to prevent such
data from being inaccessible. Authors should not presume that keys will
be available indefinitely.

::: header-wrapper
### 6.3 Security considerations for users

Users of applications that employ the APIs defined in this specification
should be aware that these applications will have full access to all
messages exchanged, regardless of the cryptography employed. That is,
for messages that are encrypted, applications that use these APIs will
have full access to the decrypted message as well.

::: header-wrapper
## 7. Privacy considerations

*This section is non-normative.*

Fingerprinting
: By exposing additional APIs that reflect capabilities of the
 underlying platform, this specification may allow malicious
 applications to determine or distinguish different user agents or
 devices.

Super-cookies
: This specification does not provide any means for malicious
 applications to create identifiers that outlive existing web storage
 technologies. However, care must be taken when introducing future
 revisions to this API or additional cryptographic capabilities, such
 as those that are hardware backed (e.g.: smart cards or Trusted
 Platform Modules). Considering that such storage is designed to
 prevent any two users from having the same underlying key data, such
 APIs may represent a real risk of being used as a permanent
 identifier against the user\'s wishes.

Use of [`randomUUID`](#dfn-Crypto-method-randomUUID) as user ID
: [`randomUUID`](#dfn-Crypto-method-randomUUID) is useful for generating [user
 IDs](https://w3cping.github.io/privacy-threat-model/#user-id), but
 does not directly give any ability to generate [global
 identifiers](https://w3cping.github.io/privacy-threat-model/#global-identifier).

::: header-wrapper
## 8. Dependencies

This specification relies on underlying specifications.

DOM

: A [conforming user
 agent](#dfn-conforming-implementation) *MUST* support at least
 the subset of the functionality defined in DOM that this
 specification relies upon; in particular, it *MUST* support
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)s and
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). \[[DOM](#bib-dom "DOM Standard")\]

HTML

: A [conforming user
 agent](#dfn-conforming-implementation) *MUST* support at least
 the subset of the functionality defined in HTML that this
 specification relies upon; in particular, it *MUST* support the
 [`ArrayBufferView`](https://webidl.spec.whatwg.org/#ArrayBufferView) typedef and [serializable
 objects](#dfn-serializable-objects).
 \[[HTML](#bib-html "HTML Standard")\]

Web IDL

: A [conforming user
 agent](#dfn-conforming-implementation) *MUST* be a conforming
 implementation of the IDL fragments in this specification, as
 described in the Web IDL specification.
 \[[WebIDL](#bib-webidl "Web IDL Standard")\]

::: header-wrapper
## 9. Terminology

The terms
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer),
[`ArrayBufferView`](https://webidl.spec.whatwg.org/#ArrayBufferView), and [serializable
objects], are defined by the HTML
specification \[[HTML](#bib-html "HTML Standard")\].

The terms
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) and
[`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) are defined in
\[[WEBIDL](#bib-webidl "Web IDL Standard")\].

The term [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence)
is defined in \[[Infra](#bib-infra "Infra Standard")\].

The [length in bits] of a [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence)
is its
[length](https://infra.spec.whatwg.org/#byte-sequence-length)
multiplied by 8.

A [byte sequence containing a bit
sequence] `b` is
the [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence)
obtained by first appending zero or more bits of value zero to
`b` such that the length of the resulting bit sequence is
minimal and an integer multiple of 8 and then considering each
consecutive sequence of 8 bits in that string as a byte.

To [convert a non-negative integer `i` to a byte sequence of
length `n`], where
`n` \* 8 is greater than the logarithm to base 2 of
`i`, calculate the binary representation of `i`,
most significant bit first, prefix this with sufficient zero bits to
form a bit sequence of length `n` \* 8, and then return the
[byte
sequence](https://infra.spec.whatwg.org/#byte-sequence)
formed by considering each consecutive sequence of 8 bits in that bit
sequence as a byte.

To [convert a byte sequence to a non-negative
integer], interpret the byte sequence as a
big-endian non-negative integer (most significant bit first), and return
that integer.

Comparing two strings in a [case-sensitive] manner means
comparing them exactly, code point for code point.

Comparing two strings in a [ASCII case-insensitive] manner means comparing them exactly, code point for code
point, except that the codepoints in the range U+0041 .. U+005A (i.e.
LATIN CAPITAL LETTER A to LATIN CAPITAL LETTER Z) and the corresponding
codepoints in the range U+0061 .. U+007A (i.e. LATIN SMALL LETTER A to
LATIN SMALL LETTER Z) are also considered to match.

When this specification says to [terminate the
algorithm], the user agent must terminate
the algorithm after finishing the step it is on. The algorithm referred
to is the set of specification-defined processing steps, rather than the
underlying cryptographic algorithm that may be in the midst of
processing.

When this specification says to [parse an ASN.1
structure], the user agent must perform the
following steps:

1. Let `data` be a sequence of bytes to be parsed.

2. Let `structure` be the ASN.1 structure to be parsed.

3. Let `exactData` be an optional boolean value. If it is
 not supplied, let it be initialized to `true`.

4. Parse `data` according to the Distinguished Encoding
 Rules of
 \[[X690](#bib-x690 "Information technology - ASN.1 encoding rules: Specification of Basic Encoding Rules (BER), Canonical Encoding Rules (CER) and Distinguished Encoding Rules (DER)")\], using `structure` as the ASN.1
 structure to be decoded.

5. If `exactData` was specified, and all of the bytes of
 `data` were not consumed during the parsing phase, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

6. Return the parsed ASN.1 structure.

When this specification says to [parse a
subjectPublicKeyInfo], the user agent must [parse an
ASN.1
structure](#concept-parse-an-asn1-structure), with `data` set to
the sequence of bytes to be parsed, `structure` as the ASN.1
structure of subjectPublicKeyInfo, as specified in
\[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\], and `exactData` set to `true`.

When this specification says to [parse a
PrivateKeyInfo], the user agent must [parse an
ASN.1
structure](#concept-parse-an-asn1-structure) with `data` set to
the sequence of bytes to be parsed, `structure` as the ASN.1
structure of PrivateKeyInfo, as specified in
\[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\], and `exactData` set to `true`.

When this specification says to [parse a JWK], the user agent must
run the following steps:

1. Let `data` be the sequence of bytes to be parsed.

2. Let `json` be the Unicode string that results from
 interpreting `data` according to UTF-8.

3. Convert `json` to UTF-16.

4. Let `result` be the object literal that results from
 executing the `JSON.parse` internal function in the context of a new
 global object, with `text` argument set to a JavaScript String
 containing `json`.

5. Let `key` be the result of converting `result`
 to the IDL dictionary type of
 [`JsonWebKey`](#dfn-JsonWebKey).

6. If the [`kty`](#dom-jsonwebkey-kty) field of `key` is not
 defined, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

7. Return `key`.

When this specification says to calculate the [usage
intersection] of two sequences, `a`
and `b` the result shall be a sequence containing each
[recognized key usage
value](#dfn-RecognizedKeyUsage) that appears in both
`a` and `b`, in the order listed in the list of
[recognized key usage
value](#dfn-RecognizedKeyUsage)s, where a value is said to
appear in a sequence if an element of the sequence exists that is a
case-sensitive string match for that value.

When this specification says to calculate the [ normalized value of a
usages list], `usages`
the result shall be the [usage
intersection](#concept-usage-intersection) of `usages` and a
sequence containing all [recognized key usage
value](#dfn-RecognizedKeyUsage)s.

When this specification refers to the [cached ECMAScript
object] associated with an internal slot
\[\[`slot`\]\] of `object`, the user agent must
run the following steps:

1.

 If the \[\[`slot`\_cached\]\] internal slot of `object` is undefined:
 : Set the \[\[`slot`\_cached\]\] internal slot of
 `object` to the result of performing type conversion
 to an ECMAScript object as defined in
 \[[WebIDL](#bib-webidl "Web IDL Standard")\] to the contents of the
 \[\[`slot`\]\] internal slot of `object`.

2. Return the contents of the \[\[`slot`\_cached\]\]
 internal slot of `object`.

::: header-wrapper
## 10. Crypto interface

The [`Crypto`] interface represents an interface to general
purpose cryptographic functionality including a cryptographically strong
pseudo-random number generator seeded with truly random values.

```
WebIDLpartial interface mixin WindowOrWorkerGlobalScope {
 [SameObject] readonly attribute Crypto crypto;
};

[Exposed=(Window,Worker)]
interface Crypto {
 [SecureContext] readonly attribute SubtleCrypto subtle;
 ArrayBufferView getRandomValues(ArrayBufferView array);
 [SecureContext] DOMString randomUUID();
};
```

Implementations should generate cryptographically strong random values
using well-established cryptographic pseudo-random number generators
seeded with high-quality entropy, such as from an operating-system
entropy source (e.g., \"/dev/urandom\"). This specification provides no
lower-bound on the information theoretic entropy present in
cryptographically strong random values, but implementations should make
a best effort to provide as much entropy as practicable.

This interface defines a synchronous method for obtaining
cryptographically strong random values. While some devices and
implementations may support truly random cryptographic number generators
or provide interfaces that block when there is insufficient entropy,
implementations are discouraged from using these sources when
implementing getRandomValues, both for performance and to avoid
depleting the system of entropy. Instead, these sources should be used
to seed a cryptographic pseudo-random number generator that can then
return suitable values efficiently.

::: header-wrapper
### 10.1 Methods and Parameters

::: header-wrapper
#### 10.1.1 The getRandomValues method

The [`getRandomValues`] method generates cryptographically
strong random values. It must act as follows:

1. If `array` is not an
 [`Int8Array`](https://webidl.spec.whatwg.org/#idl-Int8Array),
 [`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array),
 [`Uint8ClampedArray`](https://webidl.spec.whatwg.org/#idl-Uint8ClampedArray),
 [`Int16Array`](https://webidl.spec.whatwg.org/#idl-Int16Array),
 [`Uint16Array`](https://webidl.spec.whatwg.org/#idl-Uint16Array),
 [`Int32Array`](https://webidl.spec.whatwg.org/#idl-Int32Array),
 [`Uint32Array`](https://webidl.spec.whatwg.org/#idl-Uint32Array),
 [`BigInt64Array`](https://webidl.spec.whatwg.org/#idl-BigInt64Array), or
 [`BigUint64Array`](https://webidl.spec.whatwg.org/#idl-BigUint64Array), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`TypeMismatchError`](https://webidl.spec.whatwg.org/#typemismatcherror) and [terminate the
 algorithm](#terminate-the-algorithm).

2. Let `byteLength` be the [byte
 length](https://webidl.spec.whatwg.org/#buffersource-byte-length)
 of `array`.

3. If `byteLength` is greater than 65536,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) and [terminate the
 algorithm](#terminate-the-algorithm).

4. Let `bytes` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 of length `byteLength`.

5. Fill `bytes` with cryptographically secure random bytes.

6. [Write](https://webidl.spec.whatwg.org/#arraybufferview-write)
 `bytes` into `array`.

7. Return `array`.

Do not generate keys using the `getRandomValues` method. Use the
[`generateKey`](#dfn-SubtleCrypto-method-generateKey) method instead.

::: header-wrapper
#### 10.1.2 The randomUUID method

The [`randomUUID`] method generates a new [version 4
UUID](https://www.rfc-editor.org/info/rfc4122/#section-4.4) and returns
its [namespace specific string
representation](https://www.rfc-editor.org/info/rfc2141/#section-2.2) as
described in [section
3](https://www.rfc-editor.org/info/rfc4122/#section-3) of
\[[RFC4122](#bib-rfc4122 "A Universally Unique IDentifier (UUID) URN Namespace")\]. To [generate a random
UUID]:

1. Let `bytes` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 of length 16.

2. Fill `bytes` with cryptographically secure random bytes.

3. Set the 4 most significant bits of `bytes`\[6\], which
 represent the UUID
 [version](https://www.rfc-editor.org/info/rfc4122/#section-4.1.3),
 to `0100`.

4. Set the 2 most significant bits of `bytes`\[8\], which
 represent the UUID
 [variant](https://www.rfc-editor.org/info/rfc4122/#section-4.1.1),
 to `10`.

5. Return the [string
 concatenation](https://infra.spec.whatwg.org/#string-concatenate) of «

 1. [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[0\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[1\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[2\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[3\],
 2. \"`-`\",
 3. [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[4\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[5\],
 4. \"`-`\",
 5. [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[6\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[7\],
 6. \"`-`\",
 7. [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[8\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[9\],
 8. \"`-`\",
 9. [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[10\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[11\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[12\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[13\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[14\], [hexadecimal
 representation](#dfn-hexadecimal-representation) of
 `bytes`\[15\]

 ».

For the steps described in the algorithm to [generate a random
UUID](#dfn-generate-a-random-uuid), the [hexadecimal
representation] of a byte `value` is
the two-character string created by expressing `value` in
hexadecimal using [ASCII lower hex
digits](https://infra.spec.whatwg.org/#ascii-lower-hex-digit),
left-padded with \"`0`\" to reach two [ASCII lower hex
digits](https://infra.spec.whatwg.org/#ascii-lower-hex-digit).

::: header-wrapper
### 10.2 Attributes

::: header-wrapper
#### 10.2.1 The subtle attribute

The [`subtle`] attribute provides an instance of
the [`SubtleCrypto`](#dfn-SubtleCrypto) interface which provides
low-level cryptographic primitives and algorithms.

::: header-wrapper
## 11. Algorithm dictionary

The [`Algorithm`] object is a dictionary object
\[[WEBIDL](#bib-webidl "Web IDL Standard")\]
which is used to specify an algorithm and any additional parameters
required to fully specify the desired operation.

```
WebIDLtypedef (object or DOMString) AlgorithmIdentifier;

typedef AlgorithmIdentifier HashAlgorithmIdentifier;

dictionary Algorithm {
 required DOMString name;
};
```

::: header-wrapper
### 11.1 [`Algorithm`](#dfn-Algorithm) Dictionary Members

[`name`]
: The name of the [registered algorithm](#algorithms) to use.

::: header-wrapper
## 12. KeyAlgorithm dictionary

The [`KeyAlgorithm`] dictionary represents information about the
contents of a given
[`CryptoKey`](#dfn-CryptoKey) object.

```
WebIDLdictionary KeyAlgorithm {
 required DOMString name;
};
```

::: header-wrapper
### 12.1 Description

*This section is non-normative.*

The [`KeyAlgorithm`](#dfn-KeyAlgorithm) dictionary is provided
to aid in documenting how fixed, public properties of a
[`CryptoKey`](#dfn-CryptoKey) are reflected back to an application.
The actual dictionary type is never exposed to applications.

::: header-wrapper
### 12.2 KeyAlgorithm dictionary members

[`name`]
: The name of the algorithm used to generate the
 [`CryptoKey`](#dfn-CryptoKey)

::: header-wrapper
## 13. CryptoKey interface

The [`CryptoKey`] object represents an opaque reference to keying
material that is managed by the user agent.

```
WebIDLenum KeyType { "public", "private", "secret" };

enum KeyUsage { "encrypt", "decrypt", "sign", "verify", "deriveKey", "deriveBits", "wrapKey", "unwrapKey" };

[SecureContext,Exposed=(Window,Worker),Serializable]
interface CryptoKey {
 readonly attribute KeyType type;
 readonly attribute boolean extractable;
 readonly attribute object algorithm;
 readonly attribute object usages;
};
```

::: header-wrapper
### 13.1 Description

*This section is non-normative.*

This specification provides a uniform interface for many different kinds
of keying material managed by the user agent. This may include keys that
have been generated by the user agent, derived from other keys by the
user agent, imported to the user agent through user actions or using
this API, pre-provisioned within software or hardware to which the user
agent has access or made available to the user agent in other ways. The
term key refers broadly to any keying material including actual keys for
cryptographic operations and secret values obtained within key
derivation or exchange operations.

The CryptoKey object is not required to directly interface with the
underlying key storage mechanism, and may instead simply be a reference
for the user agent to understand how to obtain the keying material when
needed, e.g. when performing a cryptographic operation.

::: header-wrapper
### 13.2 Key interface data types

[`KeyType`]
: The type of a key. The [recognized key type
 values]
 are \"`public`\", \"`private`\", and \"`secret`\". Opaque keying
 material, including that used for symmetric algorithms, is
 represented by [`secret`], while keys
 used as part of asymmetric algorithms composed of public/private
 keypairs will be either [`public`] or
 [`private`].

[`KeyUsage`]
: A type of operation that may be performed using a key. The
 [recognized key usage values] are
 [`encrypt`],
 [`decrypt`], [`sign`], [`verify`],
 [`deriveKey`],
 [`deriveBits`],
 [`wrapKey`] and
 [`unwrapKey`].

::: header-wrapper
### 13.3 CryptoKey internal slots

Every [`CryptoKey`](#dfn-CryptoKey) object has a set of
internal slots that store information about the key. These slots are not
exposed as part of this specification; they represent internal state
that an implementation uses to implement this specification. The
notational convention used in
\[[ECMA-262](#bib-ecma-262 "ECMAScript Language Specification")\] is re-used here; internal slots are identified by
names enclosed in double square brackets \[\[ \]\].

All [`CryptoKey`](#dfn-CryptoKey) objects have internal slots named
[\[\[type\]\]],
[\[\[extractable\]\]],
[\[\[algorithm\]\]],
[\[\[algorithm_cached\]\]],
[\[\[usages\]\]],
[\[\[usages_cached\]\]],
and [\[\[handle\]\]].

The contents of the
[`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
shall be, or be derived from, a
[`KeyAlgorithm`](#dfn-KeyAlgorithm). The contents of the
[`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot shall
be of type Sequence\<KeyUsage\>.

[`[[handle]]`](#dfn-CryptoKey-slot-handle) slot is an opaque
type that contains whatever data the underlying cryptographic
implementation uses to represent a logical key. Different cryptographic
implementations may use different types, ranging from opaque identifiers
represented as integers, pointer types, or structures that provide
identifying information. These handles are never exposed to
applications.

::: header-wrapper
### 13.4 CryptoKey interface members

[`type`]
: Reflects the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot,
 which contains the type of the underlying key.

[`extractable`]
: Reflects the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot, which indicates whether or not the raw keying material may be
 exported by the application.

[`algorithm`]
: Returns the [cached ECMAScript
 object](#concept-cached-object) associated with the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal
 slot.

[`usages`]
: Returns the [cached ECMAScript
 object](#concept-cached-object) associated with the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot,
 which indicates which cryptographic operations are permissible to be
 used with this key.

::: header-wrapper
### 13.5 Serialization and deserialization steps

[`CryptoKey`](#dfn-CryptoKey) objects are [serializable
objects](#dfn-serializable-objects). Their [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps),
given `value` and `serialized`, are:

1. Set `serialized`.\[\[Type\]\] to the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `value`.
2. Set `serialized`.\[\[Extractable\]\] to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `value`.
3. Set `serialized`.\[\[Algorithm\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization)
 of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `value`.
4. Set `serialized`.\[\[Usages\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization)
 of the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `value`.
5. Set `serialized`.\[\[Handle\]\] to the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `value`.

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps),
given `serialized` and `value`, are:

1. Initialize the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `value` to `serialized`.\[\[Type\]\].
2. Initialize the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `value` to
 `serialized`.\[\[Extractable\]\].
3. Initialize the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `value` to the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization)
 of `serialized`.\[\[Algorithm\]\].
4. Initialize the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `value` to the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization)
 of `serialized`.\[\[Usages\]\].
5. Initialize the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `value` to `serialized`.\[\[Handle\]\].

When deserializing a serialized
[`CryptoKey`](#dfn-CryptoKey) object, it is important that the object
is not deserialized as a different type. This is normatively required by
the definition of the [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps),
but it merits specific attention, as such deserialization may expose the
contents of the key material, which in some cases (such as when the
[`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal slot
is false) should not be exposed to applications.

::: header-wrapper
## 14. SubtleCrypto interface

The [`SubtleCrypto`] interface provides a set of methods for dealing
with low-level cryptographic primitives and algorithms.

```
WebIDLenum KeyFormat { "raw", "spki", "pkcs8", "jwk" };

[SecureContext,Exposed=(Window,Worker)]
interface SubtleCrypto {
 Promise<ArrayBuffer> encrypt(
 AlgorithmIdentifier algorithm,
 CryptoKey key,
 BufferSource data
 );
 Promise<ArrayBuffer> decrypt(
 AlgorithmIdentifier algorithm,
 CryptoKey key,
 BufferSource data
 );
 Promise<ArrayBuffer> sign(
 AlgorithmIdentifier algorithm,
 CryptoKey key,
 BufferSource data
 );
 Promise<boolean> verify(
 AlgorithmIdentifier algorithm,
 CryptoKey key,
 BufferSource signature,
 BufferSource data
 );
 Promise<ArrayBuffer> digest(
 AlgorithmIdentifier algorithm,
 BufferSource data
 );

 Promise<(CryptoKey or CryptoKeyPair)> generateKey(
 AlgorithmIdentifier algorithm,
 boolean extractable,
 sequence<KeyUsage> keyUsages
 );
 Promise<CryptoKey> deriveKey(
 AlgorithmIdentifier algorithm,
 CryptoKey baseKey,
 AlgorithmIdentifier derivedKeyType,
 boolean extractable,
 sequence<KeyUsage> keyUsages
 );
 Promise<ArrayBuffer> deriveBits(
 AlgorithmIdentifier algorithm,
 CryptoKey baseKey,
 optional [EnforceRange] unsigned long? length = null
 );

 Promise<CryptoKey> importKey(
 KeyFormat format,
 (BufferSource or JsonWebKey) keyData,
 AlgorithmIdentifier algorithm,
 boolean extractable,
 sequence<KeyUsage> keyUsages
 );
 Promise<(ArrayBuffer or JsonWebKey)> exportKey(
 KeyFormat format,
 CryptoKey key
 );

 Promise<ArrayBuffer> wrapKey(
 KeyFormat format,
 CryptoKey key,
 CryptoKey wrappingKey,
 AlgorithmIdentifier wrapAlgorithm
 );
 Promise<CryptoKey> unwrapKey(
 KeyFormat format,
 BufferSource wrappedKey,
 CryptoKey unwrappingKey,
 AlgorithmIdentifier unwrapAlgorithm,
 AlgorithmIdentifier unwrappedKeyAlgorithm,
 boolean extractable,
 sequence<KeyUsage> keyUsages
 );
};
```

The [`SubtleCrypto`](#dfn-SubtleCrypto) interface is named
\"SubtleCrypto\" to reflect the fact that many of these algorithms have
subtle usage requirements in order to provide the required algorithmic
security guarantees.

For example, the direct use of an unauthenticated encryption scheme,
such as [AES in counter mode](#aes-ctr), gives potential attackers the
ability to manipulate bits in the output by manipulating bits in the
input, compromising the integrity of the message. However, AES-CTR can
be used securely in combination with other cryptographic primitives,
such as message authentication codes, to ensure the integrity of the
protected message, but only when the message authentication code is
constructed over the encrypted message and IV.

Developers making use of the SubtleCrypto interface are expected to be
aware of the security concerns associated with both the design and
implementation of the various algorithms provided. The raw algorithms
are provided in order to allow developers maximum flexibility in
implementing a variety of protocols and applications, each of which may
represent the composition and security parameters in a unique manner
that necessitate the use of the raw algorithms.

::: header-wrapper
### 14.1 Data Types

[`KeyFormat`]
: Specifies a serialization format for a key. The [recognized key
 format values]
 are:

 [`raw`]
 : An unformatted sequence of bytes. Intended for secret keys.

 [`pkcs8`]
 : The DER encoding of the PrivateKeyInfo structure from
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\].

 [`spki`]
 : The DER encoding of the SubjectPublicKeyInfo structure from
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\].

 [`jwk`]
 : The key is a
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary encoded
 as a JavaScript object

::: header-wrapper
### 14.2 Task Source

The [crypto task source]
: This [task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source)
 is used to queue tasks to resolve or reject promises created in
 response to calls to methods of
 [`SubtleCrypto`](#dfn-SubtleCrypto).

This specification makes no specific requirements on the ordering of
responses to calls to methods of
[`SubtleCrypto`](#dfn-SubtleCrypto), neither between
multiple calls, nor between calls and tasks from other [task
sources](https://html.spec.whatwg.org/multipage/webappapis.html#task-source). This task source is merely used to [queue a
task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
to resolve or reject the relevant promise whenever the cryptographic
operation is completed, in order to [prevent race
conditions](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-for-spec-authors).

::: header-wrapper
### 14.3 Methods and Parameters

All errors are reported asynchronously by rejecting the returned
Promise. This includes Web IDL type mapping errors.

::: header-wrapper
#### 14.3.1 The encrypt method

The [`encrypt`] method returns a new Promise object
that will encrypt data using the specified
[`AlgorithmIdentifier`](#dom-algorithmidentifier) with the supplied
[`CryptoKey`](#dfn-CryptoKey). It must act as follows:

1. Let `algorithm` and `key` be the `algorithm`
 and `key` parameters passed to the
 [`encrypt`](#dfn-SubtleCrypto-method-encrypt)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`encrypt`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `data` be the result of [getting a copy of the bytes
 held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `data` parameter passed to
 the
 [`encrypt`](#dfn-SubtleCrypto-method-encrypt)`()` method.

5. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

6. Let `promise` be a new Promise.

7. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

8. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

9. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

10. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` does not contain an entry that is \"`encrypt`\",
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

11. Let `ciphertext` be the result of performing the encrypt
 operation specified by `normalizedAlgorithm` using
 `algorithm` and `key` and with
 `data` as `plaintext`.

12. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

13. Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `ciphertext`.

14. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.2 The decrypt method

The [`decrypt`] method returns a new Promise object
that will decrypt data using the specified
[`AlgorithmIdentifier`](#dom-algorithmidentifier) with the supplied
[`CryptoKey`](#dfn-CryptoKey). It must act as follows:

1. Let `algorithm` and `key` be the `algorithm`
 and `key` parameters passed to the
 [`decrypt`](#dfn-SubtleCrypto-method-decrypt)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`decrypt`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `data` be the result of [getting a copy of the bytes
 held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `data` parameter passed to
 the
 [`decrypt`](#dfn-SubtleCrypto-method-decrypt)`()` method.

5. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

6. Let `promise` be a new Promise.

7. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

8. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

9. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

10. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` does not contain an entry that is \"`decrypt`\",
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

11. Let `plaintext` be the result of performing the decrypt
 operation specified by `normalizedAlgorithm` using
 `key` and `algorithm` and with
 `data` as `ciphertext`.

12. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

13. Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `plaintext`.

14. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.3 The sign method

The [`sign`] method returns a new Promise object that will
sign data using the specified
[`AlgorithmIdentifier`](#dom-algorithmidentifier) with the supplied
[`CryptoKey`](#dfn-CryptoKey). It must act as follows:

1. Let `algorithm` and `key` be the `algorithm`
 and `key` parameters passed to the
 [`sign`](#dfn-SubtleCrypto-method-sign)`()` method, respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to \"`sign`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `data` be the result of [getting a copy of the bytes
 held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `data` parameter passed to
 the
 [`sign`](#dfn-SubtleCrypto-method-sign)`()` method.

5. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

6. Let `promise` be a new Promise.

7. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

8. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

9. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

10. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` does not contain an entry that is \"`sign`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

11. Let `signature` be the result of performing the sign
 operation specified by `normalizedAlgorithm` using
 `key` and `algorithm` and with
 `data` as `message`.

12. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

13. Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `signature`.

14. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.4 The verify method

The [`verify`] method returns a new Promise object that will
verify data using the specified
[`AlgorithmIdentifier`](#dom-algorithmidentifier) with the supplied
[`CryptoKey`](#dfn-CryptoKey). It must act as follows:

1. Let `algorithm` and `key` be the `algorithm`
 and `key` parameters passed to the
 [`verify`](#dfn-SubtleCrypto-method-verify)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`verify`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `signature` be the result of [getting a copy of the
 bytes held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `signature` parameter
 passed to the
 [`verify`](#dfn-SubtleCrypto-method-verify)`()` method.

5. Let `data` be the result of [getting a copy of the bytes
 held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `data` parameter passed to
 the
 [`verify`](#dfn-SubtleCrypto-method-verify)`()` method.

6. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

7. Let `promise` be a new Promise.

8. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

9. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

10. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

11. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` does not contain an entry that is \"`verify`\",
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

12. Let `result` be the result of performing the verify
 operation specified by `normalizedAlgorithm` using
 `key`, `algorithm` and `signature`
 and with `data` as `message`.

13. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

14. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.5 The digest method

The [`digest`] method returns a new Promise object that will
digest data using the specified
[`AlgorithmIdentifier`](#dom-algorithmidentifier). It must act as
follows:

1. Let `algorithm` be the `algorithm` parameter passed to
 the
 [`digest`](#dfn-SubtleCrypto-method-digest)`()` method.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`digest`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `data` be the result of [getting a copy of the bytes
 held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `data` parameter passed to
 the
 [`digest`](#dfn-SubtleCrypto-method-digest)`()` method.

5. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

6. Let `promise` be a new Promise.

7. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

8. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

9. Let `digest` be the result of performing the digest
 operation specified by `normalizedAlgorithm` using
 `algorithm`, with `data` as
 `message`.

10. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

11. Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `digest`.

12. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.6 The generateKey method

When invoked, [`generateKey`] *MUST* perform the following steps:

1. Let `algorithm`, `extractable` and
 `usages` be the `algorithm`, `extractable` and
 `keyUsages` parameters passed to the
 [`generateKey`](#dfn-SubtleCrypto-method-generateKey)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`generateKey`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

5. Let `promise` be a new Promise.

6. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

7. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

8. Let `result` be the result of performing the generate key
 operation specified by `normalizedAlgorithm` using
 `algorithm`, `extractable` and
 `usages`.

9.

 If `result` is a [`CryptoKey`](#dfn-CryptoKey) object:

 : If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot
 of `result` is
 \"[`secret`](#dom-keytype-secret)\" or
 \"[`private`](#dom-keytype-private)\" and `usages` is
 empty, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 If `result` is a [`CryptoKeyPair`](#dfn-CryptoKeyPair) object:

 : If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal
 slot of the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result`
 is the empty sequence, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

10. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

11. Let `result` be the result of converting
 `result` to an ECMAScript Object in `realm`,
 as defined by \[[WebIDL](#bib-webidl "Web IDL Standard")\].

12. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.7 The deriveKey method

When invoked, [`deriveKey`] *MUST* perform the following steps:

1. Let `algorithm`, `baseKey`,
 `derivedKeyType`, `extractable` and
 `usages` be the `algorithm`, `baseKey`, `derivedKeyType`,
 `extractable` and `keyUsages` parameters passed to the
 [`deriveKey`](#dfn-SubtleCrypto-method-deriveKey)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`deriveBits`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `normalizedDerivedKeyAlgorithmImport` be the result
 of [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `derivedKeyType` and `op` set to
 \"`importKey`\".

5. If an error occurred, return a Promise rejected with
 `normalizedDerivedKeyAlgorithmImport`.

6. Let `normalizedDerivedKeyAlgorithmLength` be the result
 of [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `derivedKeyType` and `op` set to
 \"`get key length`\".

7. If an error occurred, return a Promise rejected with
 `normalizedDerivedKeyAlgorithmLength`.

8. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

9. Let `promise` be a new Promise.

10. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

11. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

12. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `baseKey` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

13. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `baseKey` does not contain an entry that is
 \"`deriveKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

14. Let `length` be the result of performing the get key
 length algorithm specified by
 `normalizedDerivedKeyAlgorithmLength` using
 `derivedKeyType`.

15. Let `secret` be the result of performing the derive bits
 operation specified by `normalizedAlgorithm` using
 `key`, `algorithm` and `length`.

16. Let `result` be the result of performing the import key
 operation specified by
 `normalizedDerivedKeyAlgorithmImport` using \"`raw`\" as
 `format`, `secret` as `keyData`,
 `derivedKeyType` as `algorithm` and using
 `extractable` and `usages`.

17. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `result` is
 \"[`secret`](#dom-keytype-secret)\" or
 \"[`private`](#dom-keytype-private)\" and `usages` is empty,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

18. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `result` to `extractable`.

19. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `result` to the [normalized
 value](#concept-normalized-usages) of `usages`.

20. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

21. Let `result` be the result of converting
 `result` to an ECMAScript Object in `realm`,
 as defined by \[[WebIDL](#bib-webidl "Web IDL Standard")\].

22. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.8 The deriveBits method

When invoked, [`deriveBits`] *MUST* perform the following steps:

1. Let `algorithm`, `baseKey` and
 `length`, be the `algorithm`, `baseKey` and `length`
 parameters passed to the
 [`deriveBits`](#dfn-SubtleCrypto-method-deriveBits)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`deriveBits`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

5. Let `promise` be a new Promise.

6. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

7. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

8. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `baseKey` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

9. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `baseKey` does not contain an entry that is
 \"`deriveBits`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

10. Let `bits` be the result of performing the derive bits
 operation specified by `normalizedAlgorithm` using
 `baseKey`, `algorithm` and
 `length`.

11. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

12. Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `bits`.

13. Resolve `promise` with `result`.

::: header-wrapper
#### 14.3.9 The importKey method

When invoked, the [`importKey`] method *MUST* perform the following
steps:

1. Let `format`, `algorithm`,
 `extractable` and `usages`, be the `format`,
 `algorithm`, `extractable` and `keyUsages` parameters passed to the
 [`importKey`](#dfn-SubtleCrypto-method-importKey)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`importKey`\".

3. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

4.

 If `format` is equal to the string \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. If the `keyData` parameter passed to the
 [`importKey`](#dfn-SubtleCrypto-method-importKey)`()` method is
 not a
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `keyData` be the `keyData` parameter passed
 to the
 [`importKey`](#dfn-SubtleCrypto-method-importKey)`()` method.

 Otherwise:

 : 1. If the `keyData` parameter passed to the
 [`importKey`](#dfn-SubtleCrypto-method-importKey)`()` method is
 a [`JsonWebKey`](#dfn-JsonWebKey) dictionary,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `keyData` be the result of [getting a copy of
 the bytes held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `keyData`
 parameter passed to the
 [`importKey`](#dfn-SubtleCrypto-method-importKey)`()` method.

5. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

6. Let `promise` be a new Promise.

7. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

8. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

9. Let `result` be the
 [`CryptoKey`](#dfn-CryptoKey) object that results from performing
 the import key operation specified by
 `normalizedAlgorithm` using `keyData`,
 `algorithm`, `format`,
 `extractable` and `usages`.

10. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `result` is
 \"[`secret`](#dom-keytype-secret)\" or
 \"[`private`](#dom-keytype-private)\" and `usages` is empty,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

11. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `result` to `extractable`.

12. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `result` to the [normalized
 value](#concept-normalized-usages) of `usages`.

13. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

14. Let `result` be the result of converting
 `result` to an ECMAScript Object in `realm`,
 as defined by \[[WebIDL](#bib-webidl "Web IDL Standard")\].

15. Resolve `promise` with `result`.

Support of \"[`raw`](#dom-keyformat-raw)\" key formats is encouraged for
interoperability. Web developers should consult the test-suite for
detailed information on implementations support of other key formats.

For structured key formats,
\"[`spki`](#dom-keyformat-spki)\",
\"[`pkcs8`](#dom-keyformat-pkcs8)\" and
\"[`jwk`](#dom-keyformat-jwk)\", fields that are not explicitly referred to in the
key import procedures for an algorithm are ignored.

::: header-wrapper
#### 14.3.10 The exportKey method

When invoked, the [`exportKey`] method *MUST* perform the following
steps:

1. Let `format` and `key` be the `format` and
 `key` parameters passed to the
 [`exportKey`](#dfn-SubtleCrypto-method-exportKey)`()` method,
 respectively.

2. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

3. Let `promise` be a new Promise.

4. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

5. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

6. If the [`name`](#dom-algorithm-name) member of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` does not identify a [registered
 algorithm](#algorithms) that supports the export key operation, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

7. If the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` is false, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

8. Let `result` be the result of performing the export key
 operation specified by the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` using `key` and `format`.

9. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

10.

 If `format` is equal to the string \"[`jwk`](#dom-keyformat-jwk)\":
 : Let `result` be the result of converting
 `result` to an ECMAScript Object in
 `realm`, as defined by
 \[[WebIDL](#bib-webidl "Web IDL Standard")\].

 Otherwise:
 : Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `result`.

11. Resolve `promise` with `result`.

Support of \"[`raw`](#dom-keyformat-raw)\" key formats is encouraged for
interoperability. Web developers should consult the test-suite for
detailed information on implementations support of other key formats.

::: header-wrapper
#### 14.3.11 The wrapKey method

When invoked, the [`wrapKey`] method *MUST* perform the following
steps:

1. Let `format`, `key`, `wrappingKey`
 and `algorithm` be the `format`, `key`, `wrappingKey` and
 `wrapAlgorithm` parameters passed to the
 [`wrapKey`](#dfn-SubtleCrypto-method-wrapKey)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`wrapKey`\".

3. If an error occurred, let `normalizedAlgorithm` be the
 result of [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`encrypt`\".

4. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

5. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

6. Let `promise` be a new Promise.

7. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

8. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

9. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `wrappingKey` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

10. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `wrappingKey` does not contain an entry that is
 \"`wrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

11. If the algorithm identified by the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` does not support the export key operation, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

12. If the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` is false, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 :::::
 :::
 Note
 :::

 :::
 Because the wrapKey method effectively exports the key, only keys
 marked as extractable may be wrapped. In particular, this means that
 this API cannot create a wrapped JWK key that is marked as
 non-extractable using the
 [`ext`](#dom-jsonwebkey-ext) JWK member.

 However, the unwrapKey method *does* support the
 [`ext`](#dom-jsonwebkey-ext) JWK member, so that wrapped
 non-extractable keys created elsewhere, for example by a server, can
 be unwrapped using this API.
 :::
 :::::

13. Let `exportedKey` be the result of performing the export
 key operation specified by the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` using `key` and `format`.

14.

 If `format` is equal to the string \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `json` be the result of representing
 `exportedKey` as a UTF-16 string conforming to
 the JSON grammar; for example, by executing the
 `JSON.stringify` algorithm specified in
 \[[ECMA-262](#bib-ecma-262 "ECMAScript Language Specification")\] in the context of a new global object.

 2. Let `bytes` be the result of [UTF-8
 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `json`.

 Otherwise:
 : Let `bytes` be `exportedKey`.

 :::::
 :::
 Note
 :::

 :::
 The key wrapping operations for some algorithms place constraints on
 the payload size. For example AES-KW requires the payload to be a
 multiple of 8 bytes in length and RSA-OAEP places a restriction on
 the length. For key formats that offer flexibility in serialization
 of a given key (for example JWK), implementations may choose to
 adapt the serialization to the constraints of the wrapping
 algorithm. This is why JSON.stringify is not normatively required,
 as otherwise it would prohibit implementations from introducing
 added padding.
 :::
 :::::

15.

 If `normalizedAlgorithm` supports the wrap key operation:

 : Let `result` be the result of performing the wrap key
 operation specified by `normalizedAlgorithm` using
 `algorithm`, `wrappingKey` as
 `key` and `bytes` as
 `plaintext`.

 Otherwise, if `normalizedAlgorithm` supports the encrypt operation:

 : Let `result` be the result of performing the encrypt
 operation specified by `normalizedAlgorithm` using
 `algorithm`, `wrappingKey` as
 `key` and `bytes` as
 `plaintext`.

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

16. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

17. Let `result` be the result of
 [creating](https://webidl.spec.whatwg.org/#arraybuffer-create) an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) in `realm`, containing
 `result`.

18. Resolve `promise` with `result`.

Support of \"[`raw`](#dom-keyformat-raw)\" key formats is encouraged for
interoperability. Web developers should consult the test-suite for
detailed information on implementations support of other key formats.

::: header-wrapper
#### 14.3.12 The unwrapKey method

When invoked, the [`unwrapKey`] method *MUST* perform the following
steps:

1. Let `format`, `unwrappingKey`,
 `algorithm`, `unwrappedKeyAlgorithm`,
 `extractable` and `usages`, be the `format`,
 `unwrappingKey`, `unwrapAlgorithm`, `unwrappedKeyAlgorithm`,
 `extractable` and `keyUsages` parameters passed to the
 [`unwrapKey`](#dfn-SubtleCrypto-method-unwrapKey)`()` method,
 respectively.

2. Let `normalizedAlgorithm` be the result of [normalizing
 an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`unwrapKey`\".

3. If an error occurred, let `normalizedAlgorithm` be the
 result of [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `algorithm` and `op` set to
 \"`decrypt`\".

4. If an error occurred, return a Promise rejected with
 `normalizedAlgorithm`.

5. Let `normalizedKeyAlgorithm` be the result of
 [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with `alg` set to `unwrappedKeyAlgorithm` and `op` set to
 \"`importKey`\".

6. If an error occurred, return a Promise rejected with
 `normalizedKeyAlgorithm`.

7. Let `wrappedKey` be the result of [getting a copy of the
 bytes held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the `wrappedKey` parameter
 passed to the
 [`unwrapKey`](#dfn-SubtleCrypto-method-unwrapKey)`()` method.

8. Let `realm` be the [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
 of [this](https://webidl.spec.whatwg.org/#this).

9. Let `promise` be a new Promise.

10. Return `promise` and perform the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

11. If the following steps or referenced procedures say to
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an error, [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to reject `promise`
 with the returned error; and then [terminate the
 algorithm](#terminate-the-algorithm).

12. If the [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm` is not equal to the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `unwrappingKey` then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

13. If the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `unwrappingKey` does not contain an entry that is
 \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

14.

 If `normalizedAlgorithm` supports an unwrap key operation:
 : Let `bytes` be the result of performing the unwrap
 key operation specified by `normalizedAlgorithm`
 using `algorithm`, `unwrappingKey` as
 `key` and `wrappedKey` as
 `ciphertext`.

 Otherwise, if `normalizedAlgorithm` supports a decrypt operation:
 : Let `bytes` be the result of performing the decrypt
 operation specified by `normalizedAlgorithm` using
 `algorithm`, `unwrappingKey` as
 `key` and `wrappedKey` as
 `ciphertext`.

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

15.

 If `format` is equal to the string \"[`jwk`](#dom-keyformat-jwk)\":
 : Let `key` be the result of executing the [parse a
 JWK](#concept-parse-a-jwk) algorithm, with
 `bytes` as the `data` to be parsed.

 Otherwise:
 : Let `key` be `bytes`.

16. Let `result` be the result of performing the import key
 operation specified by `normalizedKeyAlgorithm` using
 `unwrappedKeyAlgorithm` as `algorithm`,
 `format`, `usages` and
 `extractable` and with `key` as
 `keyData`.

17. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `result` is
 \"[`secret`](#dom-keytype-secret)\" or
 \"[`private`](#dom-keytype-private)\" and `usages` is empty,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

18. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `result` to `extractable`.

19. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `result` to the [normalized
 value](#concept-normalized-usages) of `usages`.

20. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [crypto task
 source](#dfn-crypto-task-source-0), given
 `realm`\'s global object, to perform the remaining steps.

21. Let `result` be the result of converting
 `result` to an ECMAScript Object in `realm`,
 as defined by \[[WebIDL](#bib-webidl "Web IDL Standard")\].

22. Resolve `promise` with `result`.

Support of \"[`raw`](#dom-keyformat-raw)\" key formats is encouraged for
interoperability. Web developers should consult the test-suite for
detailed information on implementations support of other key formats.

::: header-wrapper
### 14.4 Exceptions

The methods of the
[`SubtleCrypto`](#dfn-SubtleCrypto) interface return errors
by rejecting the returned promise with a predefined exception defined in
ECMAScript
\[[ECMA-262](#bib-ecma-262 "ECMAScript Language Specification")\] or
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). The following predefined exceptions are used:
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). The following DOMException types from
\[[DOM](#bib-dom "DOM Standard")\] are used:

 --------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------
 Name Description
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) The algorithm is not supported
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) A required parameter was missing or out-of-range
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) The requested operation is not valid for the provided key
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror) Data provided to an operation does not meet requirements
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror) The operation failed for an operation-specific reason
 --------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------

When this specification says to
[throw](https://webidl.spec.whatwg.org/#dfn-throw) an
error, the user agent must throw an error as described in
\[[WebIDL](#bib-webidl "Web IDL Standard")\]. When this occurs in a sub-algorithm, this results
in termination of execution of the sub-algorithm and all ancestor
algorithms until one is reached that explicitly describes procedures for
catching exceptions. The error object thrown shall be associated with
the [relevant
realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
of [this](https://webidl.spec.whatwg.org/#this).

::: header-wrapper
## 15. JsonWebKey dictionary

```
WebIDLdictionary RsaOtherPrimesInfo {
 // The following fields are defined in Section 6.3.2.7 of JSON Web Algorithms
 DOMString r;
 DOMString d;
 DOMString t;
};

dictionary JsonWebKey {
 // The following fields are defined in Section 3.1 of JSON Web Key
 DOMString kty;
 DOMString use;
 sequence<DOMString> key_ops;
 DOMString alg;

 // The following fields are defined in JSON Web Key Parameters Registration
 boolean ext;

 // The following fields are defined in Section 6 of JSON Web Algorithms
 DOMString crv;
 DOMString x;
 DOMString y;
 DOMString d;
 DOMString n;
 DOMString e;
 DOMString p;
 DOMString q;
 DOMString dp;
 DOMString dq;
 DOMString qi;
 sequence<RsaOtherPrimesInfo> oth;
 DOMString k;
};
```

The [`JsonWebKey`] dictionary provides a way to represent and
exchange cryptographic keys represented by the JSON Web Key
\[[JWK](#bib-jwk "JSON Web Key (JWK)")\]
structure, while allowing native and efficient use within Web
Cryptography API applications.

The members of the [`RsaOtherPrimesInfo`] are defined in Section 6.3.2.7 of JSON Web
Algorithms.

::: header-wrapper
## 16. BigInteger

```
WebIDLtypedef Uint8Array BigInteger;
```

The [`BigInteger`] typedef is a
[`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array) that holds an arbitrary magnitude unsigned integer in
big-endian order. Values read from the API *SHALL* have minimal typed
array length (that is, at most 7 leading zero bits, except the value 0
which shall have length 8 bits). The API *SHALL* accept values with any
number of leading zero bits, including the empty array, which represents
zero.

Since the integer is unsigned, the highest order bit is NOT a sign bit.
Implementors should take care when mapping to big integer
implementations that expected signed integers.

::: header-wrapper
## 17. CryptoKeyPair dictionary

```
WebIDLdictionary CryptoKeyPair {
 CryptoKey publicKey;
 CryptoKey privateKey;
};
```

The [`CryptoKeyPair`] dictionary represents an asymmetric key pair
that is comprised of both public
([`publicKey`]) and private
([`privateKey`]) keys.

::: header-wrapper
## 18. Algorithms

::: header-wrapper
### 18.1 Overview

*This section is non-normative.*

In addition to providing a common interface to perform cryptographic
operations, by way of the
[`SubtleCrypto`](#dfn-SubtleCrypto) interface, this
specification also provides descriptions for a variety of algorithms
that authors may wish to use and that User Agents may choose to
implement. This includes a selection of commonly-deployed symmetric and
asymmetric algorithms, key derivation mechanisms, and methods for
wrapping and unwrapping keys. Further, this specification defines a
process to allow additional specifications to introduce additional
cryptographic algorithms.

::: header-wrapper
### 18.2 Concepts

::: header-wrapper
#### 18.2.1 Naming

Every cryptographic algorithm defined for use with the Web Cryptography
API *MUST* have a unique name, referred to as its [recognized algorithm
name], such that no other specification
defines the same case-insensitive string for use with the Web
Cryptography API.

::: header-wrapper
#### 18.2.2 Supported Operations

Every cryptographic algorithm defined for use with the Web Cryptography
API has a list of [supported operations], which are a set of sub-algorithms to be invoked by the
[`SubtleCrypto`](#dfn-SubtleCrypto) interface in order to
perform the desired cryptographic operation. This specification makes
use of the following operations:

- encrypt
- decrypt
- sign
- verify
- digest
- deriveBits
- wrapKey
- unwrapKey
- generateKey
- importKey
- exportKey
- get key length

If a given algorithm specification does not list a particular operation
as supported, or explicitly lists an operation as not-supported, then
the User Agent *MUST* behave as if the invocation of the sub-algorithm
threw a NotSupportedError.

::: header-wrapper
#### 18.2.3 Normalization

Every cryptographic algorithm defined for use with the Web Cryptography
API *MUST* define, for every [supported
operation](#supported-operation), the IDL type to use for
[algorithm
normalization](#dfn-algorithm-normalization), as well as the IDL type or
types of the return values of the sub-algorithms.

::: header-wrapper
### 18.3 Specification Conventions

Every cryptographic algorithm definition within this specification
employs the following specification conventions. A section, titled
*\"Registration\"*, will include the [recognized algorithm
name](#recognized-algorithm-name). Additionally, it includes a
table, which will list each of the [supported
operations](#supported-operation) as
rows, identified by the [Operation] column. The contents
of the [Parameters] column for a given row will
contain the IDL type to use for [algorithm
normalization](#dfn-algorithm-normalization) for that operation, and the
contents of the [Result] column for that row indicate the
IDL type that results from performing the supported operation.

If a conforming User Agent implements an algorithm, it *MUST* implement
all of the [supported
operations](#supported-operation) and
*MUST* return the IDL type specified.

Additionally, upon initialization, conforming User Agents must perform
the [define an
algorithm](#concept-define-an-algorithm) steps for each of the
supported operations, registering their IDL parameter type as indicated.

Unless otherwise stated, objects created by the operations defined in
this specification shall be associated with the [relevant
realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)
of [this](https://webidl.spec.whatwg.org/#this).

::: header-wrapper
### 18.4 [Algorithm Normalization]

::: header-wrapper
#### 18.4.1 Description

*This section is non-normative.*

The
[`AlgorithmIdentifier`](#dom-algorithmidentifier) typedef permits
algorithms to either be specified as a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) or an object. The usage of
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) is to permit authors a short-hand for noting algorithms
that have no parameters (e.g. SHA-1). The usage of object is to allow an
[`Algorithm`](#dfn-Algorithm) (or appropriate subclass) to be
specified, which contains all of the associated parameters for an
object.

Because of this, it\'s necessary to define the algorithm for converting
an
[`AlgorithmIdentifier`](#dom-algorithmidentifier) into an
appropriate dictionary that is usable with this API. This algorithm must
be extensible, so as to allow new cryptographic algorithms to be added,
and consistent, so that Web IDL type mapping can occur before any
control is returned to the calling script, which would potentially allow
the mutation of parameters or the script environment.

::: header-wrapper
#### 18.4.2 Internal State Objects

This specification makes use of an internal object,
[supportedAlgorithms]. This internal object is not
exposed to applications.

Because this value is not exposed to applications, the exact type is not
specified. It is only required to behave as an associative container of
key/value pairs, where comparisons of keys are performed in a
case-sensitive manner.

The initial contents of this internal object are as follows:

1. For each value, `v` in the List of [supported
 operations](#supported-operation),
 set the `v` key of the internal object
 [`supportedAlgorithms`](#dfn-supportedAlgorithms) to a new
 associative container.

::: header-wrapper
#### 18.4.3 Defining an Algorithm

The [define an algorithm] algorithm is used by
specification authors to indicate how a user agent should normalize
arguments for a particular algorithm. Its input is an algorithm name
`alg`, represented as a DOMString, operation name
`op`, represented as a DOMString, and desired IDL dictionary
type `type`. The algorithm behaves as follows:

1. Let `registeredAlgorithms` be the associative container
 stored at the `op` key of
 [`supportedAlgorithms`](#dfn-supportedAlgorithms).
2. Set the `alg` key of `registeredAlgorithms` to
 the IDL dictionary type `type`.

::: header-wrapper
#### 18.4.4 Normalizing an algorithm

The [normalize an algorithm] algorithm defines a
process for coercing inputs to a targeted IDL dictionary type, after Web
IDL conversion has occurred. It is designed to be extensible, to allow
future specifications to define additional algorithms, as well as safe
for use with Promises. Its input is an operation name `op`
and an
[`AlgorithmIdentifier`](#dom-algorithmidentifier) `alg`.
Its output is either an IDL dictionary type or an error. It behaves as
follows:

If `alg` is an instance of a DOMString:

: Return the result of running the [normalize an
 algorithm](#dfn-normalize-an-algorithm)
 algorithm, with the `alg` set to a new
 [`Algorithm`](#dfn-Algorithm) dictionary whose
 [`name`](#dom-keyalgorithm-name) attribute is `alg`, and
 with the `op` set to `op`.

If `alg` is an object:

: 1. Let `registeredAlgorithms` be the associative
 container stored at the `op` key of
 [`supportedAlgorithms`](#dfn-supportedAlgorithms).

 2. Let `initialAlg` be the result of converting the
 ECMAScript object represented by `alg` to the IDL
 dictionary type
 [`Algorithm`](#dfn-Algorithm), as defined by
 \[[WebIDL](#bib-webidl "Web IDL Standard")\].

 3. If an error occurred, return the error and terminate this
 algorithm.

 4. Let `algName` be the value of the
 [`name`](#dom-algorithm-name) attribute of
 `initialAlg`.

 5.

 If `registeredAlgorithms` contains a key that is a [case-insensitive](#case-insensitive) string match for `algName`:

 : 1. Set `algName` to the value of the matching
 key.

 2. Let `desiredType` be the IDL dictionary type
 stored at `algName` in
 `registeredAlgorithms`.

 Otherwise:
 : Return a new `NotSupportedError` and terminate this
 algorithm.

 6. Let `normalizedAlgorithm` be the result of converting
 the ECMAScript object represented by `alg` to the IDL
 dictionary type `desiredType`, as defined by
 \[[WebIDL](#bib-webidl "Web IDL Standard")\].

 7. Set the
 [`name`](#dom-algorithm-name) attribute of
 `normalizedAlgorithm` to `algName`.

 8. If an error occurred, return the error and terminate this
 algorithm.

 9. Let `dictionaries` be a list consisting of the IDL
 dictionary type `desiredType` and all of
 `desiredType`\'s inherited dictionaries, in order
 from least to most derived.

 10. For each dictionary `dictionary` in
 `dictionaries`:

 1. For each dictionary member `member` declared on
 `dictionary`, in order:

 1. Let `key` be the identifier of
 `member`.

 2. Let `idlValue` be the value of the dictionary
 member with key name of `key` on
 `normalizedAlgorithm`.

 3.

 If `member` is of the type [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) and is present:
 : Set the dictionary member on
 `normalizedAlgorithm` with key name
 `key` to the result of [getting a copy of
 the bytes held
 by](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy)
 `idlValue`, replacing the current value.

 If `member` is of the type [`HashAlgorithmIdentifier`](#dom-hashalgorithmidentifier):
 : Set the dictionary member on
 `normalizedAlgorithm` with key name
 `key` to the result of [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with the `alg` set to `idlValue` and the
 `op` set to \"`digest`\".

 If `member` is of the type [`AlgorithmIdentifier`](#dom-algorithmidentifier):
 : Set the dictionary member on
 `normalizedAlgorithm` with key name
 `key` to the result of [normalizing an
 algorithm](#dfn-normalize-an-algorithm),
 with the `alg` set to `idlValue` and the
 `op` set to the operation defined by the
 specification that defines the algorithm identified
 by `algName`.

 4. If an error occurred, return the error and terminate
 this algorithm.

 11. Return `normalizedAlgorithm`.

::: header-wrapper
### 18.5 Recommendations

*This section is non-normative.*

::: header-wrapper
#### 18.5.1 For Authors

As this API is meant to be extensible, in order to keep up with future
developments within cryptography, there are no algorithms that
conforming user agents are required to implement. As such, authors
should check to see what algorithms are currently recommended and
supported by implementations.

As highlighted in the [Security
Considerations](#security-considerations), even cryptographic algorithms
that might be considered strong for one purpose may be insufficient when
used with another purpose. Authors should therefore proceed with extreme
caution before inventing new cryptographic protocols.

Additionally, this specification includes several algorithms which, in
their default usage, can result in cryptographic vulnerabilities. While
these concerns may be mitigated, such as through the combination and
composition with additional algorithms provided by this specification,
authors should proceed with caution and review the relevant
cryptographic literature before using a given algorithm. The inclusion
of algorithms within this specification is not an indicator of their
suitability for any or all purpose, and instead merely serve to provide
as a specification for how a conforming User Agent must implement the
given algorithm, if it choses to implement the algorithm.

::: header-wrapper
#### 18.5.2 For Implementers

In order to promote interoperability for developers, this specification
includes a list of suggested algorithms. These are considered to be the
most widely used algorithms in practice at the time of writing, and
therefore provide a good starting point for initial implementations of
this specification. The suggested algorithms are:

- [HMAC](#hmac) using [SHA-1](#alg-sha-1)
- [HMAC](#hmac) using [SHA-256](#alg-sha-256)
- [RSASSA-PKCS1-v1_5](#rsassa-pkcs1) using [SHA-1](#alg-sha-256)
- [RSA-PSS](#rsa-pss) using [SHA-256](#alg-sha-256) and MGF1 with
 [SHA-256](#alg-sha-256).
- [RSA-OAEP](#rsa-oaep) using [SHA-256](#alg-sha-256) and MGF1 with
 [SHA-256](#alg-sha-256).
- [ECDSA](#ecdsa) using [P-256](#dfn-NamedCurve-p256) curve and
 [SHA-256](#alg-sha-256)
- [AES-CBC](#aes-cbc)

::: header-wrapper
## 19. Algorithm Overview

*This section is non-normative.*

The table below contains an overview of the algorithms described within
this specification, as well as the set of [SubtleCrypto
methods](#subtlecrypto-interface-methods) the algorithm may be used
with. In order for an algorithm to be used with a method the
corresponding operation or operations, as defined in the procedures for
the method, must be defined in the algorithm specification. Note that
this mapping of methods to underlying operations is not one-to-one:

- The
 [`encrypt`](#dfn-SubtleCrypto-method-encrypt) method requires the encrypt operation.

- The
 [`decrypt`](#dfn-SubtleCrypto-method-decrypt) method requires the decrypt operation.

- The
 [`sign`](#dfn-SubtleCrypto-method-sign) method requires the sign operation.

- The
 [`verify`](#dfn-SubtleCrypto-method-verify) method requires the verify operation.

- The
 [`generateKey`](#dfn-SubtleCrypto-method-generateKey) method requires the generateKey
 operation.

- The
 [`importKey`](#dfn-SubtleCrypto-method-importKey) method requires the importKey operation.

- The
 [`exportKey`](#dfn-SubtleCrypto-method-exportKey) method requires the exportKey operation.

- The
 [`deriveKey`](#dfn-SubtleCrypto-method-deriveKey) method requires the deriveBits operation
 for the key derivation algorithm and the get key length and importKey
 operations for the derived key algorithm.

- The
 [`deriveBits`](#dfn-SubtleCrypto-method-deriveBits) method requires the deriveBits operation
 for the key derivation algorithm.

- The
 [`digest`](#dfn-SubtleCrypto-method-digest) method requires the digest operation.

- The
 [`wrapKey`](#dfn-SubtleCrypto-method-wrapKey) method requires either the encrypt or
 wrapKey operation for the wrapping algorithm and the exportKey
 operation for the wrapped key algorithm.

- The
 [`unwrapKey`](#dfn-SubtleCrypto-method-unwrapKey) method requires either the decrypt or
 unwrapKey operation for the unwrapping algorithm and the importKey
 operation for the unwrapped key algorithm.

Application developers and script authors should not interpret this
table as a recommendation for the use of particular algorithms. Instead,
it simply documents what methods are supported. Authors should refer to
the [Security considerations for authors](#security-developers) section
of this document to better understand the risks and concerns that may
arise when using certain algorithms.

 Algorithm name encrypt decrypt sign verify digest generateKey deriveKey deriveBits importKey exportKey wrapKey unwrapKey
 ------------------------------------ --------- --------- ------ -------- -------- ------------- ----------- ------------ ----------- ----------- --------- -----------
 [RSASSA-PKCS1-v1_5](#rsassa-pkcs1) ✔ ✔ ✔ ✔ ✔
 [RSA-PSS](#rsa-pss) ✔ ✔ ✔ ✔ ✔
 [RSA-OAEP](#rsa-oaep) ✔ ✔ ✔ ✔ ✔ ✔ ✔
 [ECDSA](#ecdsa) ✔ ✔ ✔ ✔ ✔
 [ECDH](#ecdh) ✔ ✔ ✔ ✔ ✔
 [Ed25519](#ed25519) ✔ ✔ ✔ ✔ ✔
 [X25519](#x25519) ✔ ✔ ✔ ✔ ✔
 [AES-CTR](#aes-ctr) ✔ ✔ ✔ ✔ ✔ ✔ ✔
 [AES-CBC](#aes-cbc) ✔ ✔ ✔ ✔ ✔ ✔ ✔
 [AES-GCM](#aes-gcm) ✔ ✔ ✔ ✔ ✔ ✔ ✔
 [AES-KW](#aes-kw) ✔ ✔ ✔ ✔ ✔
 [HMAC](#hmac) ✔ ✔ ✔ ✔ ✔
 [SHA-1](#sha) ✔
 [SHA-256](#sha) ✔
 [SHA-384](#sha) ✔
 [SHA-512](#sha) ✔
 [HKDF](#hkdf) ✔ ✔ ✔
 [PBKDF2](#pbkdf2) ✔ ✔ ✔

::: header-wrapper
## 20. RSASSA-PKCS1-v1_5

::: header-wrapper
### 20.1 Description

*This section is non-normative.*

The \"`RSASSA-PKCS1-v1_5`\" algorithm identifier is used to perform
signing and verification using the RSASSA-PKCS1-v1_5 algorithm specified
in
\[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] and using the SHA hash functions defined in this
specification.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional hash algorithms with
RSASSA-PKCS1-v1_5. Such specifications must define the digest operations
for the additional hash algorithms and [key import
steps] and [key export
steps]
for RSASSA-PKCS1-v1_5.

::: header-wrapper
### 20.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`RSASSA-PKCS1-v1_5`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------
 sign None [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 verify None boolean
 generateKey [`RsaHashedKeyGenParams`](#dfn-RsaHashedKeyGenParams) [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 importKey [`RsaHashedImportParams`](#dfn-RsaHashedImportParams) [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 20.3 [`RsaKeyGenParams`] dictionary

```
WebIDLdictionary RsaKeyGenParams : Algorithm {
 required [EnforceRange] unsigned long modulusLength;
 required BigInteger publicExponent;
};
```

The [`modulusLength`] member contains the length, in bits, of the RSA
modulus.

The [`publicExponent`] member contains the RSA public exponent.

::: header-wrapper
### 20.4 [`RsaHashedKeyGenParams`] dictionary

```
WebIDLdictionary RsaHashedKeyGenParams : RsaKeyGenParams {
 required HashAlgorithmIdentifier hash;
};
```

The [`hash`] member represents the hash
algorithm to use.

::: header-wrapper
### 20.5 RSA key generation parameter validation

The [validate RSA key generation
parameters] algorithm takes a
[`RsaKeyGenParams`](#dfn-RsaKeyGenParams)
`normalizedAlgorithm` and performs the following steps:

1. Let `modulusLength` be the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) member of
 `normalizedAlgorithm`.

2. Let `publicExponent` be the result of [converting the
 `publicExponent` member of `normalizedAlgorithm` to a
 non-negative
 integer](#dfn-convert-byte-sequence-to-integer).

3. If `modulusLength` is less than 4, or if
 `publicExponent` is less than 3, is even, or is greater
 than or equal to 2\^`modulusLength` - 1, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

These checks follow from the definition of a valid RSA public key in
\[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]: the modulus is the product of at least two
distinct odd primes, and the public exponent is an integer between 3 and
the modulus minus one that is relatively prime to the least common
multiple of the values one less than each prime.

::: header-wrapper
### 20.6 [`RsaKeyAlgorithm`] dictionary

```
WebIDLdictionary RsaKeyAlgorithm : KeyAlgorithm {
 required [EnforceRange] unsigned long modulusLength;
 required BigInteger publicExponent;
};
```

The [`modulusLength`] member contains the length, in bits, of the RSA
modulus.

The [`publicExponent`] member contains the RSA public exponent.

::: header-wrapper
### 20.7 [`RsaHashedKeyAlgorithm`] dictionary

```
WebIDLdictionary RsaHashedKeyAlgorithm : RsaKeyAlgorithm {
 required KeyAlgorithm hash;
};
```

The [`hash`] member describes the hash algorithm that is used
with this key.

::: header-wrapper
### 20.8 [`RsaHashedImportParams`] dictionary

```
WebIDLdictionary RsaHashedImportParams : Algorithm {
 required HashAlgorithmIdentifier hash;
};
```

The [`hash`] member describes the hash algorithm to use.

::: header-wrapper
### 20.9 Operations

::: header-wrapper
#### 20.9.1 Sign

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Perform the signature generation operation defined in Section 8.2 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] with the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` as the signer\'s private key and
 `message` as `M` and using the hash function
 specified in the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` as the Hash option for the EMSA-PKCS1-v1_5
 encoding method.

3. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. Let `signature` be the value `S` that results
 from performing the operation.

5. Return `signature`.

::: header-wrapper
#### 20.9.2 Verify

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Perform the signature verification operation defined in Section 8.2
 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] with the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` as the signer\'s RSA public key and
 `message` as `M` and `signature` as
 `S` and using the hash function specified in the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` as the Hash option for the EMSA-PKCS1-v1_5
 encoding method.

3. Let `result` be a boolean with value true if the result
 of the operation was \"valid signature\" and the value false
 otherwise.

4. Return `result`.

::: header-wrapper
#### 20.9.3 Generate Key

1. If `usages` contains an entry which is not \"`sign`\" or
 \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Perform the [validate RSA key generation
 parameters](#dfn-validate-rsa-key-generation-parameters) algorithm with
 `normalizedAlgorithm`.

3. Generate an RSA key pair, as defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], with RSA modulus length equal to the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) attribute of
 `normalizedAlgorithm` and RSA public exponent equal to
 the
 [`publicExponent`](#dfn-RsaKeyGenParams-publicExponent) attribute of
 `normalizedAlgorithm`.

4. If generation of the key pair fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `algorithm` be a new
 [`RsaHashedKeyAlgorithm`](#dfn-RsaHashedKeyAlgorithm) dictionary.

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`RSASSA-PKCS1-v1_5`\".

7. Set the
 [`modulusLength`](#dfn-RsaKeyAlgorithm-modulusLength) attribute of `algorithm` to
 equal the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) attribute of
 `normalizedAlgorithm`.

8. Set the
 [`publicExponent`](#dfn-RsaKeyAlgorithm-publicExponent) attribute of `algorithm` to
 equal the
 [`publicExponent`](#dfn-RsaKeyGenParams-publicExponent) attribute of
 `normalizedAlgorithm`.

9. Set the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of `algorithm` to
 equal the
 [`hash`](#dfn-RsaHashedKeyGenParams-hash) member of
 `normalizedAlgorithm`.

10. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

11. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

13. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

14. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "verify" ]`.

15. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

16. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

18. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

19. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "sign" ]`.

20. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

21. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to be
 `publicKey`.

22. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to be
 `privateKey`.

23. Return `result`.

::: header-wrapper
#### 20.9.4 Import Key

1. Let `keyData` be the key data to be imported.

2.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` contains an entry which is not
 \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `rsaEncryption` object identifier
 defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. Let `publicKey` be the result of performing the
 [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `subjectPublicKeyInfo` field of
 `spki`, `structure` as the
 `RSAPublicKey` structure specified in Section A.1.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], and `exactData` set to
 true.

 6. If an error occurred while parsing, or it can be determined
 that `publicKey` is not a valid public key
 according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the RSA public key identified by `publicKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`sign`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the
 `rsaEncryption` object identifier defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. Let `rsaPrivateKey` be the result of performing
 the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `privateKey` field of
 `privateKeyInfo`, `structure` as the
 `RSAPrivateKey` structure specified in Section A.1.2 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], and `exactData` set to
 true.

 6. If an error occurred while parsing, or if
 `rsaPrivateKey` is not a valid RSA private key
 according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the RSA private key identified by
 `rsaPrivateKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field of `jwk` is
 present and `usages` contains an entry which is
 not \"`sign`\", or, if the
 [`d`](#dom-jsonwebkey-d) field of `jwk` is
 not present and `usages` contains an entry which
 is not \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not a case-sensitive string match to \"`RSA`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not a case-sensitive string match to
 \"`sig`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `hash` be a be a string whose initial value
 is undefined.

 8.

 If the [`alg`](#dom-jsonwebkey-alg) field of `jwk` is not present:

 : Let `hash` be undefined.

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`RS1`\":

 : Let `hash` be the string \"`SHA-1`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`RS256`\":

 : Let `hash` be the string \"`SHA-256`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`RS384`\":

 : Let `hash` be the string \"`SHA-384`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`RS512`\":

 : Let `hash` be the string \"`SHA-512`\".

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-rsa-ssa-extended-import-steps) defined by
 [other applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `jwk` and
 obtaining `hash`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9.

 If `hash` is not undefined:

 : 1. Let `normalizedHash` be the result of
 [normalize an
 algorithm](#dfn-normalize-an-algorithm)
 with `alg` set to `hash` and `op` set to
 `digest`.

 2. If `normalizedHash` is not equal to the
 [`hash`](#dfn-RsaHashedImportParams-hash) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 10.

 If the [`d`](#dom-jsonwebkey-d) field of `jwk` is present:

 : 1. If `jwk` does not meet the requirements
 of Section 6.3.2 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `privateKey` represents the RSA
 private key identified by interpreting
 `jwk` according to Section 6.3.2 of JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. If `privateKey` is not a valid RSA
 private key according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object
 that represents `privateKey`.

 5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 Otherwise:

 : 1. If `jwk` does not meet the requirements
 of Section 6.3.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `publicKey` represent the RSA public
 key identified by interpreting `jwk`
 according to Section 6.3.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. If `publicKey` can be determined to not
 be a valid RSA public key according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 representing `publicKey`.

 5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Let `algorithm` be a new
 [`RsaHashedKeyAlgorithm`](#dfn-RsaHashedKeyAlgorithm) dictionary.

4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`RSASSA-PKCS1-v1_5`\"

5. Set the
 [`modulusLength`](#dfn-RsaKeyAlgorithm-modulusLength) attribute of `algorithm` to
 the length, in bits, of the RSA public modulus.

6. Set the
 [publicExponent](#dfn-RsaKeyAlgorithm-publicExponent)
 attribute of `algorithm` to the
 [BigInteger](#dfn-BigInteger)
 representation of the RSA public exponent.

7. Set the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of `algorithm` to
 the
 [`hash`](#dfn-RsaHashedImportParams-hash) member of
 `normalizedAlgorithm`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

9. Return `key`.

::: header-wrapper
#### 20.9.5 Export Key

1. Let `key` be the key to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\"

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` field to the OID
 `rsaEncryption` defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\].

 - Set the `params` field to the ASN.1 type
 NULL.

 - Set the `subjectPublicKey` field to the result
 of DER-encoding an `RSAPublicKey` ASN.1 type, as defined
 in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], Appendix A.1.1, that represents the
 RSA public key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` field to the OID
 `rsaEncryption` defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\].

 - Set the `params` field to the ASN.1 type
 NULL.

 - Set the `privateKey` field to the result of
 DER-encoding an `RSAPrivateKey` ASN.1 type, as defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], Appendix A.1.2, that represents the
 RSA private key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 :::::
 :::
 Note
 :::

 :::
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] specifies that the encoding of this
 field should be *BER* encoded in Section 5 (as a \"for
 example\"). However, to avoid requiring WebCrypto
 implementations support BER-encoding and BER-decoding,
 only *DER* encodings are produced or accepted.
 :::
 :::::

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`RSA`\".

 3. Let `hash` be the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key`.

 4.

 If `hash` is \"`SHA-1`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RS1`\".

 If `hash` is \"`SHA-256`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RS256`\".

 If `hash` is \"`SHA-384`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RS384`\".

 If `hash` is \"`SHA-512`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RS512`\".

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-rsa-ssa-extended-import-steps) defined by
 [other applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `key` and
 obtaining `alg`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

 3. Set the `alg` attribute of `jwk` to
 `alg`.

 5. Set the attributes
 [`n`](#dom-jsonwebkey-n) and
 [`e`](#dom-jsonwebkey-e) of `jwk` according
 to the corresponding definitions in JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.1.

 6.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\":

 : 1. Set the attributes named
 [`d`](#dom-jsonwebkey-d),
 [`p`](#dom-jsonwebkey-p),
 [`q`](#dom-jsonwebkey-q),
 [`dp`](#dom-jsonwebkey-dp),
 [`dq`](#dom-jsonwebkey-dq), and
 [`qi`](#dom-jsonwebkey-qi) of `jwk`
 according to the corresponding definitions in JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.2.

 2. If the underlying RSA private key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` is represented by
 more than two primes, set the attribute named
 [`oth`](#dom-jsonwebkey-oth) of `jwk`
 according to the corresponding definition in JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.2.7

 7. Set the `key_ops` attribute of `jwk` to the
 [usages](#dfn-CryptoKey-usages) attribute of
 `key`.

 8. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 9. Let `result` be `jwk`.

 Otherwise

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `result`.

::: header-wrapper
## 21. RSA-PSS

::: header-wrapper
### 21.1 Description

*This section is non-normative.*

The \"`RSA-PSS`\" algorithm identifier is used to perform signing and
verification using the RSASSA-PSS algorithm specified in
\[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], using the SHA hash functions defined in this
specification and the mask generation formula MGF1.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional hash algorithms with RSASSA-PSS. Such
specifications must define the digest operation for the additional hash
algorithms and [key import steps] and [key export
steps] for RSASSA-PSS.

::: header-wrapper
### 21.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`RSA-PSS`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------
 sign [`RsaPssParams`](#dfn-RsaPssParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 verify [`RsaPssParams`](#dfn-RsaPssParams) boolean
 generateKey [`RsaHashedKeyGenParams`](#dfn-RsaHashedKeyGenParams) [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 importKey [`RsaHashedImportParams`](#dfn-RsaHashedImportParams) [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 21.3 [`RsaPssParams`] dictionary

```
WebIDLdictionary RsaPssParams : Algorithm {
 required [EnforceRange] unsigned long saltLength;
};
```

The [`saltLength`] member represents the desired length of the
random salt in bytes.

::: header-wrapper
### 21.4 Operations

::: header-wrapper
#### 21.4.1 Sign

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Perform the signature generation operation defined in Section 8.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] with the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` as the signer\'s private key, `K`, and
 `message` as the message to be signed, `M`,
 and using the hash function specified by the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` as the Hash option, MGF1 (defined in Section
 B.2.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]) as the MGF option and the
 [saltLength](#dfn-RsaPssParams-saltLength)
 member of `normalizedAlgorithm` as the salt length option
 for the EMSA-PSS-ENCODE operation.

3. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. Let `signature` be the signature, S, that results from
 performing the operation.

5. Return `signature`.

::: header-wrapper
#### 21.4.2 Verify

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Perform the signature verification operation defined in Section 8.1
 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] with the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` as the signer\'s RSA public key and
 `message` as `M` and `signature` as
 `S` and using the hash function specified by the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` as the Hash option, MGF1 (defined in Section
 B.2.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]) as the MGF option and the
 [saltLength](#dfn-RsaPssParams-saltLength)
 member of `normalizedAlgorithm` as the salt length option
 for the EMSA-PSS-VERIFY operation.

3. Let `result` be a boolean with the value true if the
 result of the operation was \"valid signature\" and the value false
 otherwise.

::: header-wrapper
#### 21.4.3 Generate Key

1. If `usages` contains an entry which is not \"`sign`\" or
 \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Perform the [validate RSA key generation
 parameters](#dfn-validate-rsa-key-generation-parameters) algorithm with
 `normalizedAlgorithm`.

3. Generate an RSA key pair, as defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], with RSA modulus length equal to the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) member of
 `normalizedAlgorithm` and RSA public exponent equal to
 the
 [`publicExponent`](#dfn-RsaKeyGenParams-publicExponent) member of
 `normalizedAlgorithm`.

4. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `algorithm` be a new
 [`RsaHashedKeyAlgorithm`](#dfn-RsaHashedKeyAlgorithm) dictionary.

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`RSA-PSS`\".

7. Set the
 [`modulusLength`](#dfn-RsaKeyAlgorithm-modulusLength) attribute of `algorithm` to
 equal the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) member of
 `normalizedAlgorithm`.

8. Set the
 [`publicExponent`](#dfn-RsaKeyAlgorithm-publicExponent) attribute of `algorithm` to
 equal the
 [`publicExponent`](#dfn-RsaKeyGenParams-publicExponent) member of
 `normalizedAlgorithm`.

9. Set the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of `algorithm` to
 equal the
 [`hash`](#dfn-RsaHashedKeyGenParams-hash) member of
 `normalizedAlgorithm`.

10. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

11. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

13. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

14. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "verify" ]`.

15. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

16. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

18. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

19. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "sign" ]`.

20. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

21. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to
 `publicKey`.

22. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to
 `privateKey`.

23. Return `result`.

::: header-wrapper
#### 21.4.4 Import Key

1. Let `keyData` be the key data to be imported.

2.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` contains an entry which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `rsaEncryption` object identifier
 defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. Let `publicKey` be the result of performing the
 [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `subjectPublicKeyInfo` field of
 `spki`, `structure` as the
 `RSAPublicKey` structure specified in Section A.1.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], and `exactData` set to
 true.

 6. If an error occurred while parsing, or it can be determined
 that `publicKey` is not a valid public key
 according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the RSA public key identified by `publicKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`sign`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the
 `rsaEncryption` object identifier defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. Let `rsaPrivateKey` be the result of performing
 the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `privateKey` field of
 `privateKeyInfo`, `structure` as the
 `RSAPrivateKey` structure specified in Section A.1.2 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], and `exactData` set to
 true.

 6. If an error occurred while parsing, or if
 `rsaPrivateKey` is not a valid RSA private key
 according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the RSA private key identified by
 `rsaPrivateKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field of `jwk` is
 present and `usages` contains an entry which is
 not \"`sign`\", or, if the
 [`d`](#dom-jsonwebkey-d) field of `jwk` is
 not present and `usages` contains an entry which
 is not \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not a case-sensitive string match to \"`RSA`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not a case-sensitive string match to
 \"`sig`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7.

 If the [`alg`](#dom-jsonwebkey-alg) field of `jwk` is not present:

 : Let `hash` be undefined.

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`PS1`\":

 : Let `hash` be the string \"`SHA-1`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`PS256`\":

 : Let `hash` be the string \"`SHA-256`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`PS384`\":

 : Let `hash` be the string \"`SHA-384`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"`PS512`\":

 : Let `hash` be the string \"`SHA-512`\".

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-rsa-pss-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `jwk` and
 obtaining `hash`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8.

 If `hash` is not undefined:

 : 1. Let `normalizedHash` be the result of
 [normalize an
 algorithm](#dfn-normalize-an-algorithm)
 with `alg` set to `hash` and `op` set to
 `digest`.

 2. If `normalizedHash` is not equal to the
 [`hash`](#dfn-RsaHashedImportParams-hash) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9.

 If the [`d`](#dom-jsonwebkey-d) field of `jwk` is present:

 : 1. If `jwk` does not meet the requirements
 of Section 6.3.2 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `privateKey` represent the RSA
 private key identified by interpreting
 `jwk` according to Section 6.3.2 of JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. If `privateKey` can be determined to not
 be a valid RSA private key according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 representing `privateKey`.

 5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 Otherwise:

 : 1. If `jwk` does not meet the requirements
 of Section 6.3.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `publicKey` represent the RSA public
 key identified by interpreting `jwk`
 according to Section 6.3.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. If `publicKey` can be determined to not
 be a valid RSA public key according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 representing `publicKey`.

 5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Let `algorithm` be a new
 [`RsaHashedKeyAlgorithm`](#dfn-RsaHashedKeyAlgorithm) dictionary.

4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`RSA-PSS`\"

5. Set the
 [`modulusLength`](#dfn-RsaKeyAlgorithm-modulusLength) attribute of `algorithm` to
 the length, in bits, of the RSA public modulus.

6. Set the
 [`publicExponent`](#dfn-RsaKeyAlgorithm-publicExponent) attribute of `algorithm` to
 the [`BigInteger`](#dfn-BigInteger) representation of the
 RSA public exponent.

7. Set the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of `algorithm` to
 the
 [`hash`](#dfn-RsaHashedImportParams-hash) member of
 `normalizedAlgorithm`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`

9. Return `key`.

::: header-wrapper
#### 21.4.5 Export Key

1. Let `key` be the key to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\"

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` field to the OID
 `rsaEncryption` defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\].

 - Set the `params` field to the ASN.1 type
 NULL.

 - Set the `subjectPublicKey` field to the result
 of DER-encoding an `RSAPublicKey` ASN.1 type, as defined
 in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], Appendix A.1.1, that represents the
 RSA public key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` field to the OID
 `rsaEncryption` defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\].

 - Set the `params` field to the ASN.1 type
 NULL.

 - Set the `privateKey` field to the result of
 DER-encoding an `RSAPrivateKey` ASN.1 type, as defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], Appendix A.1.2, that represents the
 RSA private key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 :::::
 :::
 Note
 :::

 :::
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] specifies that the encoding of this
 field should be *BER* encoded in Section 5 (as a \"for
 example\"). However, to avoid requiring WebCrypto
 implementations support BER-encoding and BER-decoding,
 only *DER* encodings are produced or accepted.
 :::
 :::::

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`RSA`\".

 3. Let `hash` be the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key`.

 4.

 If `hash` is \"`SHA-1`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`PS1`\".

 If `hash` is \"`SHA-256`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`PS256`\".

 If `hash` is \"`SHA-384`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`PS384`\".

 If `hash` is \"`SHA-512`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`PS512`\".

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-rsa-pss-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining `alg`.

 2. Set the `alg` attribute of `jwk` to
 `alg`.

 5. Set the attributes
 [`n`](#dom-jsonwebkey-n) and
 [`e`](#dom-jsonwebkey-e) of `jwk` according
 to the corresponding definitions in JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.1.

 6.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\":

 : 1. Set the attributes named
 [`d`](#dom-jsonwebkey-d),
 [`p`](#dom-jsonwebkey-p),
 [`q`](#dom-jsonwebkey-q),
 [`dp`](#dom-jsonwebkey-dp),
 [`dq`](#dom-jsonwebkey-dq), and
 [`qi`](#dom-jsonwebkey-qi) of `jwk`
 according to the corresponding definitions in JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.2.

 2. If the underlying RSA private key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` is represented by
 more than two primes, set the attribute named
 [`oth`](#dom-jsonwebkey-oth) of `jwk`
 according to the corresponding definition in JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.2.7

 7. Set the `key_ops` attribute of `jwk` to the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 8. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 9. Let `result` be `jwk`.

 Otherwise

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `result`.

::: header-wrapper
## 22. RSA-OAEP

::: header-wrapper
### 22.1 Description

*This section is non-normative.*

The \"`RSA-OAEP`\" algorithm identifier is used to perform encryption
and decryption ordering to the RSAES-OAEP algorithm specified in
\[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], using the SHA hash functions defined in this
specification and using the mask generation function MGF1.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional hash algorithms with RSAES-OAEP. Such
specifications must define the digest operation for the additional hash
algorithm and [key import steps] and [key export
steps] for RSAES-OAEP.

::: header-wrapper
### 22.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`RSA-OAEP`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------
 encrypt [`RsaOaepParams`](#dfn-RsaOaepParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 decrypt [`RsaOaepParams`](#dfn-RsaOaepParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 generateKey [`RsaHashedKeyGenParams`](#dfn-RsaHashedKeyGenParams) [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 importKey [`RsaHashedImportParams`](#dfn-RsaHashedImportParams) [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 22.3 [`RsaOaepParams`] dictionary

```
WebIDLdictionary RsaOaepParams : Algorithm {
 BufferSource label;
};
```

The [`label`] member represents the optional label/application
data to associate with the message.

::: header-wrapper
### 22.4 Operations

::: header-wrapper
#### 22.4.1 Encrypt

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Let `label` be the
 [`label`](#dfn-RsaOaepParams-label) member of
 `normalizedAlgorithm` or the empty byte sequence if the
 [`label`](#dfn-RsaOaepParams-label) member of
 `normalizedAlgorithm` is not present.

3. Perform the encryption operation defined in Section 7.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] with the key represented by `key`
 as the recipient\'s RSA public key, `plaintext` as the
 message to be encrypted, `M` and `label` as
 the label, `L`, and with the hash function specified by
 the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` as the Hash option and MGF1 (defined in Section
 B.2.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]) as the MGF option.

4. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `ciphertext` be the value `C` that results
 from performing the operation.

6. Return `ciphertext`.

::: header-wrapper
#### 22.4.2 Decrypt

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Let `label` be the
 [`label`](#dfn-RsaOaepParams-label) member of
 `normalizedAlgorithm` or the empty byte sequence if the
 [`label`](#dfn-RsaOaepParams-label) member of
 `normalizedAlgorithm` is not present.

3. Perform the decryption operation defined in Section 7.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\] with the key represented by `key`
 as the recipient\'s RSA private key, `ciphertext` as the
 ciphertext to be decrypted, C, and `label` as the label,
 `L`, and with the hash function specified by the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` as the Hash option and MGF1 (defined in Section
 B.2.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]) as the MGF option.

4. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `plaintext` the value `M` that results
 from performing the operation.

6. Return `plaintext`.

::: header-wrapper
#### 22.4.3 Generate Key

1. If `usages` contains an entry which is not \"`encrypt`\",
 \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Perform the [validate RSA key generation
 parameters](#dfn-validate-rsa-key-generation-parameters) algorithm with
 `normalizedAlgorithm`.

3. Generate an RSA key pair, as defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], with RSA modulus length equal to the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) member of
 `normalizedAlgorithm` and RSA public exponent equal to
 the
 [`publicExponent`](#dfn-RsaKeyGenParams-publicExponent) member of
 `normalizedAlgorithm`.

4. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `algorithm` be a new
 [`RsaHashedKeyAlgorithm`](#dfn-RsaHashedKeyAlgorithm) object.

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`RSA-OAEP`\".

7. Set the
 [`modulusLength`](#dfn-RsaKeyAlgorithm-modulusLength) attribute of `algorithm` to
 equal the
 [`modulusLength`](#dfn-RsaKeyGenParams-modulusLength) member of
 `normalizedAlgorithm`.

8. Set the
 [`publicExponent`](#dfn-RsaKeyAlgorithm-publicExponent) attribute of `algorithm` to
 equal the
 [`publicExponent`](#dfn-RsaKeyGenParams-publicExponent) member of
 `normalizedAlgorithm`.

9. Set the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of `algorithm` to
 equal the
 [`hash`](#dfn-RsaHashedKeyGenParams-hash) member of
 `normalizedAlgorithm`.

10. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

11. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

13. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

14. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "encrypt", "wrapKey" ]`.

15. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

16. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

18. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

19. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "decrypt", "unwrapKey" ]`.

20. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

21. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to be
 `publicKey`.

22. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to be
 `privateKey`.

23. Return `result`.

::: header-wrapper
#### 22.4.4 Import Key

1. Let `keyData` be the key data to be imported.

2.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` contains an entry which is not
 \"`encrypt`\" or \"`wrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `rsaEncryption` object identifier
 defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. Let `publicKey` be the result of performing the
 [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `subjectPublicKeyInfo` field of
 `spki`, `structure` as the
 `RSAPublicKey` structure specified in Section A.1.1 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], and `exactData` set to
 true.

 6. If an error occurred while parsing, or it can be determined
 that `publicKey` is not a valid public key
 according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the RSA public key identified by `publicKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`decrypt`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the
 `rsaEncryption` object identifier defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. Let `rsaPrivateKey` be the result of performing
 the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `privateKey` field of
 `privateKeyInfo`, `structure` as the
 `RSAPrivateKey` structure specified in Section A.1.2 of
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], and `exactData` set to
 true.

 6. If an error occurred while parsing, or if
 `rsaPrivateKey` is not a valid RSA private key
 according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the RSA private key identified by
 `rsaPrivateKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field of `jwk` is
 present and `usages` contains an entry which is
 not \"`decrypt`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the [`d`](#dom-jsonwebkey-d) field of `jwk` is
 not present and `usages` contains an entry which
 is not \"`encrypt`\" or \"`wrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 4. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not a case-sensitive string match to \"`RSA`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not a case-sensitive string match to
 \"`enc`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8.

 If the `alg` field of `jwk` is not present:
 : Let `hash` be undefined.

 If the `alg` field of `jwk` is equal to \"`RSA-OAEP`\":
 : Let `hash` be the string \"`SHA-1`\".

 If the `alg` field of `jwk` is equal to \"`RSA-OAEP-256`\":
 : Let `hash` be the string \"`SHA-256`\".

 If the `alg` field of `jwk` is equal to \"`RSA-OAEP-384`\":
 : Let `hash` be the string \"`SHA-384`\".

 If the `alg` field of `jwk` is equal to \"`RSA-OAEP-512`\":
 : Let `hash` be the string \"`SHA-512`\".

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-rsa-oaep-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `jwk` and
 obtaining `hash`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9.

 If `hash` is not undefined:

 : 1. Let `normalizedHash` be the result of
 [normalize an
 algorithm](#dfn-normalize-an-algorithm)
 with `alg` set to `hash` and `op` set to
 `digest`.

 2. If `normalizedHash` is not equal to the
 [`hash`](#dfn-RsaHashedImportParams-hash) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 10.

 If the [`d`](#dom-jsonwebkey-d) field of `jwk` is present:

 : 1. If `jwk` does not meet the requirements
 of Section 6.3.2 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `privateKey` represent the RSA
 private key identified by interpreting
 `jwk` according to Section 6.3.2 of JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. If `privateKey` can be determined to not
 be a valid RSA private key according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 representing `privateKey`.

 5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 Otherwise:

 : 1. If `jwk` does not meet the requirements
 of Section 6.3.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `publicKey` represent the RSA public
 key identified by interpreting `jwk`
 according to Section 6.3.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. If `publicKey` can be determined to not
 be a valid RSA public key according to
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 representing `publicKey`.

 5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Let `algorithm` be a new
 [`RsaHashedKeyAlgorithm`](#dfn-RsaHashedKeyAlgorithm).

4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`RSA-OAEP`\"

5. Set the
 [`modulusLength`](#dfn-RsaKeyAlgorithm-modulusLength) attribute of `algorithm` to
 the length, in bits, of the RSA public modulus.

6. Set the
 [`publicExponent`](#dfn-RsaKeyAlgorithm-publicExponent) attribute of `algorithm` to
 the [`BigInteger`](#dfn-BigInteger) representation of the
 RSA public exponent.

7. Set the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of `algorithm` to
 the
 [`hash`](#dfn-RsaHashedImportParams-hash) member of
 `normalizedAlgorithm`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`

9. Return `key`.

::: header-wrapper
#### 22.4.5 Export Key

1. Let `key` be the key to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\"

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` field to the OID
 `rsaEncryption` defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\].

 - Set the `params` field to the ASN.1 type
 NULL.

 - Set the `subjectPublicKey` field to the result
 of DER-encoding an `RSAPublicKey` ASN.1 type, as defined
 in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], Appendix A.1.1, that represents the
 RSA public key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` field to the OID
 `rsaEncryption` defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\].

 - Set the `params` field to the ASN.1 type
 NULL.

 - Set the `privateKey` field to the result of
 DER-encoding an `RSAPrivateKey` ASN.1 type, as defined in
 \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\], Appendix A.1.2, that represents the
 RSA private key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 :::::
 :::
 Note
 :::

 :::
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] specifies that the encoding of this
 field should be *BER* encoded in Section 5 (as a \"for
 example\"). However, to avoid requiring WebCrypto
 implementations support BER-encoding and BER-decoding,
 only *DER* encodings are produced or accepted.
 :::
 :::::

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`RSA`\".

 3. Let `hash` be the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key`.

 4.

 If `hash` is \"`SHA-1`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RSA-OAEP`\".

 If `hash` is \"`SHA-256`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RSA-OAEP-256`\".

 If `hash` is \"`SHA-384`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RSA-OAEP-384`\".

 If `hash` is \"`SHA-512`\":

 : Set the `alg` attribute of `jwk` to the
 string \"`RSA-OAEP-512`\".

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-rsa-oaep-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`hash`](#dfn-RsaHashedKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining `alg`.

 2. Set the `alg` attribute of `jwk` to
 `alg`.

 5. Set the attributes
 [`n`](#dom-jsonwebkey-n) and
 [`e`](#dom-jsonwebkey-e) of `jwk` according
 to the corresponding definitions in JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.1.

 6.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\":

 : 1. Set the attributes named
 [`d`](#dom-jsonwebkey-d),
 [`p`](#dom-jsonwebkey-p),
 [`q`](#dom-jsonwebkey-q),
 [`dp`](#dom-jsonwebkey-dp),
 [`dq`](#dom-jsonwebkey-dq), and
 [`qi`](#dom-jsonwebkey-qi) of `jwk`
 according to the corresponding definitions in JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.2.

 2. If the underlying RSA private key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` is represented by
 more than two primes, set the attribute named
 [`oth`](#dom-jsonwebkey-oth) of `jwk`
 according to the corresponding definition in JSON
 Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], Section 6.3.2.7

 7. Set the `key_ops` attribute of `jwk` to the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 8. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 9. Let `result` be `jwk`.

 Otherwise

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `result`.

::: header-wrapper
## 23. ECDSA

::: header-wrapper
### 23.1 Description

*This section is non-normative.*

The \"`ECDSA`\" algorithm identifier is used to perform signing and
verification using the ECDSA algorithm specified in
\[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\] and using the SHA hash functions and elliptic
curves defined in this specification.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional elliptic curves and hash algorithms
with ECDSA. To specify additional hash algorithms to be used with ECDSA,
a specification must define a [registered algorithm](#algorithms) that
supports the digest operation. To specify an additional elliptic curve a
specification must define [the curve
name], [ECDSA signature
steps], [ECDSA verification
steps], [ECDSA generation
steps], [ECDSA key import
steps] and [ECDSA key export
steps].

::: header-wrapper
### 23.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`ECDSA`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------
 sign [`EcdsaParams`](#dfn-EcdsaParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 verify [`EcdsaParams`](#dfn-EcdsaParams) boolean
 generateKey [`EcKeyGenParams`](#dfn-EcKeyGenParams) [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 importKey [`EcKeyImportParams`](#dfn-EcKeyImportParams) [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 23.3 [`EcdsaParams`] dictionary

```
WebIDLdictionary EcdsaParams : Algorithm {
 required HashAlgorithmIdentifier hash;
};
```

The [`hash`]
member represents the hash algorithm to use.

::: header-wrapper
### 23.4 [`EcKeyGenParams`] dictionary

```
WebIDLtypedef DOMString NamedCurve;

dictionary EcKeyGenParams : Algorithm {
 required NamedCurve namedCurve;
};
```

The [`NamedCurve`] type represents named elliptic curves, which are
a convenient way to specify the domain parameters of well-known elliptic
curves. The following values defined by this specification:

\"`P-256`\"
: NIST recommended curve P-256, also known as `secp256r1`.

\"`P-384`\"
: NIST recommended curve P-384, also known as `secp384r1`.

\"`P-521`\"
: NIST recommended curve P-521, also known as `secp521r1`.

[Other
specifications](#dfn-applicable-specification)
may define [additional
values](#dfn-ecdsa-extended-namedcurve-values).

The [`namedCurve`] member of the
[`EcKeyGenParams`](#dfn-EcKeyGenParams) dictionary represents
a named curve.

::: header-wrapper
### 23.5 [`EcKeyAlgorithm`] dictionary

```
WebIDLdictionary EcKeyAlgorithm : KeyAlgorithm {
 required NamedCurve namedCurve;
};
```

The [`namedCurve`] member represents the named curve that the key
uses.

::: header-wrapper
### 23.6 [`EcKeyImportParams`] dictionary

```
WebIDLdictionary EcKeyImportParams : Algorithm {
 required NamedCurve namedCurve;
};
```

The [`namedCurve`] member represents a named curve.

::: header-wrapper
### 23.7 Operations

::: header-wrapper
#### 23.7.1 Sign

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Let `hashAlgorithm` be the
 [`hash`](#dfn-EcdsaParams-hash) member of
 `normalizedAlgorithm`.

3. Let `M` be the result of performing the digest operation
 specified by `hashAlgorithm` using `message`.

4. Let `d` be the ECDSA private key associated with
 `key`.

5. Let `params` be the EC domain parameters associated with
 `key`.

6.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1. Perform the ECDSA signing process, as specified in
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\], Section 5.4.2, with `M` as
 the message, using `params` as the EC domain
 parameters, and with `d` as the private key.

 2. Let `r` and `s` be the pair of
 integers resulting from performing the ECDSA signing
 process.

 3. Let `result` be an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence).

 4. Let `n` be the smallest integer such that
 `n` \* 8 is greater than the logarithm to base 2
 of the order of the base point of the elliptic curve
 identified by `params`.

 5. [Convert `r` to a byte sequence of length
 `n`](#dfn-convert-integer-to-byte-sequence)
 and append it to `result`.

 6. [Convert `s` to a byte sequence of length
 `n`](#dfn-convert-integer-to-byte-sequence)
 and append it to `result`.

 Otherwise, the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is a value specified in an [applicable specification](#dfn-applicable-specification):

 : Perform the [ECDSA signature
 steps](#dfn-ecdsa-extended-signature-steps) specified in that
 specification, passing in `M`, `params`
 and `d` and resulting in `result`.

7. Return `result`.

::: header-wrapper
#### 23.7.2 Verify

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Let `hashAlgorithm` be the
 [`hash`](#dfn-EcdsaParams-hash) member of
 `normalizedAlgorithm`.

3. Let `M` be the result of performing the digest operation
 specified by `hashAlgorithm` using `message`.

4. Let `Q` be the ECDSA public key associated with
 `key`.

5. Let `params` be the EC domain parameters associated with
 `key`.

6.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1. Let `n` be the smallest integer such that
 `n` \* 8 is greater than the logarithm to base 2
 of the order of the base point of the elliptic curve
 identified by `params`.

 2. If `signature` does not have a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 of `n` \* 2 bytes, then return false.

 3. Let `r` be the result of [converting the first
 `n` bytes of `signature` to an
 integer](#dfn-convert-byte-sequence-to-integer).

 4. Let `s` be the result of [converting the last
 `n` bytes of `signature` to an
 integer](#dfn-convert-byte-sequence-to-integer).

 5. Perform the ECDSA verifying process, as specified in
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\], Section 5.4.3, with `M` as
 the received message, (`r`, `s`) as
 the signature and using `params` as the EC domain
 parameters, and `Q` as the public key.

 Otherwise, the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is a value specified in an [applicable specification](#dfn-applicable-specification):

 : Perform the [ECDSA verification
 steps](#dfn-ecdsa-extended-verification-steps) specified in that
 specification passing in `M`, `signature`,
 `params` and `Q` and resulting in an
 indication of whether or not the purported signature is valid.

7. Let `result` be a boolean with the value `true` if the
 signature is valid and the value `false` otherwise.

8. Return `result`.

::: header-wrapper
#### 23.7.3 Generate Key

1. If `usages` contains an entry which is not one of
 \"`sign`\" or \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If the [`namedCurve`](#dfn-EcKeyGenParams-namedCurve) member of `normalizedAlgorithm` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Generate an Elliptic Curve key pair, as defined in
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\] with domain parameters for the curve
 identified by the
 [`namedCurve`](#dfn-EcKeyGenParams-namedCurve) member of
 `normalizedAlgorithm`.

 If the [`namedCurve`](#dfn-EcKeyGenParams-namedCurve) member of `normalizedAlgorithm` is a value specified in an [applicable specification](#dfn-applicable-specification):

 : Perform the [ECDSA generation
 steps](#dfn-ecdsa-extended-generation-steps) specified in that
 specification, passing in `normalizedAlgorithm` and
 resulting in an elliptic curve key pair.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)

3. If performing the key generation operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm) object.

5. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`ECDSA`\".

6. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of `algorithm` to
 equal the [`namedCurve`](#dfn-NamedCurve) member of
 `normalizedAlgorithm`.

7. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

9. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

10. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

11. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "verify" ]`.

12. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

13. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

14. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

15. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

16. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "sign" ]`.

17. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

18. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to be
 `publicKey`.

19. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to be
 `privateKey`.

20. Return `result`.

::: header-wrapper
#### 23.7.4 Import Key

1. If the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm` is not one of \"`P-256`\",
 \"`P-384`\" or \"`P-521`\", and is not a value specified in an
 [applicable
 specification](#dfn-applicable-specification)
 that specifies the use of that value with ECDSA, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

2. Let `keyData` be the key data to be imported.

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` contains an entry which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `id-ecPublicKey` object identifier
 defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `algorithm`
 AlgorithmIdentifier field of `spki` is absent,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `params` be the `parameters` field of the
 `algorithm` AlgorithmIdentifier field of `spki`.

 7. If `params` is not an instance of the
 `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] that specifies a `namedCurve`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `namedCurve` be a string whose initial value
 is undefined.

 9.

 If `params` is equivalent to the `secp256r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-256`\".

 If `params` is equivalent to the `secp384r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-384`\".

 If `params` is equivalent to the `secp521r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-521`\".

 10.

 If `namedCurve` is not undefined:

 : 1. Let `publicKey` be the Elliptic Curve
 public key identified by performing the conversion
 steps defined in Section 2.3.4 of
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] using the `subjectPublicKey`
 field of `spki`.

 The uncompressed point format *MUST* be supported.

 2. If the implementation does not support the
 compressed point format and a compressed point is
 provided,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If a decode error occurs or an identity point is
 found,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that
 represents `publicKey`.

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdsa-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `spki` and
 obtaining `namedCurve` and
 `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 11. If `namedCurve` is defined, and not equal to the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 12. If the public key value is not a valid point on the Elliptic
 Curve identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 13. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 14. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm).

 15. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDSA`\".

 16. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to `namedCurve`.

 17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`sign`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurs while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the
 `id-ecPublicKey` object identifier defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `privateKeyAlgorithm`
 PrivateKeyAlgorithmIdentifier field of
 `privateKeyInfo` is not present, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `params` be the `parameters` field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithmIdentifier field of
 `privateKeyInfo`.

 7. If `params` is not an instance of the
 `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] that specifies a `namedCurve`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `namedCurve` be a string whose initial value
 is undefined.

 9.

 If `params` is equivalent to the `secp256r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-256`\".

 If `params` is equivalent to the `secp384r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-384`\".

 If `params` is equivalent to the `secp521r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-521`\".

 10.

 If `namedCurve` is not undefined:

 : 1. Let `ecPrivateKey` be the result of
 performing the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm,
 with `data` as the `privateKey` field of
 `privateKeyInfo`, `structure`
 as the ASN.1 `ECPrivateKey` structure specified in
 Section 3 of
 \[[RFC5915](#bib-rfc5915 "Elliptic Curve Private Key Structure")\], and `exactData`
 set to true.

 2. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If the `parameters` field of
 `ecPrivateKey` is present, and is not an
 instance of the `namedCurve` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\], or does not contain the same
 object identifier as the `parameters` field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithmIdentifier
 field of `privateKeyInfo`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that
 represents the Elliptic Curve private key identified
 by performing the conversion steps defined in
 Section 3 of
 \[[RFC5915](#bib-rfc5915 "Elliptic Curve Private Key Structure")\] using
 `ecPrivateKey`.

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdsa-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`,
 `privateKeyInfo` and obtaining
 `namedCurve` and `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 11. If `namedCurve` is defined, and not equal to the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 12. If the private key value is not a valid point on the
 Elliptic Curve identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 13. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 14. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm).

 15. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDSA`\".

 16. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to `namedCurve`.

 17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field is present and
 `usages` contains a value which is not
 \"`sign`\", or, if the
 [`d`](#dom-jsonwebkey-d) field is not present and
 `usages` contains a value which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`EC`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`sig`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\], or it does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. Let `namedCurve` be a string whose value is equal
 to the
 [`crv`](#dom-jsonwebkey-crv) field of `jwk`.

 8. If `namedCurve` is not equal to the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9.

 If `namedCurve` is equal to \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1. Let `algNamedCurve` be a string whose
 initial value is undefined.

 2.

 If the [`alg`](#dom-jsonwebkey-alg) field is not present:
 : Let `algNamedCurve` be undefined.

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"ES256\":
 : Let `algNamedCurve` be the string
 \"`P-256`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"ES384\":
 : Let `algNamedCurve` be the string
 \"`P-384`\".

 If the [`alg`](#dom-jsonwebkey-alg) field is equal to the string \"ES512\":
 : Let `algNamedCurve` be the string
 \"`P-521`\".

 otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If `algNamedCurve` is defined, and is not
 equal to `namedCurve`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4.

 If the [`d`](#dom-jsonwebkey-d) field is present:

 : 1. If `jwk` does not meet the
 requirements of Section 6.2.2 of JSON Web
 Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 object that represents the Elliptic Curve
 private key identified by interpreting
 `jwk` according to Section 6.2.2
 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `Key` to
 \"[`private`](#dom-keytype-private)\".

 Otherwise:

 : 1. If `jwk` does not meet the
 requirements of Section 6.2.1 of JSON Web
 Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 object that represents the Elliptic Curve
 public key identified by interpreting
 `jwk` according to Section 6.2.1
 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `Key` to
 \"[`public`](#dom-keytype-public)\".

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdsa-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `jwk` and
 obtaining `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 10. If the key value is not a valid point on the Elliptic Curve
 identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 11. Let `algorithm` be a new instance of an
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm) object.

 12. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDSA`\".

 13. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to `namedCurve`.

 14. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm` is not a [named
 curve](#dfn-NamedCurve), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If `usages` contains an entry which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3.

 If `namedCurve` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1. Let `Q` be the elliptic curve point on
 the curve identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm` identified by
 performing the conversion steps defined in Section
 2.3.4 of
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] on `keyData`.

 The uncompressed point format *MUST* be supported.

 2. If the implementation does not support the
 compressed point format and a compressed point is
 provided,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If a decode error occurs or an identity point is
 found,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that
 represents `Q`.

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdh-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `keyData`
 and obtaining `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm) object.

 5. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDSA`\".

 6. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to equal the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`.

 7. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `key`.

::: header-wrapper
#### 23.7.5 Export Key

1. Let `key` be the
 [`CryptoKey`](#dfn-CryptoKey) to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` field to the OID
 `id-ecPublicKey` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\].

 - Set the `parameters` field to an instance of
 the `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] as follows:

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Let `keyData` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 that represents the Elliptic Curve public key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` according to the
 encoding rules specified in Section 2.2 of
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] and using the uncompressed
 form. and `keyData`.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\":

 : Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `secp256r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-384`\":

 : Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `secp384r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-521`\":

 : Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `secp521r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-ecdsa-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining
 `namedCurveOid` and
 `keyData`.

 2. Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `namedCurveOid`.

 - Set the `subjectPublicKey` field to
 `keyData`.

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` field to the OID
 `id-ecPublicKey` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\].

 - Set the `parameters` field to an instance of
 the `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] as follows:

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Let `keyData` be the result of
 DER-encoding an instance of the `ECPrivateKey`
 structure defined in Section 3 of
 \[[RFC5915](#bib-rfc5915 "Elliptic Curve Private Key Structure")\] for the Elliptic Curve private
 key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` and that conforms
 to the following:

 - The `parameters` field is present, and
 is equivalent to the `parameters` field
 of the `privateKeyAlgorithm` field of
 this `PrivateKeyInfo` ASN.1 structure.

 - The `publicKey` field is present and
 represents the Elliptic Curve public key
 associated with the Elliptic Curve private key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key`.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\":

 : Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `secp256r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-384`\":

 : Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `secp384r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-521`\":

 : Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `secp521r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-ecdsa-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining
 `namedCurveOid` and
 `keyData`.

 2. Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `namedCurveOid`.

 - Set the `privateKey` field to
 `keyData`.

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to \"`EC`\".

 3.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\":
 : Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to \"`P-256`\"

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-384`\":
 : Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to \"`P-384`\"

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-521`\":
 : Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to \"`P-521`\"

 2. Set the
 [`x`](#dom-jsonwebkey-x) attribute of
 `jwk` according to the definition in
 Section 6.2.1.2 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. Set the
 [`y`](#dom-jsonwebkey-y) attribute of
 `jwk` according to the definition in
 Section 6.2.1.3 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\"

 : Set the
 [`d`](#dom-jsonwebkey-d) attribute of
 `jwk` according to the definition in
 Section 6.2.2.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-ecdsa-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining
 `namedCurve` and a new value of
 `jwk`.

 2. Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to `namedCurve`.

 4. Set the `key_ops` attribute of `jwk` to the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 5. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 6. Let `result` be `jwk`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 representing the Elliptic Curve point `Q`
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` according to
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] 2.3.3 using the uncompressed
 format.

 Otherwise:

 : Perform any [key export
 steps](#dfn-ecdh-extended-export-steps) defined by [other applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` and obtaining
 `namedCurve` and `data`.

 3. Let `result` be `data`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `result`.

::: header-wrapper
## 24. ECDH

::: header-wrapper
### 24.1 Description

*This section is non-normative.*

This describes using Elliptic Curve Diffie-Hellman (ECDH) for key
generation and key agreement, as specified by
\[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\].

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional elliptic curves with ECDH. To specify
an additional elliptic curve a specification must define [the curve
name],
[ECDH generation steps], [ECDH
derivation steps], [ECDH key import
steps] and [ECDH key export
steps].

::: header-wrapper
### 24.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`ECDH`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------
 generateKey [`EcKeyGenParams`](#dfn-EcKeyGenParams) [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 deriveBits [`EcdhKeyDeriveParams`](#dfn-EcdhKeyDeriveParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 importKey [`EcKeyImportParams`](#dfn-EcKeyImportParams) [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 24.3 [`EcdhKeyDeriveParams`] dictionary

```
WebIDLdictionary EcdhKeyDeriveParams : Algorithm {
 required CryptoKey public;
};
```

The [`public`] member represents the peer\'s EC public key.

::: header-wrapper
### 24.4 Operations

::: header-wrapper
#### 24.4.1 Generate Key

1. If `usages` contains an entry which is not
 \"`deriveKey`\" or \"`deriveBits`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If the [`namedCurve`](#dfn-EcKeyGenParams-namedCurve) member of `normalizedAlgorithm` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Generate an Elliptic Curve key pair, as defined in
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\] with domain parameters for the curve
 identified by the
 [`namedCurve`](#dfn-EcKeyGenParams-namedCurve) member of
 `normalizedAlgorithm`.

 If the [`namedCurve`](#dfn-EcKeyGenParams-namedCurve) member of `normalizedAlgorithm` is a value specified in an [applicable specification](#dfn-applicable-specification) that specifies the use of that value with ECDH:

 : Perform the [ECDH generation
 steps](#dfn-ecdh-extended-generation-steps) specified in that
 specification, passing in `normalizedAlgorithm` and
 resulting in an elliptic curve key pair.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)

3. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm) object.

5. Set the [`name`](#dom-algorithm-name) member of `algorithm` to
 \"`ECDH`\".

6. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of `algorithm` to
 equal the [`namedCurve`](#dfn-NamedCurve) member of
 `normalizedAlgorithm`.

7. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

9. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

10. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

11. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the empty list.

12. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

13. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

14. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

15. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

16. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "deriveKey", "deriveBits" ]`.

17. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

18. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to be
 `publicKey`.

19. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to be
 `privateKey`.

20. Return `result`.

::: header-wrapper
#### 24.4.2 Derive Bits

1. Let `publicKey` be the
 [`public`](#dfn-EcdhKeyDeriveParams-public) member of
 `normalizedAlgorithm`.

2. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

3. If the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` is not equal to the
 [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

4. Let `maximumLength` be the length in bits of the output
 of the field element to octet string conversion defined in Section
 6.2 of
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\] for the EC domain parameters associated with
 `publicKey`.

5. If `length` is not null and is greater than
 `maximumLength`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

6. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

7. If the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` is not equal to the
 [`name`](#dom-keyalgorithm-name) property of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

8. If the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` is not equal to the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) property of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

9.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) property of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1. Perform the ECDH primitive specified in
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\] Section 4 with `key` as the
 EC private key `d` and the EC public key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `publicKey` as the EC public key.

 2. Let `secret` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 containing the result of applying the field element to octet
 string conversion defined in Section 6.2 of
 \[[RFC6090](#bib-rfc6090 "Fundamental Elliptic Curve Cryptography Algorithms")\] to the output of the ECDH primitive.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) property of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is a value specified in an [applicable specification](#dfn-applicable-specification) that specifies the use of that value with ECDH:

 : Perform the [ECDH derivation
 steps](#dfn-ecdh-extended-derivation-steps) specified in that
 specification, passing in `key` and
 `publicKey` and resulting in `secret`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)

10. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

11.

 If `length` is null:
 : Return `secret`.

 Otherwise:

 :

 If the [length in bits](#dfn-length-in-bits) of `secret` is less than `length`:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

 Otherwise:
 : Return a [byte sequence
 containing](#dfn-byte-sequence-containing) the first
 `length` bits of `secret`.

::: header-wrapper
#### 24.4.3 Import Key

1. If the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm` is not one of \"`P-256`\",
 \"`P-384`\" or \"`P-521`\", and is not a value specified in an
 [applicable
 specification](#dfn-applicable-specification)
 that specifies the use of that value with ECDH, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

2. Let `keyData` be the key data to be imported.

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` is not empty then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `id-ecPublicKey` object identifier
 defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `algorithm`
 AlgorithmIdentifier field of `spki` is absent,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `params` be the `parameters` field of the
 `algorithm` AlgorithmIdentifier field of `spki`.

 7. If `params` is not an instance of the
 `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] that specifies a `namedCurve`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `namedCurve` be a string whose initial value
 is undefined.

 9.

 If `params` is equivalent to the `secp256r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-256`\".

 If `params` is equivalent to the `secp384r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-384`\".

 If `params` is equivalent to the `secp521r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` \"`P-521`\".

 10.

 If `namedCurve` is not undefined:

 : 1. Let `publicKey` be the Elliptic Curve
 public key identified by performing the conversion
 steps defined in Section 2.3.4 of
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] to the `subjectPublicKey`
 field of `spki`.

 The uncompressed point format *MUST* be supported.

 2. If the implementation does not support the
 compressed point format and a compressed point is
 provided,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If a decode error occurs or an identity point is
 found,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that
 represents `publicKey`.

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdh-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `spki` and
 obtaining `namedCurve` and
 `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 11. If `namedCurve` is defined, and not equal to the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 12. If the key value is not a valid point on the Elliptic Curve
 identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 13. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 14. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm).

 15. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDH`\".

 16. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to `namedCurve`.

 17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`deriveKey`\" or \"`deriveBits`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurs while parsing,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the
 `id-ecPublicKey` object identifier defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\],
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `privateKeyAlgorithm`
 PrivateKeyAlgorithmIdentifier field of
 `privateKeyInfo` is not present,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `params` be the `parameters` field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithmIdentifier field of
 `privateKeyInfo`.

 7. If `params` is not an instance of the
 `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] that specifies a `namedCurve`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `namedCurve` be a string whose initial value
 is undefined.

 9.

 If `params` is equivalent to the `secp256r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` to \"`P-256`\".

 If `params` is equivalent to the `secp384r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` to \"`P-384`\".

 If `params` is equivalent to the `secp521r1` object identifier defined in \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]:

 : Set `namedCurve` to \"`P-521`\".

 10.

 If `namedCurve` is not undefined:

 : 1. Let `ecPrivateKey` be the result of
 performing the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm,
 with `data` as the `privateKey` field of
 `privateKeyInfo`, `structure`
 as the ASN.1 `ECPrivateKey` structure specified in
 Section 3 of
 \[[RFC5915](#bib-rfc5915 "Elliptic Curve Private Key Structure")\], and `exactData`
 set to true.

 2. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If the `parameters` field of
 `ecPrivateKey` is present, and is not an
 instance of the `namedCurve` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\], or does not contain the same
 object identifier as the `parameters` field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithmIdentifier
 field of `privateKeyInfo`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that
 represents the Elliptic Curve private key identified
 by performing the conversion steps defined in
 Section 3 of
 \[[RFC5915](#bib-rfc5915 "Elliptic Curve Private Key Structure")\] using
 `ecPrivateKey`.

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdh-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`,
 `privateKeyInfo` and obtaining
 `namedCurve` and `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 11. If `namedCurve` is defined, and not equal to the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 12. If the key value is not a valid point on the Elliptic Curve
 identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 13. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\".

 14. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm).

 15. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDH`\".

 16. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to `namedCurve`.

 17. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field is present and if
 `usages` contains an entry which is not
 \"`deriveKey`\" or \"`deriveBits`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the [`d`](#dom-jsonwebkey-d) field is not present and if
 `usages` is not empty then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 4. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`EC`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not equal to \"`enc`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\], or it does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `namedCurve` be a string whose value is equal
 to the
 [`crv`](#dom-jsonwebkey-crv) field of `jwk`.

 9. If `namedCurve` is not equal to the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 10.

 If `namedCurve` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 :

 If the [`d`](#dom-jsonwebkey-d) field is present:

 : 1. If `jwk` does not meet the
 requirements of Section 6.2.2 of JSON Web
 Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 object that represents the Elliptic Curve
 private key identified by interpreting
 `jwk` according to Section 6.2.2 of
 JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `Key`
 to
 \"[`private`](#dom-keytype-private)\".

 Otherwise:

 : 1. If `jwk` does not meet the
 requirements of Section 6.2.1 of JSON Web
 Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey)
 object that represents the Elliptic Curve public
 key identified by interpreting `jwk`
 according to Section 6.2.1 of JSON Web
 Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `Key`
 to
 \"[`public`](#dom-keytype-public)\".

 Otherwise

 : 1. Perform any [key import
 steps](#dfn-ecdh-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `jwk` and
 obtaining `key`.

 2. If an error occurred or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 11. If the key value is not a valid point on the Elliptic Curve
 identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 12. Let `algorithm` be a new instance of an
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm) object.

 13. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDH`\".

 14. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to `namedCurve`.

 15. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm` is not a [named
 curve](#dfn-NamedCurve), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If `usages` is not the empty list, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3.

 If `namedCurve` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1. Let `Q` be the Elliptic Curve public key
 on the curve identified by the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm` identified by
 performing the conversion steps defined in Section
 2.3.4 of
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] to `keyData`.

 The uncompressed point format *MUST* be supported.

 2. If the implementation does not support the
 compressed point format and a compressed point is
 provided,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If a decode error occurs or an identity point is
 found,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that
 represents `Q`.

 Otherwise:

 : 1. Perform any [key import
 steps](#dfn-ecdh-extended-import-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `keyData`
 and obtaining `key`.

 2. If an error occured or there are no [applicable
 specifications](#dfn-applicable-specification),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `algorithm` be a new
 [`EcKeyAlgorithm`](#dfn-EcKeyAlgorithm) object.

 5. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`ECDH`\".

 6. Set the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of
 `algorithm` to equal the
 [`namedCurve`](#dfn-EcKeyImportParams-namedCurve) member of
 `normalizedAlgorithm`.

 7. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

4. Return `key`.

::: header-wrapper
#### 24.4.4 Export Key

1. Let `key` be the
 [`CryptoKey`](#dfn-CryptoKey) to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` field to the OID
 `id-ecPublicKey` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\].

 - Set the `parameters` field to an instance of
 the `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] as follows:

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Let `keyData` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 that represents the Elliptic Curve public key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` according to the
 encoding rules specified in Section 2.3.3 of
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] and using the uncompressed
 form.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\":

 : Set `parameters` to the
 `namedCurve` choice with value equal
 to the object identifier `secp256r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-384`\":

 : Set `parameters` to the
 `namedCurve` choice with value equal
 to the object identifier `secp384r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-521`\":

 : Set `parameters` to the
 `namedCurve` choice with value equal
 to the object identifier `secp521r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-ecdh-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining
 `namedCurveOid` and
 `keyData`.

 2. Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `namedCurveOid`.

 - Set the `subjectPublicKey` field to
 `keyData`

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` field to the OID
 `id-ecPublicKey` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\].

 - Set the `parameters` field to an instance of
 the `ECParameters` ASN.1 type defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\] as follows:

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Let `keyData` be the result of
 DER-encoding an instance of the `ECPrivateKey`
 structure defined in Section 3 of
 \[[RFC5915](#bib-rfc5915 "Elliptic Curve Private Key Structure")\] for the Elliptic Curve private
 key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` and that conforms
 to the following:

 - The `parameters` field is present, and
 is equivalent to the `parameters` field
 of the `privateKeyAlgorithm` field of
 this `PrivateKeyInfo` ASN.1 structure.

 - The `publicKey` field is present and
 represents the Elliptic Curve public key
 associated with the Elliptic Curve private key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key`.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\":

 : Set `parameters` to the
 `namedCurve` choice with value equal
 to the object identifier `secp256r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-384`\":

 : Set `parameters` to the
 `namedCurve` choice with value equal
 to the object identifier `secp384r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-521`\":

 : Set `parameters` to the
 `namedCurve` choice with value equal
 to the object identifier `secp521r1` defined in
 \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-ecdh-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining
 `namedCurveOid` and
 `keyData`.

 2. Set `parameters` to the `namedCurve`
 choice with value equal to the object identifier
 `namedCurveOid`.

 - Set the `privateKey` field to
 `keyData`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to \"`EC`\".

 3.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : 1.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\":
 : Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to \"`P-256`\"

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-384`\":
 : Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to \"`P-384`\"

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-521`\":
 : Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to \"`P-521`\"

 2. Set the
 [`x`](#dom-jsonwebkey-x) attribute of
 `jwk` according to the definition in
 Section 6.2.1.2 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 3. Set the
 [`y`](#dom-jsonwebkey-y) attribute of
 `jwk` according to the definition in
 Section 6.2.1.3 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\"

 : Set the
 [`d`](#dom-jsonwebkey-d) attribute of
 `jwk` according to the definition in
 Section 6.2.2.1 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 Otherwise:

 : 1. Perform any [key export
 steps](#dfn-ecdh-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of
 `key` and obtaining
 `namedCurve` and a new value of
 `jwk`.

 2. Set the
 [`crv`](#dom-jsonwebkey-crv) attribute of
 `jwk` to `namedCurve`.

 4. Set the `key_ops` attribute of `jwk` to the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 5. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 6. Let `result` be `jwk`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2.

 If the [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot of `key` is \"`P-256`\", \"`P-384`\" or \"`P-521`\":

 : Let `data` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 that represents the Elliptic Curve public key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key` according to the
 encoding rules specified in Section 2.3.3 of
 \[[SEC1](#bib-sec1 "SEC 1: Elliptic Curve Cryptography")\] and using the uncompressed form.

 Otherwise:

 : Perform any [key export
 steps](#dfn-ecdh-extended-export-steps) defined by [other applicable
 specifications](#dfn-applicable-specification),
 passing `format` and the
 [`namedCurve`](#dfn-EcKeyAlgorithm-namedCurve) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` and obtaining
 `namedCurve` and `data`.

 3. Let `result` be `data`.

4. Return `result`.

::: header-wrapper
## 25. Ed25519

::: header-wrapper
### 25.1 Description

*This section is non-normative.*

The \"`Ed25519`\" algorithm identifier is used to perform signing and
verification using the Ed25519 algorithm specified in
\[[RFC8032](#bib-rfc8032 "Edwards-Curve Digital Signature Algorithm (EdDSA)")\].

::: header-wrapper
### 25.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`Ed25519`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- -------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------
 sign None [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 verify None boolean
 generateKey None [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 25.3 Operations

::: header-wrapper
#### 25.3.1 Sign

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. Let `result` be the result of performing the Ed25519
 signing process, as specified in
 \[[RFC8032](#bib-rfc8032 "Edwards-Curve Digital Signature Algorithm (EdDSA)")\], Section 5.1.6, with `message` as
 `M`, using the Ed25519 private key associated with
 `key`.

 ::::
 :::
 [[Issue
 424]](https://github.com/w3c/webcrypto/issues/424)[:
 Allow creating hedged EdDSA signatures?]
 :::

 Some implementations may (wish to) generate randomized signatures as
 per
 [draft-irtf-cfrg-det-sigs-with-noise](https://datatracker.ietf.org/doc/draft-irtf-cfrg-det-sigs-with-noise/)
 instead of deterministic signatures as per
 \[[RFC8032](#bib-rfc8032 "Edwards-Curve Digital Signature Algorithm (EdDSA)")\].
 ::::

3. Return `result`.

::: header-wrapper
#### 25.3.2 Verify

1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

2. If the key data of `key` represents an invalid point or a
 small-order element on the Elliptic Curve of Ed25519, return
 `false`.

 ::::
 :::
 [[Issue
 423]](https://github.com/w3c/webcrypto/issues/423)[:
 Make small-order checks in EdDSA optional?]
 :::

 Not all implementations perform this check.
 ::::

3. If the point R, encoded in the first half of `signature`,
 represents an invalid point or a small-order element on the Elliptic
 Curve of Ed25519, return `false`.

 ::::
 :::
 [[Issue
 423]](https://github.com/w3c/webcrypto/issues/423)[:
 Make small-order checks in EdDSA optional?]
 :::

 Not all implementations perform this check.
 ::::

4. Perform the Ed25519 verification steps, as specified in
 \[[RFC8032](#bib-rfc8032 "Edwards-Curve Digital Signature Algorithm (EdDSA)")\], Section 5.1.7, using the cofactorless
 (unbatched) equation, `[S]B = R + [k]A'`, on the
 `signature`, with `message` as `M`,
 using the Ed25519 public key associated with `key`.

5. Let `result` be a boolean with the value `true` if the
 signature is valid and the value `false` otherwise.

6. Return `result`.

::: header-wrapper
#### 25.3.3 Generate Key

1. If `usages` contains an entry which is not one of
 \"`sign`\" or \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Generate an Ed25519 key pair, as defined in
 \[[RFC8032](#bib-rfc8032 "Edwards-Curve Digital Signature Algorithm (EdDSA)")\], section 5.1.5.

3. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`Ed25519`\".

5. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

6. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

7. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

8. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

9. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "verify" ]`.

10. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

11. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

13. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

14. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "sign" ]`.

15. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

16. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to be
 `publicKey`.

17. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to be
 `privateKey`.

18. Return `result`.

::: header-wrapper
#### 25.3.4 Import Key

1. Let `keyData` be the key data to be imported.

2.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` contains an entry which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `id-Ed25519` object identifier defined
 in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `algorithm`
 AlgorithmIdentifier field of `spki` is present,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `publicKey` be the Ed25519 public key
 identified by the `subjectPublicKey` field of
 `spki`.

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 `publicKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 9. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm).

 10. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`Ed25519`\".

 11. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`sign`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurs while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the `id-Ed25519`
 object identifier defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `privateKeyAlgorithm`
 PrivateKeyAlgorithmIdentifier field of
 `privateKeyInfo` is present, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `curvePrivateKey` be the result of performing
 the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `privateKey` field of
 `privateKeyInfo`, `structure` as the
 ASN.1 `CurvePrivateKey` structure specified in Section 7 of
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], and `exactData` set to
 true.

 7. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the Ed25519 private key identified by
 `curvePrivateKey`.

 9. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 10. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm).

 11. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`Ed25519`\".

 12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field is present and
 `usages` contains a value which is not
 \"`sign`\", or, if the
 [`d`](#dom-jsonwebkey-d) field is not present and
 `usages` contains a value which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`OKP`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the
 [`crv`](#dom-jsonwebkey-crv) field of `jwk` is
 not \"`Ed25519`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk` is
 present and is not \"`Ed25519`\" or \"`EdDSA`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`sig`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\], or it does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9.

 If the [`d`](#dom-jsonwebkey-d) field is present:

 : 1. If `jwk` does not meet the requirements
 of the JWK private key format described in Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object
 that represents the Ed25519 private key identified
 by interpreting `jwk` according to
 Section 2 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `Key` to
 \"[`private`](#dom-keytype-private)\".

 Otherwise:

 : 1. If `jwk` does not meet the requirements
 of the JWK public key format described in Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object
 that represents the Ed25519 public key identified by
 interpreting `jwk` according to Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `Key` to
 \"[`public`](#dom-keytype-public)\".

 10. Let `algorithm` be a new instance of a
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

 11. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`Ed25519`\".

 12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If `usages` contains an entry which is not
 \"`verify`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. If the [length in
 bits](#dfn-length-in-bits) of
 `keyData` is not 256 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

 4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`Ed25519`\".

 5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing
 the key data provided in `keyData`.

 6. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 7. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Return `key`.

::: header-wrapper
#### 25.3.5 Export Key

1. Let `key` be the
 [`CryptoKey`](#dfn-CryptoKey) to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` object identifier to the
 `id-Ed25519` OID defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\].

 - Set the `subjectPublicKey` field to
 `keyData`.

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` object identifier to the
 `id-Ed25519` OID defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\].

 - Set the `privateKey` field to the result of
 DER-encoding a `CurvePrivateKey` ASN.1 type, as defined in
 Section 7 of
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], that represents the Ed25519 private
 key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to \"`OKP`\".

 3. Set the `alg` attribute of `jwk` to
 \"`Ed25519`\".

 4. Set the `crv` attribute of `jwk` to
 \"`Ed25519`\".

 5. Set the [`x`](#dom-jsonwebkey-x) attribute of `jwk`
 according to the definition in Section 2 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 6.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\"
 : Set the
 [`d`](#dom-jsonwebkey-d) attribute of
 `jwk` according to the definition in Section
 2 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 7. Set the `key_ops` attribute of `jwk` to the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 8. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 9. Let `result` be `jwk`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 representing the Ed25519 public key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`.

 3. Let `result` be `data`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `result`.

::: header-wrapper
## 26. X25519

::: header-wrapper
### 26.1 Description

*This section is non-normative.*

The \"`X25519`\" algorithm identifier is used to perform key agreement
using the X25519 algorithm specified in
\[[RFC7748](#bib-rfc7748 "Elliptic Curves for Security")\].

::: header-wrapper
### 26.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`X25519`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------
 deriveBits [`EcdhKeyDeriveParams`](#dfn-EcdhKeyDeriveParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 generateKey None [`CryptoKeyPair`](#dfn-CryptoKeyPair)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object

::: header-wrapper
### 26.3 Operations

::: header-wrapper
#### 26.3.1 Derive Bits

1. Let `publicKey` be the
 [`public`](#dfn-EcdhKeyDeriveParams-public) member of
 `normalizedAlgorithm`.

2. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

3. If the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` is not equal to the
 [`name`](#dom-algorithm-name) member of
 `normalizedAlgorithm`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

4. If `length` is not null and is greater than 256, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

6. If the
 [`name`](#dom-keyalgorithm-name) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` is not equal to the
 [`name`](#dom-keyalgorithm-name) property of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

7. Let `secret` be the result of performing the X25519
 function specified in
 \[[RFC7748](#bib-rfc7748 "Elliptic Curves for Security")\] Section 5 with `key` as the X25519
 private key `k` and the X25519 public key represented by
 the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `publicKey` as the X25519 public key `u`.

8. If `secret` is the all-zero value, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror). This check must be performed in constant-time,
 as per
 \[[RFC7748](#bib-rfc7748 "Elliptic Curves for Security")\] Section 6.1.

9.

 If `length` is null:
 : Return `secret`.

 Otherwise:

 :

 If the length of `secret` in bits is less than `length`:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

 Otherwise:
 : Return a [byte sequence
 containing](#dfn-byte-sequence-containing) the first
 `length` bits of `secret`.

::: header-wrapper
#### 26.3.2 Generate Key

1. If `usages` contains an entry which is not
 \"`deriveKey`\" or \"`deriveBits`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Generate an X25519 key pair, with the private key being 32 random
 bytes, and the public key being `X25519(a, 9)`, as defined in
 \[[RFC7748](#bib-rfc7748 "Elliptic Curves for Security")\], section 6.1.

3. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`X25519`\".

5. Let `publicKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the public key of the
 generated key pair.

6. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `publicKey` to
 \"[`public`](#dom-keytype-public)\"

7. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `publicKey` to `algorithm`.

8. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `publicKey` to true.

9. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `publicKey` to be the empty list.

10. Let `privateKey` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing the private key of the
 generated key pair.

11. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `privateKey` to
 \"[`private`](#dom-keytype-private)\"

12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `privateKey` to `algorithm`.

13. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `privateKey` to `extractable`.

14. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `privateKey` to be the [usage
 intersection](#concept-usage-intersection) of `usages` and
 `[ "deriveKey", "deriveBits" ]`.

15. Let `result` be a new
 [`CryptoKeyPair`](#dfn-CryptoKeyPair) dictionary.

16. Set the
 [`publicKey`](#dfn-CryptoKeyPair-publicKey) attribute of `result` to be
 `publicKey`.

17. Set the
 [`privateKey`](#dfn-CryptoKeyPair-privateKey) attribute of `result` to be
 `privateKey`.

18. Return `result`.

::: header-wrapper
#### 26.3.3 Import Key

1. Let `keyData` be the key data to be imported.

2.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If `usages` is not empty then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `spki` be the result of running the [parse a
 subjectPublicKeyInfo](#concept-parse-a-spki) algorithm over
 `keyData`.

 3. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `algorithm` AlgorithmIdentifier field of `spki`
 is not equal to the `id-X25519` object identifier defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `algorithm`
 AlgorithmIdentifier field of `spki` is present,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `publicKey` be the X25519 public key
 identified by the `subjectPublicKey` field of
 `spki`.

 7. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 `publicKey`.

 8. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 9. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm).

 10. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`X25519`\".

 11. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If `usages` contains an entry which is not
 \"`deriveKey`\" or \"`deriveBits`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. Let `privateKeyInfo` be the result of running the
 [parse a
 privateKeyInfo](#concept-parse-a-privateKeyInfo) algorithm over
 `keyData`.

 3. If an error occurs while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If the `algorithm` object identifier field of the
 `privateKeyAlgorithm` PrivateKeyAlgorithm field of
 `privateKeyInfo` is not equal to the `id-X25519`
 object identifier defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the `parameters` field of the `privateKeyAlgorithm`
 PrivateKeyAlgorithmIdentifier field of
 `privateKeyInfo` is present, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. Let `curvePrivateKey` be the result of performing
 the [parse an ASN.1
 structure](#concept-parse-an-asn1-structure) algorithm, with
 `data` as the `privateKey` field of
 `privateKeyInfo`, `structure` as the
 ASN.1 `CurvePrivateKey` structure specified in Section 7 of
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], and `exactData` set to
 true.

 7. If an error occurred while parsing, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) that represents
 the X25519 private key identified by
 `curvePrivateKey`.

 9. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`private`](#dom-keytype-private)\"

 10. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm).

 11. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`X25519`\".

 12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the [`d`](#dom-jsonwebkey-d) field is present and if
 `usages` contains an entry which is not
 \"`deriveKey`\" or \"`deriveBits`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. If the [`d`](#dom-jsonwebkey-d) field is not present and if
 `usages` is not empty then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 4. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`OKP`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 5. If the
 [`crv`](#dom-jsonwebkey-crv) field of `jwk` is
 not \"`X25519`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not equal to \"`enc`\" then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\], or it does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9.

 If the [`d`](#dom-jsonwebkey-d) field is present:

 : 1. If `jwk` does not meet the requirements
 of the JWK private key format described in Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object
 that represents the X25519 private key identified by
 interpreting `jwk` according to Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `Key` to
 \"[`private`](#dom-keytype-private)\".

 Otherwise:

 : 1. If `jwk` does not meet the requirements
 of the JWK public key format described in Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object
 that represents the X25519 public key identified by
 interpreting `jwk` according to Section 2
 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 3. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type)
 internal slot of `Key` to
 \"[`public`](#dom-keytype-public)\".

 10. Let `algorithm` be a new instance of a
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

 11. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`X25519`\".

 12. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If `usages` is not empty then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. If the [length in
 bits](#dfn-length-in-bits) of
 `keyData` is not 256 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

 4. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`X25519`\".

 5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing
 the key data provided in `keyData`.

 6. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`public`](#dom-keytype-public)\"

 7. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Return `key`.

::: header-wrapper
#### 26.3.4 Export Key

1. Let `key` be the
 [`CryptoKey`](#dfn-CryptoKey) to be exported.

2. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If `format` is \"[`spki`](#dom-keyformat-spki)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the
 `SubjectPublicKeyInfo` ASN.1 structure defined in
 \[[RFC5280](#bib-rfc5280 "Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile")\] with the following properties:

 - Set the `algorithm` field to an
 `AlgorithmIdentifier` ASN.1 type with the following
 properties:

 - Set the `algorithm` object identifier to the
 `id-X25519` OID defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\].

 - Set the `subjectPublicKey` field to
 `keyData`.

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`pkcs8`](#dom-keyformat-pkcs8)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`private`](#dom-keytype-private)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be an instance of the `PrivateKeyInfo`
 ASN.1 structure defined in
 \[[RFC5208](#bib-rfc5208 "Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification Version 1.2")\] with the following properties:

 - Set the `version` field to `0`.

 - Set the `privateKeyAlgorithm` field to a
 `PrivateKeyAlgorithmIdentifier` ASN.1 type with the
 following properties:

 - Set the `algorithm` object identifier to the
 `id-X25519` OID defined in
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\].

 - Set the `privateKey` field to the result of
 DER-encoding a `CurvePrivateKey` ASN.1 type, as defined in
 Section 7 of
 \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\], that represents the X25519 private
 key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle)
 internal slot of `key`

 3. Let `result` be the result of DER-encoding
 `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to \"`OKP`\".

 3. Set the `crv` attribute of `jwk` to \"`X25519`\".

 4. Set the [`x`](#dom-jsonwebkey-x) attribute of `jwk`
 according to the definition in Section 2 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 5.

 If the [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of `key` is \"[`private`](#dom-keytype-private)\"
 : Set the
 [`d`](#dom-jsonwebkey-d) attribute of
 `jwk` according to the definition in Section
 2 of
 \[[RFC8037](#bib-rfc8037 "CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON Object Signing and Encryption (JOSE)")\].

 6. Set the `key_ops` attribute of `jwk` to the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 7. Set the `ext` attribute of `jwk` to the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 8. Let `result` be `jwk`.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` is not
 \"[`public`](#dom-keytype-public)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).

 2. Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 representing the X25519 public key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`.

 3. Let `result` be `data`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

4. Return `result`.

::: header-wrapper
## 27. AES-CTR

::: header-wrapper
### 27.1 Description

*This section is non-normative.*

The \"`AES-CTR`\" algorithm identifier is used to perform encryption and
decryption using AES in Counter mode, as described in
\[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\].

::: header-wrapper
### 27.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`AES-CTR`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 encrypt [`AesCtrParams`](#dfn-AesCtrParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 decrypt [`AesCtrParams`](#dfn-AesCtrParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 generateKey [`AesKeyGenParams`](#dfn-AesKeyGenParams) [`CryptoKey`](#dfn-CryptoKey)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object
 get key length [`AesDerivedKeyParams`](#dfn-AesDerivedKeyParams) Integer

::: header-wrapper
### 27.3 [`AesCtrParams`] dictionary

```
WebIDLdictionary AesCtrParams : Algorithm {
 required BufferSource counter;
 required [EnforceRange] octet length;
};
```

The [`counter`] member
contains the initial value of the counter block.
[`counter`](#dfn-AesCtrParams-counter) *MUST* be 16 bytes (the AES block size).
The counter bits are the rightmost length bits of the counter block. The
rest of the counter block is for the nonce. The counter bits are
incremented using the standard incrementing function specified in NIST
SP 800-38A Appendix B.1: the counter bits are interpreted as a
big-endian integer and incremented by one.

The [`length`] member contains
the length, in bits, of the rightmost part of the counter block that is
incremented.

::: header-wrapper
### 27.4 [`AesKeyAlgorithm`] dictionary

```
WebIDLdictionary AesKeyAlgorithm : KeyAlgorithm {
 required [EnforceRange] unsigned short length;
};
```

The [`length`] member represents the length, in bits, of the
key.

::: header-wrapper
### 27.5 [`AesKeyGenParams`] dictionary

```
WebIDLdictionary AesKeyGenParams : Algorithm {
 required [EnforceRange] unsigned short length;
};
```

The [`length`] member represents the length, in bits, of the
key.

::: header-wrapper
### 27.6 [`AesDerivedKeyParams`] dictionary

```
WebIDLdictionary AesDerivedKeyParams : Algorithm {
 required [EnforceRange] unsigned short length;
};
```

The [`length`] member represents the length, in bits, of the
key.

::: header-wrapper
### 27.7 Operations

::: header-wrapper
#### 27.7.1 Encrypt

1. If the
 [`counter`](#dfn-AesCtrParams-counter) member of
 `normalizedAlgorithm` does not have a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 of 16 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. If the
 [`length`](#dfn-AesCtrParams-length) member of
 `normalizedAlgorithm` is zero or is greater than 128,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Let `ciphertext` be the result of performing the CTR
 Encryption operation described in Section 6.5 of
 \[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\] using AES as the block cipher, the
 [`counter`](#dfn-AesCtrParams-counter) member of
 `normalizedAlgorithm` as the initial value of the counter
 block, the
 [`length`](#dfn-AesCtrParams-length) member of
 `normalizedAlgorithm` as the input parameter
 `m` to the standard counter block incrementing function
 defined in Appendix B.1 of
 \[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\] and `plaintext` as the input
 plaintext.

4. Return `ciphertext`.

::: header-wrapper
#### 27.7.2 Decrypt

1. If the
 [`counter`](#dfn-AesCtrParams-counter) member of
 `normalizedAlgorithm` does not have a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 of 16 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. If the
 [`length`](#dfn-AesCtrParams-length) member of
 `normalizedAlgorithm` is zero or is greater than 128,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Let `plaintext` be the result of performing the CTR
 Decryption operation described in Section 6.5 of
 \[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\] using AES as the block cipher, the
 [`counter`](#dfn-AesCtrParams-counter) member of
 `normalizedAlgorithm` as the initial value of the counter
 block, the
 [`length`](#dfn-AesCtrParams-length) member of
 `normalizedAlgorithm` as the input parameter
 `m` to the standard counter block incrementing function
 defined in Appendix B.1 of
 \[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\] and `ciphertext` as the input
 ciphertext.

4. Return `plaintext`.

::: header-wrapper
#### 27.7.3 Generate Key

1. If `usages` contains an entry which is not one of
 \"`encrypt`\", \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. If the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm` is not equal to one of 128, 192 or
 256, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Generate an AES key of length equal to the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

4. If the key generation step fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing the
 generated AES key.

6. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

7. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-CTR`\".

8. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 equal the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

9. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

10. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

11. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` to be `extractable`.

12. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` to be the [normalized
 value](#concept-normalized-usages) of `usages`.

13. Return `key`.

::: header-wrapper
#### 27.7.4 Import Key

1. If `usages` contains an entry which is not one of
 \"`encrypt`\", \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be `keyData`.

 2. If the [length in
 bits](#dfn-length-in-bits) of
 `data` is not 128, 192 or 256 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`oct`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If `jwk` does not meet the requirements of
 Section 6.4 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `data` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 obtained by decoding the
 [`k`](#dom-jsonwebkey-k) field of `jwk`.

 5.

 If the [length in bits](#dfn-length-in-bits) of `data` is 128:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A128CTR`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 192:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A192CTR`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 256:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A256CTR`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`enc`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing an
 AES key with value `data`.

4. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

5. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-CTR`\".

7. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 the length, in bits, of `data`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

9. Return `key`.

::: header-wrapper
#### 27.7.5 Export Key

1. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 containing the raw octets of the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`.

 2. Let `result` be `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`oct`\".

 3. Set the [`k`](#dom-jsonwebkey-k) attribute of `jwk`
 to be a string containing the raw octets of the key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`, encoded according to Section 6.4
 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4.

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 128:
 : Set the `alg` attribute of `jwk` to the
 string \"`A128CTR`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 192:
 : Set the `alg` attribute of `jwk` to the
 string \"`A192CTR`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 256:
 : Set the `alg` attribute of `jwk` to the
 string \"`A256CTR`\".

 5. Set the `key_ops` attribute of `jwk` to equal the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal
 slot of `key`.

 6. Set the `ext` attribute of `jwk` to equal the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 7. Let `result` be `jwk`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Return `result`.

::: header-wrapper
#### 27.7.6 Get key length

1. If the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm` is not 128, 192 or 256,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Return the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm`.

::: header-wrapper
## 28. AES-CBC

::: header-wrapper
### 28.1 Description

*This section is non-normative.*

The \"`AES-CBC`\" algorithm identifier is used to perform encryption and
decryption using AES in Cipher Block Chaining mode, as described in
\[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\].

When operating in CBC mode, messages that are not exact multiples of the
AES block size (16 bytes) can be padded under a variety of padding
schemes. In the Web Crypto API, the only padding mode that is supported
is that of PKCS#7, as described by Section 10.3, step 2, of
\[[RFC2315](#bib-rfc2315 "PKCS #7: Cryptographic Message Syntax Version 1.5")\].

::: header-wrapper
### 28.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`AES-CBC`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 --------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 encrypt [`AesCbcParams`](#dfn-AesCbcParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 decrypt [`AesCbcParams`](#dfn-AesCbcParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 generateKey [`AesKeyGenParams`](#dfn-AesKeyGenParams) [`CryptoKey`](#dfn-CryptoKey)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object
 get key length [`AesDerivedKeyParams`](#dfn-AesDerivedKeyParams) Integer

::: header-wrapper
### 28.3 [`AesCbcParams`] dictionary

```
WebIDLdictionary AesCbcParams : Algorithm {
 required BufferSource iv;
};
```

The [`iv`] member
represents the initialization vector. It *MUST* be 16 bytes.

::: header-wrapper
### 28.4 Operations

::: header-wrapper
#### 28.4.1 Encrypt

1. If the [`iv`](#dfn-AesCbcParams-iv) member of
 `normalizedAlgorithm` does not have a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 of 16 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Let `paddedPlaintext` be the result of adding padding
 octets to `plaintext` according to the procedure defined
 in Section 10.3 of
 \[[RFC2315](#bib-rfc2315 "PKCS #7: Cryptographic Message Syntax Version 1.5")\], step 2, with a value of `k` of 16.

3. Let `ciphertext` be the result of performing the CBC
 Encryption operation described in Section 6.2 of
 \[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\] using AES as the block cipher, the
 [`iv`](#dfn-AesCbcParams-iv) member of
 `normalizedAlgorithm` as the `IV` input
 parameter and `paddedPlaintext` as the input plaintext.

4. Return `ciphertext`.

::: header-wrapper
#### 28.4.2 Decrypt

1. If the [`iv`](#dfn-AesCbcParams-iv) member of
 `normalizedAlgorithm` does not have a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 of 16 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. If the length of `ciphertext` is zero or is not a
 multiple of 16 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Let `paddedPlaintext` be the result of performing the CBC
 Decryption operation described in Section 6.2 of
 \[[NIST-SP800-38A](#bib-nist-sp800-38a "NIST Special Publication 800-38A: Recommendation for Block Cipher Modes of Operation, Methods and Techniques")\] using AES as the block cipher, the
 [`iv`](#dfn-AesCbcParams-iv) member of
 `normalizedAlgorithm` as the `IV` input
 parameter and `ciphertext` as the input ciphertext.

4. Let `p` be the value of the last octet of
 `paddedPlaintext`.

5. If `p` is zero or greater than 16, or if any of the last
 `p` octets of `paddedPlaintext` have a value
 which is not `p`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

6. Let `plaintext` be the result of removing `p`
 octets from the end of `paddedPlaintext`.

7. Return `plaintext`.

::: header-wrapper
#### 28.4.3 Generate Key

1. If `usages` contains an entry which is not one of
 \"`encrypt`\", \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. If the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm` is not equal to one of 128, 192 or
 256, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Generate an AES key of length equal to the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

4. If the key generation step fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing the
 generated AES key.

6. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

7. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-CBC`\".

8. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 equal the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

9. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

10. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

11. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` to be `extractable`.

12. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` to be the [normalized
 value](#concept-normalized-usages) of `usages`.

13. Return `key`.

::: header-wrapper
#### 28.4.4 Import Key

1. If `usages` contains an entry which is not one of
 \"`encrypt`\", \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be `keyData`.

 2. If the [length in
 bits](#dfn-length-in-bits) of
 `data` is not 128, 192 or 256 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`oct`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If `jwk` does not meet the requirements of
 Section 6.4 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `data` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 obtained by decoding the
 [`k`](#dom-jsonwebkey-k) field of `jwk`.

 5.

 If the [length in bits](#dfn-length-in-bits) of `data` is 128:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A128CBC`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 192:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A192CBC`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 256:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A256CBC`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`enc`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)

3. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing an
 AES key with value `data`.

4. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

5. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-CBC`\".

7. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 the length, in bits, of `data`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

9. Return `key`.

::: header-wrapper
#### 28.4.5 Export Key

1. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 containing the raw octets of the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`.

 2. Let `result` be `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`oct`\".

 3. Set the [`k`](#dom-jsonwebkey-k) attribute of `jwk`
 to be a string containing the raw octets of the key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`, encoded according to Section 6.4
 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4.

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 128:
 : Set the `alg` attribute of `jwk` to the
 string \"`A128CBC`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 192:
 : Set the `alg` attribute of `jwk` to the
 string \"`A192CBC`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 256:
 : Set the `alg` attribute of `jwk` to the
 string \"`A256CBC`\".

 5. Set the `key_ops` attribute of `jwk` to equal the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 6. Set the `ext` attribute of `jwk` to equal the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 7. Let `result` be `jwk`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Return `result`.

::: header-wrapper
#### 28.4.6 Get key length

1. If the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm` is not 128, 192 or 256,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Return the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm`.

::: header-wrapper
## 29. AES-GCM

::: header-wrapper
### 29.1 Description

*This section is non-normative.*

The \"`AES-GCM`\" algorithm identifier is used to perform authenticated
encryption and decryption using AES in Galois/Counter Mode mode, as
described in
\[[NIST-SP800-38D](#bib-nist-sp800-38d "NIST Special Publication 800-38D: Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC")\].

::: header-wrapper
### 29.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`AES-GCM`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 ---------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 encrypt [`AesGcmParams`](#dfn-AesGcmParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 decrypt [`AesGcmParams`](#dfn-AesGcmParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 generateKey [`AesKeyGenParams`](#dfn-AesKeyGenParams) [`CryptoKey`](#dfn-CryptoKey)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object
 get key length [`AesDerivedKeyParams`](#dfn-AesDerivedKeyParams) Integer

::: header-wrapper
### 29.3 [`AesGcmParams`] dictionary

```
WebIDLdictionary AesGcmParams : Algorithm {
 required BufferSource iv;
 BufferSource additionalData;
 [EnforceRange] octet tagLength;
};
```

The [`iv`] member
represents the initialization vector to use. May be up to 2\^64-1 bytes
long.

The [`additionalData`] member represents the additional authentication
data to include.

The [`tagLength`] member represents the desired length of the
authentication tag. May be 0 - 128.

::: header-wrapper
### 29.4 Operations

::: header-wrapper
#### 29.4.1 Encrypt

1. If the [`iv`](#dfn-AesGcmParams-iv) member of
 `normalizedAlgorithm` has a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 greater than 2\^64 - 1 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. If the
 [`additionalData`](#dfn-AesGcmParams-additionalData) member of
 `normalizedAlgorithm` is present and has a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 greater than 2\^64 - 1 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3.

 If the [`tagLength`](#dfn-AesGcmParams-tagLength) member of `normalizedAlgorithm` is not present:
 : Let `tagLength` be 128.

 If the [`tagLength`](#dfn-AesGcmParams-tagLength) member of `normalizedAlgorithm` is one of 32, 64, 96, 104, 112, 120 or 128:
 : Let `tagLength` be equal to the
 [`tagLength`](#dfn-AesGcmParams-tagLength) member of
 `normalizedAlgorithm`

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. If `plaintext` has a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 greater than 2\^39 - 256 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `additionalData` be the
 [`additionalData`](#dfn-AesGcmParams-additionalData) member of
 `normalizedAlgorithm` if present or an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 otherwise.

6. Let `C` and `T` be the outputs that result
 from performing the Authenticated Encryption Function described in
 Section 7.1 of
 \[[NIST-SP800-38D](#bib-nist-sp800-38d "NIST Special Publication 800-38D: Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC")\] using AES as the block cipher, the
 [`iv`](#dfn-AesGcmParams-iv) member of
 `normalizedAlgorithm` as the `IV` input
 parameter, `additionalData` as the `A` input
 parameter, `tagLength` as the `t`
 pre-requisite and `plaintext` as the input plaintext.

7. Let `ciphertext` be equal to `C` \|
 `T`, where \'\|\' denotes concatenation.

8. Return `ciphertext`.

::: header-wrapper
#### 29.4.2 Decrypt

1.

 If the [`tagLength`](#dfn-AesGcmParams-tagLength) member of `normalizedAlgorithm` is not present:
 : Let `tagLength` be 128.

 If the [`tagLength`](#dfn-AesGcmParams-tagLength) member of `normalizedAlgorithm` is one of 32, 64, 96, 104, 112, 120 or 128:
 : Let `tagLength` be equal to the
 [`tagLength`](#dfn-AesGcmParams-tagLength) member of
 `normalizedAlgorithm`

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. If the [`iv`](#dfn-AesGcmParams-iv) member of
 `normalizedAlgorithm` has a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 greater than 2\^64 - 1 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. If the
 [`additionalData`](#dfn-AesGcmParams-additionalData) member of
 `normalizedAlgorithm` is present and has a
 [length](https://infra.spec.whatwg.org/#byte-sequence-length)
 greater than 2\^64 - 1 bytes, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. If `ciphertext` has a [length in
 bits](#dfn-length-in-bits) less than
 `tagLength`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `tag` be the last `tagLength` bits of
 `ciphertext`.

6. Let `actualCiphertext` be the result of removing the last
 `tagLength` bits from `ciphertext`.

7. Let `additionalData` be the
 [`additionalData`](#dfn-AesGcmParams-additionalData) member of
 `normalizedAlgorithm` if present or an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 otherwise.

8. Perform the Authenticated Decryption Function described in Section
 7.2 of
 \[[NIST-SP800-38D](#bib-nist-sp800-38d "NIST Special Publication 800-38D: Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC")\] using AES as the block cipher, the
 [`iv`](#dfn-AesGcmParams-iv) member of
 `normalizedAlgorithm` as the `IV` input
 parameter, `additionalData` as the `A` input
 parameter, `tagLength` as the `t`
 pre-requisite, `actualCiphertext` as the input
 ciphertext, `C` and `tag` as the
 authentication tag, `T`.

 If the result of the algorithm is the indication of inauthenticity, \"`FAIL`\":
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror)

 Otherwise:
 : Let `plaintext` be the output `P` of the
 Authenticated Decryption Function.

9. Return `plaintext`.

::: header-wrapper
#### 29.4.3 Generate Key

1. If `usages` contains an entry which is not one of
 \"`encrypt`\", \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. If the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm` is not equal to one of 128, 192 or
 256, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Generate an AES key of length equal to the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

4. If the key generation step fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing the
 generated AES key.

6. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

7. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-GCM`\".

8. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 equal the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

9. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

10. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

11. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` to be `extractable`.

12. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` to be the [normalized
 value](#concept-normalized-usages) of `usages`.

13. Return `key`.

::: header-wrapper
#### 29.4.4 Import Key

1. If `usages` contains an entry which is not one of
 \"`encrypt`\", \"`decrypt`\", \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be `keyData`.

 2. If the [length in
 bits](#dfn-length-in-bits) of
 `data` is not 128, 192 or 256 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`oct`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If `jwk` does not meet the requirements of
 Section 6.4 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `data` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 obtained by decoding the
 [`k`](#dom-jsonwebkey-k) field of `jwk`.

 5.

 If the [length in bits](#dfn-length-in-bits) of `data` is 128:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A128GCM`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 192:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A192GCM`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 256:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A256GCM`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`enc`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing an
 AES key with value `data`.

4. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

5. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-GCM`\".

7. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 the length, in bits, of `data`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

9. Return `key`.

::: header-wrapper
#### 29.4.5 Export Key

1. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 containing the raw octets of the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`.

 2. Let `result` be `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`oct`\".

 3. Set the [`k`](#dom-jsonwebkey-k) attribute of `jwk`
 to be a string containing the raw octets of the key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`, encoded according to Section 6.4
 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4.

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 128:
 : Set the `alg` attribute of `jwk` to the
 string \"`A128GCM`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 192:
 : Set the `alg` attribute of `jwk` to the
 string \"`A192GCM`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 256:
 : Set the `alg` attribute of `jwk` to the
 string \"`A256GCM`\".

 5. Set the `key_ops` attribute of `jwk` to equal the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 6. Set the `ext` attribute of `jwk` to equal the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 7. Let `result` be `jwk`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Return `result`.

::: header-wrapper
#### 29.4.6 Get key length

1. If the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm` is not 128, 192 or 256,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Return the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm`.

::: header-wrapper
## 30. AES-KW

::: header-wrapper
### 30.1 Description

*This section is non-normative.*

The \"`AES-KW`\" algorithm identifier is used to perform key wrapping
using AES, as described in
\[[RFC3394](#bib-rfc3394 "Advanced Encryption Standard (AES) Key Wrap Algorithm")\].

::: header-wrapper
### 30.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`AES-KW`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 ---------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 wrapKey None [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 unwrapKey None [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 generateKey [`AesKeyGenParams`](#dfn-AesKeyGenParams) [`CryptoKey`](#dfn-CryptoKey)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object
 get key length [`AesDerivedKeyParams`](#dfn-AesDerivedKeyParams) Integer

::: header-wrapper
### 30.3 Operations

::: header-wrapper
#### 30.3.1 Wrap Key

1. If `plaintext` is not a multiple of 64 bits in length,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Let `ciphertext` be the result of performing the Key Wrap
 operation described in Section 2.2.1 of
 \[[RFC3394](#bib-rfc3394 "Advanced Encryption Standard (AES) Key Wrap Algorithm")\] with `plaintext` as the plaintext
 to be wrapped and using the default Initial Value defined in Section
 2.2.3.1 of the same document.

3. Return `ciphertext`.

::: header-wrapper
#### 30.3.2 Unwrap Key

1. Let `plaintext` be the result of performing the Key
 Unwrap operation described in Section 2.2.2 of
 \[[RFC3394](#bib-rfc3394 "Advanced Encryption Standard (AES) Key Wrap Algorithm")\] with `ciphertext` as the input
 ciphertext and using the default Initial Value defined in Section
 2.2.3.1 of the same document.

2. If the Key Unwrap operation returns an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Return `plaintext`.

::: header-wrapper
#### 30.3.3 Generate Key

1. If `usages` contains an entry which is not one of
 \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. If the
 [`length`](#dfn-AesKeyGenParams-length) property of
 `normalizedAlgorithm` is not equal to one of 128, 192 or
 256, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Generate an AES key of length equal to the
 [`length`](#dfn-AesKeyGenParams-length) member of
 `normalizedAlgorithm`.

4. If the key generation step fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing the
 generated AES key.

6. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

7. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-KW`\".

8. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 equal the
 [`length`](#dfn-AesKeyGenParams-length) property of
 `normalizedAlgorithm`.

9. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

10. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

11. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` to be `extractable`.

12. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` to be the [normalized
 value](#concept-normalized-usages) of `usages`.

13. Return `key`.

::: header-wrapper
#### 30.3.4 Import Key

1. If `usages` contains an entry which is not one of
 \"`wrapKey`\" or \"`unwrapKey`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be `keyData`.

 2. If the [length in
 bits](#dfn-length-in-bits) of
 `data` is not 128, 192 or 256 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`oct`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If `jwk` does not meet the requirements of
 Section 6.4 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `data` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 obtained by decoding the
 [`k`](#dom-jsonwebkey-k) field of `jwk`.

 5.

 If the [length in bits](#dfn-length-in-bits) of `data` is 128:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A128KW`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 192:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A192KW`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [length in bits](#dfn-length-in-bits) of `data` is 256:
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present, and is not \"`A256KW`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 6. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`enc`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 7. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing an AES key
 with value `data`.

4. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

5. Let `algorithm` be a new
 [`AesKeyAlgorithm`](#dfn-AesKeyAlgorithm).

6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`AES-KW`\".

7. Set the
 [`length`](#dfn-AesKeyAlgorithm-length) attribute of `algorithm` to
 the length, in bits, of `data`.

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

9. Return `key`.

::: header-wrapper
#### 30.3.5 Export Key

1. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 containing the raw octets of the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`.

 2. Let `result` be `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`oct`\".

 3. Set the [`k`](#dom-jsonwebkey-k) attribute of `jwk`
 to be a string containing the raw octets of the key
 represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal
 slot of `key`, encoded according to Section 6.4
 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4.

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 128:
 : Set the `alg` attribute of `jwk` to the
 string \"`A128KW`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 192:
 : Set the `alg` attribute of `jwk` to the
 string \"`A192KW`\".

 If the [`length`](#dfn-AesKeyAlgorithm-length) attribute of `key` is 256:
 : Set the `alg` attribute of `jwk` to the
 string \"`A256KW`\".

 5. Set the `key_ops` attribute of `jwk` to equal the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 6. Set the `ext` attribute of `jwk` to equal the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 7. Let `result` be `jwk`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

3. Return `result`.

::: header-wrapper
#### 30.3.6 Get key length

1. If the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm` is not 128, 192 or 256,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Return the
 [`length`](#dfn-AesDerivedKeyParams-length) member of
 `normalizedDerivedKeyAlgorithm`.

::: header-wrapper
## 31. HMAC

::: header-wrapper
### 31.1 Description

*This section is non-normative.*

The `HMAC` algorithm calculates and verifies hash-based message
authentication codes according to
\[[FIPS-198-1](#bib-fips-198-1 "The Keyed-Hash Message Authentication Code (HMAC)")\] using the SHA hash functions defined in this
specification.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional hash algorithms with HMAC. Such
specifications must define the digest operation for the additional hash
algorithms and [key import steps] and [key export
steps] for HMAC.

::: header-wrapper
### 31.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`HMAC`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 ---------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 sign None [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 verify None boolean
 generateKey [`HmacKeyGenParams`](#dfn-HmacKeyGenParams) [`CryptoKey`](#dfn-CryptoKey)
 importKey [`HmacImportParams`](#dfn-HmacImportParams) [`CryptoKey`](#dfn-CryptoKey)
 exportKey None object
 get key length [`HmacImportParams`](#dfn-HmacImportParams) Integer

::: header-wrapper
### 31.3 [`HmacImportParams`] dictionary

```
WebIDLdictionary HmacImportParams : Algorithm {
 required HashAlgorithmIdentifier hash;
 [EnforceRange] unsigned long length;
};
```

The [`hash`]
member represents the inner hash function to use.

The [`length`] member represent the length (in bits) of the
key.

::: header-wrapper
### 31.4 [`HmacKeyAlgorithm`] dictionary

```
WebIDLdictionary HmacKeyAlgorithm : KeyAlgorithm {
 required KeyAlgorithm hash;
 required [EnforceRange] unsigned long length;
};
```

The [`hash`] member
represents the inner hash function to use.

The [`length`] member represent the length (in bits) of the
key.

::: header-wrapper
### 31.5 [`HmacKeyGenParams`] dictionary

```
WebIDLdictionary HmacKeyGenParams : Algorithm {
 required HashAlgorithmIdentifier hash;
 [EnforceRange] unsigned long length;
};
```

The [`hash`]
member represents the inner hash function to use.

The [`length`] member represent the length (in bits) of the key
to generate. If unspecified, the recommended length will be used, which
is the size of the associated hash function\'s block size.

::: header-wrapper
### 31.6 Operations

::: header-wrapper
#### 31.6.1 Sign

1. Let `mac` be the result of performing the MAC Generation
 operation described in Section 4 of
 \[[FIPS-198-1](#bib-fips-198-1 "The Keyed-Hash Message Authentication Code (HMAC)")\] using the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key`, the hash function identified by the
 [`hash`](#dfn-HmacKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` and `message` as the input data
 `text`.

2. Return `mac`.

::: header-wrapper
#### 31.6.2 Verify

1. Let `mac` be the result of performing the MAC Generation
 operation described in Section 4 of
 \[[FIPS-198-1](#bib-fips-198-1 "The Keyed-Hash Message Authentication Code (HMAC)")\] using the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key`, the hash function identified by the
 [`hash`](#dfn-HmacKeyAlgorithm-hash) attribute of the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` and `message` as the input data
 `text`.

2. Return true if `mac` is equal to `signature`
 and false otherwise. This comparison must be performed in
 constant-time.

::: header-wrapper
#### 31.6.3 Generate Key

1. If `usages` contains an entry which is not \"`sign`\" or
 \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2.

 If the [`length`](#dfn-HmacKeyGenParams-length) member of `normalizedAlgorithm` is not present:
 : Let `length` be the block size in bits of the hash
 function identified by the
 [`hash`](#dfn-HmacKeyGenParams-hash) member of
 `normalizedAlgorithm`.

 Otherwise, if the [`length`](#dfn-HmacKeyGenParams-length) member of `normalizedAlgorithm` is non-zero:
 : Let `length` be equal to the
 [`length`](#dfn-HmacKeyGenParams-length) member of
 `normalizedAlgorithm`.

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Generate a key of length `length` bits.

4. If the key generation step fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

5. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing the
 generated key.

6. Let `algorithm` be a new
 [`HmacKeyAlgorithm`](#dfn-HmacKeyAlgorithm).

7. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`HMAC`\".

8. Set the
 [`length`](#dfn-HmacKeyAlgorithm-length) attribute of `algorithm` to
 `length`.

9. Let `hash` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm).

10. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `hash` to
 equal the
 [`name`](#dom-algorithm-name) member of the
 [`hash`](#dfn-HmacKeyGenParams-hash) member of
 `normalizedAlgorithm`.

11. Set the
 [`hash`](#dfn-HmacKeyAlgorithm-hash) attribute of `algorithm` to
 `hash`.

12. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

13. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

14. Set the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable) internal
 slot of `key` to be `extractable`.

15. Set the
 [`[[usages]]`](#dfn-CryptoKey-slot-usages) internal slot of
 `key` to be the [normalized
 value](#concept-normalized-usages) of `usages`.

16. Return `key`.

::: header-wrapper
#### 31.6.4 Import Key

1. If the
 [`length`](#dfn-HmacImportParams-length) member of
 `normalizedAlgorithm` is present and is zero, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

2. Let `keyData` be the key data to be imported.

3. If `usages` contains an entry which is not \"`sign`\" or
 \"`verify`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

4. Let `hash` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm).

5.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `data` be `keyData`.

 2. Set `hash` to equal the
 [`hash`](#dfn-HmacImportParams-hash) member of
 `normalizedAlgorithm`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1.

 If `keyData` is a [`JsonWebKey`](#dfn-JsonWebKey) dictionary:

 : Let `jwk` equal `keyData`.

 Otherwise:

 : [Throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. If the
 [`kty`](#dom-jsonwebkey-kty) field of `jwk` is
 not \"`oct`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. If `jwk` does not meet the requirements of
 Section 6.4 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\], then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. Let `data` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence)
 obtained by decoding the
 [`k`](#dom-jsonwebkey-k) field of `jwk`.

 5. Set the `hash` to equal the
 [`hash`](#dfn-HmacImportParams-hash) member of
 `normalizedAlgorithm`.

 6.

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-1`\":
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present and is not \"`HS1`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-256`\":
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present and is not \"`HS256`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-384`\":
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present and is not \"`HS384`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-512`\":
 : If the
 [`alg`](#dom-jsonwebkey-alg) field of `jwk`
 is present and is not \"`HS512`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise, if the [`name`](#dom-keyalgorithm-name) attribute of `hash` is defined in [another applicable specification](#dfn-applicable-specification):
 : Perform any [key import
 steps](#dfn-hmac-extended-import-steps) defined by [other applicable
 specifications](#dfn-applicable-specification),
 passing `format`, `jwk` and
 `hash` and obtaining `hash`.

 7. If `usages` is non-empty and the
 [`use`](#dom-jsonwebkey-use) field of `jwk` is
 present and is not \"`sig`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 8. If the
 [`key_ops`](#dom-jsonwebkey-key_ops) field of `jwk` is
 present, and is invalid according to the requirements of
 JSON Web Key \[[JWK](#bib-jwk "JSON Web Key (JWK)")\] or does not contain all of the
 specified `usages` values, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 9. If the
 [`ext`](#dom-jsonwebkey-ext) field of `jwk` is
 present and has the value false and `extractable`
 is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

6. Let `length` be the [length in
 bits](#dfn-length-in-bits) of `data`.

7. If `length` is zero then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

8.

 If the [`length`](#dfn-HmacImportParams-length) member of `normalizedAlgorithm` is present:

 :

 If the [`length`](#dfn-HmacImportParams-length) member of `normalizedAlgorithm` is greater than `length`:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 If the [`length`](#dfn-HmacImportParams-length) member of `normalizedAlgorithm`, is less than or equal to `length` minus eight:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 Otherwise:
 : Set `length` equal to the
 [`length`](#dfn-HmacImportParams-length) member of
 `normalizedAlgorithm`.

9. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) object representing an
 HMAC key with the first `length` bits of
 `data`.

10. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

11. Let `algorithm` be a new
 [`HmacKeyAlgorithm`](#dfn-HmacKeyAlgorithm).

12. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`HMAC`\".

13. Set the
 [`length`](#dfn-HmacKeyAlgorithm-length) attribute of `algorithm` to
 `length`.

14. Set the
 [`hash`](#dfn-HmacKeyAlgorithm-hash) attribute of `algorithm` to
 `hash`.

15. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

16. Return `key`.

::: header-wrapper
#### 31.6.5 Export Key

1. If the underlying cryptographic key material represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` cannot be accessed, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Let `bits` be the raw bits of the key represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key`.

3. Let `data` be a [byte sequence
 containing](#dfn-byte-sequence-containing) `bits`.

4.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. Let `result` be `data`.

 If `format` is \"[`jwk`](#dom-keyformat-jwk)\":

 : 1. Let `jwk` be a new
 [`JsonWebKey`](#dfn-JsonWebKey) dictionary.

 2. Set the `kty` attribute of `jwk` to the string
 \"`oct`\".

 3. Set the
 [`k`](#dom-jsonwebkey-k) attribute of `jwk`
 to be a string containing `data`, encoded
 according to Section 6.4 of JSON Web Algorithms
 \[[JWA](#bib-jwa "JSON Web Algorithms (JWA)")\].

 4. Let `algorithm` be the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key`.

 5. Let `hash` be the
 [`hash`](#dfn-HmacKeyAlgorithm-hash) attribute of
 `algorithm`.

 6.

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-1`\":
 : Set the `alg` attribute of `jwk` to the
 string \"`HS1`\".

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-256`\":
 : Set the `alg` attribute of `jwk` to the
 string \"`HS256`\".

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-384`\":
 : Set the `alg` attribute of `jwk` to the
 string \"`HS384`\".

 If the [`name`](#dom-keyalgorithm-name) attribute of `hash` is \"`SHA-512`\":
 : Set the `alg` attribute of `jwk` to the
 string \"`HS512`\".

 Otherwise, the [`name`](#dom-keyalgorithm-name) attribute of `hash` is defined in [another applicable specification](#dfn-applicable-specification):

 : 1. Perform any [key export
 steps](#dfn-hmac-extended-export-steps) defined by [other
 applicable
 specifications](#dfn-applicable-specification),
 passing `format` and `key` and
 obtaining `alg`.

 2. Set the `alg` attribute of `jwk` to
 `alg`.

 7. Set the `key_ops` attribute of `jwk` to equal the
 [`usages`](#dom-cryptokey-usages) attribute of `key`.

 8. Set the `ext` attribute of `jwk` to equal the
 [`[[extractable]]`](#dfn-CryptoKey-slot-extractable)
 internal slot of `key`.

 9. Let `result` be `jwk`.

 Otherwise:

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

5. Return `result`.

::: header-wrapper
#### 31.6.6 Get key length

1.

 If the [`length`](#dfn-HmacImportParams-length) member of `normalizedDerivedKeyAlgorithm` is not present:

 : Let `length` be the block size in bits of the hash
 function identified by the
 [`hash`](#dfn-HmacImportParams-hash) member of
 `normalizedDerivedKeyAlgorithm`.

 Otherwise, if the [`length`](#dfn-HmacImportParams-length) member of `normalizedDerivedKeyAlgorithm` is non-zero:
 : Let `length` be equal to the
 [`length`](#dfn-HmacImportParams-length) member of
 `normalizedDerivedKeyAlgorithm`.

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return `length`.

::: header-wrapper
## 32. SHA

::: header-wrapper
### 32.1 Description

*This section is non-normative.*

This describes the SHA-1 and SHA-2 families, as specified by
\[[FIPS-180-4](#bib-fips-180-4 "FIPS PUB 180-4: Secure Hash Standard (SHS)")\].

::: header-wrapper
### 32.2 Registration

The [recognized algorithm
names](#recognized-algorithm-name)
are \"`SHA-1`\", \"`SHA-256`\",
\"`SHA-384`\", and \"`SHA-512`\" for the
respective SHA algorithms.

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 ---------------------------------------------------------------------- --------------------------------------------------------------------------------- --------------------------------------------------------------------------------
 digest None [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)

::: header-wrapper
### 32.3 Operations

::: header-wrapper
#### 32.3.1 Digest

1.

 If the [`name`](#dom-algorithm-name) member of `normalizedAlgorithm` is a cases-sensitive string match for \"`SHA-1`\":
 : Let `result` be the result of performing the SHA-1
 hash function defined in Section 6.1 of
 \[[FIPS-180-4](#bib-fips-180-4 "FIPS PUB 180-4: Secure Hash Standard (SHS)")\] using `message` as the input
 message, `M`.

 If the [`name`](#dom-algorithm-name) member of `normalizedAlgorithm` is a cases-sensitive string match for \"`SHA-256`\":
 : Let `result` be the result of performing the SHA-256
 hash function defined in Section 6.2 of
 \[[FIPS-180-4](#bib-fips-180-4 "FIPS PUB 180-4: Secure Hash Standard (SHS)")\] using `message` as the input
 message, `M`.

 If the [`name`](#dom-algorithm-name) member of `normalizedAlgorithm` is a cases-sensitive string match for \"`SHA-384`\":
 : Let `result` be the result of performing the SHA-384
 hash function defined in Section 6.5 of
 \[[FIPS-180-4](#bib-fips-180-4 "FIPS PUB 180-4: Secure Hash Standard (SHS)")\] using `message` as the input
 message, `M`.

 If the [`name`](#dom-algorithm-name) member of `normalizedAlgorithm` is a cases-sensitive string match for \"`SHA-512`\":
 : Let `result` be the result of performing the SHA-512
 hash function defined in Section 6.4 of
 \[[FIPS-180-4](#bib-fips-180-4 "FIPS PUB 180-4: Secure Hash Standard (SHS)")\] using `message` as the input
 message, `M`.

2. If performing the operation results in an error, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. Return `result`.

::: header-wrapper
## 33. HKDF

::: header-wrapper
### 33.1 Description

*This section is non-normative.*

The \"`HKDF`\" algorithm identifier is used to perform key derivation
using the extraction-then-expansion approach described in
\[[RFC5869](#bib-rfc5869 "HMAC-based Extract-and-Expand Key Derivation Function (HKDF)")\] and using the SHA hash functions defined in this
specification.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional hash algorithms with HKDF. Such
specifications must define the digest operation for the additional hash
algorithms.

::: header-wrapper
### 33.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`HKDF`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 ---------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 deriveBits [`HkdfParams`](#dfn-HkdfParams) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 get key length None null

::: header-wrapper
### 33.3 [`HkdfParams`] dictionary

```
WebIDLdictionary HkdfParams : Algorithm {
 required HashAlgorithmIdentifier hash;
 required BufferSource salt;
 required BufferSource info;
};
```

The [`hash`]
member represents the algorithm to use with HMAC (e.g.: SHA-256).

The [`salt`] member
represents the salt used in the extract step.

The [`info`] member
represents application specific context for the derived keying material.

::: header-wrapper
### 33.4 Operations

::: header-wrapper
#### 33.4.1 Derive Bits

1. If `length` is null or is not a multiple of 8, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. Let `hashLength` be the length in bits of the output of
 the hash function identified by the
 [`hash`](#dfn-HkdfParams-hash) member of
 `normalizedAlgorithm`.

3. If `length` is greater than 255 \*
 `hashLength`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

4. Let `keyDerivationKey` be the secret represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key`.

5. Let `result` be the result of performing the HKDF extract
 and then the HKDF expand step described in Section 2 of
 \[[RFC5869](#bib-rfc5869 "HMAC-based Extract-and-Expand Key Derivation Function (HKDF)")\] using:

 - the [`hash`](#dfn-HkdfParams-hash) member of
 `normalizedAlgorithm` as `Hash`,

 - `keyDerivationKey` as the input keying material,
 `IKM`,

 - the [`salt`](#dfn-HkdfParams-salt) member of
 `normalizedAlgorithm` as `salt`,

 - the [`info`](#dfn-HkdfParams-info) member of
 `normalizedAlgorithm` as `info`,

 - `length` divided by 8 as the value of `L`,

6. If the key derivation operation fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

7. Return `result`.

::: header-wrapper
#### 33.4.2 Import key

1. Let `keyData` be the key data to be imported.

2.

 If `format` is \"[`raw`](#dom-keyformat-raw)\":

 : 1. If `usages` contains a value that is not
 \"`deriveKey`\" or \"`deriveBits`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 2. If `extractable` is not `false`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

 3. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing
 the key data provided in `keyData`.

 4. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal
 slot of `key` to
 \"[`secret`](#dom-keytype-secret)\".

 5. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

 6. Set the
 [`name`](#dom-keyalgorithm-name) attribute of
 `algorithm` to \"`HKDF`\".

 7. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm)
 internal slot of `key` to `algorithm`.

 8. Return `key`.

 Otherwise:
 : [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

::: header-wrapper
#### 33.4.3 Get key length

1. Return null.

::: header-wrapper
## 34. PBKDF2

::: header-wrapper
### 34.1 Description

*This section is non-normative.*

The \"`PBKDF2`\" algorithm identifier is used to perform key derivation
using the PKCS#5 password-based key derivation function version 2, as
defined in
\[[RFC8018](#bib-rfc8018 "PKCS #5: Password-Based Cryptography Specification Version 2.1")\] using HMAC as the pseudo-random function, using
the SHA hash functions defined in this specification.

[Other
specifications](#dfn-applicable-specification)
may specify the use of additional hash algorithms with PBKDF2. Such
specifications must define the digest operation for the additional hash
algorithms.

::: header-wrapper
### 34.2 Registration

The [recognized algorithm
name](#recognized-algorithm-name) for this algorithm is
\"`PBKDF2`\".

 [Operation](#supported-operations) [Parameters](#algorithm-specific-params) [Result](#algorithm-result)
 ---------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
 deriveBits [`Pbkdf2Params`](#dfn-Pbkdf2Params) [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)
 importKey None [`CryptoKey`](#dfn-CryptoKey)
 get key length None null

::: header-wrapper
### 34.3 [`Pbkdf2Params`] dictionary

```
WebIDLdictionary Pbkdf2Params : Algorithm {
 required BufferSource salt;
 required [EnforceRange] unsigned long iterations;
 required HashAlgorithmIdentifier hash;
};
```

The [`Pbkdf2Params`](#dfn-Pbkdf2Params) dictionary has a
[`salt`] member, a
[`iterations`] member,
and a [`hash`]
member.

::: header-wrapper
### 34.4 Operations

::: header-wrapper
#### 34.4.1 Derive Bits

1. If `length` is null or is not a multiple of 8, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

2. If the
 [`iterations`](#dfn-Pbkdf2Params-iterations) member of
 `normalizedAlgorithm` is zero, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

3. If `length` is zero, return an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence).

4. Let `prf` be the MAC Generation function described in
 Section 4 of
 \[[FIPS-198-1](#bib-fips-198-1 "The Keyed-Hash Message Authentication Code (HMAC)")\] using the hash function described by the
 [`hash`](#dfn-Pbkdf2Params-hash) member of
 `normalizedAlgorithm`.

5. Let `result` be the result of performing the PBKDF2
 operation defined in Section 5.2 of
 \[[RFC8018](#bib-rfc8018 "PKCS #5: Password-Based Cryptography Specification Version 2.1")\] using `prf` as the pseudo-random
 function, `PRF`, the password represented by the
 [`[[handle]]`](#dfn-CryptoKey-slot-handle) internal slot of
 `key` as the password, `P`, the
 [`salt`](#dfn-Pbkdf2Params-salt) attribute of
 `normalizedAlgorithm` as the salt, `S`, the
 value of the
 [`iterations`](#dfn-Pbkdf2Params-iterations) attribute of
 `normalizedAlgorithm` as the iteration count,
 `c`, and `length` divided by 8 as the intended
 key length, `dkLen`.

6. If the key derivation operation fails, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

7. Return `result`.

::: header-wrapper
#### 34.4.2 Import key

1. If `format` is not
 \"[`raw`](#dom-keyformat-raw)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)

2. If `usages` contains a value that is not \"`deriveKey`\"
 or \"`deriveBits`\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

3. If `extractable` is not `false`, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

4. Let `key` be a new
 [`CryptoKey`](#dfn-CryptoKey) representing
 `keyData`.

5. Set the
 [`[[type]]`](#dfn-CryptoKey-slot-type) internal slot of
 `key` to
 \"[`secret`](#dom-keytype-secret)\".

6. Let `algorithm` be a new
 [`KeyAlgorithm`](#dfn-KeyAlgorithm) object.

7. Set the
 [`name`](#dom-keyalgorithm-name) attribute of `algorithm` to
 \"`PBKDF2`\".

8. Set the
 [`[[algorithm]]`](#dfn-CryptoKey-slot-algorithm) internal slot
 of `key` to `algorithm`.

9. Return `key`.

::: header-wrapper
#### 34.4.3 Get key length

1. Return null.

::: header-wrapper
## 35. JavaScript Example Code

::: header-wrapper
### 35.1 Generate two key pairs, derive a shared key, encrypt some data

This example generates two X25519 key pairs, one for Alice and one for
Bob, performs a key agreement between them, derives a 256-bit AES-GCM
key from the result using HKDF with SHA-256, and encrypts and decrypts
some data with it.

[Example 1](#example-x25519-key-agreement)[: X25519 key
agreement]

``` {aria-busy="false"}
// Generate a key pair for Alice.
const alice_x25519_key = await crypto.subtle.generateKey('X25519', false /* extractable */, ['deriveKey']);
const alice_private_key = alice_x25519_key.privateKey;

// Normally, the public key would be sent by Bob to Alice in advance over some authenticated channel.
// In this example, we'll generate another key pair and use its public key instead.
const bob_x25519_key = await crypto.subtle.generateKey('X25519', false /* extractable */, ['deriveKey']);
const bob_public_key = bob_x25519_key.publicKey;

// Perform the key agreement.
const alice_x25519_params = { name: 'X25519', public: bob_public_key };
const alice_shared_key = await crypto.subtle.deriveKey(alice_x25519_params, alice_private_key, 'HKDF', false /* extractable */, ['deriveKey']);

// Derive a symmetric key from the result.
const salt = crypto.getRandomValues(new Uint8Array(32));
const info = new TextEncoder().encode('X25519 key agreement for an AES-GCM-256 key');
const hkdf_params = { name: 'HKDF', hash: 'SHA-256', salt, info };
const gcm_params = { name: 'AES-GCM', length: 256 };
const alice_symmetric_key = await crypto.subtle.deriveKey(hkdf_params, alice_shared_key, gcm_params, false /* extractable */, ['encrypt', 'decrypt']);

// Encrypt some data with the symmetric key, and send it to Bob. The IV must be passed along as well.
const iv = crypto.getRandomValues(new Uint8Array(12));
const message = new TextEncoder().encode('Hi Bob!');
const encrypted = await crypto.subtle.encrypt({ ...gcm_params, iv }, alice_symmetric_key, message);

// On Bob's side, Alice's public key and Bob's private key are used, instead.
// To get the same result, Alice and Bob must agree on using the same salt and info.
const alice_public_key = alice_x25519_key.publicKey;
const bob_private_key = bob_x25519_key.privateKey;
const bob_x25519_params = { name: 'X25519', public: alice_public_key };
const bob_shared_key = await crypto.subtle.deriveKey(bob_x25519_params, bob_private_key, 'HKDF', false /* extractable */, ['deriveKey']);
const bob_symmetric_key = await crypto.subtle.deriveKey(hkdf_params, bob_shared_key, gcm_params, false /* extractable */, ['encrypt', 'decrypt']);

// On Bob's side, the data can be decrypted.
const decrypted = await crypto.subtle.decrypt({ ...gcm_params, iv }, bob_symmetric_key, encrypted);
const decrypted_message = new TextDecoder().decode(decrypted);
```

::: header-wrapper
### 35.2 Generate a signing key pair, sign some data

[Example 2](#example-ed25519-signing)[: Ed25519
signing]

``` {aria-busy="false"}
const data = new TextEncoder().encode('Hello, world!');
const key = await crypto.subtle.generateKey('Ed25519', false, ['sign']);
const signature = await crypto.subtle.sign('Ed25519', key.privateKey, data);
```

::: header-wrapper
### 35.3 Generate a symmetric key, encrypt some data

[Example 3](#example-aes-gcm-encryption)[: AES-GCM
encryption]

``` {aria-busy="false"}
const data = new TextEncoder().encode('Hello, world!');
const aesAlgorithmKeyGen = {
 name: 'AES-GCM',
 // AesKeyGenParams
 length: 256
};
const aesAlgorithmEncrypt = {
 name: 'AES-GCM',
 // AesGcmParams
 iv: crypto.getRandomValues(new Uint8Array(16))
};
const key = await crypto.subtle.generateKey(aesAlgorithmKeyGen, false, ['encrypt']);
const encrypted = await crypto.subtle.encrypt(aesAlgorithmEncrypt, key, data);
```

::: header-wrapper
### 35.4 Generate unique name for download

[Example 4](#example-random-uuid-generation)[: Random UUID
generation]

``` {aria-busy="false"}
const filename = `${crypto.randomUUID()}.txt`;
```

::: header-wrapper
## 36. IANA Considerations

::: header-wrapper
### 36.1 JSON Web Signature and Encryption Algorithms Registration

This section registers the following algorithm identifiers in the IANA
JSON Web Signature and Encryption Algorithms Registry for use with JSON
Web Key. Note that the \'Implementation Requirements\' field in the
template refers to use with JSON Web Signature and JSON Web Encryption
specifically, in which case use of unauthenticated encryption is
prohibited.

- Algorithm Name: \"RS1\"
- Algorithm Description: RSASSA-PKCS1-v1_5 with SHA-1
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"RSA-OAEP-384\"
- Algorithm Description: RSA-OAEP using SHA-384 and MGF1 with SHA-384
- Algorithm Usage Location(s): \"alg\"
- JOSE Implementation Requirements: Optional
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"RSA-OAEP-512\"
- Algorithm Description: RSA-OAEP using SHA-512 and MGF1 with SHA-512
- Algorithm Usage Location(s): \"alg\"
- JOSE Implementation Requirements: Optional
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"A128CBC\"
- Algorithm Description: AES CBC using 128 bit key
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"A192CBC\"
- Algorithm Description: AES CBC using 192 bit key
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"A256CBC\"
- Algorithm Description: AES CBC using 256 bit key
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"A128CTR\"
- Algorithm Description: AES CTR using 128 bit key
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"A192CTR\"
- Algorithm Description: AES CTR using 192 bit key
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"A256CTR\"
- Algorithm Description: AES CTR using 256 bit key
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

<!-- -->

- Algorithm Name: \"HS1\"
- Algorithm Description: HMAC using SHA-1
- Algorithm Usage Location(s): \"JWK\"
- JOSE Implementation Requirements: Prohibited
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

::: header-wrapper
### 36.2 JSON Web Key Parameters Registration

- Parameter Name: \"ext\"
- Parameter Description: Extractable
- Used with \"kty\" Value(s): \*
- Parameter Information Class: Public
- Change Controller: [W3C] Web
 Cryptography Working Group
- Specification Document(s): \[\[ This Document \]\]

::: header-wrapper
## 37. Acknowledgments

Thanks are due especially to Ryan Sleevi, the original author and
editor, and Mark Watson, the former editor of this document.

Thanks to Adam Barth, Alex Russell, Ali Asad, Arun Ranganathan, Brian
Smith, Brian Warner, Channy Yun, Charles Engelke, Eric Roman, Glenn
Adams, Jim Schaad, Kai Engert, Michael Hutchinson, Michael B. Jones,
Nick Van den Bleeken, Richard Barnes, Ryan Hurst, Tim Taubert, Vijay
Bharadwaj, Virginie Galindo, and Wan-Teh Chang for their technical
feedback and assistance.

Thanks to the [W3C] Web
Cryptography WG, and to participants on the public-webcrypto@w3.org
mailing list.

The [W3C] would like to thank
the [Northrop Grumman Cybersecurity Research
Consortium](http://www.northropgrumman.com/Capabilities/CybersecurityResearchConsortium/)
for supporting [W3C]/MIT.

The
[`getRandomValues`](#dfn-Crypto-method-getRandomValues) method in the
[`Crypto`](#dfn-Crypto) interface was originally proposed by Adam
Barth to the [WHATWG](https://wiki.whatwg.org/wiki/Crypto).

Ed25519 and X25519 were originally specified in the [Secure Curves in
the Web Cryptography
API](https://wicg.github.io/webcrypto-secure-curves/) specification at
the WICG.

Thanks to Ben Wiederhake, Divy Srivastava, Dominique Hazael-Massieux,
Filip Skokan, Kagami Sascha Rosylight, Luca Casonato, Martin Thomson,
Philippe Le Hégaret, Tobias Nießen, and Anna Weine for their
contributions and improvements made to this specification and the
[Secure Curves in the Web Cryptography
API](https://github.com/WICG/webcrypto-secure-curves/) specification.

::: header-wrapper
## A. Mapping between JSON Web Key / JSON Web Algorithm

*This section is non-normative.*

Refer to algorithm-specific sections for the normative requirements of
importing and exporting JWK.

::: header-wrapper
### A.1 Algorithm mappings

+-----------------------------------+-----------------------------------+
| JSON Web Key | AlgorithmIdentifier |
+===================================+===================================+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSASSA-PKCS1-v1_5", |
| alg: "RS1" } | hash: { name: "SHA-1" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSASSA-PKCS1-v1_5", |
| alg: "RS256" } | hash: { name: "SHA-256" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSASSA-PKCS1-v1_5", |
| alg: "RS384" } | hash: { name: "SHA-384" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSASSA-PKCS1-v1_5", |
| alg: "RS512" } | hash: { name: "SHA-512" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-PSS", |
| alg: "PS256" } | hash: { name: "SHA-256" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-PSS", |
| alg: "PS384" } | hash: { name: "SHA-384" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-PSS", |
| alg: "PS512" } | hash: { name: "SHA-512" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-OAEP", |
| alg: "RSA-OAEP" } | hash: { name: "SHA-1" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-OAEP", |
| alg: "RSA-OAEP-256" } | hash: { name: "SHA-256" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-OAEP", |
| alg: "RSA-OAEP-384" } | hash: { name: "SHA-384" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "RSA", | { name: "RSA-OAEP", |
| alg: "RSA-OAEP-512" } | hash: { name: "SHA-512" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "EC", | { name: "ECDSA", |
| alg: "ES256" } | namedCurve: "P-256", |
| ``` | hash: { name: "SHA-256" } |
| | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "EC", | { name: "ECDSA", |
| alg: "ES384" } | namedCurve: "P-384", |
| ``` | hash: { name: "SHA-384" } |
| | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "EC", | { name: "ECDSA", |
| alg: "ES512" } | namedCurve: "P-521", |
| ``` | hash: { name: "SHA-512" } |
| | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "OKP", | { name: "Ed25519" } |
| crv: "Ed25519", | ``` |
| alg: "Ed25519" } | |
| ``` | |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "OKP", | { name: "X25519" } |
| crv: "X25519" } | ``` |
| ``` | |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-CTR", |
| alg: "A128CTR" } | length: 128 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-CTR", |
| alg: "A192CTR" } | length: 192 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-CTR", |
| alg: "A256CTR" } | length: 256 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-CBC", |
| alg: "A128CBC" } | length: 128 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-CBC", |
| alg: "A192CBC" } | length: 192 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-CBC", |
| alg: "A256CBC" } | length: 256 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-KW", |
| alg: "A128KW" } | length: 128 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-KW", |
| alg: "A192KW" } | length: 192 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-KW", |
| alg: "A256KW" } | length: 256 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-GCM", |
| alg: "A128GCM" } | length: 128 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-GCM", |
| alg: "A192GCM" } | length: 192 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-GCM", |
| alg: "A256GCM" } | length: 256 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-GCM", |
| alg: "A128GCMKW" } | length: 128 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-GCM", |
| alg: "A192GCMKW" } | length: 192 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "AES-GCM", |
| alg: "A256GCMKW" } | length: 256 } |
| ``` | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "HMAC", |
| alg: "HS1" } | hash: { name: "SHA-1" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "HMAC", |
| alg: "HS256" } | hash: { name: "SHA-256" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "HMAC", |
| alg: "HS384" } | hash: { name: "SHA-384" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+
| ``` {aria-busy="false"} | ``` {aria-busy="false"} |
| { kty: "oct", | { name: "HMAC", |
| alg: "HS512" } | hash: { name: "SHA-512" } |
| ``` | } |
| | ``` |
+-----------------------------------+-----------------------------------+

::: header-wrapper
## B. Mapping between Algorithm and SubjectPublicKeyInfo

*This section is non-normative.*

Refer to algorithm-specific sections for the normative requirements of
importing and exporting SPKI.

 Algorithm OID subjectPublicKey ASN.1 structure AlgorithmIdentifier Reference
 -------------------------------------- ---------------------------------- ----------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 rsaEncryption (1.2.840.113549.1.1.1) RSAPublicKey \"`RSASSA-PKCS1-v1_5`\", \"`RSA-PSS`\", or \"`RSA-OAEP`\" \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]
 id-ecPublicKey (1.2.840.10045.2.1) ECPoint \"`ECDH`\" or \"`ECDSA`\" \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]
 id-Ed25519 (1.3.101.112) BIT STRING \"`Ed25519`\" \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\]
 id-X25519 (1.3.101.110) BIT STRING \"`X25519`\" \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\]

The object identifiers used by this specification do not include
information about the specific algorithm and hash that the key is
intended to be used with. If this is required, it\'s recommended that
the \"[`jwk`](#dom-keyformat-jwk)\" key format is used instead.

::: header-wrapper
## C. Mapping between Algorithm and PKCS#8 PrivateKeyInfo

*This section is non-normative.*

Refer to algorithm-specific sections for the normative requirements of
importing and exporting PKCS#8 PrivateKeyInfo.

 privateKeyAlgorithm privateKey format AlgorithmIdentifier Reference
 -------------------------------------- ------------------- ----------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 rsaEncryption (1.2.840.113549.1.1.1) RSAPrivateKey \"`RSASSA-PKCS1-v1_5`\", \"`RSA-PSS`\", or \"`RSA-OAEP`\" \[[RFC3447](#bib-rfc3447 "Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.1")\]
 id-ecPublicKey (1.2.840.10045.2.1) ECPrivateKey \"`ECDH`\" or \"`ECDSA`\" \[[RFC5480](#bib-rfc5480 "Elliptic Curve Cryptography Subject Public Key Information")\]
 id-Ed25519 (1.3.101.112) CurvePrivateKey \"`Ed25519`\" \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\]
 id-X25519 (1.3.101.110) CurvePrivateKey \"`X25519`\" \[[RFC8410](#bib-rfc8410 "Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use in the Internet X.509 Public Key Infrastructure")\]

[Permalink](#dfn-conforming-implementation)

**Referenced in:**

- [§ 3.
 Conformance](#ref-for-dfn-conforming-implementation-1 "§ 3. Conformance")
- [§ 8.
 Dependencies](#ref-for-dfn-conforming-implementation-2 "§ 8. Dependencies")
 [(2)](#ref-for-dfn-conforming-implementation-3 "Reference 2")
 [(3)](#ref-for-dfn-conforming-implementation-4 "Reference 3")

[Permalink](#dfn-applicable-specification)

**Referenced in:**

- [§ 20.1
 Description](#ref-for-dfn-applicable-specification-1 "§ 20.1 Description")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-applicable-specification-2 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dfn-applicable-specification-3 "Reference 2")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-applicable-specification-4 "§ 20.9.5 Export Key")
 [(2)](#ref-for-dfn-applicable-specification-5 "Reference 2")
- [§ 21.1
 Description](#ref-for-dfn-applicable-specification-6 "§ 21.1 Description")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-applicable-specification-7 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dfn-applicable-specification-8 "Reference 2")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-applicable-specification-9 "§ 21.4.5 Export Key")
- [§ 22.1
 Description](#ref-for-dfn-applicable-specification-10 "§ 22.1 Description")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-applicable-specification-11 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dfn-applicable-specification-12 "Reference 2")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-applicable-specification-13 "§ 22.4.5 Export Key")
- [§ 23.1
 Description](#ref-for-dfn-applicable-specification-14 "§ 23.1 Description")
- [§ 23.4 EcKeyGenParams
 dictionary](#ref-for-dfn-applicable-specification-15 "§ 23.4 EcKeyGenParams dictionary")
- [§ 23.7.1
 Sign](#ref-for-dfn-applicable-specification-16 "§ 23.7.1 Sign")
- [§ 23.7.2
 Verify](#ref-for-dfn-applicable-specification-17 "§ 23.7.2 Verify")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-applicable-specification-18 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-applicable-specification-19 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-applicable-specification-20 "Reference 2")
 [(3)](#ref-for-dfn-applicable-specification-21 "Reference 3")
 [(4)](#ref-for-dfn-applicable-specification-22 "Reference 4")
 [(5)](#ref-for-dfn-applicable-specification-23 "Reference 5")
 [(6)](#ref-for-dfn-applicable-specification-24 "Reference 6")
 [(7)](#ref-for-dfn-applicable-specification-25 "Reference 7")
 [(8)](#ref-for-dfn-applicable-specification-26 "Reference 8")
 [(9)](#ref-for-dfn-applicable-specification-27 "Reference 9")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-applicable-specification-28 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dfn-applicable-specification-29 "Reference 2")
 [(3)](#ref-for-dfn-applicable-specification-30 "Reference 3")
 [(4)](#ref-for-dfn-applicable-specification-31 "Reference 4")
- [§ 24.1
 Description](#ref-for-dfn-applicable-specification-32 "§ 24.1 Description")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-applicable-specification-33 "§ 24.4.1 Generate Key")
- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-applicable-specification-34 "§ 24.4.2 Derive Bits")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-applicable-specification-35 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-applicable-specification-36 "Reference 2")
 [(3)](#ref-for-dfn-applicable-specification-37 "Reference 3")
 [(4)](#ref-for-dfn-applicable-specification-38 "Reference 4")
 [(5)](#ref-for-dfn-applicable-specification-39 "Reference 5")
 [(6)](#ref-for-dfn-applicable-specification-40 "Reference 6")
 [(7)](#ref-for-dfn-applicable-specification-41 "Reference 7")
 [(8)](#ref-for-dfn-applicable-specification-42 "Reference 8")
 [(9)](#ref-for-dfn-applicable-specification-43 "Reference 9")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-applicable-specification-44 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dfn-applicable-specification-45 "Reference 2")
 [(3)](#ref-for-dfn-applicable-specification-46 "Reference 3")
 [(4)](#ref-for-dfn-applicable-specification-47 "Reference 4")
- [§ 31.1
 Description](#ref-for-dfn-applicable-specification-48 "§ 31.1 Description")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-applicable-specification-49 "§ 31.6.4 Import Key")
 [(2)](#ref-for-dfn-applicable-specification-50 "Reference 2")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-applicable-specification-51 "§ 31.6.5 Export Key")
 [(2)](#ref-for-dfn-applicable-specification-52 "Reference 2")
- [§ 33.1
 Description](#ref-for-dfn-applicable-specification-53 "§ 33.1 Description")
- [§ 34.1
 Description](#ref-for-dfn-applicable-specification-54 "§ 34.1 Description")

[Permalink](#dfn-serializable-objects)

**Referenced in:**

- [§ 5.2 Key
 Storage](#ref-for-dfn-serializable-objects-1 "§ 5.2 Key Storage")
- [§ 8.
 Dependencies](#ref-for-dfn-serializable-objects-2 "§ 8. Dependencies")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-serializable-objects-3 "§ 13.5 Serialization and deserialization steps")

[Permalink](#dfn-length-in-bits)

**Referenced in:**

- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-length-in-bits-1 "§ 24.4.2 Derive Bits")
- [§ 25.3.4 Import
 Key](#ref-for-dfn-length-in-bits-2 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-dfn-length-in-bits-3 "§ 26.3.3 Import Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-length-in-bits-4 "§ 27.7.4 Import Key")
 [(2)](#ref-for-dfn-length-in-bits-5 "Reference 2")
 [(3)](#ref-for-dfn-length-in-bits-6 "Reference 3")
 [(4)](#ref-for-dfn-length-in-bits-7 "Reference 4")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-length-in-bits-8 "§ 28.4.4 Import Key")
 [(2)](#ref-for-dfn-length-in-bits-9 "Reference 2")
 [(3)](#ref-for-dfn-length-in-bits-10 "Reference 3")
 [(4)](#ref-for-dfn-length-in-bits-11 "Reference 4")
- [§ 29.4.2 Decrypt](#ref-for-dfn-length-in-bits-12 "§ 29.4.2 Decrypt")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-length-in-bits-13 "§ 29.4.4 Import Key")
 [(2)](#ref-for-dfn-length-in-bits-14 "Reference 2")
 [(3)](#ref-for-dfn-length-in-bits-15 "Reference 3")
 [(4)](#ref-for-dfn-length-in-bits-16 "Reference 4")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-length-in-bits-17 "§ 30.3.4 Import Key")
 [(2)](#ref-for-dfn-length-in-bits-18 "Reference 2")
 [(3)](#ref-for-dfn-length-in-bits-19 "Reference 3")
 [(4)](#ref-for-dfn-length-in-bits-20 "Reference 4")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-length-in-bits-21 "§ 31.6.4 Import Key")

[Permalink](#dfn-byte-sequence-containing)

**Referenced in:**

- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-byte-sequence-containing-1 "§ 24.4.2 Derive Bits")
- [§ 26.3.1 Derive
 Bits](#ref-for-dfn-byte-sequence-containing-2 "§ 26.3.1 Derive Bits")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-byte-sequence-containing-3 "§ 31.6.5 Export Key")

[Permalink](#dfn-convert-integer-to-byte-sequence)

**Referenced in:**

- [§ 23.7.1
 Sign](#ref-for-dfn-convert-integer-to-byte-sequence-1 "§ 23.7.1 Sign")
 [(2)](#ref-for-dfn-convert-integer-to-byte-sequence-2 "Reference 2")

[Permalink](#dfn-convert-byte-sequence-to-integer)

**Referenced in:**

- [§ 20.5 RSA key generation parameter
 validation](#ref-for-dfn-convert-byte-sequence-to-integer-1 "§ 20.5 RSA key generation parameter validation")
- [§ 23.7.2
 Verify](#ref-for-dfn-convert-byte-sequence-to-integer-2 "§ 23.7.2 Verify")
 [(2)](#ref-for-dfn-convert-byte-sequence-to-integer-3 "Reference 2")

[Permalink](#case-sensitive)

**Referenced in:**

- [§ 3. Conformance](#ref-for-case-sensitive-1 "§ 3. Conformance")

[Permalink](#case-insensitive)

**Referenced in:**

- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-case-insensitive-1 "§ 18.4.4 Normalizing an algorithm")

[Permalink](#terminate-the-algorithm)

**Referenced in:**

- [§ 10.1.1 The getRandomValues
 method](#ref-for-terminate-the-algorithm-1 "§ 10.1.1 The getRandomValues method")
 [(2)](#ref-for-terminate-the-algorithm-2 "Reference 2")
- [§ 14.3.1 The encrypt
 method](#ref-for-terminate-the-algorithm-3 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-terminate-the-algorithm-4 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-terminate-the-algorithm-5 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-terminate-the-algorithm-6 "§ 14.3.4 The verify method")
- [§ 14.3.5 The digest
 method](#ref-for-terminate-the-algorithm-7 "§ 14.3.5 The digest method")
- [§ 14.3.6 The generateKey
 method](#ref-for-terminate-the-algorithm-8 "§ 14.3.6 The generateKey method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-terminate-the-algorithm-9 "§ 14.3.7 The deriveKey method")
- [§ 14.3.8 The deriveBits
 method](#ref-for-terminate-the-algorithm-10 "§ 14.3.8 The deriveBits method")
- [§ 14.3.9 The importKey
 method](#ref-for-terminate-the-algorithm-11 "§ 14.3.9 The importKey method")
- [§ 14.3.10 The exportKey
 method](#ref-for-terminate-the-algorithm-12 "§ 14.3.10 The exportKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-terminate-the-algorithm-13 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-terminate-the-algorithm-14 "§ 14.3.12 The unwrapKey method")

[Permalink](#concept-parse-an-asn1-structure)

**Referenced in:**

- [§ 9.
 Terminology](#ref-for-concept-parse-an-asn1-structure-1 "§ 9. Terminology")
 [(2)](#ref-for-concept-parse-an-asn1-structure-2 "Reference 2")
- [§ 20.9.4 Import
 Key](#ref-for-concept-parse-an-asn1-structure-3 "§ 20.9.4 Import Key")
 [(2)](#ref-for-concept-parse-an-asn1-structure-4 "Reference 2")
- [§ 21.4.4 Import
 Key](#ref-for-concept-parse-an-asn1-structure-5 "§ 21.4.4 Import Key")
 [(2)](#ref-for-concept-parse-an-asn1-structure-6 "Reference 2")
- [§ 22.4.4 Import
 Key](#ref-for-concept-parse-an-asn1-structure-7 "§ 22.4.4 Import Key")
 [(2)](#ref-for-concept-parse-an-asn1-structure-8 "Reference 2")
- [§ 23.7.4 Import
 Key](#ref-for-concept-parse-an-asn1-structure-9 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-concept-parse-an-asn1-structure-10 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-concept-parse-an-asn1-structure-11 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-concept-parse-an-asn1-structure-12 "§ 26.3.3 Import Key")

[Permalink](#concept-parse-a-spki)

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-concept-parse-a-spki-1 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-concept-parse-a-spki-2 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-concept-parse-a-spki-3 "§ 22.4.4 Import Key")
- [§ 23.7.4 Import
 Key](#ref-for-concept-parse-a-spki-4 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-concept-parse-a-spki-5 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-concept-parse-a-spki-6 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-concept-parse-a-spki-7 "§ 26.3.3 Import Key")

[Permalink](#concept-parse-a-privateKeyInfo)

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-1 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-2 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-3 "§ 22.4.4 Import Key")
- [§ 23.7.4 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-4 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-5 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-6 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-concept-parse-a-privateKeyInfo-7 "§ 26.3.3 Import Key")

[Permalink](#concept-parse-a-jwk)

**Referenced in:**

- [§ 14.3.12 The unwrapKey
 method](#ref-for-concept-parse-a-jwk-1 "§ 14.3.12 The unwrapKey method")

[Permalink](#concept-usage-intersection)

**Referenced in:**

- [§ 9.
 Terminology](#ref-for-concept-usage-intersection-1 "§ 9. Terminology")
- [§ 20.9.3 Generate
 Key](#ref-for-concept-usage-intersection-2 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-concept-usage-intersection-3 "Reference 2")
- [§ 21.4.3 Generate
 Key](#ref-for-concept-usage-intersection-4 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-concept-usage-intersection-5 "Reference 2")
- [§ 22.4.3 Generate
 Key](#ref-for-concept-usage-intersection-6 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-concept-usage-intersection-7 "Reference 2")
- [§ 23.7.3 Generate
 Key](#ref-for-concept-usage-intersection-8 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-concept-usage-intersection-9 "Reference 2")
- [§ 24.4.1 Generate
 Key](#ref-for-concept-usage-intersection-10 "§ 24.4.1 Generate Key")
- [§ 25.3.3 Generate
 Key](#ref-for-concept-usage-intersection-11 "§ 25.3.3 Generate Key")
 [(2)](#ref-for-concept-usage-intersection-12 "Reference 2")
- [§ 26.3.2 Generate
 Key](#ref-for-concept-usage-intersection-13 "§ 26.3.2 Generate Key")

[Permalink](#concept-normalized-usages)

**Referenced in:**

- [§ 14.3.7 The deriveKey
 method](#ref-for-concept-normalized-usages-1 "§ 14.3.7 The deriveKey method")
- [§ 14.3.9 The importKey
 method](#ref-for-concept-normalized-usages-2 "§ 14.3.9 The importKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-concept-normalized-usages-3 "§ 14.3.12 The unwrapKey method")
- [§ 27.7.3 Generate
 Key](#ref-for-concept-normalized-usages-4 "§ 27.7.3 Generate Key")
- [§ 28.4.3 Generate
 Key](#ref-for-concept-normalized-usages-5 "§ 28.4.3 Generate Key")
- [§ 29.4.3 Generate
 Key](#ref-for-concept-normalized-usages-6 "§ 29.4.3 Generate Key")
- [§ 30.3.3 Generate
 Key](#ref-for-concept-normalized-usages-7 "§ 30.3.3 Generate Key")
- [§ 31.6.3 Generate
 Key](#ref-for-concept-normalized-usages-8 "§ 31.6.3 Generate Key")

[Permalink](#concept-cached-object)

**Referenced in:**

- [§ 13.4 CryptoKey interface
 members](#ref-for-concept-cached-object-1 "§ 13.4 CryptoKey interface members")
 [(2)](#ref-for-concept-cached-object-2 "Reference 2")

[Permalink](#dfn-Crypto)
[exported]
[IDL](#webidl-1120328020 "Jump to IDL declaration")

**Referenced in:**

- [§ 10. Crypto
 interface](#ref-for-dfn-Crypto-1 "§ 10. Crypto interface")
 [(2)](#ref-for-dfn-Crypto-2 "Reference 2")
- [§ 37. Acknowledgments](#ref-for-dfn-Crypto-3 "§ 37. Acknowledgments")

[Permalink](#dom-windoworworkerglobalscope-crypto)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-Crypto-method-getRandomValues)
[exported]
[IDL](#webidl-1120328020 "Jump to IDL declaration")

**Referenced in:**

- [§ 10. Crypto
 interface](#ref-for-dfn-Crypto-method-getRandomValues-1 "§ 10. Crypto interface")
- [§ 37.
 Acknowledgments](#ref-for-dfn-Crypto-method-getRandomValues-2 "§ 37. Acknowledgments")

[Permalink](#dfn-Crypto-method-randomUUID)
[exported]
[IDL](#webidl-1120328020 "Jump to IDL declaration")

**Referenced in:**

- [§ 7. Privacy
 considerations](#ref-for-dfn-Crypto-method-randomUUID-1 "§ 7. Privacy considerations")
 [(2)](#ref-for-dfn-Crypto-method-randomUUID-2 "Reference 2")
- [§ 10. Crypto
 interface](#ref-for-dfn-Crypto-method-randomUUID-3 "§ 10. Crypto interface")

[Permalink](#dfn-generate-a-random-uuid)
[exported]

**Referenced in:**

- [§ 10.1.2 The randomUUID
 method](#ref-for-dfn-generate-a-random-uuid-1 "§ 10.1.2 The randomUUID method")

[Permalink](#dfn-hexadecimal-representation)

**Referenced in:**

- [§ 10.1.2 The randomUUID
 method](#ref-for-dfn-hexadecimal-representation-1 "§ 10.1.2 The randomUUID method")
 [(2)](#ref-for-dfn-hexadecimal-representation-2 "Reference 2")
 [(3)](#ref-for-dfn-hexadecimal-representation-3 "Reference 3")
 [(4)](#ref-for-dfn-hexadecimal-representation-4 "Reference 4")
 [(5)](#ref-for-dfn-hexadecimal-representation-5 "Reference 5")
 [(6)](#ref-for-dfn-hexadecimal-representation-6 "Reference 6")
 [(7)](#ref-for-dfn-hexadecimal-representation-7 "Reference 7")
 [(8)](#ref-for-dfn-hexadecimal-representation-8 "Reference 8")
 [(9)](#ref-for-dfn-hexadecimal-representation-9 "Reference 9")
 [(10)](#ref-for-dfn-hexadecimal-representation-10 "Reference 10")
 [(11)](#ref-for-dfn-hexadecimal-representation-11 "Reference 11")
 [(12)](#ref-for-dfn-hexadecimal-representation-12 "Reference 12")
 [(13)](#ref-for-dfn-hexadecimal-representation-13 "Reference 13")
 [(14)](#ref-for-dfn-hexadecimal-representation-14 "Reference 14")
 [(15)](#ref-for-dfn-hexadecimal-representation-15 "Reference 15")
 [(16)](#ref-for-dfn-hexadecimal-representation-16 "Reference 16")

[Permalink](#dfn-Crypto-attribute-subtle)
[exported]
[IDL](#webidl-1120328020 "Jump to IDL declaration")

**Referenced in:**

- [§ 10. Crypto
 interface](#ref-for-dfn-Crypto-attribute-subtle-1 "§ 10. Crypto interface")

[Permalink](#dfn-Algorithm)
[exported]
[IDL](#dfn-AlgorithmIdentifier "Jump to IDL declaration")

**Referenced in:**

- [§ 11. Algorithm
 dictionary](#ref-for-dfn-Algorithm-1 "§ 11. Algorithm dictionary")
- [§ 11.1 Algorithm Dictionary
 Members](#ref-for-dfn-Algorithm-2 "§ 11.1 Algorithm Dictionary Members")
- [§ 18.4.1
 Description](#ref-for-dfn-Algorithm-3 "§ 18.4.1 Description")
- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dfn-Algorithm-4 "§ 18.4.4 Normalizing an algorithm")
 [(2)](#ref-for-dfn-Algorithm-5 "Reference 2")
- [§ 20.3 RsaKeyGenParams
 dictionary](#ref-for-dfn-Algorithm-6 "§ 20.3 RsaKeyGenParams dictionary")
- [§ 20.8 RsaHashedImportParams
 dictionary](#ref-for-dfn-Algorithm-7 "§ 20.8 RsaHashedImportParams dictionary")
- [§ 21.3 RsaPssParams
 dictionary](#ref-for-dfn-Algorithm-8 "§ 21.3 RsaPssParams dictionary")
- [§ 22.3 RsaOaepParams
 dictionary](#ref-for-dfn-Algorithm-9 "§ 22.3 RsaOaepParams dictionary")
- [§ 23.3 EcdsaParams
 dictionary](#ref-for-dfn-Algorithm-10 "§ 23.3 EcdsaParams dictionary")
- [§ 23.4 EcKeyGenParams
 dictionary](#ref-for-dfn-Algorithm-11 "§ 23.4 EcKeyGenParams dictionary")
- [§ 23.6 EcKeyImportParams
 dictionary](#ref-for-dfn-Algorithm-12 "§ 23.6 EcKeyImportParams dictionary")
- [§ 24.3 EcdhKeyDeriveParams
 dictionary](#ref-for-dfn-Algorithm-13 "§ 24.3 EcdhKeyDeriveParams dictionary")
- [§ 27.3 AesCtrParams
 dictionary](#ref-for-dfn-Algorithm-14 "§ 27.3 AesCtrParams dictionary")
- [§ 27.5 AesKeyGenParams
 dictionary](#ref-for-dfn-Algorithm-15 "§ 27.5 AesKeyGenParams dictionary")
- [§ 27.6 AesDerivedKeyParams
 dictionary](#ref-for-dfn-Algorithm-16 "§ 27.6 AesDerivedKeyParams dictionary")
- [§ 28.3 AesCbcParams
 dictionary](#ref-for-dfn-Algorithm-17 "§ 28.3 AesCbcParams dictionary")
- [§ 29.3 AesGcmParams
 dictionary](#ref-for-dfn-Algorithm-18 "§ 29.3 AesGcmParams dictionary")
- [§ 31.3 HmacImportParams
 dictionary](#ref-for-dfn-Algorithm-19 "§ 31.3 HmacImportParams dictionary")
- [§ 31.5 HmacKeyGenParams
 dictionary](#ref-for-dfn-Algorithm-20 "§ 31.5 HmacKeyGenParams dictionary")
- [§ 33.3 HkdfParams
 dictionary](#ref-for-dfn-Algorithm-21 "§ 33.3 HkdfParams dictionary")
- [§ 34.3 Pbkdf2Params
 dictionary](#ref-for-dfn-Algorithm-22 "§ 34.3 Pbkdf2Params dictionary")

[Permalink](#dfn-HashAlgorithmIdentifier)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-algorithmidentifier)
[exported]

**Referenced in:**

- [§ 11. Algorithm
 dictionary](#ref-for-dom-algorithmidentifier-1 "§ 11. Algorithm dictionary")
- [§ 14. SubtleCrypto
 interface](#ref-for-dom-algorithmidentifier-2 "§ 14. SubtleCrypto interface")
 [(2)](#ref-for-dom-algorithmidentifier-3 "Reference 2")
 [(3)](#ref-for-dom-algorithmidentifier-4 "Reference 3")
 [(4)](#ref-for-dom-algorithmidentifier-5 "Reference 4")
 [(5)](#ref-for-dom-algorithmidentifier-6 "Reference 5")
 [(6)](#ref-for-dom-algorithmidentifier-7 "Reference 6")
 [(7)](#ref-for-dom-algorithmidentifier-8 "Reference 7")
 [(8)](#ref-for-dom-algorithmidentifier-9 "Reference 8")
 [(9)](#ref-for-dom-algorithmidentifier-10 "Reference 9")
 [(10)](#ref-for-dom-algorithmidentifier-11 "Reference 10")
 [(11)](#ref-for-dom-algorithmidentifier-12 "Reference 11")
 [(12)](#ref-for-dom-algorithmidentifier-13 "Reference 12")
 [(13)](#ref-for-dom-algorithmidentifier-14 "Reference 13")
- [§ 14.3.1 The encrypt
 method](#ref-for-dom-algorithmidentifier-15 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dom-algorithmidentifier-16 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dom-algorithmidentifier-17 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dom-algorithmidentifier-18 "§ 14.3.4 The verify method")
- [§ 14.3.5 The digest
 method](#ref-for-dom-algorithmidentifier-19 "§ 14.3.5 The digest method")
- [§ 18.4.1
 Description](#ref-for-dom-algorithmidentifier-20 "§ 18.4.1 Description")
 [(2)](#ref-for-dom-algorithmidentifier-21 "Reference 2")
- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dom-algorithmidentifier-22 "§ 18.4.4 Normalizing an algorithm")
 [(2)](#ref-for-dom-algorithmidentifier-23 "Reference 2")

[Permalink](#dom-hashalgorithmidentifier)
[exported]

**Referenced in:**

- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dom-hashalgorithmidentifier-1 "§ 18.4.4 Normalizing an algorithm")
- [§ 20.4 RsaHashedKeyGenParams
 dictionary](#ref-for-dom-hashalgorithmidentifier-2 "§ 20.4 RsaHashedKeyGenParams dictionary")
- [§ 20.8 RsaHashedImportParams
 dictionary](#ref-for-dom-hashalgorithmidentifier-3 "§ 20.8 RsaHashedImportParams dictionary")
- [§ 23.3 EcdsaParams
 dictionary](#ref-for-dom-hashalgorithmidentifier-4 "§ 23.3 EcdsaParams dictionary")
- [§ 31.3 HmacImportParams
 dictionary](#ref-for-dom-hashalgorithmidentifier-5 "§ 31.3 HmacImportParams dictionary")
- [§ 31.5 HmacKeyGenParams
 dictionary](#ref-for-dom-hashalgorithmidentifier-6 "§ 31.5 HmacKeyGenParams dictionary")
- [§ 33.3 HkdfParams
 dictionary](#ref-for-dom-hashalgorithmidentifier-7 "§ 33.3 HkdfParams dictionary")
- [§ 34.3 Pbkdf2Params
 dictionary](#ref-for-dom-hashalgorithmidentifier-8 "§ 34.3 Pbkdf2Params dictionary")

[Permalink](#dom-algorithm-name)
[exported]
[IDL](#dfn-AlgorithmIdentifier "Jump to IDL declaration")

**Referenced in:**

- [§ 11. Algorithm
 dictionary](#ref-for-dom-algorithm-name-1 "§ 11. Algorithm dictionary")
- [§ 14.3.1 The encrypt
 method](#ref-for-dom-algorithm-name-2 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dom-algorithm-name-3 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dom-algorithm-name-4 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dom-algorithm-name-5 "§ 14.3.4 The verify method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dom-algorithm-name-6 "§ 14.3.7 The deriveKey method")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dom-algorithm-name-7 "§ 14.3.8 The deriveBits method")
- [§ 14.3.10 The exportKey
 method](#ref-for-dom-algorithm-name-8 "§ 14.3.10 The exportKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dom-algorithm-name-9 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dom-algorithm-name-10 "§ 14.3.12 The unwrapKey method")
- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dom-algorithm-name-11 "§ 18.4.4 Normalizing an algorithm")
 [(2)](#ref-for-dom-algorithm-name-12 "Reference 2")
- [§ 24.4.1 Generate
 Key](#ref-for-dom-algorithm-name-13 "§ 24.4.1 Generate Key")
- [§ 24.4.2 Derive
 Bits](#ref-for-dom-algorithm-name-14 "§ 24.4.2 Derive Bits")
- [§ 26.3.1 Derive
 Bits](#ref-for-dom-algorithm-name-15 "§ 26.3.1 Derive Bits")
- [§ 31.6.3 Generate
 Key](#ref-for-dom-algorithm-name-16 "§ 31.6.3 Generate Key")
- [§ 32.3.1 Digest](#ref-for-dom-algorithm-name-17 "§ 32.3.1 Digest")
 [(2)](#ref-for-dom-algorithm-name-18 "Reference 2")
 [(3)](#ref-for-dom-algorithm-name-19 "Reference 3")
 [(4)](#ref-for-dom-algorithm-name-20 "Reference 4")

[Permalink](#dfn-KeyAlgorithm)
[exported]
[IDL](#webidl-1933950287 "Jump to IDL declaration")

**Referenced in:**

- [§ 12. KeyAlgorithm
 dictionary](#ref-for-dfn-KeyAlgorithm-1 "§ 12. KeyAlgorithm dictionary")
- [§ 12.1 Description](#ref-for-dfn-KeyAlgorithm-2 "§ 12.1 Description")
- [§ 13.3 CryptoKey internal
 slots](#ref-for-dfn-KeyAlgorithm-3 "§ 13.3 CryptoKey internal slots")
- [§ 20.6 RsaKeyAlgorithm
 dictionary](#ref-for-dfn-KeyAlgorithm-4 "§ 20.6 RsaKeyAlgorithm dictionary")
- [§ 20.7 RsaHashedKeyAlgorithm
 dictionary](#ref-for-dfn-KeyAlgorithm-5 "§ 20.7 RsaHashedKeyAlgorithm dictionary")
- [§ 23.5 EcKeyAlgorithm
 dictionary](#ref-for-dfn-KeyAlgorithm-6 "§ 23.5 EcKeyAlgorithm dictionary")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-KeyAlgorithm-7 "§ 25.3.3 Generate Key")
- [§ 25.3.4 Import
 Key](#ref-for-dfn-KeyAlgorithm-8 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dfn-KeyAlgorithm-9 "Reference 2")
 [(3)](#ref-for-dfn-KeyAlgorithm-10 "Reference 3")
 [(4)](#ref-for-dfn-KeyAlgorithm-11 "Reference 4")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-KeyAlgorithm-12 "§ 26.3.2 Generate Key")
- [§ 26.3.3 Import
 Key](#ref-for-dfn-KeyAlgorithm-13 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dfn-KeyAlgorithm-14 "Reference 2")
 [(3)](#ref-for-dfn-KeyAlgorithm-15 "Reference 3")
 [(4)](#ref-for-dfn-KeyAlgorithm-16 "Reference 4")
- [§ 27.4 AesKeyAlgorithm
 dictionary](#ref-for-dfn-KeyAlgorithm-17 "§ 27.4 AesKeyAlgorithm dictionary")
- [§ 31.4 HmacKeyAlgorithm
 dictionary](#ref-for-dfn-KeyAlgorithm-18 "§ 31.4 HmacKeyAlgorithm dictionary")
 [(2)](#ref-for-dfn-KeyAlgorithm-19 "Reference 2")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-KeyAlgorithm-20 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-KeyAlgorithm-21 "§ 31.6.4 Import Key")
- [§ 33.4.2 Import
 key](#ref-for-dfn-KeyAlgorithm-22 "§ 33.4.2 Import key")
- [§ 34.4.2 Import
 key](#ref-for-dfn-KeyAlgorithm-23 "§ 34.4.2 Import key")

[Permalink](#dom-keyalgorithm-name)
[exported]
[IDL](#webidl-1933950287 "Jump to IDL declaration")

**Referenced in:**

- [§ 12. KeyAlgorithm
 dictionary](#ref-for-dom-keyalgorithm-name-1 "§ 12. KeyAlgorithm dictionary")
- [§ 14.3.1 The encrypt
 method](#ref-for-dom-keyalgorithm-name-2 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dom-keyalgorithm-name-3 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dom-keyalgorithm-name-4 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dom-keyalgorithm-name-5 "§ 14.3.4 The verify method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dom-keyalgorithm-name-6 "§ 14.3.7 The deriveKey method")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dom-keyalgorithm-name-7 "§ 14.3.8 The deriveBits method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dom-keyalgorithm-name-8 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dom-keyalgorithm-name-9 "§ 14.3.12 The unwrapKey method")
- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dom-keyalgorithm-name-10 "§ 18.4.4 Normalizing an algorithm")
- [§ 20.9.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-11 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dom-keyalgorithm-name-12 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dom-keyalgorithm-name-13 "§ 20.9.5 Export Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-14 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-keyalgorithm-name-15 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-keyalgorithm-name-16 "§ 21.4.5 Export Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-17 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-keyalgorithm-name-18 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-keyalgorithm-name-19 "§ 22.4.5 Export Key")
- [§ 23.7.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-20 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keyalgorithm-name-21 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dom-keyalgorithm-name-22 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-23 "Reference 3")
 [(4)](#ref-for-dom-keyalgorithm-name-24 "Reference 4")
- [§ 24.4.2 Derive
 Bits](#ref-for-dom-keyalgorithm-name-25 "§ 24.4.2 Derive Bits")
 [(2)](#ref-for-dom-keyalgorithm-name-26 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-27 "Reference 3")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keyalgorithm-name-28 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dom-keyalgorithm-name-29 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-30 "Reference 3")
 [(4)](#ref-for-dom-keyalgorithm-name-31 "Reference 4")
- [§ 25.3.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-32 "§ 25.3.3 Generate Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keyalgorithm-name-33 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dom-keyalgorithm-name-34 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-35 "Reference 3")
 [(4)](#ref-for-dom-keyalgorithm-name-36 "Reference 4")
- [§ 26.3.1 Derive
 Bits](#ref-for-dom-keyalgorithm-name-37 "§ 26.3.1 Derive Bits")
 [(2)](#ref-for-dom-keyalgorithm-name-38 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-39 "Reference 3")
- [§ 26.3.2 Generate
 Key](#ref-for-dom-keyalgorithm-name-40 "§ 26.3.2 Generate Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keyalgorithm-name-41 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dom-keyalgorithm-name-42 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-43 "Reference 3")
 [(4)](#ref-for-dom-keyalgorithm-name-44 "Reference 4")
- [§ 27.7.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-45 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-keyalgorithm-name-46 "§ 27.7.4 Import Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-47 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-keyalgorithm-name-48 "§ 28.4.4 Import Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-49 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-keyalgorithm-name-50 "§ 29.4.4 Import Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-51 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-keyalgorithm-name-52 "§ 30.3.4 Import Key")
- [§ 31.6.3 Generate
 Key](#ref-for-dom-keyalgorithm-name-53 "§ 31.6.3 Generate Key")
 [(2)](#ref-for-dom-keyalgorithm-name-54 "Reference 2")
- [§ 31.6.4 Import
 Key](#ref-for-dom-keyalgorithm-name-55 "§ 31.6.4 Import Key")
 [(2)](#ref-for-dom-keyalgorithm-name-56 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-57 "Reference 3")
 [(4)](#ref-for-dom-keyalgorithm-name-58 "Reference 4")
 [(5)](#ref-for-dom-keyalgorithm-name-59 "Reference 5")
 [(6)](#ref-for-dom-keyalgorithm-name-60 "Reference 6")
- [§ 31.6.5 Export
 Key](#ref-for-dom-keyalgorithm-name-61 "§ 31.6.5 Export Key")
 [(2)](#ref-for-dom-keyalgorithm-name-62 "Reference 2")
 [(3)](#ref-for-dom-keyalgorithm-name-63 "Reference 3")
 [(4)](#ref-for-dom-keyalgorithm-name-64 "Reference 4")
 [(5)](#ref-for-dom-keyalgorithm-name-65 "Reference 5")
- [§ 33.4.2 Import
 key](#ref-for-dom-keyalgorithm-name-66 "§ 33.4.2 Import key")
- [§ 34.4.2 Import
 key](#ref-for-dom-keyalgorithm-name-67 "§ 34.4.2 Import key")

[Permalink](#dfn-CryptoKey)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 5.1 Underlying Cryptographic
 Implementation](#ref-for-dfn-CryptoKey-1 "§ 5.1 Underlying Cryptographic Implementation")
 [(2)](#ref-for-dfn-CryptoKey-2 "Reference 2")
- [§ 5.2 Key Storage](#ref-for-dfn-CryptoKey-3 "§ 5.2 Key Storage")
 [(2)](#ref-for-dfn-CryptoKey-4 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-5 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-6 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-7 "Reference 5")
- [§ 6.1 Security considerations for
 implementers](#ref-for-dfn-CryptoKey-8 "§ 6.1 Security considerations for implementers")
 [(2)](#ref-for-dfn-CryptoKey-9 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-10 "Reference 3")
- [§ 6.2 Security considerations for
 authors](#ref-for-dfn-CryptoKey-11 "§ 6.2 Security considerations for authors")
 [(2)](#ref-for-dfn-CryptoKey-12 "Reference 2")
- [§ 12. KeyAlgorithm
 dictionary](#ref-for-dfn-CryptoKey-13 "§ 12. KeyAlgorithm dictionary")
- [§ 12.1 Description](#ref-for-dfn-CryptoKey-14 "§ 12.1 Description")
- [§ 12.2 KeyAlgorithm dictionary
 members](#ref-for-dfn-CryptoKey-15 "§ 12.2 KeyAlgorithm dictionary members")
- [§ 13. CryptoKey
 interface](#ref-for-dfn-CryptoKey-16 "§ 13. CryptoKey interface")
- [§ 13.3 CryptoKey internal
 slots](#ref-for-dfn-CryptoKey-17 "§ 13.3 CryptoKey internal slots")
 [(2)](#ref-for-dfn-CryptoKey-18 "Reference 2")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-CryptoKey-19 "§ 13.5 Serialization and deserialization steps")
 [(2)](#ref-for-dfn-CryptoKey-20 "Reference 2")
- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-CryptoKey-21 "§ 14. SubtleCrypto interface")
 [(2)](#ref-for-dfn-CryptoKey-22 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-23 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-24 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-25 "Reference 5")
 [(6)](#ref-for-dfn-CryptoKey-26 "Reference 6")
 [(7)](#ref-for-dfn-CryptoKey-27 "Reference 7")
 [(8)](#ref-for-dfn-CryptoKey-28 "Reference 8")
 [(9)](#ref-for-dfn-CryptoKey-29 "Reference 9")
 [(10)](#ref-for-dfn-CryptoKey-30 "Reference 10")
 [(11)](#ref-for-dfn-CryptoKey-31 "Reference 11")
 [(12)](#ref-for-dfn-CryptoKey-32 "Reference 12")
 [(13)](#ref-for-dfn-CryptoKey-33 "Reference 13")
 [(14)](#ref-for-dfn-CryptoKey-34 "Reference 14")
- [§ 14.3.1 The encrypt
 method](#ref-for-dfn-CryptoKey-35 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dfn-CryptoKey-36 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dfn-CryptoKey-37 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dfn-CryptoKey-38 "§ 14.3.4 The verify method")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-CryptoKey-39 "§ 14.3.6 The generateKey method")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-CryptoKey-40 "§ 14.3.9 The importKey method")
- [§ 17. CryptoKeyPair
 dictionary](#ref-for-dfn-CryptoKey-41 "§ 17. CryptoKeyPair dictionary")
 [(2)](#ref-for-dfn-CryptoKey-42 "Reference 2")
- [§ 20.2 Registration](#ref-for-dfn-CryptoKey-43 "§ 20.2 Registration")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKey-44 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-45 "Reference 2")
- [§ 20.9.4 Import Key](#ref-for-dfn-CryptoKey-46 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-47 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-48 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-49 "Reference 4")
- [§ 21.2 Registration](#ref-for-dfn-CryptoKey-50 "§ 21.2 Registration")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-51 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-52 "Reference 2")
- [§ 21.4.4 Import Key](#ref-for-dfn-CryptoKey-53 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-54 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-55 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-56 "Reference 4")
- [§ 22.2 Registration](#ref-for-dfn-CryptoKey-57 "§ 22.2 Registration")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-58 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-59 "Reference 2")
- [§ 22.4.4 Import Key](#ref-for-dfn-CryptoKey-60 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-61 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-62 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-63 "Reference 4")
- [§ 23.2 Registration](#ref-for-dfn-CryptoKey-64 "§ 23.2 Registration")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-65 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-66 "Reference 2")
- [§ 23.7.4 Import Key](#ref-for-dfn-CryptoKey-67 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-68 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-69 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-70 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-71 "Reference 5")
- [§ 23.7.5 Export Key](#ref-for-dfn-CryptoKey-72 "§ 23.7.5 Export Key")
- [§ 24.2 Registration](#ref-for-dfn-CryptoKey-73 "§ 24.2 Registration")
- [§ 24.3 EcdhKeyDeriveParams
 dictionary](#ref-for-dfn-CryptoKey-74 "§ 24.3 EcdhKeyDeriveParams dictionary")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKey-75 "§ 24.4.1 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-76 "Reference 2")
- [§ 24.4.3 Import Key](#ref-for-dfn-CryptoKey-77 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-78 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-79 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-80 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-81 "Reference 5")
- [§ 24.4.4 Export Key](#ref-for-dfn-CryptoKey-82 "§ 24.4.4 Export Key")
- [§ 25.2 Registration](#ref-for-dfn-CryptoKey-83 "§ 25.2 Registration")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-84 "§ 25.3.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-85 "Reference 2")
- [§ 25.3.4 Import Key](#ref-for-dfn-CryptoKey-86 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-87 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-88 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-89 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-90 "Reference 5")
- [§ 25.3.5 Export Key](#ref-for-dfn-CryptoKey-91 "§ 25.3.5 Export Key")
- [§ 26.2 Registration](#ref-for-dfn-CryptoKey-92 "§ 26.2 Registration")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKey-93 "§ 26.3.2 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-94 "Reference 2")
- [§ 26.3.3 Import Key](#ref-for-dfn-CryptoKey-95 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-96 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-97 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-98 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-99 "Reference 5")
- [§ 26.3.4 Export
 Key](#ref-for-dfn-CryptoKey-100 "§ 26.3.4 Export Key")
- [§ 27.2
 Registration](#ref-for-dfn-CryptoKey-101 "§ 27.2 Registration")
 [(2)](#ref-for-dfn-CryptoKey-102 "Reference 2")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-103 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-CryptoKey-104 "§ 27.7.4 Import Key")
- [§ 28.2
 Registration](#ref-for-dfn-CryptoKey-105 "§ 28.2 Registration")
 [(2)](#ref-for-dfn-CryptoKey-106 "Reference 2")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-107 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-CryptoKey-108 "§ 28.4.4 Import Key")
- [§ 29.2
 Registration](#ref-for-dfn-CryptoKey-109 "§ 29.2 Registration")
 [(2)](#ref-for-dfn-CryptoKey-110 "Reference 2")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-111 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-CryptoKey-112 "§ 29.4.4 Import Key")
- [§ 30.2
 Registration](#ref-for-dfn-CryptoKey-113 "§ 30.2 Registration")
 [(2)](#ref-for-dfn-CryptoKey-114 "Reference 2")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-115 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-CryptoKey-116 "§ 30.3.4 Import Key")
- [§ 31.2
 Registration](#ref-for-dfn-CryptoKey-117 "§ 31.2 Registration")
 [(2)](#ref-for-dfn-CryptoKey-118 "Reference 2")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-CryptoKey-119 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-CryptoKey-120 "§ 31.6.4 Import Key")
- [§ 33.2
 Registration](#ref-for-dfn-CryptoKey-121 "§ 33.2 Registration")
- [§ 33.4.2 Import
 key](#ref-for-dfn-CryptoKey-122 "§ 33.4.2 Import key")
- [§ 34.2
 Registration](#ref-for-dfn-CryptoKey-123 "§ 34.2 Registration")
- [§ 34.4.2 Import
 key](#ref-for-dfn-CryptoKey-124 "§ 34.4.2 Import key")

[Permalink](#dom-keytype)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keytype-1 "§ 13. CryptoKey interface")
 [(2)](#ref-for-dom-keytype-2 "Reference 2")

[Permalink](#dfn-RecognizedKeyType)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-keytype-secret)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keytype-secret-1 "§ 13. CryptoKey interface")
- [§ 14.3.6 The generateKey
 method](#ref-for-dom-keytype-secret-2 "§ 14.3.6 The generateKey method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dom-keytype-secret-3 "§ 14.3.7 The deriveKey method")
- [§ 14.3.9 The importKey
 method](#ref-for-dom-keytype-secret-4 "§ 14.3.9 The importKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dom-keytype-secret-5 "§ 14.3.12 The unwrapKey method")
- [§ 27.7.3 Generate
 Key](#ref-for-dom-keytype-secret-6 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-keytype-secret-7 "§ 27.7.4 Import Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dom-keytype-secret-8 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-keytype-secret-9 "§ 28.4.4 Import Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dom-keytype-secret-10 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-keytype-secret-11 "§ 29.4.4 Import Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dom-keytype-secret-12 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-keytype-secret-13 "§ 30.3.4 Import Key")
- [§ 31.6.3 Generate
 Key](#ref-for-dom-keytype-secret-14 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-keytype-secret-15 "§ 31.6.4 Import Key")
- [§ 33.4.2 Import
 key](#ref-for-dom-keytype-secret-16 "§ 33.4.2 Import key")
- [§ 34.4.2 Import
 key](#ref-for-dom-keytype-secret-17 "§ 34.4.2 Import key")

[Permalink](#dom-keytype-public)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keytype-public-1 "§ 13. CryptoKey interface")
- [§ 20.9.2 Verify](#ref-for-dom-keytype-public-2 "§ 20.9.2 Verify")
- [§ 20.9.3 Generate
 Key](#ref-for-dom-keytype-public-3 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dom-keytype-public-4 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dom-keytype-public-5 "Reference 2")
- [§ 20.9.5 Export
 Key](#ref-for-dom-keytype-public-6 "§ 20.9.5 Export Key")
- [§ 21.4.2 Verify](#ref-for-dom-keytype-public-7 "§ 21.4.2 Verify")
- [§ 21.4.3 Generate
 Key](#ref-for-dom-keytype-public-8 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-keytype-public-9 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dom-keytype-public-10 "Reference 2")
- [§ 21.4.5 Export
 Key](#ref-for-dom-keytype-public-11 "§ 21.4.5 Export Key")
- [§ 22.4.1 Encrypt](#ref-for-dom-keytype-public-12 "§ 22.4.1 Encrypt")
- [§ 22.4.3 Generate
 Key](#ref-for-dom-keytype-public-13 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-keytype-public-14 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dom-keytype-public-15 "Reference 2")
- [§ 22.4.5 Export
 Key](#ref-for-dom-keytype-public-16 "§ 22.4.5 Export Key")
- [§ 23.7.2 Verify](#ref-for-dom-keytype-public-17 "§ 23.7.2 Verify")
- [§ 23.7.3 Generate
 Key](#ref-for-dom-keytype-public-18 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keytype-public-19 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dom-keytype-public-20 "Reference 2")
 [(3)](#ref-for-dom-keytype-public-21 "Reference 3")
- [§ 23.7.5 Export
 Key](#ref-for-dom-keytype-public-22 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dom-keytype-public-23 "Reference 2")
- [§ 24.4.1 Generate
 Key](#ref-for-dom-keytype-public-24 "§ 24.4.1 Generate Key")
- [§ 24.4.2 Derive
 Bits](#ref-for-dom-keytype-public-25 "§ 24.4.2 Derive Bits")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keytype-public-26 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dom-keytype-public-27 "Reference 2")
 [(3)](#ref-for-dom-keytype-public-28 "Reference 3")
- [§ 24.4.4 Export
 Key](#ref-for-dom-keytype-public-29 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dom-keytype-public-30 "Reference 2")
- [§ 25.3.2 Verify](#ref-for-dom-keytype-public-31 "§ 25.3.2 Verify")
- [§ 25.3.3 Generate
 Key](#ref-for-dom-keytype-public-32 "§ 25.3.3 Generate Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keytype-public-33 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dom-keytype-public-34 "Reference 2")
 [(3)](#ref-for-dom-keytype-public-35 "Reference 3")
- [§ 25.3.5 Export
 Key](#ref-for-dom-keytype-public-36 "§ 25.3.5 Export Key")
 [(2)](#ref-for-dom-keytype-public-37 "Reference 2")
- [§ 26.3.1 Derive
 Bits](#ref-for-dom-keytype-public-38 "§ 26.3.1 Derive Bits")
- [§ 26.3.2 Generate
 Key](#ref-for-dom-keytype-public-39 "§ 26.3.2 Generate Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keytype-public-40 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dom-keytype-public-41 "Reference 2")
 [(3)](#ref-for-dom-keytype-public-42 "Reference 3")
- [§ 26.3.4 Export
 Key](#ref-for-dom-keytype-public-43 "§ 26.3.4 Export Key")
 [(2)](#ref-for-dom-keytype-public-44 "Reference 2")

[Permalink](#dom-keytype-private)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keytype-private-1 "§ 13. CryptoKey interface")
- [§ 14.3.6 The generateKey
 method](#ref-for-dom-keytype-private-2 "§ 14.3.6 The generateKey method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dom-keytype-private-3 "§ 14.3.7 The deriveKey method")
- [§ 14.3.9 The importKey
 method](#ref-for-dom-keytype-private-4 "§ 14.3.9 The importKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dom-keytype-private-5 "§ 14.3.12 The unwrapKey method")
- [§ 20.9.1 Sign](#ref-for-dom-keytype-private-6 "§ 20.9.1 Sign")
- [§ 20.9.3 Generate
 Key](#ref-for-dom-keytype-private-7 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dom-keytype-private-8 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dom-keytype-private-9 "Reference 2")
- [§ 20.9.5 Export
 Key](#ref-for-dom-keytype-private-10 "§ 20.9.5 Export Key")
 [(2)](#ref-for-dom-keytype-private-11 "Reference 2")
- [§ 21.4.1 Sign](#ref-for-dom-keytype-private-12 "§ 21.4.1 Sign")
- [§ 21.4.3 Generate
 Key](#ref-for-dom-keytype-private-13 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-keytype-private-14 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dom-keytype-private-15 "Reference 2")
- [§ 21.4.5 Export
 Key](#ref-for-dom-keytype-private-16 "§ 21.4.5 Export Key")
 [(2)](#ref-for-dom-keytype-private-17 "Reference 2")
- [§ 22.4.2 Decrypt](#ref-for-dom-keytype-private-18 "§ 22.4.2 Decrypt")
- [§ 22.4.3 Generate
 Key](#ref-for-dom-keytype-private-19 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-keytype-private-20 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dom-keytype-private-21 "Reference 2")
- [§ 22.4.5 Export
 Key](#ref-for-dom-keytype-private-22 "§ 22.4.5 Export Key")
 [(2)](#ref-for-dom-keytype-private-23 "Reference 2")
- [§ 23.7.1 Sign](#ref-for-dom-keytype-private-24 "§ 23.7.1 Sign")
- [§ 23.7.3 Generate
 Key](#ref-for-dom-keytype-private-25 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keytype-private-26 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dom-keytype-private-27 "Reference 2")
- [§ 23.7.5 Export
 Key](#ref-for-dom-keytype-private-28 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dom-keytype-private-29 "Reference 2")
- [§ 24.4.1 Generate
 Key](#ref-for-dom-keytype-private-30 "§ 24.4.1 Generate Key")
- [§ 24.4.2 Derive
 Bits](#ref-for-dom-keytype-private-31 "§ 24.4.2 Derive Bits")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keytype-private-32 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dom-keytype-private-33 "Reference 2")
- [§ 24.4.4 Export
 Key](#ref-for-dom-keytype-private-34 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dom-keytype-private-35 "Reference 2")
- [§ 25.3.1 Sign](#ref-for-dom-keytype-private-36 "§ 25.3.1 Sign")
- [§ 25.3.3 Generate
 Key](#ref-for-dom-keytype-private-37 "§ 25.3.3 Generate Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keytype-private-38 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dom-keytype-private-39 "Reference 2")
- [§ 25.3.5 Export
 Key](#ref-for-dom-keytype-private-40 "§ 25.3.5 Export Key")
 [(2)](#ref-for-dom-keytype-private-41 "Reference 2")
- [§ 26.3.1 Derive
 Bits](#ref-for-dom-keytype-private-42 "§ 26.3.1 Derive Bits")
- [§ 26.3.2 Generate
 Key](#ref-for-dom-keytype-private-43 "§ 26.3.2 Generate Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keytype-private-44 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dom-keytype-private-45 "Reference 2")
- [§ 26.3.4 Export
 Key](#ref-for-dom-keytype-private-46 "§ 26.3.4 Export Key")
 [(2)](#ref-for-dom-keytype-private-47 "Reference 2")

[Permalink](#dom-keyusage)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-1 "§ 13. CryptoKey interface")
- [§ 14. SubtleCrypto
 interface](#ref-for-dom-keyusage-2 "§ 14. SubtleCrypto interface")
 [(2)](#ref-for-dom-keyusage-3 "Reference 2")
 [(3)](#ref-for-dom-keyusage-4 "Reference 3")
 [(4)](#ref-for-dom-keyusage-5 "Reference 4")

[Permalink](#dfn-RecognizedKeyUsage)

**Referenced in:**

- [§ 9.
 Terminology](#ref-for-dfn-RecognizedKeyUsage-1 "§ 9. Terminology")
 [(2)](#ref-for-dfn-RecognizedKeyUsage-2 "Reference 2")
 [(3)](#ref-for-dfn-RecognizedKeyUsage-3 "Reference 3")

[Permalink](#dom-keyusage-encrypt)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-encrypt-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-decrypt)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-decrypt-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-sign)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-sign-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-verify)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-verify-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-derivekey)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-derivekey-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-derivebits)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-derivebits-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-wrapkey)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-wrapkey-1 "§ 13. CryptoKey interface")

[Permalink](#dom-keyusage-unwrapkey)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-keyusage-unwrapkey-1 "§ 13. CryptoKey interface")

[Permalink](#dfn-CryptoKey-slot-type)

**Referenced in:**

- [§ 13.4 CryptoKey interface
 members](#ref-for-dfn-CryptoKey-slot-type-1 "§ 13.4 CryptoKey interface members")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-CryptoKey-slot-type-2 "§ 13.5 Serialization and deserialization steps")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-3 "Reference 2")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-CryptoKey-slot-type-4 "§ 14.3.6 The generateKey method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-CryptoKey-slot-type-5 "§ 14.3.7 The deriveKey method")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-CryptoKey-slot-type-6 "§ 14.3.9 The importKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-CryptoKey-slot-type-7 "§ 14.3.12 The unwrapKey method")
- [§ 20.9.1 Sign](#ref-for-dfn-CryptoKey-slot-type-8 "§ 20.9.1 Sign")
- [§ 20.9.2
 Verify](#ref-for-dfn-CryptoKey-slot-type-9 "§ 20.9.2 Verify")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-10 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-11 "Reference 2")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-12 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-13 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-14 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-15 "Reference 4")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-16 "§ 20.9.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-17 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-18 "Reference 3")
- [§ 21.4.1 Sign](#ref-for-dfn-CryptoKey-slot-type-19 "§ 21.4.1 Sign")
- [§ 21.4.2
 Verify](#ref-for-dfn-CryptoKey-slot-type-20 "§ 21.4.2 Verify")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-21 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-22 "Reference 2")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-23 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-24 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-25 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-26 "Reference 4")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-27 "§ 21.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-28 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-29 "Reference 3")
- [§ 22.4.1
 Encrypt](#ref-for-dfn-CryptoKey-slot-type-30 "§ 22.4.1 Encrypt")
- [§ 22.4.2
 Decrypt](#ref-for-dfn-CryptoKey-slot-type-31 "§ 22.4.2 Decrypt")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-32 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-33 "Reference 2")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-34 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-35 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-36 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-37 "Reference 4")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-38 "§ 22.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-39 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-40 "Reference 3")
- [§ 23.7.1 Sign](#ref-for-dfn-CryptoKey-slot-type-41 "§ 23.7.1 Sign")
- [§ 23.7.2
 Verify](#ref-for-dfn-CryptoKey-slot-type-42 "§ 23.7.2 Verify")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-43 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-44 "Reference 2")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-45 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-46 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-47 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-48 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-type-49 "Reference 5")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-50 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-51 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-52 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-53 "Reference 4")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-54 "§ 24.4.1 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-55 "Reference 2")
- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-type-56 "§ 24.4.2 Derive Bits")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-57 "Reference 2")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-58 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-59 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-60 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-61 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-type-62 "Reference 5")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-63 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-64 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-65 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-66 "Reference 4")
- [§ 25.3.1 Sign](#ref-for-dfn-CryptoKey-slot-type-67 "§ 25.3.1 Sign")
- [§ 25.3.2
 Verify](#ref-for-dfn-CryptoKey-slot-type-68 "§ 25.3.2 Verify")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-69 "§ 25.3.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-70 "Reference 2")
- [§ 25.3.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-71 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-72 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-73 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-74 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-type-75 "Reference 5")
- [§ 25.3.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-76 "§ 25.3.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-77 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-78 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-79 "Reference 4")
- [§ 26.3.1 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-type-80 "§ 26.3.1 Derive Bits")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-81 "Reference 2")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-82 "§ 26.3.2 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-83 "Reference 2")
- [§ 26.3.3 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-84 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-85 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-86 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-87 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-type-88 "Reference 5")
- [§ 26.3.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-type-89 "§ 26.3.4 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-type-90 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-type-91 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-type-92 "Reference 4")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-93 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-94 "§ 27.7.4 Import Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-95 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-96 "§ 28.4.4 Import Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-97 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-98 "§ 29.4.4 Import Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-99 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-100 "§ 30.3.4 Import Key")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-type-101 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-type-102 "§ 31.6.4 Import Key")
- [§ 33.4.2 Import
 key](#ref-for-dfn-CryptoKey-slot-type-103 "§ 33.4.2 Import key")
- [§ 34.4.2 Import
 key](#ref-for-dfn-CryptoKey-slot-type-104 "§ 34.4.2 Import key")

[Permalink](#dfn-CryptoKey-slot-extractable)

**Referenced in:**

- [§ 13.4 CryptoKey interface
 members](#ref-for-dfn-CryptoKey-slot-extractable-1 "§ 13.4 CryptoKey interface members")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-CryptoKey-slot-extractable-2 "§ 13.5 Serialization and deserialization steps")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-3 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-extractable-4 "Reference 3")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-CryptoKey-slot-extractable-5 "§ 14.3.7 The deriveKey method")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-CryptoKey-slot-extractable-6 "§ 14.3.9 The importKey method")
- [§ 14.3.10 The exportKey
 method](#ref-for-dfn-CryptoKey-slot-extractable-7 "§ 14.3.10 The exportKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dfn-CryptoKey-slot-extractable-8 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-CryptoKey-slot-extractable-9 "§ 14.3.12 The unwrapKey method")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-10 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-11 "Reference 2")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-12 "§ 20.9.5 Export Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-13 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-14 "Reference 2")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-15 "§ 21.4.5 Export Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-16 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-17 "Reference 2")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-18 "§ 22.4.5 Export Key")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-19 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-20 "Reference 2")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-21 "§ 23.7.5 Export Key")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-22 "§ 24.4.1 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-23 "Reference 2")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-24 "§ 24.4.4 Export Key")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-25 "§ 25.3.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-26 "Reference 2")
- [§ 25.3.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-27 "§ 25.3.5 Export Key")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-28 "§ 26.3.2 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-extractable-29 "Reference 2")
- [§ 26.3.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-30 "§ 26.3.4 Export Key")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-31 "§ 27.7.3 Generate Key")
- [§ 27.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-32 "§ 27.7.5 Export Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-33 "§ 28.4.3 Generate Key")
- [§ 28.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-34 "§ 28.4.5 Export Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-35 "§ 29.4.3 Generate Key")
- [§ 29.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-36 "§ 29.4.5 Export Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-37 "§ 30.3.3 Generate Key")
- [§ 30.3.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-38 "§ 30.3.5 Export Key")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-extractable-39 "§ 31.6.3 Generate Key")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-extractable-40 "§ 31.6.5 Export Key")

[Permalink](#dfn-CryptoKey-slot-algorithm)

**Referenced in:**

- [§ 13.3 CryptoKey internal
 slots](#ref-for-dfn-CryptoKey-slot-algorithm-1 "§ 13.3 CryptoKey internal slots")
- [§ 13.4 CryptoKey interface
 members](#ref-for-dfn-CryptoKey-slot-algorithm-2 "§ 13.4 CryptoKey interface members")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-CryptoKey-slot-algorithm-3 "§ 13.5 Serialization and deserialization steps")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-4 "Reference 2")
- [§ 14.3.1 The encrypt
 method](#ref-for-dfn-CryptoKey-slot-algorithm-5 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dfn-CryptoKey-slot-algorithm-6 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dfn-CryptoKey-slot-algorithm-7 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dfn-CryptoKey-slot-algorithm-8 "§ 14.3.4 The verify method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-CryptoKey-slot-algorithm-9 "§ 14.3.7 The deriveKey method")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dfn-CryptoKey-slot-algorithm-10 "§ 14.3.8 The deriveBits method")
- [§ 14.3.10 The exportKey
 method](#ref-for-dfn-CryptoKey-slot-algorithm-11 "§ 14.3.10 The exportKey method")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-12 "Reference 2")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dfn-CryptoKey-slot-algorithm-13 "§ 14.3.11 The wrapKey method")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-14 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-15 "Reference 3")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-CryptoKey-slot-algorithm-16 "§ 14.3.12 The unwrapKey method")
- [§ 20.9.1
 Sign](#ref-for-dfn-CryptoKey-slot-algorithm-17 "§ 20.9.1 Sign")
- [§ 20.9.2
 Verify](#ref-for-dfn-CryptoKey-slot-algorithm-18 "§ 20.9.2 Verify")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-19 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-20 "Reference 2")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-21 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-22 "§ 20.9.5 Export Key")
- [§ 21.4.1
 Sign](#ref-for-dfn-CryptoKey-slot-algorithm-23 "§ 21.4.1 Sign")
- [§ 21.4.2
 Verify](#ref-for-dfn-CryptoKey-slot-algorithm-24 "§ 21.4.2 Verify")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-25 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-26 "Reference 2")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-27 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-28 "§ 21.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-29 "Reference 2")
- [§ 22.4.1
 Encrypt](#ref-for-dfn-CryptoKey-slot-algorithm-30 "§ 22.4.1 Encrypt")
- [§ 22.4.2
 Decrypt](#ref-for-dfn-CryptoKey-slot-algorithm-31 "§ 22.4.2 Decrypt")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-32 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-33 "Reference 2")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-34 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-35 "§ 22.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-36 "Reference 2")
- [§ 23.7.1
 Sign](#ref-for-dfn-CryptoKey-slot-algorithm-37 "§ 23.7.1 Sign")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-38 "Reference 2")
- [§ 23.7.2
 Verify](#ref-for-dfn-CryptoKey-slot-algorithm-39 "§ 23.7.2 Verify")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-40 "Reference 2")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-41 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-42 "Reference 2")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-43 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-44 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-45 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-46 "Reference 4")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-47 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-48 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-49 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-50 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-algorithm-51 "Reference 5")
 [(6)](#ref-for-dfn-CryptoKey-slot-algorithm-52 "Reference 6")
 [(7)](#ref-for-dfn-CryptoKey-slot-algorithm-53 "Reference 7")
 [(8)](#ref-for-dfn-CryptoKey-slot-algorithm-54 "Reference 8")
 [(9)](#ref-for-dfn-CryptoKey-slot-algorithm-55 "Reference 9")
 [(10)](#ref-for-dfn-CryptoKey-slot-algorithm-56 "Reference 10")
 [(11)](#ref-for-dfn-CryptoKey-slot-algorithm-57 "Reference 11")
 [(12)](#ref-for-dfn-CryptoKey-slot-algorithm-58 "Reference 12")
 [(13)](#ref-for-dfn-CryptoKey-slot-algorithm-59 "Reference 13")
 [(14)](#ref-for-dfn-CryptoKey-slot-algorithm-60 "Reference 14")
 [(15)](#ref-for-dfn-CryptoKey-slot-algorithm-61 "Reference 15")
 [(16)](#ref-for-dfn-CryptoKey-slot-algorithm-62 "Reference 16")
 [(17)](#ref-for-dfn-CryptoKey-slot-algorithm-63 "Reference 17")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-64 "§ 24.4.1 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-65 "Reference 2")
- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-algorithm-66 "§ 24.4.2 Derive Bits")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-67 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-68 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-69 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-algorithm-70 "Reference 5")
 [(6)](#ref-for-dfn-CryptoKey-slot-algorithm-71 "Reference 6")
 [(7)](#ref-for-dfn-CryptoKey-slot-algorithm-72 "Reference 7")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-73 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-74 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-75 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-76 "Reference 4")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-77 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-78 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-79 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-80 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-algorithm-81 "Reference 5")
 [(6)](#ref-for-dfn-CryptoKey-slot-algorithm-82 "Reference 6")
 [(7)](#ref-for-dfn-CryptoKey-slot-algorithm-83 "Reference 7")
 [(8)](#ref-for-dfn-CryptoKey-slot-algorithm-84 "Reference 8")
 [(9)](#ref-for-dfn-CryptoKey-slot-algorithm-85 "Reference 9")
 [(10)](#ref-for-dfn-CryptoKey-slot-algorithm-86 "Reference 10")
 [(11)](#ref-for-dfn-CryptoKey-slot-algorithm-87 "Reference 11")
 [(12)](#ref-for-dfn-CryptoKey-slot-algorithm-88 "Reference 12")
 [(13)](#ref-for-dfn-CryptoKey-slot-algorithm-89 "Reference 13")
 [(14)](#ref-for-dfn-CryptoKey-slot-algorithm-90 "Reference 14")
 [(15)](#ref-for-dfn-CryptoKey-slot-algorithm-91 "Reference 15")
 [(16)](#ref-for-dfn-CryptoKey-slot-algorithm-92 "Reference 16")
 [(17)](#ref-for-dfn-CryptoKey-slot-algorithm-93 "Reference 17")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-94 "§ 25.3.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-95 "Reference 2")
- [§ 25.3.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-96 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-97 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-98 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-99 "Reference 4")
- [§ 26.3.1 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-algorithm-100 "§ 26.3.1 Derive Bits")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-101 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-102 "Reference 3")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-103 "§ 26.3.2 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-104 "Reference 2")
- [§ 26.3.3 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-105 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-algorithm-106 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-algorithm-107 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-algorithm-108 "Reference 4")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-109 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-110 "§ 27.7.4 Import Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-111 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-112 "§ 28.4.4 Import Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-113 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-114 "§ 29.4.4 Import Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-115 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-116 "§ 30.3.4 Import Key")
- [§ 31.6.1
 Sign](#ref-for-dfn-CryptoKey-slot-algorithm-117 "§ 31.6.1 Sign")
- [§ 31.6.2
 Verify](#ref-for-dfn-CryptoKey-slot-algorithm-118 "§ 31.6.2 Verify")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-119 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-120 "§ 31.6.4 Import Key")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-algorithm-121 "§ 31.6.5 Export Key")
- [§ 33.4.2 Import
 key](#ref-for-dfn-CryptoKey-slot-algorithm-122 "§ 33.4.2 Import key")
- [§ 34.4.2 Import
 key](#ref-for-dfn-CryptoKey-slot-algorithm-123 "§ 34.4.2 Import key")

[Permalink](#dfn-CryptoKey-slot-algorithm_cached)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-CryptoKey-slot-usages)

**Referenced in:**

- [§ 13.3 CryptoKey internal
 slots](#ref-for-dfn-CryptoKey-slot-usages-1 "§ 13.3 CryptoKey internal slots")
- [§ 13.4 CryptoKey interface
 members](#ref-for-dfn-CryptoKey-slot-usages-2 "§ 13.4 CryptoKey interface members")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-CryptoKey-slot-usages-3 "§ 13.5 Serialization and deserialization steps")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-4 "Reference 2")
- [§ 14.3.1 The encrypt
 method](#ref-for-dfn-CryptoKey-slot-usages-5 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dfn-CryptoKey-slot-usages-6 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dfn-CryptoKey-slot-usages-7 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dfn-CryptoKey-slot-usages-8 "§ 14.3.4 The verify method")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-CryptoKey-slot-usages-9 "§ 14.3.6 The generateKey method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-CryptoKey-slot-usages-10 "§ 14.3.7 The deriveKey method")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-11 "Reference 2")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dfn-CryptoKey-slot-usages-12 "§ 14.3.8 The deriveBits method")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-CryptoKey-slot-usages-13 "§ 14.3.9 The importKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dfn-CryptoKey-slot-usages-14 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-CryptoKey-slot-usages-15 "§ 14.3.12 The unwrapKey method")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-16 "Reference 2")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-17 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-18 "Reference 2")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-19 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-20 "Reference 2")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-21 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-22 "Reference 2")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-23 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-24 "Reference 2")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-25 "§ 24.4.1 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-26 "Reference 2")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-27 "§ 25.3.3 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-28 "Reference 2")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-29 "§ 26.3.2 Generate Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-usages-30 "Reference 2")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-31 "§ 27.7.3 Generate Key")
- [§ 27.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-usages-32 "§ 27.7.5 Export Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-33 "§ 28.4.3 Generate Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-34 "§ 29.4.3 Generate Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-35 "§ 30.3.3 Generate Key")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-CryptoKey-slot-usages-36 "§ 31.6.3 Generate Key")

[Permalink](#dfn-CryptoKey-slot-usages_cached)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-CryptoKey-slot-handle)

**Referenced in:**

- [§ 5.1 Underlying Cryptographic
 Implementation](#ref-for-dfn-CryptoKey-slot-handle-1 "§ 5.1 Underlying Cryptographic Implementation")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-2 "Reference 2")
- [§ 13.3 CryptoKey internal
 slots](#ref-for-dfn-CryptoKey-slot-handle-3 "§ 13.3 CryptoKey internal slots")
- [§ 13.5 Serialization and deserialization
 steps](#ref-for-dfn-CryptoKey-slot-handle-4 "§ 13.5 Serialization and deserialization steps")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-5 "Reference 2")
- [§ 20.9.1 Sign](#ref-for-dfn-CryptoKey-slot-handle-6 "§ 20.9.1 Sign")
- [§ 20.9.2
 Verify](#ref-for-dfn-CryptoKey-slot-handle-7 "§ 20.9.2 Verify")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-8 "§ 20.9.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-9 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-10 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-handle-11 "Reference 4")
- [§ 21.4.1 Sign](#ref-for-dfn-CryptoKey-slot-handle-12 "§ 21.4.1 Sign")
- [§ 21.4.2
 Verify](#ref-for-dfn-CryptoKey-slot-handle-13 "§ 21.4.2 Verify")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-14 "§ 21.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-15 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-16 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-handle-17 "Reference 4")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-18 "§ 22.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-19 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-20 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-handle-21 "Reference 4")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-22 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-23 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-24 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-handle-25 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-handle-26 "Reference 5")
- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-handle-27 "§ 24.4.2 Derive Bits")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-28 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-29 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-30 "Reference 3")
 [(4)](#ref-for-dfn-CryptoKey-slot-handle-31 "Reference 4")
 [(5)](#ref-for-dfn-CryptoKey-slot-handle-32 "Reference 5")
- [§ 25.3.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-33 "§ 25.3.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-34 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-35 "Reference 3")
- [§ 26.3.1 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-handle-36 "§ 26.3.1 Derive Bits")
- [§ 26.3.4 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-37 "§ 26.3.4 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-38 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-39 "Reference 3")
- [§ 27.7.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-40 "§ 27.7.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-41 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-42 "Reference 3")
- [§ 28.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-43 "§ 28.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-44 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-45 "Reference 3")
- [§ 29.4.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-46 "§ 29.4.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-47 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-48 "Reference 3")
- [§ 30.3.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-49 "§ 30.3.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-50 "Reference 2")
 [(3)](#ref-for-dfn-CryptoKey-slot-handle-51 "Reference 3")
- [§ 31.6.1 Sign](#ref-for-dfn-CryptoKey-slot-handle-52 "§ 31.6.1 Sign")
- [§ 31.6.2
 Verify](#ref-for-dfn-CryptoKey-slot-handle-53 "§ 31.6.2 Verify")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-CryptoKey-slot-handle-54 "§ 31.6.5 Export Key")
 [(2)](#ref-for-dfn-CryptoKey-slot-handle-55 "Reference 2")
- [§ 33.4.1 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-handle-56 "§ 33.4.1 Derive Bits")
- [§ 34.4.1 Derive
 Bits](#ref-for-dfn-CryptoKey-slot-handle-57 "§ 34.4.1 Derive Bits")

[Permalink](#dom-cryptokey-type)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-cryptokey-type-1 "§ 13. CryptoKey interface")

[Permalink](#dom-cryptokey-extractable)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.2 Security considerations for
 authors](#ref-for-dom-cryptokey-extractable-1 "§ 6.2 Security considerations for authors")
- [§ 13. CryptoKey
 interface](#ref-for-dom-cryptokey-extractable-2 "§ 13. CryptoKey interface")

[Permalink](#dom-cryptokey-algorithm)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-cryptokey-algorithm-1 "§ 13. CryptoKey interface")

[Permalink](#dom-cryptokey-usages)
[exported]
[IDL](#webidl-136831043 "Jump to IDL declaration")

**Referenced in:**

- [§ 13. CryptoKey
 interface](#ref-for-dom-cryptokey-usages-1 "§ 13. CryptoKey interface")
- [§ 21.4.5 Export
 Key](#ref-for-dom-cryptokey-usages-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-cryptokey-usages-3 "§ 22.4.5 Export Key")
- [§ 23.7.5 Export
 Key](#ref-for-dom-cryptokey-usages-4 "§ 23.7.5 Export Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-cryptokey-usages-5 "§ 24.4.4 Export Key")
- [§ 25.3.5 Export
 Key](#ref-for-dom-cryptokey-usages-6 "§ 25.3.5 Export Key")
- [§ 26.3.4 Export
 Key](#ref-for-dom-cryptokey-usages-7 "§ 26.3.4 Export Key")
- [§ 28.4.5 Export
 Key](#ref-for-dom-cryptokey-usages-8 "§ 28.4.5 Export Key")
- [§ 29.4.5 Export
 Key](#ref-for-dom-cryptokey-usages-9 "§ 29.4.5 Export Key")
- [§ 30.3.5 Export
 Key](#ref-for-dom-cryptokey-usages-10 "§ 30.3.5 Export Key")
- [§ 31.6.5 Export
 Key](#ref-for-dom-cryptokey-usages-11 "§ 31.6.5 Export Key")

[Permalink](#dfn-SubtleCrypto)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-SubtleCrypto-1 "§ 1. Introduction")
- [§ 10. Crypto
 interface](#ref-for-dfn-SubtleCrypto-2 "§ 10. Crypto interface")
- [§ 10.2.1 The subtle
 attribute](#ref-for-dfn-SubtleCrypto-3 "§ 10.2.1 The subtle attribute")
- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-4 "§ 14. SubtleCrypto interface")
 [(2)](#ref-for-dfn-SubtleCrypto-5 "Reference 2")
- [§ 14.2 Task Source](#ref-for-dfn-SubtleCrypto-6 "§ 14.2 Task Source")
 [(2)](#ref-for-dfn-SubtleCrypto-7 "Reference 2")
- [§ 14.4 Exceptions](#ref-for-dfn-SubtleCrypto-8 "§ 14.4 Exceptions")
- [§ 18.1 Overview](#ref-for-dfn-SubtleCrypto-9 "§ 18.1 Overview")
- [§ 18.2.2 Supported
 Operations](#ref-for-dfn-SubtleCrypto-10 "§ 18.2.2 Supported Operations")

[Permalink](#dom-keyformat)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dom-keyformat-1 "§ 14. SubtleCrypto interface")
 [(2)](#ref-for-dom-keyformat-2 "Reference 2")
 [(3)](#ref-for-dom-keyformat-3 "Reference 3")
 [(4)](#ref-for-dom-keyformat-4 "Reference 4")
 [(5)](#ref-for-dom-keyformat-5 "Reference 5")

[Permalink](#dfn-RecognizedKeyFormats)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-keyformat-raw)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dom-keyformat-raw-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.9 The importKey
 method](#ref-for-dom-keyformat-raw-2 "§ 14.3.9 The importKey method")
- [§ 14.3.10 The exportKey
 method](#ref-for-dom-keyformat-raw-3 "§ 14.3.10 The exportKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dom-keyformat-raw-4 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dom-keyformat-raw-5 "§ 14.3.12 The unwrapKey method")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keyformat-raw-6 "§ 23.7.4 Import Key")
- [§ 23.7.5 Export
 Key](#ref-for-dom-keyformat-raw-7 "§ 23.7.5 Export Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keyformat-raw-8 "§ 24.4.3 Import Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-keyformat-raw-9 "§ 24.4.4 Export Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keyformat-raw-10 "§ 25.3.4 Import Key")
- [§ 25.3.5 Export
 Key](#ref-for-dom-keyformat-raw-11 "§ 25.3.5 Export Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keyformat-raw-12 "§ 26.3.3 Import Key")
- [§ 26.3.4 Export
 Key](#ref-for-dom-keyformat-raw-13 "§ 26.3.4 Export Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-keyformat-raw-14 "§ 27.7.4 Import Key")
- [§ 27.7.5 Export
 Key](#ref-for-dom-keyformat-raw-15 "§ 27.7.5 Export Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-keyformat-raw-16 "§ 28.4.4 Import Key")
- [§ 28.4.5 Export
 Key](#ref-for-dom-keyformat-raw-17 "§ 28.4.5 Export Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-keyformat-raw-18 "§ 29.4.4 Import Key")
- [§ 29.4.5 Export
 Key](#ref-for-dom-keyformat-raw-19 "§ 29.4.5 Export Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-keyformat-raw-20 "§ 30.3.4 Import Key")
- [§ 30.3.5 Export
 Key](#ref-for-dom-keyformat-raw-21 "§ 30.3.5 Export Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-keyformat-raw-22 "§ 31.6.4 Import Key")
- [§ 31.6.5 Export
 Key](#ref-for-dom-keyformat-raw-23 "§ 31.6.5 Export Key")
- [§ 33.4.2 Import
 key](#ref-for-dom-keyformat-raw-24 "§ 33.4.2 Import key")
- [§ 34.4.2 Import
 key](#ref-for-dom-keyformat-raw-25 "§ 34.4.2 Import key")

[Permalink](#dom-keyformat-pkcs8)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dom-keyformat-pkcs8-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.9 The importKey
 method](#ref-for-dom-keyformat-pkcs8-2 "§ 14.3.9 The importKey method")
- [§ 20.9.4 Import
 Key](#ref-for-dom-keyformat-pkcs8-3 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dom-keyformat-pkcs8-4 "§ 20.9.5 Export Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-keyformat-pkcs8-5 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-keyformat-pkcs8-6 "§ 21.4.5 Export Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-keyformat-pkcs8-7 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-keyformat-pkcs8-8 "§ 22.4.5 Export Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keyformat-pkcs8-9 "§ 23.7.4 Import Key")
- [§ 23.7.5 Export
 Key](#ref-for-dom-keyformat-pkcs8-10 "§ 23.7.5 Export Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keyformat-pkcs8-11 "§ 24.4.3 Import Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-keyformat-pkcs8-12 "§ 24.4.4 Export Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keyformat-pkcs8-13 "§ 25.3.4 Import Key")
- [§ 25.3.5 Export
 Key](#ref-for-dom-keyformat-pkcs8-14 "§ 25.3.5 Export Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keyformat-pkcs8-15 "§ 26.3.3 Import Key")
- [§ 26.3.4 Export
 Key](#ref-for-dom-keyformat-pkcs8-16 "§ 26.3.4 Export Key")

[Permalink](#dom-keyformat-spki)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dom-keyformat-spki-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.9 The importKey
 method](#ref-for-dom-keyformat-spki-2 "§ 14.3.9 The importKey method")
- [§ 20.9.4 Import
 Key](#ref-for-dom-keyformat-spki-3 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dom-keyformat-spki-4 "§ 20.9.5 Export Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-keyformat-spki-5 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-keyformat-spki-6 "§ 21.4.5 Export Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-keyformat-spki-7 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-keyformat-spki-8 "§ 22.4.5 Export Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keyformat-spki-9 "§ 23.7.4 Import Key")
- [§ 23.7.5 Export
 Key](#ref-for-dom-keyformat-spki-10 "§ 23.7.5 Export Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keyformat-spki-11 "§ 24.4.3 Import Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-keyformat-spki-12 "§ 24.4.4 Export Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keyformat-spki-13 "§ 25.3.4 Import Key")
- [§ 25.3.5 Export
 Key](#ref-for-dom-keyformat-spki-14 "§ 25.3.5 Export Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keyformat-spki-15 "§ 26.3.3 Import Key")
- [§ 26.3.4 Export
 Key](#ref-for-dom-keyformat-spki-16 "§ 26.3.4 Export Key")

[Permalink](#dom-keyformat-jwk)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dom-keyformat-jwk-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.9 The importKey
 method](#ref-for-dom-keyformat-jwk-2 "§ 14.3.9 The importKey method")
 [(2)](#ref-for-dom-keyformat-jwk-3 "Reference 2")
- [§ 14.3.10 The exportKey
 method](#ref-for-dom-keyformat-jwk-4 "§ 14.3.10 The exportKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dom-keyformat-jwk-5 "§ 14.3.11 The wrapKey method")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dom-keyformat-jwk-6 "§ 14.3.12 The unwrapKey method")
- [§ 20.9.4 Import
 Key](#ref-for-dom-keyformat-jwk-7 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dom-keyformat-jwk-8 "§ 20.9.5 Export Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-keyformat-jwk-9 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-keyformat-jwk-10 "§ 21.4.5 Export Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-keyformat-jwk-11 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-keyformat-jwk-12 "§ 22.4.5 Export Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-keyformat-jwk-13 "§ 23.7.4 Import Key")
- [§ 23.7.5 Export
 Key](#ref-for-dom-keyformat-jwk-14 "§ 23.7.5 Export Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-keyformat-jwk-15 "§ 24.4.3 Import Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-keyformat-jwk-16 "§ 24.4.4 Export Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-keyformat-jwk-17 "§ 25.3.4 Import Key")
- [§ 25.3.5 Export
 Key](#ref-for-dom-keyformat-jwk-18 "§ 25.3.5 Export Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-keyformat-jwk-19 "§ 26.3.3 Import Key")
- [§ 26.3.4 Export
 Key](#ref-for-dom-keyformat-jwk-20 "§ 26.3.4 Export Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-keyformat-jwk-21 "§ 27.7.4 Import Key")
- [§ 27.7.5 Export
 Key](#ref-for-dom-keyformat-jwk-22 "§ 27.7.5 Export Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-keyformat-jwk-23 "§ 28.4.4 Import Key")
- [§ 28.4.5 Export
 Key](#ref-for-dom-keyformat-jwk-24 "§ 28.4.5 Export Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-keyformat-jwk-25 "§ 29.4.4 Import Key")
- [§ 29.4.5 Export
 Key](#ref-for-dom-keyformat-jwk-26 "§ 29.4.5 Export Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-keyformat-jwk-27 "§ 30.3.4 Import Key")
- [§ 30.3.5 Export
 Key](#ref-for-dom-keyformat-jwk-28 "§ 30.3.5 Export Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-keyformat-jwk-29 "§ 31.6.4 Import Key")
- [§ 31.6.5 Export
 Key](#ref-for-dom-keyformat-jwk-30 "§ 31.6.5 Export Key")
- [§ B. Mapping between Algorithm and
 SubjectPublicKeyInfo](#ref-for-dom-keyformat-jwk-31 "§ B. Mapping between Algorithm and SubjectPublicKeyInfo")

[Permalink](#dfn-crypto-task-source-0)

**Referenced in:**

- [§ 14.3.1 The encrypt
 method](#ref-for-dfn-crypto-task-source-0-1 "§ 14.3.1 The encrypt method")
 [(2)](#ref-for-dfn-crypto-task-source-0-2 "Reference 2")
- [§ 14.3.2 The decrypt
 method](#ref-for-dfn-crypto-task-source-0-3 "§ 14.3.2 The decrypt method")
 [(2)](#ref-for-dfn-crypto-task-source-0-4 "Reference 2")
- [§ 14.3.3 The sign
 method](#ref-for-dfn-crypto-task-source-0-5 "§ 14.3.3 The sign method")
 [(2)](#ref-for-dfn-crypto-task-source-0-6 "Reference 2")
- [§ 14.3.4 The verify
 method](#ref-for-dfn-crypto-task-source-0-7 "§ 14.3.4 The verify method")
 [(2)](#ref-for-dfn-crypto-task-source-0-8 "Reference 2")
- [§ 14.3.5 The digest
 method](#ref-for-dfn-crypto-task-source-0-9 "§ 14.3.5 The digest method")
 [(2)](#ref-for-dfn-crypto-task-source-0-10 "Reference 2")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-crypto-task-source-0-11 "§ 14.3.6 The generateKey method")
 [(2)](#ref-for-dfn-crypto-task-source-0-12 "Reference 2")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-crypto-task-source-0-13 "§ 14.3.7 The deriveKey method")
 [(2)](#ref-for-dfn-crypto-task-source-0-14 "Reference 2")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dfn-crypto-task-source-0-15 "§ 14.3.8 The deriveBits method")
 [(2)](#ref-for-dfn-crypto-task-source-0-16 "Reference 2")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-crypto-task-source-0-17 "§ 14.3.9 The importKey method")
 [(2)](#ref-for-dfn-crypto-task-source-0-18 "Reference 2")
- [§ 14.3.10 The exportKey
 method](#ref-for-dfn-crypto-task-source-0-19 "§ 14.3.10 The exportKey method")
 [(2)](#ref-for-dfn-crypto-task-source-0-20 "Reference 2")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dfn-crypto-task-source-0-21 "§ 14.3.11 The wrapKey method")
 [(2)](#ref-for-dfn-crypto-task-source-0-22 "Reference 2")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-crypto-task-source-0-23 "§ 14.3.12 The unwrapKey method")
 [(2)](#ref-for-dfn-crypto-task-source-0-24 "Reference 2")

[Permalink](#dfn-SubtleCrypto-method-encrypt)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-encrypt-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.1 The encrypt
 method](#ref-for-dfn-SubtleCrypto-method-encrypt-2 "§ 14.3.1 The encrypt method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-encrypt-3 "Reference 2")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-encrypt-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-decrypt)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-decrypt-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.2 The decrypt
 method](#ref-for-dfn-SubtleCrypto-method-decrypt-2 "§ 14.3.2 The decrypt method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-decrypt-3 "Reference 2")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-decrypt-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-sign)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-sign-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.3 The sign
 method](#ref-for-dfn-SubtleCrypto-method-sign-2 "§ 14.3.3 The sign method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-sign-3 "Reference 2")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-sign-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-verify)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-verify-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.4 The verify
 method](#ref-for-dfn-SubtleCrypto-method-verify-2 "§ 14.3.4 The verify method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-verify-3 "Reference 2")
 [(3)](#ref-for-dfn-SubtleCrypto-method-verify-4 "Reference 3")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-verify-5 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-digest)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-digest-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.5 The digest
 method](#ref-for-dfn-SubtleCrypto-method-digest-2 "§ 14.3.5 The digest method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-digest-3 "Reference 2")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-digest-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-generateKey)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1.1 The getRandomValues
 method](#ref-for-dfn-SubtleCrypto-method-generateKey-1 "§ 10.1.1 The getRandomValues method")
- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-generateKey-2 "§ 14. SubtleCrypto interface")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-SubtleCrypto-method-generateKey-3 "§ 14.3.6 The generateKey method")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-generateKey-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-deriveKey)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-deriveKey-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-SubtleCrypto-method-deriveKey-2 "§ 14.3.7 The deriveKey method")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-deriveKey-3 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-deriveBits)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-deriveBits-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dfn-SubtleCrypto-method-deriveBits-2 "§ 14.3.8 The deriveBits method")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-deriveBits-3 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-importKey)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-importKey-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-SubtleCrypto-method-importKey-2 "§ 14.3.9 The importKey method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-importKey-3 "Reference 2")
 [(3)](#ref-for-dfn-SubtleCrypto-method-importKey-4 "Reference 3")
 [(4)](#ref-for-dfn-SubtleCrypto-method-importKey-5 "Reference 4")
 [(5)](#ref-for-dfn-SubtleCrypto-method-importKey-6 "Reference 5")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-importKey-7 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-exportKey)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.2 Security considerations for
 authors](#ref-for-dfn-SubtleCrypto-method-exportKey-1 "§ 6.2 Security considerations for authors")
- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-exportKey-2 "§ 14. SubtleCrypto interface")
- [§ 14.3.10 The exportKey
 method](#ref-for-dfn-SubtleCrypto-method-exportKey-3 "§ 14.3.10 The exportKey method")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-exportKey-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-wrapKey)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.2 Security considerations for
 authors](#ref-for-dfn-SubtleCrypto-method-wrapKey-1 "§ 6.2 Security considerations for authors")
- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-wrapKey-2 "§ 14. SubtleCrypto interface")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dfn-SubtleCrypto-method-wrapKey-3 "§ 14.3.11 The wrapKey method")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-wrapKey-4 "§ 19. Algorithm Overview")

[Permalink](#dfn-SubtleCrypto-method-unwrapKey)
[exported]
[IDL](#webidl-778491045 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-SubtleCrypto-method-unwrapKey-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-SubtleCrypto-method-unwrapKey-2 "§ 14.3.12 The unwrapKey method")
 [(2)](#ref-for-dfn-SubtleCrypto-method-unwrapKey-3 "Reference 2")
- [§ 19. Algorithm
 Overview](#ref-for-dfn-SubtleCrypto-method-unwrapKey-4 "§ 19. Algorithm Overview")

[Permalink](#dom-rsaotherprimesinfo-r)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-rsaotherprimesinfo-d)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-rsaotherprimesinfo-t)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-jsonwebkey-kty)
[exported]

**Referenced in:**

- [§ 9. Terminology](#ref-for-dom-jsonwebkey-kty-1 "§ 9. Terminology")
- [§ 20.9.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-2 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-3 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-4 "§ 22.4.4 Import Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-5 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-jsonwebkey-kty-6 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-7 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-jsonwebkey-kty-8 "§ 26.3.3 Import Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-9 "§ 27.7.4 Import Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-10 "§ 28.4.4 Import Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-11 "§ 29.4.4 Import Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-12 "§ 30.3.4 Import Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-jsonwebkey-kty-13 "§ 31.6.4 Import Key")

[Permalink](#dom-jsonwebkey-use)
[exported]

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-dom-jsonwebkey-use-1 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-jsonwebkey-use-2 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-jsonwebkey-use-3 "§ 22.4.4 Import Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-use-4 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-jsonwebkey-use-5 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-use-6 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-jsonwebkey-use-7 "§ 26.3.3 Import Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-jsonwebkey-use-8 "§ 27.7.4 Import Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-jsonwebkey-use-9 "§ 28.4.4 Import Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-jsonwebkey-use-10 "§ 29.4.4 Import Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-jsonwebkey-use-11 "§ 30.3.4 Import Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-jsonwebkey-use-12 "§ 31.6.4 Import Key")

[Permalink](#dom-jsonwebkey-key_ops)
[exported]

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-1 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-2 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-3 "§ 22.4.4 Import Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-4 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-5 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-6 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-7 "§ 26.3.3 Import Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-8 "§ 27.7.4 Import Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-9 "§ 28.4.4 Import Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-10 "§ 29.4.4 Import Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-11 "§ 30.3.4 Import Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-jsonwebkey-key_ops-12 "§ 31.6.4 Import Key")

[Permalink](#dom-jsonwebkey-alg)
[exported]

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-1 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-2 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-3 "Reference 3")
 [(4)](#ref-for-dom-jsonwebkey-alg-4 "Reference 4")
 [(5)](#ref-for-dom-jsonwebkey-alg-5 "Reference 5")
- [§ 21.4.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-6 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-7 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-8 "Reference 3")
 [(4)](#ref-for-dom-jsonwebkey-alg-9 "Reference 4")
 [(5)](#ref-for-dom-jsonwebkey-alg-10 "Reference 5")
- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-11 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-12 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-13 "Reference 3")
 [(4)](#ref-for-dom-jsonwebkey-alg-14 "Reference 4")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-15 "§ 25.3.4 Import Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-16 "§ 27.7.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-17 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-18 "Reference 3")
- [§ 28.4.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-19 "§ 28.4.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-20 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-21 "Reference 3")
- [§ 29.4.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-22 "§ 29.4.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-23 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-24 "Reference 3")
- [§ 30.3.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-25 "§ 30.3.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-26 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-27 "Reference 3")
- [§ 31.6.4 Import
 Key](#ref-for-dom-jsonwebkey-alg-28 "§ 31.6.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-alg-29 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-alg-30 "Reference 3")
 [(4)](#ref-for-dom-jsonwebkey-alg-31 "Reference 4")

[Permalink](#dom-jsonwebkey-ext)
[exported]

**Referenced in:**

- [§ 14.3.11 The wrapKey
 method](#ref-for-dom-jsonwebkey-ext-1 "§ 14.3.11 The wrapKey method")
 [(2)](#ref-for-dom-jsonwebkey-ext-2 "Reference 2")
- [§ 20.9.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-3 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-4 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-5 "§ 22.4.4 Import Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-6 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-jsonwebkey-ext-7 "§ 24.4.3 Import Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-8 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-jsonwebkey-ext-9 "§ 26.3.3 Import Key")
- [§ 27.7.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-10 "§ 27.7.4 Import Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-11 "§ 28.4.4 Import Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-12 "§ 29.4.4 Import Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-13 "§ 30.3.4 Import Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-jsonwebkey-ext-14 "§ 31.6.4 Import Key")

[Permalink](#dom-jsonwebkey-crv)
[exported]

**Referenced in:**

- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-crv-1 "§ 23.7.4 Import Key")
- [§ 23.7.5 Export
 Key](#ref-for-dom-jsonwebkey-crv-2 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dom-jsonwebkey-crv-3 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-crv-4 "Reference 3")
 [(4)](#ref-for-dom-jsonwebkey-crv-5 "Reference 4")
- [§ 24.4.3 Import
 Key](#ref-for-dom-jsonwebkey-crv-6 "§ 24.4.3 Import Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-jsonwebkey-crv-7 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dom-jsonwebkey-crv-8 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-crv-9 "Reference 3")
 [(4)](#ref-for-dom-jsonwebkey-crv-10 "Reference 4")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-crv-11 "§ 25.3.4 Import Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-jsonwebkey-crv-12 "§ 26.3.3 Import Key")

[Permalink](#dom-jsonwebkey-x)
[exported]

**Referenced in:**

- [§ 23.7.5 Export
 Key](#ref-for-dom-jsonwebkey-x-1 "§ 23.7.5 Export Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-jsonwebkey-x-2 "§ 24.4.4 Export Key")
- [§ 25.3.5 Export
 Key](#ref-for-dom-jsonwebkey-x-3 "§ 25.3.5 Export Key")
- [§ 26.3.4 Export
 Key](#ref-for-dom-jsonwebkey-x-4 "§ 26.3.4 Export Key")

[Permalink](#dom-jsonwebkey-y)
[exported]

**Referenced in:**

- [§ 23.7.5 Export
 Key](#ref-for-dom-jsonwebkey-y-1 "§ 23.7.5 Export Key")
- [§ 24.4.4 Export
 Key](#ref-for-dom-jsonwebkey-y-2 "§ 24.4.4 Export Key")

[Permalink](#dom-jsonwebkey-d)
[exported]

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-dom-jsonwebkey-d-1 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-2 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-3 "Reference 3")
- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-d-4 "§ 20.9.5 Export Key")
- [§ 21.4.4 Import
 Key](#ref-for-dom-jsonwebkey-d-5 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-6 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-7 "Reference 3")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-d-8 "§ 21.4.5 Export Key")
- [§ 22.4.4 Import
 Key](#ref-for-dom-jsonwebkey-d-9 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-10 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-11 "Reference 3")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-d-12 "§ 22.4.5 Export Key")
- [§ 23.7.4 Import
 Key](#ref-for-dom-jsonwebkey-d-13 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-14 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-15 "Reference 3")
- [§ 23.7.5 Export
 Key](#ref-for-dom-jsonwebkey-d-16 "§ 23.7.5 Export Key")
- [§ 24.4.3 Import
 Key](#ref-for-dom-jsonwebkey-d-17 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-18 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-19 "Reference 3")
- [§ 24.4.4 Export
 Key](#ref-for-dom-jsonwebkey-d-20 "§ 24.4.4 Export Key")
- [§ 25.3.4 Import
 Key](#ref-for-dom-jsonwebkey-d-21 "§ 25.3.4 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-22 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-23 "Reference 3")
- [§ 25.3.5 Export
 Key](#ref-for-dom-jsonwebkey-d-24 "§ 25.3.5 Export Key")
- [§ 26.3.3 Import
 Key](#ref-for-dom-jsonwebkey-d-25 "§ 26.3.3 Import Key")
 [(2)](#ref-for-dom-jsonwebkey-d-26 "Reference 2")
 [(3)](#ref-for-dom-jsonwebkey-d-27 "Reference 3")
- [§ 26.3.4 Export
 Key](#ref-for-dom-jsonwebkey-d-28 "§ 26.3.4 Export Key")

[Permalink](#dom-jsonwebkey-n)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-n-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-n-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-n-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-e)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-e-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-e-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-e-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-p)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-p-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-p-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-p-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-q)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-q-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-q-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-q-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-dp)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-dp-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-dp-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-dp-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-dq)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-dq-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-dq-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-dq-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-qi)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-qi-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-qi-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-qi-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-oth)
[exported]

**Referenced in:**

- [§ 20.9.5 Export
 Key](#ref-for-dom-jsonwebkey-oth-1 "§ 20.9.5 Export Key")
- [§ 21.4.5 Export
 Key](#ref-for-dom-jsonwebkey-oth-2 "§ 21.4.5 Export Key")
- [§ 22.4.5 Export
 Key](#ref-for-dom-jsonwebkey-oth-3 "§ 22.4.5 Export Key")

[Permalink](#dom-jsonwebkey-k)
[exported]

**Referenced in:**

- [§ 27.7.4 Import
 Key](#ref-for-dom-jsonwebkey-k-1 "§ 27.7.4 Import Key")
- [§ 27.7.5 Export
 Key](#ref-for-dom-jsonwebkey-k-2 "§ 27.7.5 Export Key")
- [§ 28.4.4 Import
 Key](#ref-for-dom-jsonwebkey-k-3 "§ 28.4.4 Import Key")
- [§ 28.4.5 Export
 Key](#ref-for-dom-jsonwebkey-k-4 "§ 28.4.5 Export Key")
- [§ 29.4.4 Import
 Key](#ref-for-dom-jsonwebkey-k-5 "§ 29.4.4 Import Key")
- [§ 29.4.5 Export
 Key](#ref-for-dom-jsonwebkey-k-6 "§ 29.4.5 Export Key")
- [§ 30.3.4 Import
 Key](#ref-for-dom-jsonwebkey-k-7 "§ 30.3.4 Import Key")
- [§ 30.3.5 Export
 Key](#ref-for-dom-jsonwebkey-k-8 "§ 30.3.5 Export Key")
- [§ 31.6.4 Import
 Key](#ref-for-dom-jsonwebkey-k-9 "§ 31.6.4 Import Key")
- [§ 31.6.5 Export
 Key](#ref-for-dom-jsonwebkey-k-10 "§ 31.6.5 Export Key")

[Permalink](#dfn-JsonWebKey)
[exported]
[IDL](#webidl-1155528801 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. Terminology](#ref-for-dfn-JsonWebKey-1 "§ 9. Terminology")
- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-JsonWebKey-2 "§ 14. SubtleCrypto interface")
 [(2)](#ref-for-dfn-JsonWebKey-3 "Reference 2")
- [§ 14.1 Data Types](#ref-for-dfn-JsonWebKey-4 "§ 14.1 Data Types")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-JsonWebKey-5 "§ 14.3.9 The importKey method")
 [(2)](#ref-for-dfn-JsonWebKey-6 "Reference 2")
- [§ 15. JsonWebKey
 dictionary](#ref-for-dfn-JsonWebKey-7 "§ 15. JsonWebKey dictionary")
- [§ 20.9.4 Import Key](#ref-for-dfn-JsonWebKey-8 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export Key](#ref-for-dfn-JsonWebKey-9 "§ 20.9.5 Export Key")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-JsonWebKey-10 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-JsonWebKey-11 "§ 21.4.5 Export Key")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-JsonWebKey-12 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-JsonWebKey-13 "§ 22.4.5 Export Key")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-JsonWebKey-14 "§ 23.7.4 Import Key")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-JsonWebKey-15 "§ 23.7.5 Export Key")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-JsonWebKey-16 "§ 24.4.3 Import Key")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-JsonWebKey-17 "§ 24.4.4 Export Key")
- [§ 25.3.4 Import
 Key](#ref-for-dfn-JsonWebKey-18 "§ 25.3.4 Import Key")
- [§ 25.3.5 Export
 Key](#ref-for-dfn-JsonWebKey-19 "§ 25.3.5 Export Key")
- [§ 26.3.3 Import
 Key](#ref-for-dfn-JsonWebKey-20 "§ 26.3.3 Import Key")
- [§ 26.3.4 Export
 Key](#ref-for-dfn-JsonWebKey-21 "§ 26.3.4 Export Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-JsonWebKey-22 "§ 27.7.4 Import Key")
- [§ 27.7.5 Export
 Key](#ref-for-dfn-JsonWebKey-23 "§ 27.7.5 Export Key")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-JsonWebKey-24 "§ 28.4.4 Import Key")
- [§ 28.4.5 Export
 Key](#ref-for-dfn-JsonWebKey-25 "§ 28.4.5 Export Key")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-JsonWebKey-26 "§ 29.4.4 Import Key")
- [§ 29.4.5 Export
 Key](#ref-for-dfn-JsonWebKey-27 "§ 29.4.5 Export Key")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-JsonWebKey-28 "§ 30.3.4 Import Key")
- [§ 30.3.5 Export
 Key](#ref-for-dfn-JsonWebKey-29 "§ 30.3.5 Export Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-JsonWebKey-30 "§ 31.6.4 Import Key")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-JsonWebKey-31 "§ 31.6.5 Export Key")

[Permalink](#dfn-RsaOtherPrimesInfo)
[exported]
[IDL](#webidl-1155528801 "Jump to IDL declaration")

**Referenced in:**

- [§ 15. JsonWebKey
 dictionary](#ref-for-dfn-RsaOtherPrimesInfo-1 "§ 15. JsonWebKey dictionary")
 [(2)](#ref-for-dfn-RsaOtherPrimesInfo-2 "Reference 2")

[Permalink](#dfn-BigInteger)
[exported]
[IDL](#webidl-2056593075 "Jump to IDL declaration")

**Referenced in:**

- [§ 16. BigInteger](#ref-for-dfn-BigInteger-1 "§ 16. BigInteger")
- [§ 20.3 RsaKeyGenParams
 dictionary](#ref-for-dfn-BigInteger-2 "§ 20.3 RsaKeyGenParams dictionary")
- [§ 20.6 RsaKeyAlgorithm
 dictionary](#ref-for-dfn-BigInteger-3 "§ 20.6 RsaKeyAlgorithm dictionary")
- [§ 20.9.4 Import Key](#ref-for-dfn-BigInteger-4 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import Key](#ref-for-dfn-BigInteger-5 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import Key](#ref-for-dfn-BigInteger-6 "§ 22.4.4 Import Key")

[Permalink](#dfn-CryptoKeyPair)
[exported]
[IDL](#webidl-1948446941 "Jump to IDL declaration")

**Referenced in:**

- [§ 14. SubtleCrypto
 interface](#ref-for-dfn-CryptoKeyPair-1 "§ 14. SubtleCrypto interface")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-CryptoKeyPair-2 "§ 14.3.6 The generateKey method")
- [§ 17. CryptoKeyPair
 dictionary](#ref-for-dfn-CryptoKeyPair-3 "§ 17. CryptoKeyPair dictionary")
- [§ 20.2
 Registration](#ref-for-dfn-CryptoKeyPair-4 "§ 20.2 Registration")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-5 "§ 20.9.3 Generate Key")
- [§ 21.2
 Registration](#ref-for-dfn-CryptoKeyPair-6 "§ 21.2 Registration")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-7 "§ 21.4.3 Generate Key")
- [§ 22.2
 Registration](#ref-for-dfn-CryptoKeyPair-8 "§ 22.2 Registration")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-9 "§ 22.4.3 Generate Key")
- [§ 23.2
 Registration](#ref-for-dfn-CryptoKeyPair-10 "§ 23.2 Registration")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-11 "§ 23.7.3 Generate Key")
- [§ 24.2
 Registration](#ref-for-dfn-CryptoKeyPair-12 "§ 24.2 Registration")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKeyPair-13 "§ 24.4.1 Generate Key")
- [§ 25.2
 Registration](#ref-for-dfn-CryptoKeyPair-14 "§ 25.2 Registration")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-15 "§ 25.3.3 Generate Key")
- [§ 26.2
 Registration](#ref-for-dfn-CryptoKeyPair-16 "§ 26.2 Registration")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKeyPair-17 "§ 26.3.2 Generate Key")

[Permalink](#dfn-CryptoKeyPair-publicKey)
[exported]
[IDL](#webidl-1948446941 "Jump to IDL declaration")

**Referenced in:**

- [§ 17. CryptoKeyPair
 dictionary](#ref-for-dfn-CryptoKeyPair-publicKey-1 "§ 17. CryptoKeyPair dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-2 "§ 20.9.3 Generate Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-3 "§ 21.4.3 Generate Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-4 "§ 22.4.3 Generate Key")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-5 "§ 23.7.3 Generate Key")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-6 "§ 24.4.1 Generate Key")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-7 "§ 25.3.3 Generate Key")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKeyPair-publicKey-8 "§ 26.3.2 Generate Key")

[Permalink](#dfn-CryptoKeyPair-privateKey)
[exported]
[IDL](#webidl-1948446941 "Jump to IDL declaration")

**Referenced in:**

- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-CryptoKeyPair-privateKey-1 "§ 14.3.6 The generateKey method")
- [§ 17. CryptoKeyPair
 dictionary](#ref-for-dfn-CryptoKeyPair-privateKey-2 "§ 17. CryptoKeyPair dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-3 "§ 20.9.3 Generate Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-4 "§ 21.4.3 Generate Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-5 "§ 22.4.3 Generate Key")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-6 "§ 23.7.3 Generate Key")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-7 "§ 24.4.1 Generate Key")
- [§ 25.3.3 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-8 "§ 25.3.3 Generate Key")
- [§ 26.3.2 Generate
 Key](#ref-for-dfn-CryptoKeyPair-privateKey-9 "§ 26.3.2 Generate Key")

[Permalink](#recognized-algorithm-name)

**Referenced in:**

- [§ 18.3 Specification
 Conventions](#ref-for-recognized-algorithm-name-1 "§ 18.3 Specification Conventions")
- [§ 20.2
 Registration](#ref-for-recognized-algorithm-name-2 "§ 20.2 Registration")
- [§ 21.2
 Registration](#ref-for-recognized-algorithm-name-3 "§ 21.2 Registration")
- [§ 22.2
 Registration](#ref-for-recognized-algorithm-name-4 "§ 22.2 Registration")
- [§ 23.2
 Registration](#ref-for-recognized-algorithm-name-5 "§ 23.2 Registration")
- [§ 24.2
 Registration](#ref-for-recognized-algorithm-name-6 "§ 24.2 Registration")
- [§ 25.2
 Registration](#ref-for-recognized-algorithm-name-7 "§ 25.2 Registration")
- [§ 26.2
 Registration](#ref-for-recognized-algorithm-name-8 "§ 26.2 Registration")
- [§ 27.2
 Registration](#ref-for-recognized-algorithm-name-9 "§ 27.2 Registration")
- [§ 28.2
 Registration](#ref-for-recognized-algorithm-name-10 "§ 28.2 Registration")
- [§ 29.2
 Registration](#ref-for-recognized-algorithm-name-11 "§ 29.2 Registration")
- [§ 30.2
 Registration](#ref-for-recognized-algorithm-name-12 "§ 30.2 Registration")
- [§ 31.2
 Registration](#ref-for-recognized-algorithm-name-13 "§ 31.2 Registration")
- [§ 32.2
 Registration](#ref-for-recognized-algorithm-name-14 "§ 32.2 Registration")
- [§ 33.2
 Registration](#ref-for-recognized-algorithm-name-15 "§ 33.2 Registration")
- [§ 34.2
 Registration](#ref-for-recognized-algorithm-name-16 "§ 34.2 Registration")

[Permalink](#supported-operation)

**Referenced in:**

- [§ 18.2.3
 Normalization](#ref-for-supported-operation-1 "§ 18.2.3 Normalization")
- [§ 18.3 Specification
 Conventions](#ref-for-supported-operation-2 "§ 18.3 Specification Conventions")
 [(2)](#ref-for-supported-operation-3 "Reference 2")
- [§ 18.4.2 Internal State
 Objects](#ref-for-supported-operation-4 "§ 18.4.2 Internal State Objects")

[Permalink](#supported-operations)

**Referenced in:**

- [§ 20.2
 Registration](#ref-for-supported-operations-1 "§ 20.2 Registration")
- [§ 21.2
 Registration](#ref-for-supported-operations-2 "§ 21.2 Registration")
- [§ 22.2
 Registration](#ref-for-supported-operations-3 "§ 22.2 Registration")
- [§ 23.2
 Registration](#ref-for-supported-operations-4 "§ 23.2 Registration")
- [§ 24.2
 Registration](#ref-for-supported-operations-5 "§ 24.2 Registration")
- [§ 25.2
 Registration](#ref-for-supported-operations-6 "§ 25.2 Registration")
- [§ 26.2
 Registration](#ref-for-supported-operations-7 "§ 26.2 Registration")
- [§ 27.2
 Registration](#ref-for-supported-operations-8 "§ 27.2 Registration")
- [§ 28.2
 Registration](#ref-for-supported-operations-9 "§ 28.2 Registration")
- [§ 29.2
 Registration](#ref-for-supported-operations-10 "§ 29.2 Registration")
- [§ 30.2
 Registration](#ref-for-supported-operations-11 "§ 30.2 Registration")
- [§ 31.2
 Registration](#ref-for-supported-operations-12 "§ 31.2 Registration")
- [§ 32.2
 Registration](#ref-for-supported-operations-13 "§ 32.2 Registration")
- [§ 33.2
 Registration](#ref-for-supported-operations-14 "§ 33.2 Registration")
- [§ 34.2
 Registration](#ref-for-supported-operations-15 "§ 34.2 Registration")

[Permalink](#algorithm-specific-params)

**Referenced in:**

- [§ 20.2
 Registration](#ref-for-algorithm-specific-params-1 "§ 20.2 Registration")
- [§ 21.2
 Registration](#ref-for-algorithm-specific-params-2 "§ 21.2 Registration")
- [§ 22.2
 Registration](#ref-for-algorithm-specific-params-3 "§ 22.2 Registration")
- [§ 23.2
 Registration](#ref-for-algorithm-specific-params-4 "§ 23.2 Registration")
- [§ 24.2
 Registration](#ref-for-algorithm-specific-params-5 "§ 24.2 Registration")
- [§ 25.2
 Registration](#ref-for-algorithm-specific-params-6 "§ 25.2 Registration")
- [§ 26.2
 Registration](#ref-for-algorithm-specific-params-7 "§ 26.2 Registration")
- [§ 27.2
 Registration](#ref-for-algorithm-specific-params-8 "§ 27.2 Registration")
- [§ 28.2
 Registration](#ref-for-algorithm-specific-params-9 "§ 28.2 Registration")
- [§ 29.2
 Registration](#ref-for-algorithm-specific-params-10 "§ 29.2 Registration")
- [§ 30.2
 Registration](#ref-for-algorithm-specific-params-11 "§ 30.2 Registration")
- [§ 31.2
 Registration](#ref-for-algorithm-specific-params-12 "§ 31.2 Registration")
- [§ 32.2
 Registration](#ref-for-algorithm-specific-params-13 "§ 32.2 Registration")
- [§ 33.2
 Registration](#ref-for-algorithm-specific-params-14 "§ 33.2 Registration")
- [§ 34.2
 Registration](#ref-for-algorithm-specific-params-15 "§ 34.2 Registration")

[Permalink](#algorithm-result)

**Referenced in:**

- [§ 20.2
 Registration](#ref-for-algorithm-result-1 "§ 20.2 Registration")
- [§ 21.2
 Registration](#ref-for-algorithm-result-2 "§ 21.2 Registration")
- [§ 22.2
 Registration](#ref-for-algorithm-result-3 "§ 22.2 Registration")
- [§ 23.2
 Registration](#ref-for-algorithm-result-4 "§ 23.2 Registration")
- [§ 24.2
 Registration](#ref-for-algorithm-result-5 "§ 24.2 Registration")
- [§ 25.2
 Registration](#ref-for-algorithm-result-6 "§ 25.2 Registration")
- [§ 26.2
 Registration](#ref-for-algorithm-result-7 "§ 26.2 Registration")
- [§ 27.2
 Registration](#ref-for-algorithm-result-8 "§ 27.2 Registration")
- [§ 28.2
 Registration](#ref-for-algorithm-result-9 "§ 28.2 Registration")
- [§ 29.2
 Registration](#ref-for-algorithm-result-10 "§ 29.2 Registration")
- [§ 30.2
 Registration](#ref-for-algorithm-result-11 "§ 30.2 Registration")
- [§ 31.2
 Registration](#ref-for-algorithm-result-12 "§ 31.2 Registration")
- [§ 32.2
 Registration](#ref-for-algorithm-result-13 "§ 32.2 Registration")
- [§ 33.2
 Registration](#ref-for-algorithm-result-14 "§ 33.2 Registration")
- [§ 34.2
 Registration](#ref-for-algorithm-result-15 "§ 34.2 Registration")

[Permalink](#dfn-algorithm-normalization)

**Referenced in:**

- [§ 18.2.3
 Normalization](#ref-for-dfn-algorithm-normalization-1 "§ 18.2.3 Normalization")
- [§ 18.3 Specification
 Conventions](#ref-for-dfn-algorithm-normalization-2 "§ 18.3 Specification Conventions")

[Permalink](#dfn-supportedAlgorithms)

**Referenced in:**

- [§ 18.4.2 Internal State
 Objects](#ref-for-dfn-supportedAlgorithms-1 "§ 18.4.2 Internal State Objects")
- [§ 18.4.3 Defining an
 Algorithm](#ref-for-dfn-supportedAlgorithms-2 "§ 18.4.3 Defining an Algorithm")
- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dfn-supportedAlgorithms-3 "§ 18.4.4 Normalizing an algorithm")

[Permalink](#concept-define-an-algorithm)

**Referenced in:**

- [§ 18.3 Specification
 Conventions](#ref-for-concept-define-an-algorithm-1 "§ 18.3 Specification Conventions")

[Permalink](#dfn-normalize-an-algorithm)

**Referenced in:**

- [§ 14.3.1 The encrypt
 method](#ref-for-dfn-normalize-an-algorithm-1 "§ 14.3.1 The encrypt method")
- [§ 14.3.2 The decrypt
 method](#ref-for-dfn-normalize-an-algorithm-2 "§ 14.3.2 The decrypt method")
- [§ 14.3.3 The sign
 method](#ref-for-dfn-normalize-an-algorithm-3 "§ 14.3.3 The sign method")
- [§ 14.3.4 The verify
 method](#ref-for-dfn-normalize-an-algorithm-4 "§ 14.3.4 The verify method")
- [§ 14.3.5 The digest
 method](#ref-for-dfn-normalize-an-algorithm-5 "§ 14.3.5 The digest method")
- [§ 14.3.6 The generateKey
 method](#ref-for-dfn-normalize-an-algorithm-6 "§ 14.3.6 The generateKey method")
- [§ 14.3.7 The deriveKey
 method](#ref-for-dfn-normalize-an-algorithm-7 "§ 14.3.7 The deriveKey method")
 [(2)](#ref-for-dfn-normalize-an-algorithm-8 "Reference 2")
 [(3)](#ref-for-dfn-normalize-an-algorithm-9 "Reference 3")
- [§ 14.3.8 The deriveBits
 method](#ref-for-dfn-normalize-an-algorithm-10 "§ 14.3.8 The deriveBits method")
- [§ 14.3.9 The importKey
 method](#ref-for-dfn-normalize-an-algorithm-11 "§ 14.3.9 The importKey method")
- [§ 14.3.11 The wrapKey
 method](#ref-for-dfn-normalize-an-algorithm-12 "§ 14.3.11 The wrapKey method")
 [(2)](#ref-for-dfn-normalize-an-algorithm-13 "Reference 2")
- [§ 14.3.12 The unwrapKey
 method](#ref-for-dfn-normalize-an-algorithm-14 "§ 14.3.12 The unwrapKey method")
 [(2)](#ref-for-dfn-normalize-an-algorithm-15 "Reference 2")
 [(3)](#ref-for-dfn-normalize-an-algorithm-16 "Reference 3")
- [§ 18.4.4 Normalizing an
 algorithm](#ref-for-dfn-normalize-an-algorithm-17 "§ 18.4.4 Normalizing an algorithm")
 [(2)](#ref-for-dfn-normalize-an-algorithm-18 "Reference 2")
 [(3)](#ref-for-dfn-normalize-an-algorithm-19 "Reference 3")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-normalize-an-algorithm-20 "§ 20.9.4 Import Key")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-normalize-an-algorithm-21 "§ 21.4.4 Import Key")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-normalize-an-algorithm-22 "§ 22.4.4 Import Key")

[Permalink](#dfn-rsa-ssa-extended-import-steps)

**Referenced in:**

- [§ 20.9.4 Import
 Key](#ref-for-dfn-rsa-ssa-extended-import-steps-1 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-rsa-ssa-extended-import-steps-2 "§ 20.9.5 Export Key")

[Permalink](#dfn-rsa-ssa-extended-export-steps)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-RsaKeyGenParams)
[exported]
[IDL](#webidl-815829470 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.3 RsaKeyGenParams
 dictionary](#ref-for-dfn-RsaKeyGenParams-1 "§ 20.3 RsaKeyGenParams dictionary")
- [§ 20.4 RsaHashedKeyGenParams
 dictionary](#ref-for-dfn-RsaKeyGenParams-2 "§ 20.4 RsaHashedKeyGenParams dictionary")
- [§ 20.5 RSA key generation parameter
 validation](#ref-for-dfn-RsaKeyGenParams-3 "§ 20.5 RSA key generation parameter validation")

[Permalink](#dfn-RsaKeyGenParams-modulusLength)
[exported]
[IDL](#webidl-815829470 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.3 RsaKeyGenParams
 dictionary](#ref-for-dfn-RsaKeyGenParams-modulusLength-1 "§ 20.3 RsaKeyGenParams dictionary")
- [§ 20.5 RSA key generation parameter
 validation](#ref-for-dfn-RsaKeyGenParams-modulusLength-2 "§ 20.5 RSA key generation parameter validation")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaKeyGenParams-modulusLength-3 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-RsaKeyGenParams-modulusLength-4 "Reference 2")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaKeyGenParams-modulusLength-5 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-RsaKeyGenParams-modulusLength-6 "Reference 2")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaKeyGenParams-modulusLength-7 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-RsaKeyGenParams-modulusLength-8 "Reference 2")

[Permalink](#dfn-RsaKeyGenParams-publicExponent)
[exported]
[IDL](#webidl-815829470 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.3 RsaKeyGenParams
 dictionary](#ref-for-dfn-RsaKeyGenParams-publicExponent-1 "§ 20.3 RsaKeyGenParams dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaKeyGenParams-publicExponent-2 "§ 20.9.3 Generate Key")
 [(2)](#ref-for-dfn-RsaKeyGenParams-publicExponent-3 "Reference 2")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaKeyGenParams-publicExponent-4 "§ 21.4.3 Generate Key")
 [(2)](#ref-for-dfn-RsaKeyGenParams-publicExponent-5 "Reference 2")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaKeyGenParams-publicExponent-6 "§ 22.4.3 Generate Key")
 [(2)](#ref-for-dfn-RsaKeyGenParams-publicExponent-7 "Reference 2")

[Permalink](#dfn-RsaHashedKeyGenParams)
[exported]
[IDL](#webidl-526256594 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.2
 Registration](#ref-for-dfn-RsaHashedKeyGenParams-1 "§ 20.2 Registration")
- [§ 20.4 RsaHashedKeyGenParams
 dictionary](#ref-for-dfn-RsaHashedKeyGenParams-2 "§ 20.4 RsaHashedKeyGenParams dictionary")
- [§ 21.2
 Registration](#ref-for-dfn-RsaHashedKeyGenParams-3 "§ 21.2 Registration")
- [§ 22.2
 Registration](#ref-for-dfn-RsaHashedKeyGenParams-4 "§ 22.2 Registration")

[Permalink](#dfn-RsaHashedKeyGenParams-hash)
[exported]
[IDL](#webidl-526256594 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.4 RsaHashedKeyGenParams
 dictionary](#ref-for-dfn-RsaHashedKeyGenParams-hash-1 "§ 20.4 RsaHashedKeyGenParams dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyGenParams-hash-2 "§ 20.9.3 Generate Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyGenParams-hash-3 "§ 21.4.3 Generate Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyGenParams-hash-4 "§ 22.4.3 Generate Key")

[Permalink](#dfn-validate-rsa-key-generation-parameters)

**Referenced in:**

- [§ 20.9.3 Generate
 Key](#ref-for-dfn-validate-rsa-key-generation-parameters-1 "§ 20.9.3 Generate Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-validate-rsa-key-generation-parameters-2 "§ 21.4.3 Generate Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-validate-rsa-key-generation-parameters-3 "§ 22.4.3 Generate Key")

[Permalink](#dfn-RsaKeyAlgorithm)
[exported]
[IDL](#webidl-1451449080 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.6 RsaKeyAlgorithm
 dictionary](#ref-for-dfn-RsaKeyAlgorithm-1 "§ 20.6 RsaKeyAlgorithm dictionary")
- [§ 20.7 RsaHashedKeyAlgorithm
 dictionary](#ref-for-dfn-RsaKeyAlgorithm-2 "§ 20.7 RsaHashedKeyAlgorithm dictionary")

[Permalink](#dfn-RsaKeyAlgorithm-modulusLength)
[exported]
[IDL](#webidl-1451449080 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.6 RsaKeyAlgorithm
 dictionary](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-1 "§ 20.6 RsaKeyAlgorithm dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-2 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-3 "§ 20.9.4 Import Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-4 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-5 "§ 21.4.4 Import Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-6 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-RsaKeyAlgorithm-modulusLength-7 "§ 22.4.4 Import Key")

[Permalink](#dfn-RsaKeyAlgorithm-publicExponent)
[exported]
[IDL](#webidl-1451449080 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.6 RsaKeyAlgorithm
 dictionary](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-1 "§ 20.6 RsaKeyAlgorithm dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-2 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-3 "§ 20.9.4 Import Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-4 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-5 "§ 21.4.4 Import Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-6 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-RsaKeyAlgorithm-publicExponent-7 "§ 22.4.4 Import Key")

[Permalink](#dfn-RsaHashedKeyAlgorithm)
[exported]
[IDL](#webidl-756923192 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.7 RsaHashedKeyAlgorithm
 dictionary](#ref-for-dfn-RsaHashedKeyAlgorithm-1 "§ 20.7 RsaHashedKeyAlgorithm dictionary")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-2 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-3 "§ 20.9.4 Import Key")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-4 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-5 "§ 21.4.4 Import Key")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-6 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-7 "§ 22.4.4 Import Key")

[Permalink](#dfn-RsaHashedKeyAlgorithm-hash)
[exported]
[IDL](#webidl-756923192 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.7 RsaHashedKeyAlgorithm
 dictionary](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-1 "§ 20.7 RsaHashedKeyAlgorithm dictionary")
- [§ 20.9.1
 Sign](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-2 "§ 20.9.1 Sign")
- [§ 20.9.2
 Verify](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-3 "§ 20.9.2 Verify")
- [§ 20.9.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-4 "§ 20.9.3 Generate Key")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-5 "§ 20.9.4 Import Key")
- [§ 20.9.5 Export
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-6 "§ 20.9.5 Export Key")
- [§ 21.4.1
 Sign](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-7 "§ 21.4.1 Sign")
- [§ 21.4.2
 Verify](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-8 "§ 21.4.2 Verify")
- [§ 21.4.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-9 "§ 21.4.3 Generate Key")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-10 "§ 21.4.4 Import Key")
- [§ 21.4.5 Export
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-11 "§ 21.4.5 Export Key")
 [(2)](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-12 "Reference 2")
- [§ 22.4.1
 Encrypt](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-13 "§ 22.4.1 Encrypt")
- [§ 22.4.2
 Decrypt](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-14 "§ 22.4.2 Decrypt")
- [§ 22.4.3 Generate
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-15 "§ 22.4.3 Generate Key")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-16 "§ 22.4.4 Import Key")
- [§ 22.4.5 Export
 Key](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-17 "§ 22.4.5 Export Key")
 [(2)](#ref-for-dfn-RsaHashedKeyAlgorithm-hash-18 "Reference 2")

[Permalink](#dfn-RsaHashedImportParams)
[exported]
[IDL](#webidl-1001762278 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.2
 Registration](#ref-for-dfn-RsaHashedImportParams-1 "§ 20.2 Registration")
- [§ 20.8 RsaHashedImportParams
 dictionary](#ref-for-dfn-RsaHashedImportParams-2 "§ 20.8 RsaHashedImportParams dictionary")
- [§ 21.2
 Registration](#ref-for-dfn-RsaHashedImportParams-3 "§ 21.2 Registration")
- [§ 22.2
 Registration](#ref-for-dfn-RsaHashedImportParams-4 "§ 22.2 Registration")

[Permalink](#dfn-RsaHashedImportParams-hash)
[exported]
[IDL](#webidl-1001762278 "Jump to IDL declaration")

**Referenced in:**

- [§ 20.8 RsaHashedImportParams
 dictionary](#ref-for-dfn-RsaHashedImportParams-hash-1 "§ 20.8 RsaHashedImportParams dictionary")
- [§ 20.9.4 Import
 Key](#ref-for-dfn-RsaHashedImportParams-hash-2 "§ 20.9.4 Import Key")
 [(2)](#ref-for-dfn-RsaHashedImportParams-hash-3 "Reference 2")
- [§ 21.4.4 Import
 Key](#ref-for-dfn-RsaHashedImportParams-hash-4 "§ 21.4.4 Import Key")
 [(2)](#ref-for-dfn-RsaHashedImportParams-hash-5 "Reference 2")
- [§ 22.4.4 Import
 Key](#ref-for-dfn-RsaHashedImportParams-hash-6 "§ 22.4.4 Import Key")
 [(2)](#ref-for-dfn-RsaHashedImportParams-hash-7 "Reference 2")

[Permalink](#dfn-rsa-pss-extended-import-steps)

**Referenced in:**

- [§ 21.4.4 Import
 Key](#ref-for-dfn-rsa-pss-extended-import-steps-1 "§ 21.4.4 Import Key")

[Permalink](#dfn-rsa-pss-extended-export-steps)

**Referenced in:**

- [§ 21.4.5 Export
 Key](#ref-for-dfn-rsa-pss-extended-export-steps-1 "§ 21.4.5 Export Key")

[Permalink](#dfn-RsaPssParams)
[exported]
[IDL](#webidl-1995992012 "Jump to IDL declaration")

**Referenced in:**

- [§ 21.2
 Registration](#ref-for-dfn-RsaPssParams-1 "§ 21.2 Registration")
 [(2)](#ref-for-dfn-RsaPssParams-2 "Reference 2")
- [§ 21.3 RsaPssParams
 dictionary](#ref-for-dfn-RsaPssParams-3 "§ 21.3 RsaPssParams dictionary")

[Permalink](#dfn-RsaPssParams-saltLength)
[exported]
[IDL](#webidl-1995992012 "Jump to IDL declaration")

**Referenced in:**

- [§ 21.3 RsaPssParams
 dictionary](#ref-for-dfn-RsaPssParams-saltLength-1 "§ 21.3 RsaPssParams dictionary")
- [§ 21.4.1
 Sign](#ref-for-dfn-RsaPssParams-saltLength-2 "§ 21.4.1 Sign")
- [§ 21.4.2
 Verify](#ref-for-dfn-RsaPssParams-saltLength-3 "§ 21.4.2 Verify")

[Permalink](#dfn-rsa-oaep-extended-import-steps)

**Referenced in:**

- [§ 22.4.4 Import
 Key](#ref-for-dfn-rsa-oaep-extended-import-steps-1 "§ 22.4.4 Import Key")

[Permalink](#dfn-rsa-oaep-extended-export-steps)

**Referenced in:**

- [§ 22.4.5 Export
 Key](#ref-for-dfn-rsa-oaep-extended-export-steps-1 "§ 22.4.5 Export Key")

[Permalink](#dfn-RsaOaepParams)
[exported]
[IDL](#webidl-1133829035 "Jump to IDL declaration")

**Referenced in:**

- [§ 22.2
 Registration](#ref-for-dfn-RsaOaepParams-1 "§ 22.2 Registration")
 [(2)](#ref-for-dfn-RsaOaepParams-2 "Reference 2")
- [§ 22.3 RsaOaepParams
 dictionary](#ref-for-dfn-RsaOaepParams-3 "§ 22.3 RsaOaepParams dictionary")

[Permalink](#dfn-RsaOaepParams-label)
[exported]
[IDL](#webidl-1133829035 "Jump to IDL declaration")

**Referenced in:**

- [§ 22.3 RsaOaepParams
 dictionary](#ref-for-dfn-RsaOaepParams-label-1 "§ 22.3 RsaOaepParams dictionary")
- [§ 22.4.1
 Encrypt](#ref-for-dfn-RsaOaepParams-label-2 "§ 22.4.1 Encrypt")
 [(2)](#ref-for-dfn-RsaOaepParams-label-3 "Reference 2")
- [§ 22.4.2
 Decrypt](#ref-for-dfn-RsaOaepParams-label-4 "§ 22.4.2 Decrypt")
 [(2)](#ref-for-dfn-RsaOaepParams-label-5 "Reference 2")

[Permalink](#dfn-ecdsa-extended-namedcurve-values)

**Referenced in:**

- [§ 23.4 EcKeyGenParams
 dictionary](#ref-for-dfn-ecdsa-extended-namedcurve-values-1 "§ 23.4 EcKeyGenParams dictionary")

[Permalink](#dfn-ecdsa-extended-signature-steps)

**Referenced in:**

- [§ 23.7.1
 Sign](#ref-for-dfn-ecdsa-extended-signature-steps-1 "§ 23.7.1 Sign")

[Permalink](#dfn-ecdsa-extended-verification-steps)

**Referenced in:**

- [§ 23.7.2
 Verify](#ref-for-dfn-ecdsa-extended-verification-steps-1 "§ 23.7.2 Verify")

[Permalink](#dfn-ecdsa-extended-generation-steps)

**Referenced in:**

- [§ 23.7.3 Generate
 Key](#ref-for-dfn-ecdsa-extended-generation-steps-1 "§ 23.7.3 Generate Key")

[Permalink](#dfn-ecdsa-extended-import-steps)

**Referenced in:**

- [§ 23.7.4 Import
 Key](#ref-for-dfn-ecdsa-extended-import-steps-1 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-ecdsa-extended-import-steps-2 "Reference 2")
 [(3)](#ref-for-dfn-ecdsa-extended-import-steps-3 "Reference 3")

[Permalink](#dfn-ecdsa-extended-export-steps)

**Referenced in:**

- [§ 23.7.5 Export
 Key](#ref-for-dfn-ecdsa-extended-export-steps-1 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dfn-ecdsa-extended-export-steps-2 "Reference 2")
 [(3)](#ref-for-dfn-ecdsa-extended-export-steps-3 "Reference 3")

[Permalink](#dfn-EcdsaParams)
[exported]
[IDL](#webidl-817369052 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.2
 Registration](#ref-for-dfn-EcdsaParams-1 "§ 23.2 Registration")
 [(2)](#ref-for-dfn-EcdsaParams-2 "Reference 2")
- [§ 23.3 EcdsaParams
 dictionary](#ref-for-dfn-EcdsaParams-3 "§ 23.3 EcdsaParams dictionary")

[Permalink](#dfn-EcdsaParams-hash)
[exported]
[IDL](#webidl-817369052 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.3 EcdsaParams
 dictionary](#ref-for-dfn-EcdsaParams-hash-1 "§ 23.3 EcdsaParams dictionary")
- [§ 23.7.1 Sign](#ref-for-dfn-EcdsaParams-hash-2 "§ 23.7.1 Sign")
- [§ 23.7.2 Verify](#ref-for-dfn-EcdsaParams-hash-3 "§ 23.7.2 Verify")

[Permalink](#dfn-EcKeyGenParams)
[exported]
[IDL](#webidl-807795004 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.2
 Registration](#ref-for-dfn-EcKeyGenParams-1 "§ 23.2 Registration")
- [§ 23.4 EcKeyGenParams
 dictionary](#ref-for-dfn-EcKeyGenParams-2 "§ 23.4 EcKeyGenParams dictionary")
 [(2)](#ref-for-dfn-EcKeyGenParams-3 "Reference 2")
- [§ 24.2
 Registration](#ref-for-dfn-EcKeyGenParams-4 "§ 24.2 Registration")

[Permalink](#dfn-NamedCurve)
[exported]
[IDL](#webidl-807795004 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.4 EcKeyGenParams
 dictionary](#ref-for-dfn-NamedCurve-1 "§ 23.4 EcKeyGenParams dictionary")
 [(2)](#ref-for-dfn-NamedCurve-2 "Reference 2")
- [§ 23.5 EcKeyAlgorithm
 dictionary](#ref-for-dfn-NamedCurve-3 "§ 23.5 EcKeyAlgorithm dictionary")
- [§ 23.6 EcKeyImportParams
 dictionary](#ref-for-dfn-NamedCurve-4 "§ 23.6 EcKeyImportParams dictionary")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-NamedCurve-5 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import Key](#ref-for-dfn-NamedCurve-6 "§ 23.7.4 Import Key")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-NamedCurve-7 "§ 24.4.1 Generate Key")
- [§ 24.4.3 Import Key](#ref-for-dfn-NamedCurve-8 "§ 24.4.3 Import Key")

[Permalink](#dfn-EcKeyGenParams-namedCurve)
[exported]
[IDL](#webidl-807795004 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.4 EcKeyGenParams
 dictionary](#ref-for-dfn-EcKeyGenParams-namedCurve-1 "§ 23.4 EcKeyGenParams dictionary")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-EcKeyGenParams-namedCurve-2 "§ 23.7.3 Generate Key")
 [(2)](#ref-for-dfn-EcKeyGenParams-namedCurve-3 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyGenParams-namedCurve-4 "Reference 3")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-EcKeyGenParams-namedCurve-5 "§ 24.4.1 Generate Key")
 [(2)](#ref-for-dfn-EcKeyGenParams-namedCurve-6 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyGenParams-namedCurve-7 "Reference 3")

[Permalink](#dfn-EcKeyAlgorithm)
[exported]
[IDL](#webidl-1701110857 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.5 EcKeyAlgorithm
 dictionary](#ref-for-dfn-EcKeyAlgorithm-1 "§ 23.5 EcKeyAlgorithm dictionary")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-EcKeyAlgorithm-2 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-EcKeyAlgorithm-3 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-4 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-5 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-6 "Reference 4")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-EcKeyAlgorithm-7 "§ 24.4.1 Generate Key")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-EcKeyAlgorithm-8 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-9 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-10 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-11 "Reference 4")

[Permalink](#dfn-EcKeyAlgorithm-namedCurve)
[exported]
[IDL](#webidl-1701110857 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.5 EcKeyAlgorithm
 dictionary](#ref-for-dfn-EcKeyAlgorithm-namedCurve-1 "§ 23.5 EcKeyAlgorithm dictionary")
- [§ 23.7.1
 Sign](#ref-for-dfn-EcKeyAlgorithm-namedCurve-2 "§ 23.7.1 Sign")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-3 "Reference 2")
- [§ 23.7.2
 Verify](#ref-for-dfn-EcKeyAlgorithm-namedCurve-4 "§ 23.7.2 Verify")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-5 "Reference 2")
- [§ 23.7.3 Generate
 Key](#ref-for-dfn-EcKeyAlgorithm-namedCurve-6 "§ 23.7.3 Generate Key")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-EcKeyAlgorithm-namedCurve-7 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-8 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-9 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-10 "Reference 4")
- [§ 23.7.5 Export
 Key](#ref-for-dfn-EcKeyAlgorithm-namedCurve-11 "§ 23.7.5 Export Key")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-12 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-13 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-14 "Reference 4")
 [(5)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-15 "Reference 5")
 [(6)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-16 "Reference 6")
 [(7)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-17 "Reference 7")
 [(8)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-18 "Reference 8")
 [(9)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-19 "Reference 9")
 [(10)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-20 "Reference 10")
 [(11)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-21 "Reference 11")
 [(12)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-22 "Reference 12")
 [(13)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-23 "Reference 13")
 [(14)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-24 "Reference 14")
 [(15)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-25 "Reference 15")
 [(16)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-26 "Reference 16")
 [(17)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-27 "Reference 17")
- [§ 24.4.1 Generate
 Key](#ref-for-dfn-EcKeyAlgorithm-namedCurve-28 "§ 24.4.1 Generate Key")
- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-EcKeyAlgorithm-namedCurve-29 "§ 24.4.2 Derive Bits")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-30 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-31 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-32 "Reference 4")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-EcKeyAlgorithm-namedCurve-33 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-34 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-35 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-36 "Reference 4")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-EcKeyAlgorithm-namedCurve-37 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-38 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-39 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-40 "Reference 4")
 [(5)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-41 "Reference 5")
 [(6)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-42 "Reference 6")
 [(7)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-43 "Reference 7")
 [(8)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-44 "Reference 8")
 [(9)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-45 "Reference 9")
 [(10)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-46 "Reference 10")
 [(11)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-47 "Reference 11")
 [(12)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-48 "Reference 12")
 [(13)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-49 "Reference 13")
 [(14)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-50 "Reference 14")
 [(15)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-51 "Reference 15")
 [(16)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-52 "Reference 16")
 [(17)](#ref-for-dfn-EcKeyAlgorithm-namedCurve-53 "Reference 17")

[Permalink](#dfn-EcKeyImportParams)
[exported]
[IDL](#webidl-410131068 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.2
 Registration](#ref-for-dfn-EcKeyImportParams-1 "§ 23.2 Registration")
- [§ 23.6 EcKeyImportParams
 dictionary](#ref-for-dfn-EcKeyImportParams-2 "§ 23.6 EcKeyImportParams dictionary")
- [§ 24.2
 Registration](#ref-for-dfn-EcKeyImportParams-3 "§ 24.2 Registration")

[Permalink](#dfn-EcKeyImportParams-namedCurve)
[exported]
[IDL](#webidl-410131068 "Jump to IDL declaration")

**Referenced in:**

- [§ 23.6 EcKeyImportParams
 dictionary](#ref-for-dfn-EcKeyImportParams-namedCurve-1 "§ 23.6 EcKeyImportParams dictionary")
- [§ 23.7.4 Import
 Key](#ref-for-dfn-EcKeyImportParams-namedCurve-2 "§ 23.7.4 Import Key")
 [(2)](#ref-for-dfn-EcKeyImportParams-namedCurve-3 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyImportParams-namedCurve-4 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyImportParams-namedCurve-5 "Reference 4")
 [(5)](#ref-for-dfn-EcKeyImportParams-namedCurve-6 "Reference 5")
 [(6)](#ref-for-dfn-EcKeyImportParams-namedCurve-7 "Reference 6")
 [(7)](#ref-for-dfn-EcKeyImportParams-namedCurve-8 "Reference 7")
 [(8)](#ref-for-dfn-EcKeyImportParams-namedCurve-9 "Reference 8")
 [(9)](#ref-for-dfn-EcKeyImportParams-namedCurve-10 "Reference 9")
 [(10)](#ref-for-dfn-EcKeyImportParams-namedCurve-11 "Reference 10")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-EcKeyImportParams-namedCurve-12 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-EcKeyImportParams-namedCurve-13 "Reference 2")
 [(3)](#ref-for-dfn-EcKeyImportParams-namedCurve-14 "Reference 3")
 [(4)](#ref-for-dfn-EcKeyImportParams-namedCurve-15 "Reference 4")
 [(5)](#ref-for-dfn-EcKeyImportParams-namedCurve-16 "Reference 5")
 [(6)](#ref-for-dfn-EcKeyImportParams-namedCurve-17 "Reference 6")
 [(7)](#ref-for-dfn-EcKeyImportParams-namedCurve-18 "Reference 7")
 [(8)](#ref-for-dfn-EcKeyImportParams-namedCurve-19 "Reference 8")
 [(9)](#ref-for-dfn-EcKeyImportParams-namedCurve-20 "Reference 9")
 [(10)](#ref-for-dfn-EcKeyImportParams-namedCurve-21 "Reference 10")

[Permalink](#dfn-ecdh-extended-namedcurve-values)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-ecdh-extended-generation-steps)

**Referenced in:**

- [§ 24.4.1 Generate
 Key](#ref-for-dfn-ecdh-extended-generation-steps-1 "§ 24.4.1 Generate Key")

[Permalink](#dfn-ecdh-extended-derivation-steps)

**Referenced in:**

- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-ecdh-extended-derivation-steps-1 "§ 24.4.2 Derive Bits")

[Permalink](#dfn-ecdh-extended-import-steps)

**Referenced in:**

- [§ 23.7.4 Import
 Key](#ref-for-dfn-ecdh-extended-import-steps-1 "§ 23.7.4 Import Key")
- [§ 24.4.3 Import
 Key](#ref-for-dfn-ecdh-extended-import-steps-2 "§ 24.4.3 Import Key")
 [(2)](#ref-for-dfn-ecdh-extended-import-steps-3 "Reference 2")
 [(3)](#ref-for-dfn-ecdh-extended-import-steps-4 "Reference 3")
 [(4)](#ref-for-dfn-ecdh-extended-import-steps-5 "Reference 4")

[Permalink](#dfn-ecdh-extended-export-steps)

**Referenced in:**

- [§ 23.7.5 Export
 Key](#ref-for-dfn-ecdh-extended-export-steps-1 "§ 23.7.5 Export Key")
- [§ 24.4.4 Export
 Key](#ref-for-dfn-ecdh-extended-export-steps-2 "§ 24.4.4 Export Key")
 [(2)](#ref-for-dfn-ecdh-extended-export-steps-3 "Reference 2")
 [(3)](#ref-for-dfn-ecdh-extended-export-steps-4 "Reference 3")
 [(4)](#ref-for-dfn-ecdh-extended-export-steps-5 "Reference 4")

[Permalink](#dfn-EcdhKeyDeriveParams)
[exported]
[IDL](#webidl-1522123379 "Jump to IDL declaration")

**Referenced in:**

- [§ 24.2
 Registration](#ref-for-dfn-EcdhKeyDeriveParams-1 "§ 24.2 Registration")
- [§ 24.3 EcdhKeyDeriveParams
 dictionary](#ref-for-dfn-EcdhKeyDeriveParams-2 "§ 24.3 EcdhKeyDeriveParams dictionary")
- [§ 26.2
 Registration](#ref-for-dfn-EcdhKeyDeriveParams-3 "§ 26.2 Registration")

[Permalink](#dfn-EcdhKeyDeriveParams-public)
[exported]
[IDL](#webidl-1522123379 "Jump to IDL declaration")

**Referenced in:**

- [§ 24.3 EcdhKeyDeriveParams
 dictionary](#ref-for-dfn-EcdhKeyDeriveParams-public-1 "§ 24.3 EcdhKeyDeriveParams dictionary")
- [§ 24.4.2 Derive
 Bits](#ref-for-dfn-EcdhKeyDeriveParams-public-2 "§ 24.4.2 Derive Bits")
- [§ 26.3.1 Derive
 Bits](#ref-for-dfn-EcdhKeyDeriveParams-public-3 "§ 26.3.1 Derive Bits")

[Permalink](#dfn-AesCtrParams)
[exported]
[IDL](#webidl-1566726741 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.2
 Registration](#ref-for-dfn-AesCtrParams-1 "§ 27.2 Registration")
 [(2)](#ref-for-dfn-AesCtrParams-2 "Reference 2")
- [§ 27.3 AesCtrParams
 dictionary](#ref-for-dfn-AesCtrParams-3 "§ 27.3 AesCtrParams dictionary")

[Permalink](#dfn-AesCtrParams-counter)
[exported]
[IDL](#webidl-1566726741 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.3 AesCtrParams
 dictionary](#ref-for-dfn-AesCtrParams-counter-1 "§ 27.3 AesCtrParams dictionary")
 [(2)](#ref-for-dfn-AesCtrParams-counter-2 "Reference 2")
- [§ 27.7.1
 Encrypt](#ref-for-dfn-AesCtrParams-counter-3 "§ 27.7.1 Encrypt")
 [(2)](#ref-for-dfn-AesCtrParams-counter-4 "Reference 2")
- [§ 27.7.2
 Decrypt](#ref-for-dfn-AesCtrParams-counter-5 "§ 27.7.2 Decrypt")
 [(2)](#ref-for-dfn-AesCtrParams-counter-6 "Reference 2")

[Permalink](#dfn-AesCtrParams-length)
[exported]
[IDL](#webidl-1566726741 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.3 AesCtrParams
 dictionary](#ref-for-dfn-AesCtrParams-length-1 "§ 27.3 AesCtrParams dictionary")
- [§ 27.7.1
 Encrypt](#ref-for-dfn-AesCtrParams-length-2 "§ 27.7.1 Encrypt")
 [(2)](#ref-for-dfn-AesCtrParams-length-3 "Reference 2")
- [§ 27.7.2
 Decrypt](#ref-for-dfn-AesCtrParams-length-4 "§ 27.7.2 Decrypt")
 [(2)](#ref-for-dfn-AesCtrParams-length-5 "Reference 2")

[Permalink](#dfn-AesKeyAlgorithm)
[exported]
[IDL](#webidl-1999646300 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.4 AesKeyAlgorithm
 dictionary](#ref-for-dfn-AesKeyAlgorithm-1 "§ 27.4 AesKeyAlgorithm dictionary")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-2 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-3 "§ 27.7.4 Import Key")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-4 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-5 "§ 28.4.4 Import Key")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-6 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-7 "§ 29.4.4 Import Key")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-8 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-9 "§ 30.3.4 Import Key")

[Permalink](#dfn-AesKeyAlgorithm-length)
[exported]
[IDL](#webidl-1999646300 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.4 AesKeyAlgorithm
 dictionary](#ref-for-dfn-AesKeyAlgorithm-length-1 "§ 27.4 AesKeyAlgorithm dictionary")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-length-2 "§ 27.7.3 Generate Key")
- [§ 27.7.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-length-3 "§ 27.7.4 Import Key")
- [§ 27.7.5 Export
 Key](#ref-for-dfn-AesKeyAlgorithm-length-4 "§ 27.7.5 Export Key")
 [(2)](#ref-for-dfn-AesKeyAlgorithm-length-5 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyAlgorithm-length-6 "Reference 3")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-length-7 "§ 28.4.3 Generate Key")
- [§ 28.4.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-length-8 "§ 28.4.4 Import Key")
- [§ 28.4.5 Export
 Key](#ref-for-dfn-AesKeyAlgorithm-length-9 "§ 28.4.5 Export Key")
 [(2)](#ref-for-dfn-AesKeyAlgorithm-length-10 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyAlgorithm-length-11 "Reference 3")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-length-12 "§ 29.4.3 Generate Key")
- [§ 29.4.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-length-13 "§ 29.4.4 Import Key")
- [§ 29.4.5 Export
 Key](#ref-for-dfn-AesKeyAlgorithm-length-14 "§ 29.4.5 Export Key")
 [(2)](#ref-for-dfn-AesKeyAlgorithm-length-15 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyAlgorithm-length-16 "Reference 3")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-AesKeyAlgorithm-length-17 "§ 30.3.3 Generate Key")
- [§ 30.3.4 Import
 Key](#ref-for-dfn-AesKeyAlgorithm-length-18 "§ 30.3.4 Import Key")
- [§ 30.3.5 Export
 Key](#ref-for-dfn-AesKeyAlgorithm-length-19 "§ 30.3.5 Export Key")
 [(2)](#ref-for-dfn-AesKeyAlgorithm-length-20 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyAlgorithm-length-21 "Reference 3")

[Permalink](#dfn-AesKeyGenParams)
[exported]
[IDL](#webidl-1306510144 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.2
 Registration](#ref-for-dfn-AesKeyGenParams-1 "§ 27.2 Registration")
- [§ 27.5 AesKeyGenParams
 dictionary](#ref-for-dfn-AesKeyGenParams-2 "§ 27.5 AesKeyGenParams dictionary")
- [§ 28.2
 Registration](#ref-for-dfn-AesKeyGenParams-3 "§ 28.2 Registration")
- [§ 29.2
 Registration](#ref-for-dfn-AesKeyGenParams-4 "§ 29.2 Registration")
- [§ 30.2
 Registration](#ref-for-dfn-AesKeyGenParams-5 "§ 30.2 Registration")

[Permalink](#dfn-AesKeyGenParams-length)
[exported]
[IDL](#webidl-1306510144 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.5 AesKeyGenParams
 dictionary](#ref-for-dfn-AesKeyGenParams-length-1 "§ 27.5 AesKeyGenParams dictionary")
- [§ 27.7.3 Generate
 Key](#ref-for-dfn-AesKeyGenParams-length-2 "§ 27.7.3 Generate Key")
 [(2)](#ref-for-dfn-AesKeyGenParams-length-3 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyGenParams-length-4 "Reference 3")
- [§ 28.4.3 Generate
 Key](#ref-for-dfn-AesKeyGenParams-length-5 "§ 28.4.3 Generate Key")
 [(2)](#ref-for-dfn-AesKeyGenParams-length-6 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyGenParams-length-7 "Reference 3")
- [§ 29.4.3 Generate
 Key](#ref-for-dfn-AesKeyGenParams-length-8 "§ 29.4.3 Generate Key")
 [(2)](#ref-for-dfn-AesKeyGenParams-length-9 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyGenParams-length-10 "Reference 3")
- [§ 30.3.3 Generate
 Key](#ref-for-dfn-AesKeyGenParams-length-11 "§ 30.3.3 Generate Key")
 [(2)](#ref-for-dfn-AesKeyGenParams-length-12 "Reference 2")
 [(3)](#ref-for-dfn-AesKeyGenParams-length-13 "Reference 3")

[Permalink](#dfn-AesDerivedKeyParams)
[exported]
[IDL](#webidl-379647633 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.2
 Registration](#ref-for-dfn-AesDerivedKeyParams-1 "§ 27.2 Registration")
- [§ 27.6 AesDerivedKeyParams
 dictionary](#ref-for-dfn-AesDerivedKeyParams-2 "§ 27.6 AesDerivedKeyParams dictionary")
- [§ 28.2
 Registration](#ref-for-dfn-AesDerivedKeyParams-3 "§ 28.2 Registration")
- [§ 29.2
 Registration](#ref-for-dfn-AesDerivedKeyParams-4 "§ 29.2 Registration")
- [§ 30.2
 Registration](#ref-for-dfn-AesDerivedKeyParams-5 "§ 30.2 Registration")

[Permalink](#dfn-AesDerivedKeyParams-length)
[exported]
[IDL](#webidl-379647633 "Jump to IDL declaration")

**Referenced in:**

- [§ 27.6 AesDerivedKeyParams
 dictionary](#ref-for-dfn-AesDerivedKeyParams-length-1 "§ 27.6 AesDerivedKeyParams dictionary")
- [§ 27.7.6 Get key
 length](#ref-for-dfn-AesDerivedKeyParams-length-2 "§ 27.7.6 Get key length")
 [(2)](#ref-for-dfn-AesDerivedKeyParams-length-3 "Reference 2")
- [§ 28.4.6 Get key
 length](#ref-for-dfn-AesDerivedKeyParams-length-4 "§ 28.4.6 Get key length")
 [(2)](#ref-for-dfn-AesDerivedKeyParams-length-5 "Reference 2")
- [§ 29.4.6 Get key
 length](#ref-for-dfn-AesDerivedKeyParams-length-6 "§ 29.4.6 Get key length")
 [(2)](#ref-for-dfn-AesDerivedKeyParams-length-7 "Reference 2")
- [§ 30.3.6 Get key
 length](#ref-for-dfn-AesDerivedKeyParams-length-8 "§ 30.3.6 Get key length")
 [(2)](#ref-for-dfn-AesDerivedKeyParams-length-9 "Reference 2")

[Permalink](#dfn-AesCbcParams)
[exported]
[IDL](#webidl-15109397 "Jump to IDL declaration")

**Referenced in:**

- [§ 28.2
 Registration](#ref-for-dfn-AesCbcParams-1 "§ 28.2 Registration")
 [(2)](#ref-for-dfn-AesCbcParams-2 "Reference 2")
- [§ 28.3 AesCbcParams
 dictionary](#ref-for-dfn-AesCbcParams-3 "§ 28.3 AesCbcParams dictionary")

[Permalink](#dfn-AesCbcParams-iv)
[exported]
[IDL](#webidl-15109397 "Jump to IDL declaration")

**Referenced in:**

- [§ 28.3 AesCbcParams
 dictionary](#ref-for-dfn-AesCbcParams-iv-1 "§ 28.3 AesCbcParams dictionary")
- [§ 28.4.1 Encrypt](#ref-for-dfn-AesCbcParams-iv-2 "§ 28.4.1 Encrypt")
 [(2)](#ref-for-dfn-AesCbcParams-iv-3 "Reference 2")
- [§ 28.4.2 Decrypt](#ref-for-dfn-AesCbcParams-iv-4 "§ 28.4.2 Decrypt")
 [(2)](#ref-for-dfn-AesCbcParams-iv-5 "Reference 2")

[Permalink](#dfn-AesGcmParams)
[exported]
[IDL](#webidl-469526380 "Jump to IDL declaration")

**Referenced in:**

- [§ 29.2
 Registration](#ref-for-dfn-AesGcmParams-1 "§ 29.2 Registration")
 [(2)](#ref-for-dfn-AesGcmParams-2 "Reference 2")
- [§ 29.3 AesGcmParams
 dictionary](#ref-for-dfn-AesGcmParams-3 "§ 29.3 AesGcmParams dictionary")

[Permalink](#dfn-AesGcmParams-iv)
[exported]
[IDL](#webidl-469526380 "Jump to IDL declaration")

**Referenced in:**

- [§ 29.3 AesGcmParams
 dictionary](#ref-for-dfn-AesGcmParams-iv-1 "§ 29.3 AesGcmParams dictionary")
- [§ 29.4.1 Encrypt](#ref-for-dfn-AesGcmParams-iv-2 "§ 29.4.1 Encrypt")
 [(2)](#ref-for-dfn-AesGcmParams-iv-3 "Reference 2")
- [§ 29.4.2 Decrypt](#ref-for-dfn-AesGcmParams-iv-4 "§ 29.4.2 Decrypt")
 [(2)](#ref-for-dfn-AesGcmParams-iv-5 "Reference 2")

[Permalink](#dfn-AesGcmParams-additionalData)
[exported]
[IDL](#webidl-469526380 "Jump to IDL declaration")

**Referenced in:**

- [§ 29.3 AesGcmParams
 dictionary](#ref-for-dfn-AesGcmParams-additionalData-1 "§ 29.3 AesGcmParams dictionary")
- [§ 29.4.1
 Encrypt](#ref-for-dfn-AesGcmParams-additionalData-2 "§ 29.4.1 Encrypt")
 [(2)](#ref-for-dfn-AesGcmParams-additionalData-3 "Reference 2")
- [§ 29.4.2
 Decrypt](#ref-for-dfn-AesGcmParams-additionalData-4 "§ 29.4.2 Decrypt")
 [(2)](#ref-for-dfn-AesGcmParams-additionalData-5 "Reference 2")

[Permalink](#dfn-AesGcmParams-tagLength)
[exported]
[IDL](#webidl-469526380 "Jump to IDL declaration")

**Referenced in:**

- [§ 29.3 AesGcmParams
 dictionary](#ref-for-dfn-AesGcmParams-tagLength-1 "§ 29.3 AesGcmParams dictionary")
- [§ 29.4.1
 Encrypt](#ref-for-dfn-AesGcmParams-tagLength-2 "§ 29.4.1 Encrypt")
 [(2)](#ref-for-dfn-AesGcmParams-tagLength-3 "Reference 2")
 [(3)](#ref-for-dfn-AesGcmParams-tagLength-4 "Reference 3")
- [§ 29.4.2
 Decrypt](#ref-for-dfn-AesGcmParams-tagLength-5 "§ 29.4.2 Decrypt")
 [(2)](#ref-for-dfn-AesGcmParams-tagLength-6 "Reference 2")
 [(3)](#ref-for-dfn-AesGcmParams-tagLength-7 "Reference 3")

[Permalink](#dfn-hmac-extended-import-steps)

**Referenced in:**

- [§ 31.6.4 Import
 Key](#ref-for-dfn-hmac-extended-import-steps-1 "§ 31.6.4 Import Key")

[Permalink](#dfn-hmac-extended-export-steps)

**Referenced in:**

- [§ 31.6.5 Export
 Key](#ref-for-dfn-hmac-extended-export-steps-1 "§ 31.6.5 Export Key")

[Permalink](#dfn-HmacImportParams)
[exported]
[IDL](#webidl-323396047 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.2
 Registration](#ref-for-dfn-HmacImportParams-1 "§ 31.2 Registration")
 [(2)](#ref-for-dfn-HmacImportParams-2 "Reference 2")
- [§ 31.3 HmacImportParams
 dictionary](#ref-for-dfn-HmacImportParams-3 "§ 31.3 HmacImportParams dictionary")

[Permalink](#dfn-HmacImportParams-hash)
[exported]
[IDL](#webidl-323396047 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.3 HmacImportParams
 dictionary](#ref-for-dfn-HmacImportParams-hash-1 "§ 31.3 HmacImportParams dictionary")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-HmacImportParams-hash-2 "§ 31.6.4 Import Key")
 [(2)](#ref-for-dfn-HmacImportParams-hash-3 "Reference 2")
- [§ 31.6.6 Get key
 length](#ref-for-dfn-HmacImportParams-hash-4 "§ 31.6.6 Get key length")

[Permalink](#dfn-HmacImportParams-length)
[exported]
[IDL](#webidl-323396047 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.3 HmacImportParams
 dictionary](#ref-for-dfn-HmacImportParams-length-1 "§ 31.3 HmacImportParams dictionary")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-HmacImportParams-length-2 "§ 31.6.4 Import Key")
 [(2)](#ref-for-dfn-HmacImportParams-length-3 "Reference 2")
 [(3)](#ref-for-dfn-HmacImportParams-length-4 "Reference 3")
 [(4)](#ref-for-dfn-HmacImportParams-length-5 "Reference 4")
 [(5)](#ref-for-dfn-HmacImportParams-length-6 "Reference 5")
- [§ 31.6.6 Get key
 length](#ref-for-dfn-HmacImportParams-length-7 "§ 31.6.6 Get key length")
 [(2)](#ref-for-dfn-HmacImportParams-length-8 "Reference 2")
 [(3)](#ref-for-dfn-HmacImportParams-length-9 "Reference 3")

[Permalink](#dfn-HmacKeyAlgorithm)
[exported]
[IDL](#webidl-1694051636 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.4 HmacKeyAlgorithm
 dictionary](#ref-for-dfn-HmacKeyAlgorithm-1 "§ 31.4 HmacKeyAlgorithm dictionary")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-HmacKeyAlgorithm-2 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-HmacKeyAlgorithm-3 "§ 31.6.4 Import Key")

[Permalink](#dfn-HmacKeyAlgorithm-hash)
[exported]
[IDL](#webidl-1694051636 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.4 HmacKeyAlgorithm
 dictionary](#ref-for-dfn-HmacKeyAlgorithm-hash-1 "§ 31.4 HmacKeyAlgorithm dictionary")
- [§ 31.6.1 Sign](#ref-for-dfn-HmacKeyAlgorithm-hash-2 "§ 31.6.1 Sign")
- [§ 31.6.2
 Verify](#ref-for-dfn-HmacKeyAlgorithm-hash-3 "§ 31.6.2 Verify")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-HmacKeyAlgorithm-hash-4 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-HmacKeyAlgorithm-hash-5 "§ 31.6.4 Import Key")
- [§ 31.6.5 Export
 Key](#ref-for-dfn-HmacKeyAlgorithm-hash-6 "§ 31.6.5 Export Key")

[Permalink](#dfn-HmacKeyAlgorithm-length)
[exported]
[IDL](#webidl-1694051636 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.4 HmacKeyAlgorithm
 dictionary](#ref-for-dfn-HmacKeyAlgorithm-length-1 "§ 31.4 HmacKeyAlgorithm dictionary")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-HmacKeyAlgorithm-length-2 "§ 31.6.3 Generate Key")
- [§ 31.6.4 Import
 Key](#ref-for-dfn-HmacKeyAlgorithm-length-3 "§ 31.6.4 Import Key")

[Permalink](#dfn-HmacKeyGenParams)
[exported]
[IDL](#webidl-544098843 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.2
 Registration](#ref-for-dfn-HmacKeyGenParams-1 "§ 31.2 Registration")
- [§ 31.5 HmacKeyGenParams
 dictionary](#ref-for-dfn-HmacKeyGenParams-2 "§ 31.5 HmacKeyGenParams dictionary")

[Permalink](#dfn-HmacKeyGenParams-hash)
[exported]
[IDL](#webidl-544098843 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.5 HmacKeyGenParams
 dictionary](#ref-for-dfn-HmacKeyGenParams-hash-1 "§ 31.5 HmacKeyGenParams dictionary")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-HmacKeyGenParams-hash-2 "§ 31.6.3 Generate Key")
 [(2)](#ref-for-dfn-HmacKeyGenParams-hash-3 "Reference 2")

[Permalink](#dfn-HmacKeyGenParams-length)
[exported]
[IDL](#webidl-544098843 "Jump to IDL declaration")

**Referenced in:**

- [§ 31.5 HmacKeyGenParams
 dictionary](#ref-for-dfn-HmacKeyGenParams-length-1 "§ 31.5 HmacKeyGenParams dictionary")
- [§ 31.6.3 Generate
 Key](#ref-for-dfn-HmacKeyGenParams-length-2 "§ 31.6.3 Generate Key")
 [(2)](#ref-for-dfn-HmacKeyGenParams-length-3 "Reference 2")
 [(3)](#ref-for-dfn-HmacKeyGenParams-length-4 "Reference 3")

[Permalink](#dfn-HkdfParams)
[exported]
[IDL](#webidl-1209901303 "Jump to IDL declaration")

**Referenced in:**

- [§ 33.2 Registration](#ref-for-dfn-HkdfParams-1 "§ 33.2 Registration")
- [§ 33.3 HkdfParams
 dictionary](#ref-for-dfn-HkdfParams-2 "§ 33.3 HkdfParams dictionary")

[Permalink](#dfn-HkdfParams-hash)
[exported]
[IDL](#webidl-1209901303 "Jump to IDL declaration")

**Referenced in:**

- [§ 33.3 HkdfParams
 dictionary](#ref-for-dfn-HkdfParams-hash-1 "§ 33.3 HkdfParams dictionary")
- [§ 33.4.1 Derive
 Bits](#ref-for-dfn-HkdfParams-hash-2 "§ 33.4.1 Derive Bits")
 [(2)](#ref-for-dfn-HkdfParams-hash-3 "Reference 2")

[Permalink](#dfn-HkdfParams-salt)
[exported]
[IDL](#webidl-1209901303 "Jump to IDL declaration")

**Referenced in:**

- [§ 33.3 HkdfParams
 dictionary](#ref-for-dfn-HkdfParams-salt-1 "§ 33.3 HkdfParams dictionary")
- [§ 33.4.1 Derive
 Bits](#ref-for-dfn-HkdfParams-salt-2 "§ 33.4.1 Derive Bits")

[Permalink](#dfn-HkdfParams-info)
[exported]
[IDL](#webidl-1209901303 "Jump to IDL declaration")

**Referenced in:**

- [§ 33.3 HkdfParams
 dictionary](#ref-for-dfn-HkdfParams-info-1 "§ 33.3 HkdfParams dictionary")
- [§ 33.4.1 Derive
 Bits](#ref-for-dfn-HkdfParams-info-2 "§ 33.4.1 Derive Bits")

[Permalink](#dfn-Pbkdf2Params)
[exported]
[IDL](#webidl-1323938568 "Jump to IDL declaration")

**Referenced in:**

- [§ 34.2
 Registration](#ref-for-dfn-Pbkdf2Params-1 "§ 34.2 Registration")
- [§ 34.3 Pbkdf2Params
 dictionary](#ref-for-dfn-Pbkdf2Params-2 "§ 34.3 Pbkdf2Params dictionary")
 [(2)](#ref-for-dfn-Pbkdf2Params-3 "Reference 2")

[Permalink](#dfn-Pbkdf2Params-salt)
[exported]
[IDL](#webidl-1323938568 "Jump to IDL declaration")

**Referenced in:**

- [§ 34.3 Pbkdf2Params
 dictionary](#ref-for-dfn-Pbkdf2Params-salt-1 "§ 34.3 Pbkdf2Params dictionary")
- [§ 34.4.1 Derive
 Bits](#ref-for-dfn-Pbkdf2Params-salt-2 "§ 34.4.1 Derive Bits")

[Permalink](#dfn-Pbkdf2Params-iterations)
[exported]
[IDL](#webidl-1323938568 "Jump to IDL declaration")

**Referenced in:**

- [§ 34.3 Pbkdf2Params
 dictionary](#ref-for-dfn-Pbkdf2Params-iterations-1 "§ 34.3 Pbkdf2Params dictionary")
- [§ 34.4.1 Derive
 Bits](#ref-for-dfn-Pbkdf2Params-iterations-2 "§ 34.4.1 Derive Bits")
 [(2)](#ref-for-dfn-Pbkdf2Params-iterations-3 "Reference 2")

[Permalink](#dfn-Pbkdf2Params-hash)
[exported]
[IDL](#webidl-1323938568 "Jump to IDL declaration")

**Referenced in:**

- [§ 34.3 Pbkdf2Params
 dictionary](#ref-for-dfn-Pbkdf2Params-hash-1 "§ 34.3 Pbkdf2Params dictionary")
- [§ 34.4.1 Derive
 Bits](#ref-for-dfn-Pbkdf2Params-hash-2 "§ 34.4.1 Derive Bits")

::: header-wrapper
## D. References

::: header-wrapper
### D.1 Normative references

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[ECMA-262\]
: [ECMAScript Language
 Specification](https://tc39.es/ecma262/multipage/). Ecma
 International. URL: <https://tc39.es/ecma262/multipage/>

\[encoding\]
: [Encoding Standard](https://encoding.spec.whatwg.org/). Anne van
 Kesteren. WHATWG. Living Standard. URL:
 <https://encoding.spec.whatwg.org/>

\[FIPS-180-4\]
: [FIPS PUB 180-4: Secure Hash Standard
 (SHS)](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).
 U.S. Department of Commerce/National Institute of Standards and
 Technology. August 2015. National Standard. URL:
 <https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf>

\[FIPS-198-1\]
: [The Keyed-Hash Message Authentication Code
 (HMAC)](http://csrc.nist.gov/publications/fips/fips198-1/FIPS-198-1_final.pdf).
 NIST. July 2008. URL:
 <http://csrc.nist.gov/publications/fips/fips198-1/FIPS-198-1_final.pdf>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[Infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[JWA\]
: [JSON Web Algorithms
 (JWA)](https://www.rfc-editor.org/info/rfc7518/). M. Jones. IETF.
 May 2015. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc7518/>

\[JWK\]
: [JSON Web Key (JWK)](https://www.rfc-editor.org/info/rfc7517/). M.
 Jones. IETF. May 2015. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc7517/>

\[NIST-SP800-38A\]
: [NIST Special Publication 800-38A: Recommendation for Block Cipher
 Modes of Operation, Methods and
 Techniques](http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf).
 NIST. December 2001. URL:
 <http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf>

\[NIST-SP800-38D\]
: [NIST Special Publication 800-38D: Recommendation for Block Cipher
 Modes of Operation: Galois/Counter Mode (GCM) and
 GMAC](http://csrc.nist.gov/publications/nistpubs/800-38D/SP-800-38D.pdf).
 NIST. November 2007. URL:
 <http://csrc.nist.gov/publications/nistpubs/800-38D/SP-800-38D.pdf>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/info/rfc2119/). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc2119/>

\[RFC2141\]
: [URN Syntax](https://www.rfc-editor.org/info/rfc2141/). R. Moats.
 IETF. May 1997. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc2141/>

\[RFC2315\]
: [PKCS #7: Cryptographic Message Syntax Version
 1.5](https://www.rfc-editor.org/info/rfc2315/). B. Kaliski. IETF.
 March 1998. Informational. URL:
 <https://www.rfc-editor.org/info/rfc2315/>

\[RFC3394\]
: [Advanced Encryption Standard (AES) Key Wrap
 Algorithm](https://www.rfc-editor.org/info/rfc3394/). J. Schaad; R.
 Housley. IETF. October 2002. Informational. URL:
 <https://www.rfc-editor.org/info/rfc3394/>

\[RFC3447\]
: [Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography
 Specifications Version
 2.1](https://www.rfc-editor.org/info/rfc3447/). J. Jonsson; B.
 Kaliski. IETF. February 2003. Informational. URL:
 <https://www.rfc-editor.org/info/rfc3447/>

\[RFC4122\]
: [A Universally Unique IDentifier (UUID) URN
 Namespace](https://www.rfc-editor.org/info/rfc4122/). P. Leach; M.
 Mealling; R. Salz. IETF. July 2005. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc4122/>

\[RFC5208\]
: [Public-Key Cryptography Standards (PKCS) #8: Private-Key
 Information Syntax Specification Version
 1.2](https://www.rfc-editor.org/info/rfc5208/). B. Kaliski. IETF.
 May 2008. Informational. URL:
 <https://www.rfc-editor.org/info/rfc5208/>

\[RFC5280\]
: [Internet X.509 Public Key Infrastructure Certificate and
 Certificate Revocation List (CRL)
 Profile](https://www.rfc-editor.org/info/rfc5280/). D. Cooper; S.
 Santesson; S. Farrell; S. Boeyen; R. Housley; W. Polk. IETF.
 May 2008. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc5280/>

\[RFC5480\]
: [Elliptic Curve Cryptography Subject Public Key
 Information](https://www.rfc-editor.org/info/rfc5480/). S.
 Turner; D. Brown; K. Yiu; R. Housley; T. Polk. IETF. March 2009.
 Proposed Standard. URL: <https://www.rfc-editor.org/info/rfc5480/>

\[RFC5869\]
: [HMAC-based Extract-and-Expand Key Derivation Function
 (HKDF)](https://www.rfc-editor.org/info/rfc5869/). H. Krawczyk; P.
 Eronen. IETF. May 2010. Informational. URL:
 <https://www.rfc-editor.org/info/rfc5869/>

\[RFC5915\]
: [Elliptic Curve Private Key
 Structure](https://www.rfc-editor.org/info/rfc5915/). S. Turner; D.
 Brown. IETF. June 2010. Informational. URL:
 <https://www.rfc-editor.org/info/rfc5915/>

\[RFC6090\]
: [Fundamental Elliptic Curve Cryptography
 Algorithms](https://www.rfc-editor.org/info/rfc6090/). D. McGrew; K.
 Igoe; M. Salter. IETF. February 2011. Informational. URL:
 <https://www.rfc-editor.org/info/rfc6090/>

\[RFC7748\]
: [Elliptic Curves for
 Security](https://www.rfc-editor.org/info/rfc7748/). A. Langley; M.
 Hamburg; S. Turner. IETF. January 2016. Informational. URL:
 <https://www.rfc-editor.org/info/rfc7748/>

\[RFC8018\]
: [PKCS #5: Password-Based Cryptography Specification Version
 2.1](https://www.rfc-editor.org/info/rfc8018/). K. Moriarty, Ed.; B.
 Kaliski; A. Rusch. IETF. January 2017. Informational. URL:
 <https://www.rfc-editor.org/info/rfc8018/>

\[RFC8032\]
: [Edwards-Curve Digital Signature Algorithm
 (EdDSA)](https://www.rfc-editor.org/info/rfc8032/). S. Josefsson; I.
 Liusvaara. IETF. January 2017. Informational. URL:
 <https://www.rfc-editor.org/info/rfc8032/>

\[RFC8037\]
: [CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JSON
 Object Signing and Encryption
 (JOSE)](https://www.rfc-editor.org/info/rfc8037/). I. Liusvaara.
 IETF. January 2017. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc8037/>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/info/rfc8174/). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc8174/>

\[RFC8410\]
: [Algorithm Identifiers for Ed25519, Ed448, X25519, and X448 for Use
 in the Internet X.509 Public Key
 Infrastructure](https://www.rfc-editor.org/info/rfc8410/). S.
 Josefsson; J. Schaad. IETF. August 2018. Proposed Standard. URL:
 <https://www.rfc-editor.org/info/rfc8410/>

\[SEC1\]
: [SEC 1: Elliptic Curve
 Cryptography](http://www.secg.org/sec1-v2.pdf). Certicom Research.
 URL: <http://www.secg.org/sec1-v2.pdf>

\[WebIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

\[X690\]
: [Information technology - ASN.1 encoding rules: Specification of
 Basic Encoding Rules (BER), Canonical Encoding Rules (CER) and
 Distinguished Encoding Rules
 (DER)](https://tools.ietf.org/html/draft-ietf-rtcweb-jsep/). Justin
 Uberti; Cullen Jennings; Eric Rescorla. ITU-T. November 2008. ITU-T
 Recommendation. URL:
 <https://tools.ietf.org/html/draft-ietf-rtcweb-jsep/>

::: header-wrapper
### D.2 Informative references

\[INDEXEDDB\]
: [Indexed Database API](https://www.w3.org/TR/IndexedDB/). Nikunj
 Mehta; Jonas Sicking; Eliot Graff; Andrei Popescu; Jeremy Orlow;
 Joshua Bell. W3C. 8 January 2015. W3C Recommendation. URL:
 <https://www.w3.org/TR/IndexedDB/>

[[↑]](#title)
