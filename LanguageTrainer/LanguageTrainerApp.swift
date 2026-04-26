import SwiftUI

@main
struct LanguageTrainerApp: App {
    @StateObject private var starStore = StarStore()
    @StateObject private var lessonsStore = LessonsStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                } else {
                    ContentView()
                        .environmentObject(starStore)
                        .environmentObject(lessonsStore)   // ✅
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
