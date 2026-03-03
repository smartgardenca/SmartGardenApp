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

    @State private var hasStarted = false
    
    var body: some View {
        ZStack {
            if hasStarted {
                WebView(url: URL(string: "https://app.smart-garden.ca")!)
                    .ignoresSafeArea()
            }else {
                WelcomeView(isStarted: $hasStarted)
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
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
