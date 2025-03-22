//
//  ContentView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import SwiftUI

struct ContentView: View {
    @State private var appFolderURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var detectedArtwork: String?
    @State private var currentRoom = "Not located"
    @State private var isShowingARView = false
    @State private var isShowingSettings = false
    @State private var arSceneController: ARSceneView?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Setting up application...")
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Text("Error")
                            .font(.title)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            setupAppFolder()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "arkit")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("AR Museum Experience")
                            .font(.title)
                        
                        Text("This app demonstrates how to combine MARS positioning with artwork recognition in a museum setting.")
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Start AR Experience") {
                            isShowingARView = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("App Folder Settings") {
                            isShowingSettings = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("AR Museum Demo")
            .fullScreenCover(isPresented: $isShowingARView) {
                ARExperienceView(
                    detectedArtwork: $detectedArtwork,
                    currentRoom: $currentRoom,
                    appFolderURL: appFolderURL!
                )
            }
            .sheet(isPresented: $isShowingSettings) {
                if let folderURL = appFolderURL {
                    FolderSettingsView(folderURL: folderURL)
                }
            }
            .onAppear {
                setupAppFolder()
            }
        }
    }
    
    private func setupAppFolder() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Get the app name for folder name
            let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "ARMuseumApp"
            
            // Create app folder
            if let folderURL = FileManager.getOrCreateAppFolder(named: appName) {
                // Make folder visible to users
                FileManager.makeAppFolderVisible(named: appName)
                
                // Create a README file to help users
                createReadmeInFolder(folderURL)
                
                DispatchQueue.main.async {
                    self.appFolderURL = folderURL
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create app folder"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createReadmeInFolder(_ folderURL: URL) {
        let readmePath = folderURL.appendingPathComponent("README.txt")
        let readmeText = """
        This folder is for museum data files.
        
        Please copy your museum folders here.
        Each museum folder should contain floor folders.
        
        Example structure:
        - Museum1/
          - Floor1/
          - Floor2/
        - Museum2/
          - Floor1/
          - Floor2/
        """
        
        if !FileManager.default.fileExists(atPath: readmePath.path) {
            try? readmeText.write(to: readmePath, atomically: true, encoding: .utf8)
        }
    }
}
