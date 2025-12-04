import WhatWG
import CWhatWG

// Create platform with default providers
let platform = WhatWGPlatform()

// Initialize the platform
try platform.initialize()

// Create execution context
let context = try platform.createContext()

let script = "2 + 2"
var result = UnsafeMutablePointer<CChar>?.none
var resultLen = 0
whatwg_context_evaluate(context.handle, script, script.utf8.count, &result, &resultLen)