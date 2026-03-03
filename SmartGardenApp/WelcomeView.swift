struct WelcomeView: View {
    @Binding var isStarted: Bool
    
    var body: some View {
        ZStack {
            // 背景图
            Image("your_bg_image") 
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
                // Logo 区域... (同上个回答)
                
                Spacer()
                
                // 底部按钮
                Button(action: {
                    isStarted = true // 切换状态，触发 WebView 加载
                }) {
                    Text("Get started")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .padding(40)
            }
        }
    }
}