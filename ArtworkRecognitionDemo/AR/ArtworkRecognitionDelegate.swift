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
    // Get the dimensions of the detected image
    let width = imageAnchor.referenceImage.physicalSize.width
    let height = imageAnchor.referenceImage.physicalSize.height
    
    // Create a frame node that will hold all our border elements
    let frameNode = SCNNode()
    frameNode.eulerAngles.x = -.pi   // Rotate to lie flat on the image
    
    // Green material for the frame
    let frameMaterial = SCNMaterial()
    frameMaterial.diffuse.contents = UIColor.green.withAlphaComponent(0.9)
    frameMaterial.lightingModel = .constant // Always visible
    
    // Create frame thickness
    let thickness: CGFloat = 0.005  // 5mm
    let borderWidth: CGFloat = 0.01  // 1cm
    
    // Create the four border pieces correctly aligned
    // Top border - along negative Z axis in SCNNode's rotated coordinate system
    let topBorder = SCNBox(width: width, height: thickness, length: borderWidth, chamferRadius: 0)
    topBorder.materials = [frameMaterial]
    let topNode = SCNNode(geometry: topBorder)
    topNode.position = SCNVector3(0, 0, -Float(height) / 2)
    
    // Bottom border - along positive Z axis in SCNNode's rotated coordinate system
    let bottomBorder = SCNBox(width: width, height: thickness, length: borderWidth, chamferRadius: 0)
    bottomBorder.materials = [frameMaterial]
    let bottomNode = SCNNode(geometry: bottomBorder)
    bottomNode.position = SCNVector3(0, 0, Float(height) / 2)
    
    // Left border - along negative X axis in SCNNode's rotated coordinate system
    let leftBorder = SCNBox(width: borderWidth, height: thickness, length: height, chamferRadius: 0)
    leftBorder.materials = [frameMaterial]
    let leftNode = SCNNode(geometry: leftBorder)
    leftNode.position = SCNVector3(-Float(width) / 2, 0, 0)
    
    // Right border - along positive X axis in SCNNode's rotated coordinate system
    let rightBorder = SCNBox(width: borderWidth, height: thickness, length: height, chamferRadius: 0)
    rightBorder.materials = [frameMaterial]
    let rightNode = SCNNode(geometry: rightBorder)
    rightNode.position = SCNVector3(Float(width) / 2, 0, 0)
    
    // Add all borders to the frame node
    frameNode.addChildNode(topNode)
    frameNode.addChildNode(bottomNode)
    frameNode.addChildNode(leftNode)
    frameNode.addChildNode(rightNode)
    
    // Add the artwork name label
    let textNode = createTextLabel(name: name, width: width, height: height)
    frameNode.addChildNode(textNode)
    
    // Add the frame to the main node
    node.addChildNode(frameNode)
  }
  
  private func createTextLabel(name: String, width: CGFloat, height: CGFloat) -> SCNNode {
    // Create a container node for the label
    let containerNode = SCNNode()
    
    // Create a background plane for the text
    let backgroundGeometry = SCNPlane(width: width * 0.8, height: 0.04)
    let backgroundMaterial = SCNMaterial()
    backgroundMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.7)
    backgroundGeometry.materials = [backgroundMaterial]
    
    let backgroundNode = SCNNode(geometry: backgroundGeometry)
    backgroundNode.position = SCNVector3(0, 0.01, -Float(height) / 2 - 0.03) // Positioned above the top frame
    
    // Create the text
    let textGeometry = SCNText(string: name, extrusionDepth: 0.001)
    textGeometry.font = UIFont.boldSystemFont(ofSize: 0.03)
    textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
    textGeometry.firstMaterial?.diffuse.contents = UIColor.white
    textGeometry.firstMaterial?.lightingModel = .constant // Always visible
    
    // Calculate text size for centering
    let textNode = SCNNode(geometry: textGeometry)
    textNode.scale = SCNVector3(0.01, 0.01, 0.01) // Scale down the text
    
    // Calculate bounds to center the text
    let (min, max) = textNode.boundingBox
    let textWidth = max.x - min.x
    
    // Position the text on the background
    textNode.position = SCNVector3(-Float(textWidth) * 0.005, 0.005, -Float(height) / 2 - 0.03)
    
    // Add both nodes to the container
    containerNode.addChildNode(backgroundNode)
    containerNode.addChildNode(textNode)
    
    return containerNode
  }
}
