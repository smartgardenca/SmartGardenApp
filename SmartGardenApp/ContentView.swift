//
//  ContentView.swift
//  SmartGardenApp
//
//  Created by Xu Han on 2025/4/15.
//
import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var base64Image: String? = nil

    var body: some View {
        ZStack {
            WebView(url: URL(string: "https://app.smart-garden.ca")!)
                .edgesIgnoringSafeArea(.all)

            if showCamera {
                CameraManager { base64 in
                    self.base64Image = base64
                    self.showCamera = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .takePhotoNotification)) { _ in
            self.showCamera = true
        }
    }
}
