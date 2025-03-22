//
//  FileManager.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import Foundation
import UIKit

extension FileManager {
    /// Gets the app's document directory
    static func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Gets or creates the app folder and returns its URL
    static func getOrCreateAppFolder(named folderName: String = "ARMuseumApp") -> URL? {
        let fileManager = FileManager.default
        let documentsURL = getDocumentsDirectory()
        let appFolderURL = documentsURL.appendingPathComponent(folderName)
        
        // Create the folder if it doesn't exist
        if !fileManager.fileExists(atPath: appFolderURL.path) {
            do {
                try fileManager.createDirectory(
                    at: appFolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("✅ App folder created at: \(appFolderURL.path)")
                return appFolderURL
            } catch {
                print("❌ Failed to create app folder: \(error)")
                return nil
            }
        } else {
            print("✅ Using existing app folder at: \(appFolderURL.path)")
            return appFolderURL
        }
    }
    
    /// Share the app folder with the system Files app to make it visible
    static func makeAppFolderVisible(named folderName: String = "ARMuseumApp") {
        // This allows the app folder to be visible in the Files app
        do {
            if let appFolder = getOrCreateAppFolder(named: folderName) {
                try FileManager.default.setAttributes(
                    [FileAttributeKey.posixPermissions: 0o777],
                    ofItemAtPath: appFolder.path
                )
            }
        } catch {
            print("❌ Failed to set folder permissions: \(error)")
        }
    }
}
