#if os(iOS) || os(macOS)
import Foundation
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

/// File system provider implementation using system file pickers.
///
/// This provider uses UIDocumentPickerViewController on iOS and NSOpenPanel on macOS.
/// It also provides access to the Origin Private File System (OPFS) using the app's
/// documents directory.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.fileSystemProvider = UIDocumentPickerFileSystemProvider()
/// ```
///
@available(iOS 17.0, macOS 14.0, *)
public final class UIDocumentPickerFileSystemProvider: FileSystemProvider, @unchecked Sendable {
    
    private let fileManager = FileManager.default
    private let opfsDirectory: URL
    
    /// Creates a new iOS file system provider.
    ///
    /// - Parameter opfsDirectory: Custom directory for OPFS. Defaults to documents/opfs.
    public init(opfsDirectory: URL? = nil) {
        if let dir = opfsDirectory {
            self.opfsDirectory = dir
        } else {
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.opfsDirectory = documentsPath.appendingPathComponent("opfs", isDirectory: true)
        }
        
        // Create OPFS directory if needed
        try? fileManager.createDirectory(at: self.opfsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - FileSystemProvider
    
    @MainActor
    public func showOpenFilePicker(options: FilePickerOptions) async throws -> [FileHandle] {
        #if os(iOS)
        return try await withCheckedThrowingContinuation { continuation in
            let documentPicker = createDocumentPicker(for: options)
            
            let delegate = DocumentPickerDelegate { urls in
                let handles = urls.map { iOSFileHandle(url: $0) as FileHandle }
                continuation.resume(returning: handles)
            } onCancel: {
                continuation.resume(throwing: WhatWGError.operationFailed("User cancelled"))
            }
            
            // Keep delegate alive
            objc_setAssociatedObject(documentPicker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            documentPicker.delegate = delegate
            
            presentDocumentPicker(documentPicker)
        }
        #elseif os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = options.multiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if !options.types.isEmpty {
            var allowedTypes: [UTType] = []
            for type in options.types {
                for (mimeType, extensions) in type.accept {
                    if let utType = UTType(mimeType: mimeType) {
                        allowedTypes.append(utType)
                    }
                    for ext in extensions {
                        if let utType = UTType(filenameExtension: ext.trimmingCharacters(in: CharacterSet(charactersIn: "."))) {
                            allowedTypes.append(utType)
                        }
                    }
                }
            }
            panel.allowedContentTypes = allowedTypes
        }
        
        let response = panel.runModal()
        if response == .OK {
            return panel.urls.map { iOSFileHandle(url: $0) }
        } else {
            throw WhatWGError.operationFailed("User cancelled")
        }
        #endif
    }
    
    @MainActor
    public func showSaveFilePicker(options: FilePickerOptions) async throws -> FileHandle {
        #if os(iOS)
        // iOS doesn't have a native save file picker
        // We'll create a temporary file and return a handle to it
        let tempDir = fileManager.temporaryDirectory
        let fileName = "untitled"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try Data().write(to: fileURL)
        return iOSFileHandle(url: fileURL)
        #elseif os(macOS)
        let panel = NSSavePanel()
        
        if !options.types.isEmpty, let firstType = options.types.first {
            for (mimeType, _) in firstType.accept {
                if let utType = UTType(mimeType: mimeType) {
                    panel.allowedContentTypes = [utType]
                    break
                }
            }
        }
        
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            // Create empty file
            try Data().write(to: url)
            return iOSFileHandle(url: url)
        } else {
            throw WhatWGError.operationFailed("User cancelled")
        }
        #endif
    }
    
    @MainActor
    public func showDirectoryPicker(options: DirectoryPickerOptions) async throws -> DirectoryHandle {
        #if os(iOS)
        return try await withCheckedThrowingContinuation { continuation in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            documentPicker.allowsMultipleSelection = false
            
            let delegate = DocumentPickerDelegate { urls in
                if let url = urls.first {
                    continuation.resume(returning: iOSDirectoryHandle(url: url))
                } else {
                    continuation.resume(throwing: WhatWGError.operationFailed("No directory selected"))
                }
            } onCancel: {
                continuation.resume(throwing: WhatWGError.operationFailed("User cancelled"))
            }
            
            objc_setAssociatedObject(documentPicker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            documentPicker.delegate = delegate
            
            presentDocumentPicker(documentPicker)
        }
        #elseif os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            return iOSDirectoryHandle(url: url)
        } else {
            throw WhatWGError.operationFailed("User cancelled")
        }
        #endif
    }
    
    public func getOriginPrivateDirectory() async throws -> DirectoryHandle {
        return iOSDirectoryHandle(url: opfsDirectory)
    }
    
    // MARK: - Private (iOS)
    
    #if os(iOS)
    private func createDocumentPicker(for options: FilePickerOptions) -> UIDocumentPickerViewController {
        var contentTypes: [UTType] = []
        
        for type in options.types {
            for (mimeType, extensions) in type.accept {
                if let utType = UTType(mimeType: mimeType) {
                    contentTypes.append(utType)
                }
                for ext in extensions {
                    let cleanExt = ext.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    if let utType = UTType(filenameExtension: cleanExt) {
                        contentTypes.append(utType)
                    }
                }
            }
        }
        
        if contentTypes.isEmpty && !options.excludeAcceptAllOption {
            contentTypes = [.item]
        }
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = options.multiple
        return picker
    }
    
    @MainActor
    private func presentDocumentPicker(_ picker: UIDocumentPickerViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        topVC.present(picker, animated: true)
    }
    #endif
}

// MARK: - Document Picker Delegate (iOS)

#if os(iOS)
@available(iOS 17.0, *)
private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let onPick: ([URL]) -> Void
    private let onCancel: () -> Void
    
