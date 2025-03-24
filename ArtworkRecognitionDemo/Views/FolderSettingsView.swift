//
//  FolderSettingsView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import SwiftUI

struct FolderSettingsView: View {
  let folderURL: URL
  @State private var copiedPath = false
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Your museum files need to be placed in this folder:")
            .font(.headline)
          
          Text(folderURL.path)
            .font(.system(.body, design: .monospaced))
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
          
          Button(copiedPath ? "Path Copied!" : "Copy Path") {
            UIPasteboard.general.string = folderURL.path
            copiedPath = true
            
            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              copiedPath = false
            }
          }
          .buttonStyle(.borderedProminent)
          
          Divider()
          
          Text("Instructions")
            .font(.headline)
          
          VStack(alignment: .leading, spacing: 12) {
            InstructionRow(number: 1, text: "Open the Files app on your iPhone")
            InstructionRow(number: 2, text: "Navigate to 'On My iPhone' > '\(Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "ARMuseumApp")'")
            InstructionRow(number: 3, text: "Copy your museum folders into this location")
            InstructionRow(number: 4, text: "Return to the app and restart it")
          }
          
          Text("Note: You may need to enable 'On My iPhone' location in the Files app settings first.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top)
        }
        .padding()
      }
      .navigationTitle("App Folder Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            // This will dismiss the sheet
            UIPasteboard.general.string = nil
          }
        }
      }
    }
  }
}

struct InstructionRow: View {
  let number: Int
  let text: String
  
  var body: some View {
    HStack(alignment: .top) {
      Text("\(number).")
        .font(.headline)
        .frame(width: 25, alignment: .center)
      Text(text)
        .font(.body)
      Spacer()
    }
  }
}
