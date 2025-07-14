import SwiftUI
import SwiftData
import UserNotifications

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
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
    
    private func triggerTestNotification(_ checkInType: CheckInType) {
        let content = UNMutableNotificationContent()
        content.title = checkInType.displayName
        content.body = "How are you feeling about your recent episode?"
        content.sound = .default
        content.badge = 1
        
        // Set custom data for deep linking
        content.userInfo = [
            "checkInType": checkInType.rawValue,
            "episodeId": "test-episode-id"
        ]
        
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
                    alertMessage = "Error scheduling notification: \(error.localizedDescription)"
                } else {
                    alertMessage = "Test \(checkInType.displayName) notification scheduled!"
                }
                showingAlert = true
            }
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