    init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
        self.onPick = onPick
        self.onCancel = onCancel
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onCancel()
    }
}
#endif

// MARK: - iOSFileHandle

@available(iOS 17.0, macOS 14.0, *)
final class iOSFileHandle: FileHandle, @unchecked Sendable {
    
    private let url: URL
    
    public var name: String { url.lastPathComponent }
    public var kind: String { "file" }
    
    init(url: URL) {
        self.url = url
    }
    
    public func getFile() async throws -> Data {
        // Start accessing security-scoped resource if needed
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try Data(contentsOf: url)
    }
    
    public func createWritable() async throws -> FileWritableStream {
        return iOSFileWritableStream(url: url)
    }
}

// MARK: - iOSDirectoryHandle

@available(iOS 17.0, macOS 14.0, *)
final class iOSDirectoryHandle: DirectoryHandle, @unchecked Sendable {
    
    private let url: URL
    private let fileManager = FileManager.default
    
    public var name: String { url.lastPathComponent }
    public var kind: String { "directory" }
    
    init(url: URL) {
        self.url = url
    }
    
    public func getFileHandle(name: String, create: Bool) async throws -> FileHandle {
        let fileURL = url.appendingPathComponent(name)
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            if create {
                try Data().write(to: fileURL)
            } else {
                throw WhatWGError.operationFailed("File not found: \(name)")
            }
        }
        
        return iOSFileHandle(url: fileURL)
    }
    
    public func getDirectoryHandle(name: String, create: Bool) async throws -> DirectoryHandle {
        let dirURL = url.appendingPathComponent(name, isDirectory: true)
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: dirURL.path, isDirectory: &isDirectory)
        
        if !exists || !isDirectory.boolValue {
            if create {
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            } else {
                throw WhatWGError.operationFailed("Directory not found: \(name)")
            }
        }
        
        return iOSDirectoryHandle(url: dirURL)
    }
    
    public func removeEntry(name: String, recursive: Bool) async throws {
        let entryURL = url.appendingPathComponent(name)
        try fileManager.removeItem(at: entryURL)
    }
    
    public func entries() async throws -> [(String, Any)] {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
        
        return try contents.map { itemURL in
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            
            if isDirectory {
                return (itemURL.lastPathComponent, iOSDirectoryHandle(url: itemURL) as Any)
            } else {
                return (itemURL.lastPathComponent, iOSFileHandle(url: itemURL) as Any)
            }
        }
    }
}

// MARK: - iOSFileWritableStream

@available(iOS 17.0, macOS 14.0, *)
final class iOSFileWritableStream: FileWritableStream, @unchecked Sendable {
    
    private let url: URL
    private var fileHandle: Foundation.FileHandle?
    private var currentPosition: UInt64 = 0
    
    init(url: URL) {
        self.url = url
    }
    
    public func write(_ data: Data) async throws {
        if fileHandle == nil {
            // Create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            fileHandle = try Foundation.FileHandle(forWritingTo: url)
        }
        
        guard let handle = fileHandle else {
            throw WhatWGError.operationFailed("Failed to open file for writing")
        }
        
        try handle.seek(toOffset: currentPosition)
        try handle.write(contentsOf: data)
        currentPosition += UInt64(data.count)
    }
    
    public func seek(position: UInt64) async throws {
        currentPosition = position
        if let handle = fileHandle {
            try handle.seek(toOffset: position)
        }
    }
    
    public func truncate(size: UInt64) async throws {
        if fileHandle == nil {
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            fileHandle = try Foundation.FileHandle(forWritingTo: url)
        }
        
        guard let handle = fileHandle else {
            throw WhatWGError.operationFailed("Failed to open file for writing")
        }
        
        try handle.truncate(atOffset: size)
    }
    
    public func close() async throws {
        try fileHandle?.close()
        fileHandle = nil
    }
}

// MARK: - Backwards Compatibility

/// Deprecated: Use `UIDocumentPickerFileSystemProvider` instead.
@available(iOS 17.0, macOS 14.0, *)
@available(*, deprecated, renamed: "UIDocumentPickerFileSystemProvider")
public typealias iOSFileSystemProvider = UIDocumentPickerFileSystemProvider
#endif
