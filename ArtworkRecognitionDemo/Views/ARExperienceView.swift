//
//  ARExperienceView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import SwiftUI

struct ARExperienceView: View {
    @Binding var detectedArtwork: String?
    @Binding var currentRoom: String
    let appFolderURL: URL
    
    @State private var isDebugMode = false
    @State private var showArtworkInfo = false
    @Environment(\.dismiss) private var dismiss
    
    // Reference to AR controller for toggling debug mode
    @State private var arSceneView: ARSceneView?
    
    var body: some View {
        ZStack {
            // AR Scene
            ARSceneView(
                detectedArtwork: $detectedArtwork,
                currentRoom: $currentRoom,
                appFolderURL: appFolderURL
            )
            .ignoresSafeArea()
            .onAppear { viewBuilder in
                self.arSceneView = viewBuilder
            }
            
            // Status overlay at top
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Room: \(currentRoom)")
                            .font(.headline)
                        
                        if let artwork = detectedArtwork {
                            Text("Artwork: \(artwork)")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Button(action: {
                        isDebugMode.toggle()
                        arSceneView?.toggleDebugMode()
                    }) {
                        Label(
                            isDebugMode ? "Hide Debug" : "Show Debug",
                            systemImage: isDebugMode ? "eye.slash" : "eye"
                        )
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    if detectedArtwork != nil {
                        Button(action: {
                            showArtworkInfo = true
                        }) {
                            Label("Artwork Info", systemImage: "info.circle")
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            
            // Artwork recognition popup
            if let artwork = detectedArtwork, showArtworkInfo {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Artwork Detected")
                            .font(.headline)
                        
                        Text(artwork)
                            .font(.title2)
                            .bold()
                        
                        Button("Close") {
                            showArtworkInfo = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .padding()
                }
            }
        }
    }
}
