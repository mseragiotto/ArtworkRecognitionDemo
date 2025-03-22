//
//  ARExperienceView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import SwiftUI

struct ARExperienceView: View {
    @State private var detectedArtwork: String?
    @State private var detectedRoom: String = "Not located"
    @State private var isPositioned: Bool = false
    @State private var isDebugMode = false
    @State private var showArtworkInfo = false
    @State private var isHelpVisible = true
    
    let appFolderURL: URL
    
    @Environment(\.dismiss) private var dismiss
    
    // Reference to AR controller for toggling debug mode
    @State private var arSceneView: ARSceneView?
    
    var body: some View {
        ZStack {
            // AR Scene
            ARSceneView(
                detectedArtwork: $detectedArtwork,
                detectedRoom: $detectedRoom,
                isPositioned: $isPositioned,
                appFolderURL: appFolderURL
            )
            .ignoresSafeArea()
            .onChange(of: arSceneView) { view in
                if let view = view {
                    // Store reference to the view
                    self.arSceneView = view
                }
            }
            
            // Status overlay at top
            VStack {
                HStack {
                    Button(action: {
                        // Reset state before dismissing
                        detectedArtwork = nil
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
                        Text("Room: \(detectedRoom)")
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
                    // Only show debug button after positioned
                    if isPositioned {
                        Button(action: {
                            isDebugMode.toggle()
                            arSceneView?.viewController?.toggleDebugMode()
                        }) {
                            Label(
                                isDebugMode ? "Hide Map" : "Show Map",
                                systemImage: isDebugMode ? "map.fill" : "map"
                            )
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                    
                    if let artwork = detectedArtwork {
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
            
            // Initial positioning help overlay
            if !isPositioned && isHelpVisible {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Position Yourself First")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Point your camera at a room marker to establish your position in the museum.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                        
                        Button("Got it") {
                            isHelpVisible = false
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding()
                    
                    Spacer()
                }
            }
            
            // Artwork info popup
            if let artwork = detectedArtwork, showArtworkInfo {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Artwork Information")
                            .font(.headline)
                        
                        Text(artwork)
                            .font(.title2)
                            .bold()
                        
                        // Get artwork description from the controller
                        if let artworkData = arSceneView?.viewController?.artworkRecognizer?.getArtworkData(for: artwork) {
                            Text(artworkData.description)
                                .padding(.vertical)
                        }
                        
                        HStack {
                            Button("Close") {
                                showArtworkInfo = false
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Clear") {
                                showArtworkInfo = false
                                detectedArtwork = nil
                                
                                // Clear detection history in the recognizer
                                arSceneView?.viewController?.artworkRecognizer?.clearDetections()
                            }
                            .buttonStyle(.borderedProminent)
                        }
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
