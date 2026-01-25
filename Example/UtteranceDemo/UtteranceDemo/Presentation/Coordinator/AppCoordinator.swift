import Observation
import SwiftUI

// MARK: - AppCoordinator

@MainActor
@Observable
final class AppCoordinator {

    // MARK: - Navigation

    var path = NavigationPath()

    // MARK: - Child ViewModels

    private(set) var recordingViewModel: RecordingViewModel

    // MARK: - Init

    init(repository: RecordingRepositoryProtocol) {
        self.recordingViewModel = RecordingViewModel(repository: repository)
    }

    // MARK: - Navigation Methods

    func showDetails() {
        path.append(Route.details)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

// MARK: - CoordinatorView

struct CoordinatorView: View {
    @State var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            RecordingView(viewModel: coordinator.recordingViewModel)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .details:
                        Text("Details Screen")
                    }
                }
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        coordinator.recordingViewModel.items = [.init(text: "Hello every one!", isFinal: true)]
                    }
                }
        }
    }
}

#Preview {
    CoordinatorView(coordinator: .init(repository: RecordingRepository()))
}
