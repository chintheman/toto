import SwiftUI

struct LearnView: View {
    @State private var fallacies: [Fallacy] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showOnboardingReplay = false

    private let repository = FallaciesRepository()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showOnboardingReplay = true
                    } label: {
                        Label("Replay the intro carousel", systemImage: "play.rectangle.fill")
                    }
                }

                Section("Every Fallacy, Busted") {
                    ForEach(fallacies) { fallacy in
                        NavigationLink(value: fallacy) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(fallacy.emoji ?? "")
                                    Text(fallacy.mythStatement)
                                        .font(.subheadline.bold())
                                        .strikethrough()
                                }
                                Text(fallacy.verdictLabel)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Learn")
            .navigationDestination(for: Fallacy.self) { fallacy in
                FallacyDetailView(fallacy: fallacy)
            }
            .overlay {
                if isLoading { ProgressView() }
                if let error = errorMessage, fallacies.isEmpty {
                    ContentUnavailableView("Couldn't load fallacies", systemImage: "wifi.slash", description: Text(error))
                }
            }
            .task {
                await loadFallacies()
            }
            .fullScreenCover(isPresented: $showOnboardingReplay) {
                OnboardingCarouselView { showOnboardingReplay = false }
            }
        }
    }

    @MainActor
    private func loadFallacies() async {
        isLoading = true
        errorMessage = nil
        do {
            fallacies = try await repository.allFallacies()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct FallacyDetailView: View {
    let fallacy: Fallacy

    var body: some View {
        ScrollView {
            FallacyCardView(fallacy: fallacy)
        }
        .background(LinearGradient(colors: [.black, .indigo.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
