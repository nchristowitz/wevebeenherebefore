//
//  wevebeenherebeforeApp.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 03.02.25.
//

import SwiftUI
import SwiftData
import UserNotifications

// Add AppDelegate to handle notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories
        registerNotificationCategories()
        
        return true
    }
    
    private func registerNotificationCategories() {
        let category = UNNotificationCategory(
            identifier: "EPISODE_CHECKIN",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Clear badge immediately when notification is tapped
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        if let episodeID = userInfo["episodeID"] as? String,
           let checkInTypeString = userInfo["checkInType"] as? String,
           let checkInType = CheckInType(rawValue: checkInTypeString) {
            
            // Use the notification coordinator to handle navigation
            NotificationCoordinator.shared.handleNotificationTap(
                episodeID: episodeID,
                checkInType: checkInType
            )
        }
        
        completionHandler()
    }
}

@main
struct wevebeenherebeforeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Card.self,
            Episode.self,
            EpisodeNote.self,
            CheckIn.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            ensureUniqueEpisodeUUIDs(in: container)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await NotificationManager.shared.migrateNotificationsToUUIDIfNeeded(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .task {
                    // Image work is slow, so keep it off the main thread
                    let container = sharedModelContainer
                    await Task.detached(priority: .utility) {
                        downscaleStoredCardPhotosIfNeeded(in: container)
                    }.value
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// SwiftData's lightweight migration can stamp every pre-existing episode with
// the same default UUID. Notification identity needs them unique, so backfill
// any duplicates once at launch.
func ensureUniqueEpisodeUUIDs(in container: ModelContainer) {
    let context = ModelContext(container)
    guard let episodes = try? context.fetch(FetchDescriptor<Episode>()) else { return }

    var seen = Set<UUID>()
    var changed = false

    for episode in episodes {
        if seen.contains(episode.uuid) {
            episode.uuid = UUID()
            changed = true
        }
        seen.insert(episode.uuid)
    }

    if changed {
        do {
            try context.save()
            print("✅ Backfilled unique UUIDs for episodes")
        } catch {
            print("❌ Failed to backfill episode UUIDs: \(error)")
        }
    }
}

// One-time: shrink card photos stored at full resolution before photos
// were downscaled on pick (see Card.downscaledImageData). Uses its own
// context so it can run off the main thread; the UI picks up the save.
func downscaleStoredCardPhotosIfNeeded(in container: ModelContainer) {
    let migrationKey = "didDownscaleCardPhotos"
    guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

    let context = ModelContext(container)
    guard let cards = try? context.fetch(FetchDescriptor<Card>()) else { return }

    var shrunkCount = 0
    for card in cards {
        guard let original = card.imageData,
              let smaller = Card.downscaledImageData(original),
              smaller.count < original.count else { continue }
        card.imageData = smaller
        shrunkCount += 1
    }

    do {
        if shrunkCount > 0 {
            try context.save()
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ Downscaled \(shrunkCount) card photos")
    } catch {
        print("❌ Failed to save downscaled card photos: \(error)")
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var episodes: [Episode]
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared

    // Calculate pending check-ins count for badge
    private var pendingCheckInsCount: Int {
        episodes.reduce(0) { $0 + $1.pendingCheckInTypes.count }
    }

    var body: some View {
        TabView(selection: $notificationCoordinator.selectedTab) {
            EpisodesListView()
                .tabItem {
                    Label("Episodes", systemImage: "tornado")
                }
                .badge(pendingCheckInsCount > 0 ? pendingCheckInsCount : 0)
                .tag(AppTab.episodes)

            ResilienceView()
                .tabItem {
                    Label("Resilience", systemImage: "heart.fill")
                }
                .tag(AppTab.resilience)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.primary)
        .onAppear {
            refreshBadgeCount()

            Task {
                await NotificationManager.shared.checkPermission()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Check-in windows open and close while the app is in the background
            refreshBadgeCount()
        }
    }

    private func refreshBadgeCount() {
        NotificationManager.shared.refreshBadgeCount(modelContext: modelContext)
    }
}
