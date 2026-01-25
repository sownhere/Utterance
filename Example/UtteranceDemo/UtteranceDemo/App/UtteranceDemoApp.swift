//
//  UtteranceDemoApp.swift
//  UtteranceDemo
//
//  Created by SownFrenky on 1/13/26.
//

import SwiftUI

@main
struct UtteranceDemoApp: App {
    @State private var coordinator = AppCoordinator(repository: RecordingRepository())

    var body: some Scene {
        WindowGroup {
            CoordinatorView(coordinator: coordinator)
        }
    }
}
