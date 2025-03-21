//
//  MuseumModels.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import Foundation

struct Museum {
  let name: String
  let floors: [Floor]
}

struct Floor {
  let name: String
  let arlFile: ARLFile
}

struct ARLFile {
  let floorName: String
  let floorFolderURL: URL
}
