//
//  MedAlertApp.swift
//  MedAlert
//
//  Created by Kaleb Rodriguez on 3/29/26.
//
//

import SwiftUI
import SwiftData

@main
struct MedAlertApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Medication.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
