import EventKit
import Foundation

@MainActor
final class EventKitService {
    private let store = EKEventStore()
    private var remindersGranted = false
    private var eventsGranted = false

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter
    }()

    private func ensureReminders() async -> Bool {
        if remindersGranted { return true }
        remindersGranted = (try? await store.requestFullAccessToReminders()) ?? false
        return remindersGranted
    }

    private func ensureEvents() async -> Bool {
        if eventsGranted { return true }
        eventsGranted = (try? await store.requestFullAccessToEvents()) ?? false
        return eventsGranted
    }

    func addReminder(_ title: String, due: Date?) async -> String {
        guard await ensureReminders() else {
            return "Reminders access is off. System Settings, Privacy, Reminders."
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        do {
            try store.save(reminder, commit: true)
        } catch {
            return "Couldn't save that."
        }
        if let due {
            return "Set. \(Self.formatter.string(from: due))."
        }
        return "Set."
    }

    func addEvent(_ title: String, start: Date) async -> String {
        guard await ensureEvents() else {
            return "Calendar access is off. System Settings, Privacy, Calendars."
        }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            return "Couldn't save that."
        }
        return "On the calendar. \(Self.formatter.string(from: start))."
    }

    func agendaToday() async -> String {
        guard await ensureEvents() else {
            return "Calendar access is off. System Settings, Privacy, Calendars."
        }
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            return "Nothing today."
        }
        let predicate = store.predicateForEvents(
            withStart: start, end: end, calendars: nil
        )
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
        guard !events.isEmpty else { return "Nothing today. Clear water." }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return events
            .map { "\(timeFormatter.string(from: $0.startDate))  \($0.title ?? "Untitled")" }
            .joined(separator: "\n")
    }
}
