//
//  ContentView.swift
//  Schedule Generator
//
//  Created by Bret May on 5/28/24.
//

import SwiftUI

struct ContentView: View {
    @State private var startTime = Calendar.current.date(bySettingHour: 7, minute: 45, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var numEvents = 1
    @State private var setEvents: [(String, Date, Date)] = []
    @State private var schedule: String = ""
    @State private var showScheduleView = false

    var body: some View {
        TabView {
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }

            GenerateScheduleView(startTime: $startTime, endTime: $endTime, numEvents: $numEvents, setEvents: $setEvents, schedule: $schedule, showScheduleView: $showScheduleView)
                .tabItem {
                    Label("Generate Schedule", systemImage: "calendar")
                }
        }
        .sheet(isPresented: $showScheduleView) {
            ScheduleView(schedule: $schedule)
        }
    }
}

struct InfoView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image("ScheduleGeneratorLogo") // Replace with your actual image asset name
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 250) // Adjust height as needed
                Text("Welcome to the Dynamic Schedule Generator")
                    .font(.largeTitle)
                    .padding()
                Divider() // Horizontal line
                Text("This app helps you create an alternate schedule by setting the schedule start and end times, and specifying the number of equal classes you would like to generate. \n\nYou can also add preset events with specific times like lunch and elective.")
                    .padding()
                Spacer()
            }
            .padding()
            .navigationBarTitle("Info", displayMode: .inline)
        }
    }
}

struct GenerateScheduleView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var numEvents: Int
    @Binding var setEvents: [(String, Date, Date)]
    @Binding var schedule: String
    @Binding var showScheduleView: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                Image("ScheduleGeneratorLogo") // Replace with your actual image asset name
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 250) // Adjust height as needed
                DatePicker("Start Time", selection: $startTime, in: timeRange(), displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, in: timeRange(), displayedComponents: .hourAndMinute)
                Stepper(value: $numEvents, in: 0...10) {
                    Text("Number of Equal Classes: \(numEvents)")
                }
                Divider() // Horizontal line
                Text("Pre-Set Events")
                    .font(.headline) // Make the label stand out
                VStack(alignment: .leading, spacing: 10) { // Adjust spacing as needed
                    HStack {
                        Text("Event Name").frame(width: 100, alignment: .leading)
                        Text("Start Time").frame(width: 100, alignment: .leading)
                        Text("End Time").frame(width: 100, alignment: .leading)
                        Spacer()
                    }
                    ForEach(Array(setEvents.enumerated()), id: \.element.1) { index, event in
                        HStack {
                            TextField("Event Name", text: $setEvents[index].0).frame(width: 100, alignment: .leading)
                            DatePicker("", selection: $setEvents[index].1, displayedComponents: .hourAndMinute).frame(width: 100, alignment: .leading)
                            DatePicker("", selection: $setEvents[index].2, displayedComponents: .hourAndMinute).frame(width: 100, alignment: .leading)
                            Button(action: {
                                setEvents.remove(at: index)
                            }) {
                                Text("Remove")
                            }
                        }
                    }
                }
                Button(action: {
                    setEvents.append(("", Date(), Date()))
                }) {
                    Text("Add Set Event")
                }
                Button(action: {
                    schedule = BuildSchedule(startTime: startTime, endTime: endTime, numEvents: numEvents, setEvents: setEvents)
                    showScheduleView = true
                }) {
                    Text("Submit")
                }
                Spacer()
            }
            .padding()
            .navigationBarTitle("Generate Schedule", displayMode: .inline)// Set the title here
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

    func BuildSchedule(startTime: Date, endTime: Date, numEvents: Int, setEvents: [(String, Date, Date)]) -> String {
        let durationMilliseconds = endTime.timeIntervalSince(startTime) * 1000

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
            return ""
        }

        let remainingScheduleTime = durationMilliseconds - totalSetTimesDuration
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
            lastDynamicClassEndTime = end

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

    func formatDuration(_ duration: TimeInterval) -> String {
        let durationInMinutes = Int(duration / 60000)
        let hours = durationInMinutes / 60
        let minutes = durationInMinutes % 60
        return String(format: "%dh %dm", hours, minutes)
    }

    struct Utilities {
        static func formatDate(_ date: Date, _ format: String) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone.current // Use current time zone
            dateFormatter.dateFormat = format
            return dateFormatter.string(from: date)
        }
    }
}



struct ScheduleView: View {
    @Binding var schedule: String
    @State private var showShareSheet = false

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Image("ScheduleGeneratorLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: min(geometry.size.width * 0.4, 150)) // Adjust height based on available width
                Divider() // Horizontal line
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
            }
            .padding()
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
