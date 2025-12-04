package com.whatwg.android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.activity.result.ActivityResultLauncher
import com.whatwg.providers.DirectoryHandle
import com.whatwg.providers.DirectoryPickerOptions
import com.whatwg.providers.FileHandle
import com.whatwg.providers.FilePickerOptions
import com.whatwg.providers.FileSystemProvider
import com.whatwg.providers.FileWritableStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile

/**
 * Android implementation of FileSystemProvider using Storage Access Framework.
 *
 * Note: For file picker dialogs, this requires ActivityResultLauncher integration.
 * This implementation provides the OPFS (Origin Private File System) using
 * the app's internal storage directory.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.fileSystemProvider = AndroidFileSystemProvider(context)
 * ```
 *
 * @param context Android context.
 * @param opfsDirectoryName Name of the directory for OPFS storage.
 */
class AndroidFileSystemProvider(
    private val context: Context,
    opfsDirectoryName: String = "opfs"
) : FileSystemProvider {
    
    private val opfsDirectory: File = File(context.filesDir, opfsDirectoryName).also {
        it.mkdirs()
    }
    
    // Note: showOpenFilePicker, showSaveFilePicker, and showDirectoryPicker
    // require ActivityResultLauncher which needs Activity integration.
    // These are simplified implementations that throw UnsupportedOperationException.
    // For full implementation, see AndroidActivityFileSystemProvider below.
    
    override suspend fun showOpenFilePicker(options: FilePickerOptions): List<FileHandle> {
        throw UnsupportedOperationException(
            "showOpenFilePicker requires Activity integration. " +
            "Use AndroidActivityFileSystemProvider with an Activity context."
        )
    }
    
    override suspend fun showSaveFilePicker(options: FilePickerOptions): FileHandle {
        throw UnsupportedOperationException(
            "showSaveFilePicker requires Activity integration. " +
            "Use AndroidActivityFileSystemProvider with an Activity context."
        )
    }
    
    override suspend fun showDirectoryPicker(options: DirectoryPickerOptions): DirectoryHandle {
        throw UnsupportedOperationException(
            "showDirectoryPicker requires Activity integration. " +
            "Use AndroidActivityFileSystemProvider with an Activity context."
        )
    }
    
    override suspend fun getOriginPrivateDirectory(): DirectoryHandle = withContext(Dispatchers.IO) {
        AndroidLocalDirectoryHandle(opfsDirectory)
    }
}

/**
 * FileHandle implementation for local files.
 */
class AndroidLocalFileHandle(
    private val file: File
) : FileHandle {
    
    override val name: String = file.name
    
    override suspend fun getFile(): ByteArray = withContext(Dispatchers.IO) {
        file.readBytes()
    }
    
    override suspend fun createWritable(): FileWritableStream = withContext(Dispatchers.IO) {
        AndroidLocalFileWritableStream(file)
    }
}

/**
 * DirectoryHandle implementation for local directories.
 */
class AndroidLocalDirectoryHandle(
    private val directory: File
) : DirectoryHandle {
    
    override val name: String = directory.name
    
    override suspend fun getFileHandle(name: String, create: Boolean): FileHandle = withContext(Dispatchers.IO) {
        val file = File(directory, name)
        
        if (!file.exists()) {
            if (create) {
                file.createNewFile()
            } else {
                throw NoSuchFileException(file, reason = "File not found: $name")
            }
        }
        
        if (file.isDirectory) {
            throw IllegalArgumentException("$name is a directory, not a file")
        }
        
        AndroidLocalFileHandle(file)
    }
    
    override suspend fun getDirectoryHandle(name: String, create: Boolean): DirectoryHandle = withContext(Dispatchers.IO) {
        val dir = File(directory, name)
        
        if (!dir.exists()) {
            if (create) {
                dir.mkdirs()
            } else {
                throw NoSuchFileException(dir, reason = "Directory not found: $name")
            }
        }
        
        if (!dir.isDirectory) {
            throw IllegalArgumentException("$name is a file, not a directory")
        }
        
        AndroidLocalDirectoryHandle(dir)
    }
    
    override suspend fun removeEntry(name: String, recursive: Boolean) = withContext(Dispatchers.IO) {
        val entry = File(directory, name)
        
        if (!entry.exists()) {
            throw NoSuchFileException(entry)
        }
        
        if (entry.isDirectory && recursive) {
            entry.deleteRecursively()
        } else {
            entry.delete()
        }
    }
    
    override suspend fun entries(): List<Pair<String, Any>> = withContext(Dispatchers.IO) {
        directory.listFiles()?.map { file ->
            val handle: Any = if (file.isDirectory) {
                AndroidLocalDirectoryHandle(file)
            } else {
                AndroidLocalFileHandle(file)
            }
            file.name to handle
        } ?: emptyList()
    }
}

/**
 * FileWritableStream implementation for local files.
 */
class AndroidLocalFileWritableStream(
    private val file: File
) : FileWritableStream {
    
    private var randomAccessFile: RandomAccessFile? = null
    private val mutex = Mutex()
    private var position: Long = 0
    
    override suspend fun write(data: ByteArray) = withContext(Dispatchers.IO) {
        mutex.withLock {
            ensureOpen()
            randomAccessFile?.seek(position)
            randomAccessFile?.write(data)
            position += data.size
        }
    }
    
    override suspend fun seek(position: Long) {
        mutex.withLock {
            this.position = position
        }
    }
    
    override suspend fun truncate(size: Long) = withContext(Dispatchers.IO) {
        mutex.withLock {
            ensureOpen()
            randomAccessFile?.setLength(size)
        }
    }
    
    override fun close() {
        randomAccessFile?.close()
        randomAccessFile = null
    }
    
    private fun ensureOpen() {
        if (randomAccessFile == null) {
            randomAccessFile = RandomAccessFile(file, "rw")
        }
    }
}

/**
 * FileHandle implementation for content URIs (SAF - Storage Access Framework).
 */
class AndroidContentFileHandle(
    private val context: Context,
    private val uri: Uri,
    override val name: String
) : FileHandle {
    
    override suspend fun getFile(): ByteArray = withContext(Dispatchers.IO) {
        context.contentResolver.openInputStream(uri)?.use { inputStream ->
            inputStream.readBytes()
        } ?: throw IllegalStateException("Cannot read file: $name")
    }
    
    override suspend fun createWritable(): FileWritableStream = withContext(Dispatchers.IO) {
        AndroidContentFileWritableStream(context, uri)
    }
}

/**
 * FileWritableStream implementation for content URIs.
 */
class AndroidContentFileWritableStream(
    private val context: Context,
    private val uri: Uri
) : FileWritableStream {
    
    private var outputStream: FileOutputStream? = null
    private val mutex = Mutex()
    
    override suspend fun write(data: ByteArray) = withContext(Dispatchers.IO) {
        mutex.withLock {
            if (outputStream == null) {
                val descriptor = context.contentResolver.openFileDescriptor(uri, "w")
                    ?: throw IllegalStateException("Cannot open file for writing")
                outputStream = FileOutputStream(descriptor.fileDescriptor)
            }
            outputStream?.write(data)
        }
    }
    
    override suspend fun seek(position: Long) {
        // Not supported for content URIs in append mode
        throw UnsupportedOperationException("Seek not supported for content URIs")
    }
    
    override suspend fun truncate(size: Long) {
        // Not directly supported for content URIs
        throw UnsupportedOperationException("Truncate not supported for content URIs")
    }
    
    override fun close() {
        outputStream?.close()
        outputStream = null
    }
}
