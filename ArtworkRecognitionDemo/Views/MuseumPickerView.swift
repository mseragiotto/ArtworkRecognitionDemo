//
//  MuseumPickerView.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import SwiftUI

struct MuseumPickerView: View {
  let museums: [Museum]
  @Binding var selectedMuseum: Museum?
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      List(museums, id: \.name) { museum in
        Button(action: {
          selectedMuseum = museum
          dismiss()
        }) {
          HStack {
            Text(museum.name)
            Spacer()
            if selectedMuseum?.name == museum.name {
              Image(systemName: "checkmark")
                .foregroundColor(.blue)
            }
          }
        }
      }
      .navigationTitle("Select Museum")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}
