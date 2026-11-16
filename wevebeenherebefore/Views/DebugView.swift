import SwiftUI
import SwiftData
import UserNotifications

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Mock Episodes") {
                    Button("Add Recent Episode (24h ago)") {
                        addMockEpisode(hoursAgo: 24)
                    }
                    .foregroundColor(.blue)
                    
                    Button("Add Episode (2 weeks ago)") {
                        addMockEpisode(daysAgo: 14)
                    }
                    .foregroundColor(.blue)
                    
                    Button("Add Episode (3 months ago)") {
                        addMockEpisode(daysAgo: 90)
                    }
                    .foregroundColor(.blue)
                    
                    Button("Add Episode (1 hour ago)") {
                        addMockEpisode(hoursAgo: 1)
                    }
                    .foregroundColor(.blue)

                    Button("Add Episode (18 months ago)") {
                        addMockEpisode(daysAgo: 545)
                    }
                    .foregroundColor(.blue)

                    Button("Add Delight with Song") {
                        addMockSongCard()
                    }
                    .foregroundColor(.blue)

                    Button("Add Cards in Sample Colors") {
                        addSampleColorCards()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Check-in Testing") {
                    Button("Trigger 24h Check-in Notification") {
                        triggerTestNotification(.twentyFourHour)
                    }
                    .foregroundColor(.orange)
                    
                    Button("Trigger 2-Week Check-in Notification") {
                        triggerTestNotification(.twoWeek)
                    }
                    .foregroundColor(.orange)
                    
                    Button("Trigger 3-Month Check-in Notification") {
                        triggerTestNotification(.threeMonth)
                    }
                    .foregroundColor(.orange)
                }
                
                Section("Notification Testing") {
                    Button("Clear All Notifications") {
                        clearAllNotifications()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Badge Count") {
                        resetBadgeCount()
                    }
                    .foregroundColor(.red)
                    
                    Button("Check Notification Permission") {
                        checkNotificationPermission()
                    }
                    .foregroundColor(.purple)
                }
            }
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Debug Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func addMockEpisode(hoursAgo: Int = 0, daysAgo: Int = 0) {
        let calendar = Calendar.current
        let episodeDate: Date
        
        if hoursAgo > 0 {
            episodeDate = calendar.date(byAdding: .hour, value: -hoursAgo, to: Date()) ?? Date()
        } else if daysAgo > 0 {
            episodeDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        } else {
            episodeDate = Date()
        }
        
        let mockEpisodes = [
            (
                title: "Work Deadline Stress",
                emotions: ["Anxiety": 4, "Overwhelm": 3, "Stress": 5],
                prompts: [
                    "Describe the episode": "My manager just told me we have a client presentation tomorrow that I thought was next week. I feel completely unprepared and my chest is tight with panic.",
                    "How do you think you'll feel tomorrow?": "I'm worried I'll still be anxious about the presentation. Even if it goes well, I'll probably be drained from the stress.",
                    "How do you think you'll feel about this in 2 weeks?": "Hopefully I'll have learned something from this experience. Maybe I'll feel more confident about handling surprise deadlines.",
                    "What's the worst that can happen?": "I could completely bomb the presentation, lose the client, and my team would lose confidence in me. I might even get fired.",
                    "How will you feel 3 months from now?": "This will probably just be another work story. I'll have dealt with other challenges by then and this won't seem as dramatic."
                ]
            ),
            (
                title: "Social Anxiety at Party",
                emotions: ["Anxiety": 3, "Shame": 2, "Fear": 4],
                prompts: [
                    "Describe the episode": "I went to a friend's birthday party but felt completely out of place. Everyone seemed to know each other better and I stood awkwardly by the snack table.",
                    "How do you think you'll feel tomorrow?": "I'll probably replay all the awkward moments in my head. I might feel embarrassed about how quiet I was.",
                    "How do you think you'll feel about this in 2 weeks?": "Maybe I'll have perspective on it. I might realize that social situations aren't as scary as they seem in the moment.",
                    "What's the worst that can happen?": "People will remember me as the weird quiet person who didn't talk to anyone. They'll think I'm antisocial and won't invite me to future events.",
                    "How about in 3 months?": "I probably won't even remember the specific details of what made me anxious. It'll just be another social event I survived."
                ]
            ),
            (
                title: "Health Scare",
                emotions: ["Fear": 5, "Anxiety": 4, "Worry": 3],
                prompts: [
                    "Describe the episode": "I found a weird lump and convinced myself it was something serious. Spent hours googling symptoms and working myself into a panic before I could see a doctor.",
                    "How do you think you'll feel tomorrow?": "I'll probably still be worried until I get test results. The uncertainty is the worst part.",
                    "How do you think you'll feel about this in 2 weeks?": "Hopefully I'll have answers by then. Even if it's nothing serious, I'll probably feel relieved and a bit silly for panicking.",
                    "What's the worst that can happen?": "It could be a serious health issue that requires major treatment. My whole life could change.",
                    "How will you feel 3 months from now?": "Either I'll be grateful it was nothing serious, or I'll be dealing with whatever it is and have a better handle on it."
                ]
            )
        ]
        
        let randomEpisode = mockEpisodes.randomElement()!
        let episode = Episode(
            title: randomEpisode.title,
            emotions: randomEpisode.emotions,
            prompts: randomEpisode.prompts
        )
        
        // Set the custom date
        episode.date = episodeDate
        episode.createdAt = episodeDate
        
        modelContext.insert(episode)
        
        do {
            try modelContext.save()
            
            // Schedule notifications for the episode
            episode.scheduleNotifications()
            
            let timeDescription = hoursAgo > 0 ? "\(hoursAgo) hours ago" : "\(daysAgo) days ago"
            alertMessage = "Added mock episode '\(randomEpisode.title)' from \(timeDescription)"
            showingAlert = true
            
        } catch {
            alertMessage = "Error saving episode: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // Cards across the kinds of colors people pick — bright, pastel, near
    // white — for checking how cards look in light and Dark Mode
    private func addSampleColorCards() {
        let samples: [(text: String, type: CardType, red: Double, green: Double, blue: Double)] = [
            ("Sunlight on the kitchen floor", .delight, 1.00, 0.84, 0.04),
            ("Cold water, then a slow walk", .technique, 1.00, 0.58, 0.00),
            ("The first night in the new flat", .memory, 1.00, 0.71, 0.76),
            ("Fresh basil on the balcony", .delight, 0.40, 0.80, 0.40),
            ("Box breathing, four counts each", .technique, 0.35, 0.78, 0.98),
            ("Finishing the half marathon", .memory, 0.91, 0.30, 0.24),
            ("Clean sheets", .delight, 1.00, 1.00, 1.00),
            ("Write it down, then close the notebook", .technique, 0.95, 0.95, 0.97)
        ]

        for sample in samples {
            let card = Card(
                text: sample.text,
                type: sample.type,
                color: Color(.sRGB, red: sample.red, green: sample.green, blue: sample.blue, opacity: 1),
                date: sample.type == .memory ? Date() : nil
            )
            modelContext.insert(card)
        }

        do {
            try modelContext.save()
            alertMessage = "Added \(samples.count) cards in sample colors"
        } catch {
            alertMessage = "Error saving cards: \(error.localizedDescription)"
        }
        showingAlert = true
    }

    private func addMockSongCard() {
        let textCard = Card(
            text: "This song always brings me back",
            type: .delight,
            color: Color(.sRGB, red: 0.35, green: 0.34, blue: 0.84, opacity: 1),
            song: CardSong(
                persistentID: "0",
                storeID: nil,
                title: "Here Comes the Sun",
                artist: "The Beatles",
                artworkData: nil
            )
        )
        modelContext.insert(textCard)

        // Image + text + song card to exercise the caption-size text and
        // the floating song pill over the photo
        let imageCard = Card(
            text: "Golden hour on the canal",
            type: .delight,
            color: Color(.sRGB, red: 0.85, green: 0.45, blue: 0.3, opacity: 1),
            imageData: mockSunsetImageData(),
            song: CardSong(
                persistentID: "0",
                storeID: nil,
                title: "Weightless",
                artist: "Marconi Union",
                artworkData: nil
            )
        )
        modelContext.insert(imageCard)

        do {
            try modelContext.save()
            alertMessage = "Added mock delights with songs"
        } catch {
            alertMessage = "Error saving card: \(error.localizedDescription)"
        }
        showingAlert = true
    }

    // A stand-in "photo" so simulator screenshots can exercise imagery
    private func mockSunsetImageData() -> Data? {
        let size = CGSize(width: 900, height: 560)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [
                UIColor(red: 0.99, green: 0.80, blue: 0.40, alpha: 1).cgColor,
                UIColor(red: 0.90, green: 0.42, blue: 0.36, alpha: 1).cgColor,
                UIColor(red: 0.33, green: 0.24, blue: 0.50, alpha: 1).cgColor
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.55, 1]
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        return image.jpegData(compressionQuality: 0.9)
    }

    private func triggerTestNotification(_ checkInType: CheckInType) {
        // Find the most recent episode to use for the test
        let descriptor = FetchDescriptor<Episode>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        
        do {
            let episodes = try modelContext.fetch(descriptor)
            guard let latestEpisode = episodes.first else {
                alertMessage = "No episodes found - create one first!"
                showingAlert = true
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = checkInType.displayName
            content.body = "How are you feeling about your recent episode?"
            content.sound = .default
            content.badge = 1
            
            // Use the actual episode UUID from the latest episode
            let episodeIDString = latestEpisode.uuid.uuidString
            content.userInfo = [
                "checkInType": checkInType.rawValue,
                "episodeID": episodeIDString
            ]

            print("🔍 Debug notification using episode ID: '\(episodeIDString)' for episode: '\(latestEpisode.title)'")
            
            // Trigger immediately
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "test-\(checkInType.rawValue)-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.alertMessage = "Error scheduling notification: \(error.localizedDescription)"
                    } else {
                        self.alertMessage = "Test \(checkInType.displayName) notification scheduled for episode: '\(latestEpisode.title)'"
                    }
                    self.showingAlert = true
                }
            }
        } catch {
            alertMessage = "Error finding episodes: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        alertMessage = "All notifications cleared"
        showingAlert = true
    }
    
    private func resetBadgeCount() {
        Task {
            await MainActor.run {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
        }
        
        alertMessage = "Badge count reset to 0"
        showingAlert = true
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    alertMessage = "Notifications: Authorized ✅"
                case .denied:
                    alertMessage = "Notifications: Denied ❌"
                case .notDetermined:
                    alertMessage = "Notifications: Not Determined ⚠️"
                case .provisional:
                    alertMessage = "Notifications: Provisional ⚠️"
                case .ephemeral:
                    alertMessage = "Notifications: Ephemeral ⚠️"
                @unknown default:
                    alertMessage = "Notifications: Unknown Status"
                }
                showingAlert = true
            }
        }
    }
}

#Preview {
    DebugView()
        .modelContainer(for: [Episode.self, CheckIn.self, EpisodeNote.self], inMemory: true)
}