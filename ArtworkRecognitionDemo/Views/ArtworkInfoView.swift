//
//  ArtworkInfoView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import SwiftUI

struct ArtworkInfoView: View {
  let artworkName: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(artworkName)
        .font(.largeTitle)
        .bold()
      
      // Display artwork information
      // This would normally come from a database or API
      Text("Information about \(artworkName)")
        .padding(.top)
      
      Spacer()
    }
    .padding()
  }
}
