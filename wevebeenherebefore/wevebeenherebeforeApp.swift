//
//  wevebeenherebeforeApp.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 03.02.25.
//

import SwiftUI
import SwiftData

@main
struct wevebeenherebeforeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Card.self,
            Episode.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ResilienceView()
        }
        .modelContainer(sharedModelContainer)
    }
}
