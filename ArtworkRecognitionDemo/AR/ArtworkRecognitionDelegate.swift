//
//  ArtworkRecognitionDelegate.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import ARKit
import Combine

@available(iOS 16.0, *)
class ArtworkRecognitionDelegate: NSObject, ARSCNViewDelegate {
  // Collection of artwork reference images
  private(set) var artworkImages: Set<ARReferenceImage> = []
  
  // Subject to publish artwork recognition events
  private let artworkRecognized = PassthroughSubject<String, Never>()
  
  var recognitionPublisher: AnyPublisher<String, Never> {
    return artworkRecognized.eraseToAnyPublisher()
  }
  
  init(artworkImages: [ArtworkReference]) {
    super.init()
    
    // Create reference images from artwork data
    for artwork in artworkImages {
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
  
  // ARSCNViewDelegate method to handle image detection
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    if let imageAnchor = anchor as? ARImageAnchor,
       let imageName = imageAnchor.referenceImage.name,
       !imageName.hasPrefix("marker_") { // Ignore MARS markers
      
      // Publish the artwork recognition event
      artworkRecognized.send(imageName)
      
      // Add visual indicator for the recognized artwork
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
      
      // Add information text node
      let textGeometry = SCNText(string: "Artwork: \(imageName)", extrusionDepth: 0.01)
      textGeometry.font = UIFont.systemFont(ofSize: 0.1)
      textGeometry.firstMaterial?.diffuse.contents = UIColor.white
      
      let textNode = SCNNode(geometry: textGeometry)
      textNode.scale = SCNVector3(0.01, 0.01, 0.01)
      textNode.position = SCNVector3(0, 0.05, 0)
      
      planeNode.addChildNode(textNode)
      node.addChildNode(planeNode)
    }
  }
}
