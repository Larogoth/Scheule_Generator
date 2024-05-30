//
//  ContentView.swift
//  iSchedulED
//
//  Created by Bret May on 5/28/24.
//

import SwiftUI
import UIKit

@main
struct Schedule_GeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var scheduleManager = ScheduleManager()
    @State private var selectedTab = 0
    @State private var schedule: String = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(0)

            ScheduleInputView(selectedTab: $selectedTab, schedule: $schedule)
                .environmentObject(scheduleManager)
                .tabItem {
                    Label("Schedule Input", systemImage: "calendar")
                }
                .tag(1)

            GeneratedScheduleView(schedule: $schedule)
                .environmentObject(scheduleManager)
                .tabItem {
                    Label("Generated Schedule", systemImage: "list.bullet")
                }
                .tag(2)

            SavedSchedulesView()
                .environmentObject(scheduleManager)
                .tabItem {
                    Label("Saved Schedules", systemImage: "folder")
                }
                .tag(3)
        }
    }
}

struct InfoView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image("ScheduleGeneratorLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                Text("iSchedulED")
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding()
                Divider()
                (Text("This app helps you to create an alternate schedule by setting the schedule start and end times, and specifying the number of equal classes you would like to generate. \n\nYou can also add pre-set events with specific times like lunch and elective.\n\nSpecify your schedule needs on the") + Text(" Schedule Input").bold() + Text(" tab and then view your schedule on the") + Text(" Generated Schedule").bold() + Text(" tab."))
                    .padding()
                Spacer()
            }
            .padding()
            .navigationBarTitle("Info", displayMode: .inline)
        }
    }
}

struct ScheduleInputView: View {
    @State private var startTime = Calendar.current.date(bySettingHour: 7, minute: 45, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var numEvents = 1
    @State private var setEvents: [(String, Date, Date)] = []
    @State private var transitionTime: Int = 0 // New state variable for transition time
    @Binding var selectedTab: Int
    @Binding var schedule: String

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image("ScheduleGeneratorLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)

                DatePicker("Start Time", selection: $startTime, in: timeRange(), displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, in: timeRange(), displayedComponents: .hourAndMinute)
                Stepper(value: $numEvents, in: 0...10) {
                    Text("Number of Equal Classes: \(numEvents)")
                }
                Stepper(value: $transitionTime, in: 0...30) { // Stepper for transition time
                    Text("Transition Time: \(transitionTime) minutes")
                }

                Divider()

                Text("Pre-Set Events")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Event Name").frame(width: 100, alignment: .leading)
                        Text("Start Time").frame(width: 100, alignment: .leading)
                        Text("End Time").frame(width: 100, alignment: .leading)
                        Spacer()
                    }
                    ForEach(Array(setEvents.enumerated()), id: \.element.1) { index, event in
                        GeometryReader { geometry in
                            HStack {
                                TextField("Event Name", text: $setEvents[index].0).frame(width: geometry.size.width * 0.25, alignment: .leading)
                                DatePicker("", selection: $setEvents[index].1, displayedComponents: .hourAndMinute).frame(width: geometry.size.width * 0.25, alignment: .leading)
                                DatePicker("", selection: $setEvents[index].2, displayedComponents: .hourAndMinute).frame(width: geometry.size.width * 0.25, alignment: .leading)
                                Button(action: {
                                    setEvents.remove(at: index)
                                }) {
                                    Text("Remove")
                                }
                                .frame(width: geometry.size.width * 0.25, alignment: .leading)
                            }
                        }
                    }
                }
                Button(action: {
                    setEvents.append(("", Date(), Date()))
                }) {
                    Text("Add Pre-Set Event")
                }

                Button(action: {
                    schedule = BuildSchedule(startTime: startTime, endTime: endTime, numEvents: numEvents, setEvents: setEvents, transitionTime: transitionTime)
                    selectedTab = 2 // Navigate to the Generated Schedule tab
                }) {
                    Text("Submit")
                }

