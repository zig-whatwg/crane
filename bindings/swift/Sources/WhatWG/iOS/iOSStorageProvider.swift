#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
import Foundation

/// iOS/macOS implementation of StorageProvider using UserDefaults.
///
/// This provider uses UserDefaults for persistent key-value storage.
/// For more advanced storage needs, consider implementing a custom provider
/// using Core Data, SQLite, or the file system.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.storageProvider = iOSStorageProvider()
/// ```
///
public final class iOSStorageProvider: StorageProvider, @unchecked Sendable {
    
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let lock = NSLock()
    
    /// Creates a new iOS storage provider.
    ///
    /// - Parameters:
    ///   - defaults: The UserDefaults instance to use. Defaults to `.standard`.
    ///   - keyPrefix: A prefix for all keys to avoid collisions. Defaults to "whatwg_storage_".
    public init(defaults: UserDefaults = .standard, keyPrefix: String = "whatwg_storage_") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }
    
    // MARK: - StorageProvider
    
    public func getItem(key: String) async throws -> String? {
        let prefixedKey = keyPrefix + key
        return defaults.string(forKey: prefixedKey)
    }
    
    public func setItem(key: String, value: String) async throws {
        let prefixedKey = keyPrefix + key
        defaults.set(value, forKey: prefixedKey)
    }
    
    public func removeItem(key: String) async throws {
        let prefixedKey = keyPrefix + key
        defaults.removeObject(forKey: prefixedKey)
    }
    
    public func clear() async throws {
        // Get all keys with our prefix and remove them
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(keyPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    public func length() async throws -> Int {
        let allKeys = defaults.dictionaryRepresentation().keys
        return allKeys.filter { $0.hasPrefix(keyPrefix) }.count
    }
    
    public func key(at index: Int) async throws -> String? {
        let allKeys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(keyPrefix) }
            .sorted()
        
        guard index >= 0 && index < allKeys.count else {
            return nil
        }
        
        // Remove the prefix before returning
        let fullKey = allKeys[allKeys.index(allKeys.startIndex, offsetBy: index)]
        return String(fullKey.dropFirst(keyPrefix.count))
    }
}

/// iOS/macOS implementation of StorageProvider using file system.
///
/// This provider uses a directory in the app's documents for persistent storage.
/// It stores each key-value pair as a separate file.
///
public final class iOSFileStorageProvider: StorageProvider, @unchecked Sendable {
    
    private let directory: URL
    private let fileManager = FileManager.default
    
    /// Creates a new file-based storage provider.
    ///
    /// - Parameter directory: The directory to store files in. If nil, uses documents directory.
    public init(directory: URL? = nil) {
        if let dir = directory {
            self.directory = dir
        } else {
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.directory = documentsPath.appendingPathComponent("whatwg_storage", isDirectory: true)
        }
        
        // Create directory if needed
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }
    
    // MARK: - StorageProvider
    
    public func getItem(key: String) async throws -> String? {
        let fileURL = directory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
    
    public func setItem(key: String, value: String) async throws {
        let fileURL = directory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)
        try value.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    public func removeItem(key: String) async throws {
        let fileURL = directory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    public func clear() async throws {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in contents {
            try fileManager.removeItem(at: file)
        }
    }
    
    public func length() async throws -> Int {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents.count
    }
    
    public func key(at index: Int) async throws -> String? {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        guard index >= 0 && index < contents.count else {
            return nil
        }
        
        let filename = contents[index].lastPathComponent
        return filename.removingPercentEncoding ?? filename
    }
}
#endif
