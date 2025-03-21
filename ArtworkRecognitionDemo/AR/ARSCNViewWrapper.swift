//
//  ARSCNViewWrapper.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import SwiftUI
import ARKit

@available(iOS 16.0, *)
struct ARSCNViewWrapper: UIViewRepresentable {
  let arView: ARSCNView
  
  func makeUIView(context: Context) -> ARSCNView {
    return arView
  }
  
  func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
