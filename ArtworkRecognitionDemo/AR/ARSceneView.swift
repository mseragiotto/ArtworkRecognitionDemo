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
    @Binding var detectedRoom: String
    @Binding var isPositioned: Bool
    let appFolderURL: URL
    var viewController: ARViewController?
    
    class Coordinator: NSObject {
        var parent: ARSceneView
        
        init(_ parent: ARSceneView) {
            self.parent = parent
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> ARViewController {
        // Create the AR controller
        let controller = ARViewController()
        
        // Set up callbacks
        controller.onArtworkDetected = { artwork in
            detectedArtwork = artwork
        }
        
        controller.onRoomDetected = { room in
            detectedRoom = room
            isPositioned = true
        }
        
        // Initialize MARS
        controller.initializeMARS(appFolderURL: appFolderURL)
        
        // Save controller reference
        viewController = controller
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update the controller if needed
        if uiViewController.currentArtwork != detectedArtwork {
            uiViewController.currentArtwork = detectedArtwork
        }
        
        if uiViewController.currentRoom != detectedRoom {
            uiViewController.currentRoom = detectedRoom
        }
    }
    
    // Helper to toggle debug mode
    func toggleDebugMode() {
        viewController?.toggleDebugMode()
    }
}
