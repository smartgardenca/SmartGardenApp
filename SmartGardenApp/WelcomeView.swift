import SwiftUI
import Foundation
import Network

// NetworkPreloader 保持不变
class NetworkPreloader {
    static func preload() {
        guard let url = URL(string: "https://app.smart-garden.ca") else { return }
        let task = URLSession.shared.dataTask(with: url) { _, _, _ in
            print("Network preloaded - permission should be triggered.")
        }
        task.resume()
    }
}

struct WelcomeView: View {
    @Binding var isStarted: Bool
    
    var body: some View {
        // 使用 GeometryReader 获取屏幕尺寸，而不是使用硬编码的像素
        GeometryReader { geometry in
            ZStack {
                // 1. 背景层
                Image("WelcomeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // 使背景图铺满整个屏幕，包括刘海和底部指示器区域
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                
                // 2. 内容层
                VStack(spacing: 0) {
                    // Logo 区域
                    Image("SmartGardenLogo")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        // 宽度设为屏幕宽度的 60%，最大限制在 iPad 上不过大
                        .frame(width: min(geometry.size.width * 0.6, 300))
                        .padding(.top, geometry.size.height * 0.05) // 使用高度的百分比

                    // Welcome Text 区域
                    Image("WelcomeText")
                        .resizable()
                        .scaledToFit()
                        // 宽度设为屏幕宽度的 85%，在小屏 iPhone 上留有空隙
                        .frame(width: min(geometry.size.width * 0.85, 400))
                        .padding(.top, geometry.size.height * 0.08)
                    
                    Spacer() // 推开内容
                    
                    // 按钮区域
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isStarted = true
                        }
                    }) {
                        Text("Get started")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    // 按钮宽度：iPad 上不撑满，iPhone 上左右留白
                    .frame(width: min(geometry.size.width * 0.8, 400))
                    // 使用 padding 确保按钮在底部有足够空间，且兼容刘海屏
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
        }
        .onAppear {
            print("WelcomeView appeared, triggering network preload...")
            NetworkPreloader.preload()
        }
    }
}
