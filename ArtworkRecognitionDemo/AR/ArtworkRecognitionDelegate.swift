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
    
    // Create a more visible green frame
    let frameMaterial = SCNMaterial()
    frameMaterial.diffuse.contents = UIColor.green.withAlphaComponent(0.8)
    frameMaterial.lightingModel = .constant // Make sure it's always visible
    
    // Create a transparent material for the center
    let centerMaterial = SCNMaterial()
    centerMaterial.diffuse.contents = UIColor.clear
    centerMaterial.transparency = 0.2
    
    // Apply materials to the plane
    plane.materials = [centerMaterial]
    
    let planeNode = SCNNode(geometry: plane)
    planeNode.eulerAngles.x = -.pi / 2
    planeNode.opacity = 0.8
    
    // Create frame around the plane
    let frameWidth: CGFloat = 0.02 // Adjust as needed
    
    // Top frame
    let topFrame = SCNBox(width: plane.width, height: frameWidth, length: frameWidth, chamferRadius: 0)
    topFrame.materials = [frameMaterial]
    let topFrameNode = SCNNode(geometry: topFrame)
    topFrameNode.position = SCNVector3(0, 0, Float(plane.height/2) - Float(frameWidth/2))
    
    // Bottom frame
    let bottomFrame = SCNBox(width: plane.width, height: frameWidth, length: frameWidth, chamferRadius: 0)
    bottomFrame.materials = [frameMaterial]
    let bottomFrameNode = SCNNode(geometry: bottomFrame)
    bottomFrameNode.position = SCNVector3(0, 0, -Float(plane.height/2) + Float(frameWidth/2))
    
    // Left frame
    let leftFrame = SCNBox(width: frameWidth, height: frameWidth, length: plane.height, chamferRadius: 0)
    leftFrame.materials = [frameMaterial]
    let leftFrameNode = SCNNode(geometry: leftFrame)
    leftFrameNode.position = SCNVector3(-Float(plane.width/2) + Float(frameWidth/2), 0, 0)
    
    // Right frame
    let rightFrame = SCNBox(width: frameWidth, height: frameWidth, length: plane.height, chamferRadius: 0)
    rightFrame.materials = [frameMaterial]
    let rightFrameNode = SCNNode(geometry: rightFrame)
    rightFrameNode.position = SCNVector3(Float(plane.width/2) - Float(frameWidth/2), 0, 0)
    
    // Add frame parts to the plane node
    planeNode.addChildNode(topFrameNode)
    planeNode.addChildNode(bottomFrameNode)
    planeNode.addChildNode(leftFrameNode)
    planeNode.addChildNode(rightFrameNode)
    
    // Add a text node with the artwork name
    let textGeometry = SCNText(string: name, extrusionDepth: 0.01)
    textGeometry.font = UIFont.boldSystemFont(ofSize: 0.1)
    textGeometry.firstMaterial?.diffuse.contents = UIColor.white
    textGeometry.firstMaterial?.lightingModel = .constant // Ensure visibility
    
    let textNode = SCNNode(geometry: textGeometry)
    textNode.scale = SCNVector3(0.01, 0.01, 0.01)
    
    // Calculate position to center the text
    let (min, max) = textNode.boundingBox
    let textWidth = max.x - min.x
    
    // Position text above the frame
    textNode.position = SCNVector3(-Float(textWidth) * 0.01 / 2, 0.05, Float(plane.height / 2) + 0.05)
    
    // Add a backdrop for the text
    let backdropWidth = textWidth * 0.01 + 0.02
    let backdropHeight: Float = 0.03
    let backdropGeometry = SCNBox(
      width: CGFloat(backdropWidth),
      height: CGFloat(backdropHeight),
      length: 0.01,
      chamferRadius: 0.005
    )
    backdropGeometry.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.7)
    
    let backdropNode = SCNNode(geometry: backdropGeometry)
    backdropNode.position = SCNVector3(0, 0.05, Float(plane.height / 2) + 0.05)
    
    // Add text and backdrop to the frame
    planeNode.addChildNode(backdropNode)
    planeNode.addChildNode(textNode)
    
    node.addChildNode(planeNode)
  }
}