                Spacer()
            }
            .padding()
            .navigationBarTitle("Schedule Input", displayMode: .inline)
        }
    }

    func timeRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let startHour = calendar.date(byAdding: .hour, value: 7, to: startOfDay)!
        let endHour = calendar.date(byAdding: .hour, value: 15, to: startOfDay)!
        return startHour...endHour
    }

    struct Event {
        var name: String
        var isSet: Bool
        var start: Date
        var end: Date
        var duration: TimeInterval
        var remainingTime: TimeInterval
        var isContinued: Bool
    }

    func BuildSchedule(startTime: Date, endTime: Date, numEvents: Int, setEvents: [(String, Date, Date)], transitionTime: Int) -> String {
        let durationMilliseconds = endTime.timeIntervalSince(startTime) * 1000
        let transitionTimeMilliseconds = TimeInterval(transitionTime * 60 * 1000)

        var events: [Event] = setEvents.compactMap { row in
            let (constantName, constantStart, constantEnd) = row
            let name = constantName
            let start = constantStart
            let end = constantEnd
            let duration = end.timeIntervalSince(start) * 1000
            return Event(name: name, isSet: true, start: start, end: end, duration: duration, remainingTime: 0, isContinued: false)
        }.filter { $0.duration > 0 }

        events.sort { $0.start < $1.start }

        let totalSetTimesDuration = events.reduce(0, { $0 + $1.duration })

        // Check if the set events exceed the total available time
        guard totalSetTimesDuration <= durationMilliseconds else {
            print("Error: The set events exceed the total available time.")
            return "Error: The set events exceed the total available time."
        }

        let totalTransitionTime = transitionTimeMilliseconds * TimeInterval(numEvents + setEvents.count - 1)
        let remainingScheduleTime = durationMilliseconds - totalSetTimesDuration - totalTransitionTime
        let originalDynamicClassDuration = remainingScheduleTime / TimeInterval(numEvents)
        var totalDynamicClassesDuration = originalDynamicClassDuration

        var lastDynamicClassEndTime = startTime
        var rotationIndex = 1
        var dynamicEvents: [Event] = []

        for _ in 0..<numEvents {
            let name = "Rotation \(rotationIndex)"
            let isSet = false
            var start = lastDynamicClassEndTime
            var end = start.addingTimeInterval(totalDynamicClassesDuration / 1000) // Adding milliseconds directly
            var duration = end.timeIntervalSince(start) * 1000
            var isContinued = false

            var interruptions = events.filter { $0.isSet && $0.start < end && $0.end > start }

            while !interruptions.isEmpty {
                interruptions.forEach { interruptedEvent in
                    end = interruptedEvent.start
                    duration = end.timeIntervalSince(start) * 1000
                    totalDynamicClassesDuration -= duration // Subtract the duration of the interrupted part from the total

                    events.append(Event(name: name, isSet: isSet, start: start, end: end, duration: duration, remainingTime: remainingScheduleTime, isContinued: isContinued))

                    lastDynamicClassEndTime = interruptedEvent.end
                    start = lastDynamicClassEndTime
                    end = start.addingTimeInterval(totalDynamicClassesDuration / 1000) // Adding milliseconds directly
                    duration = end.timeIntervalSince(start) * 1000
                    isContinued = true // This dynamic event is a continuation of an interrupted one
                }

                interruptions = events.filter { $0.isSet && $0.start < end && $0.end > start }
            }

            events.append(Event(name: name, isSet: isSet, start: start, end: end, duration: duration, remainingTime: remainingScheduleTime, isContinued: isContinued))
            lastDynamicClassEndTime = end.addingTimeInterval(transitionTimeMilliseconds / 1000) // Add transition time

            if dynamicEvents.count < numEvents {
                rotationIndex += 1
                totalDynamicClassesDuration = originalDynamicClassDuration
            }
        }

        events.sort { $0.start < $1.start }

        // Create the share message
        let shareMessage = events.map { event in
            let formattedDuration = formatDuration(event.duration)
            return "\(event.name): \(Utilities.formatDate(event.start, "h:mm a")) - \(Utilities.formatDate(event.end, "h:mm a")) (\(formattedDuration))"
        }.joined(separator: "\n")

        return shareMessage
    }

    private func formatDuration(_ milliseconds: TimeInterval) -> String {
        let durationSeconds = milliseconds / 1000
        let durationMinutes = durationSeconds / 60
        let hours = Int(durationMinutes / 60)
        let minutes = Int(durationMinutes.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}



struct GeneratedScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Binding var schedule: String
    @State private var showShareSheet = false
    @State private var scheduleName = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Image("ScheduleGeneratorLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: min(geometry.size.width * 0.4, 150)) // Adjust height based on available width
                Divider() // Horizontal line

                TextField("Schedule Name", text: $scheduleName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                ScrollView {
                    Text(schedule)
                        .padding()
                        .multilineTextAlignment(.leading)
                }
                Button(action: {
                    showShareSheet = true
                }) {
                    Text("Share")
                }
                .padding()
                .sheet(isPresented: $showShareSheet) {
                    ActivityView(activityItems: [schedule])
                }

                Button(action: {
                    if scheduleName.isEmpty {
                        alertMessage = "Please enter a schedule name."
                        showAlert = true
                    } else {
                        let newSchedule = Schedule(name: scheduleName, startTime: Date(), endTime: Date(), numEvents: 0, setEvents: [], generatedSchedule: schedule) // Update with actual times and events
                        scheduleManager.addSchedule(newSchedule)
                        alertMessage = "Schedule saved successfully!"
                        showAlert = true
                    }
                }) {
                    Text("Save Schedule")
                }
                .padding()
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Save Schedule"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }

                Spacer()
            }
            .padding()
        }
    }
}


struct SavedSchedulesView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                List {
                    ForEach(filteredSchedules) { schedule in
                        NavigationLink(destination: ScheduleDetailView(schedule: schedule)) {
                            Text(schedule.name)
                        }
                    }
                    .onDelete(perform: deleteSchedule)
                }
                .navigationTitle("Saved Schedules")
                .navigationBarItems(trailing: EditButton())
            }
        }
    }

    private var filteredSchedules: [Schedule] {
        if searchText.isEmpty {
            return scheduleManager.schedules
        } else {
            return scheduleManager.schedules.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }

    private func deleteSchedule(at offsets: IndexSet) {
        scheduleManager.schedules.remove(atOffsets: offsets)
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String

    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }

    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
}


struct ScheduleDetailView: View {
    var schedule: Schedule
    @State private var showShareSheet = false

    var body: some View {
        VStack {
            Text(schedule.name)
                .font(.largeTitle)
                .padding()
            ScrollView {
                Text(schedule.generatedSchedule)
                    .padding()
                    .multilineTextAlignment(.leading)
            }
            Button(action: {
                showShareSheet = true
            }) {
                Text("Share")
            }
            .padding()
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: [schedule.generatedSchedule])
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Schedule Details")
    }
}



import Foundation

class ScheduleManager: ObservableObject {
    @Published var schedules: [Schedule] = []

    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
    }
}

struct Schedule: Identifiable {
    let id = UUID()
    var name: String
    var startTime: Date
    var endTime: Date
    var numEvents: Int
    var setEvents: [(String, Date, Date)]
    var generatedSchedule: String
}


struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}


struct Utilities {
    static func formatDate(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
