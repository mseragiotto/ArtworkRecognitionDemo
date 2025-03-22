//
//  ArtworkRecognitionDelegate.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import ARKit
import Combine
import Vision

class ArtworkRecognitionDelegate: NSObject, ARSCNViewDelegate {
    // Collection of artwork reference images
    private(set) var artworkImages: Set<ARReferenceImage> = []
    private var detectedArtworks = Set<String>()
    
    // Subject to publish artwork recognition events
    private let artworkRecognizedSubject = PassthroughSubject<String, Never>()
    
    // Mapping of artwork names to their data
    private var artworkData: [String: ArtworkReference] = [:]
    
    var recognitionPublisher: AnyPublisher<String, Never> {
        return artworkRecognizedSubject.eraseToAnyPublisher()
    }
    
    init(artworkImages: [ArtworkReference]) {
        super.init()
        
        // Create reference images from artwork data
        for artwork in artworkImages {
            // Store artwork data for lookup
            artworkData[artwork.name] = artwork
            
            if let cgImage = artwork.image.cgImage {
                let referenceImage = ARReferenceImage(
                    cgImage,
                    orientation: .up,
                    physicalWidth: artwork.physicalWidth
                )
                referenceImage.name = artwork.name
                self.artworkImages.insert(referenceImage)
            }
        }
    }
    
    // Get artwork data by name
    func getArtworkData(for name: String) -> ArtworkReference? {
        return artworkData[name]
    }
    
    // ARSCNViewDelegate method to handle image detection
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor,
           let imageName = imageAnchor.referenceImage.name,
           !detectedArtworks.contains(imageName) {
            
            // Mark as detected to avoid duplicate notifications
            detectedArtworks.insert(imageName)
            
            // Publish the artwork recognition event
            DispatchQueue.main.async {
                self.artworkRecognizedSubject.send(imageName)
            }
            
            // Add visual indicator for the recognized artwork
            addVisualIndicator(to: node, for: imageAnchor, name: imageName)
        }
    }
    
    // Clear detected artwork history
    func clearDetections() {
        detectedArtworks.removeAll()
    }
    
    private func addVisualIndicator(to node: SCNNode, for imageAnchor: ARImageAnchor, name: String) {
        // Create visual indicator plane
        let plane = SCNPlane(
            width: imageAnchor.referenceImage.physicalSize.width,
            height: imageAnchor.referenceImage.physicalSize.height
        )
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green.withAlphaComponent(0.6)
        plane.materials = [material]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.opacity = 0.8
        
        // Add a text node with the artwork name
        let textGeometry = SCNText(string: name, extrusionDepth: 0.01)
        textGeometry.font = UIFont.systemFont(ofSize: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        textNode.position = SCNVector3(0, 0.05, 0)
        
        planeNode.addChildNode(textNode)
        node.addChildNode(planeNode)
    }
}
