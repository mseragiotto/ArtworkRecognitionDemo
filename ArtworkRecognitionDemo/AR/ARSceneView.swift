//
//  ARSceneView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import SwiftUI
import ARKit

struct ARSceneView: UIViewControllerRepresentable {
    @Binding var detectedArtwork: String?
    @Binding var currentRoom: String
    @State private var viewController: ARViewController?
    let appFolderURL: URL
    
    func makeUIViewController(context: Context) -> ARViewController {
        // Create artwork recognizer
        let artworkRecognizer = ArtworkRecognitionDelegate(artworkImages: loadArtworkReferences())
        
        // Create the AR controller
        let controller = ARViewController(artworkRecognizer: artworkRecognizer)
        controller.onArtworkDetected = { artwork in
            detectedArtwork = artwork
        }
        
        // Store the controller
        viewController = controller
        
        // Initialize MARS
        controller.initializeMARS(appFolderURL: appFolderURL)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update the controller with current room if needed
        if uiViewController.currentRoom != currentRoom {
            uiViewController.currentRoom = currentRoom
        }
    }
    
    // Helper to toggle debug mode
    func toggleDebugMode() {
        viewController?.toggleDebugMode()
    }
    
    // Load artwork references - you'll need to customize this based on your artwork data
    private func loadArtworkReferences() -> [ArtworkReference] {
        return [
            ArtworkReference(
                name: "Mona Lisa",
                image: UIImage(named: "mona_lisa") ?? UIImage(),
                physicalWidth: 0.53, // in meters
                description: "Painted by Leonardo da Vinci between 1503 and 1506"
            ),
            ArtworkReference(
                name: "Starry Night",
                image: UIImage(named: "starry_night") ?? UIImage(),
                physicalWidth: 0.74, // in meters
                description: "Painted by Vincent van Gogh in 1889"
            )
        ]
    }
}
