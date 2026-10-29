import SwiftUI

struct StudyTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var date: Date
    var duration: Int
    var isCompleted = false
}

@MainActor
final class StudyPlannerStore: ObservableObject {
    @Published var tasks: [StudyTask] = [] {
        didSet { save() }
    }

    private let storageKey = "study_planner_tasks"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(
                [StudyTask].self, from: data
           ) {
            tasks = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addTask(title: String, subject: String,
                 date: Date, duration: Int) {
        tasks.append(
            StudyTask(
                title: title,
                subject: subject,
                date: date,
                duration: duration
            )
        )
    }

    func toggle(_ task: StudyTask) {
        guard let index = tasks.firstIndex(
            where: { $0.id == task.id }
        ) else { return }

        tasks[index].isCompleted.toggle()
    }

    func delete(_ task: StudyTask) {
        tasks.removeAll { $0.id == task.id }
    }
}

struct ContentView: View {
    @StateObject private var store = StudyPlannerStore()

    var body: some View {
        TabView {
            DashboardView(store: store)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TasksView(store: store)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            AddTaskScreen(store: store)
                .tabItem {
                    Label("Add Task", systemImage: "plus.circle.fill")
                }

            FocusTimerView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
        }
        .tint(.indigo)
    }
}

struct DashboardView: View {
    @ObservedObject var store: StudyPlannerStore

    private var todayTasks: [StudyTask] {
        store.tasks.filter {
            Calendar.current.isDateInToday($0.date)
        }
    }

    private var completed: Int {
        todayTasks.filter(\.isCompleted).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("STUDENT STUDY PLANNER")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)

                    Text("Study smarter.\nAchieve more.")
                        .font(.largeTitle.bold())

                    Text(Date.now.formatted(
                        date: .complete, time: .omitted
                    ))
                    .foregroundStyle(.secondary)

                    HStack {
                        statCard("Today's Tasks",
                                 value: "\(todayTasks.count)",
                                 color: .blue)

                        statCard("Completed",
                                 value: "\(completed)",
                                 color: .green)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Daily Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .bold()
                        }

                        ProgressView(value: progress)
                            .tint(.indigo)
                    }
                    .padding()
                    .background(
                        Color.indigo.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                    Text("Today's Study Plan")
                        .font(.title2.bold())

                    if todayTasks.isEmpty {
                        ContentUnavailableView(
                            "No Tasks Yet",
                            systemImage: "book.closed",
                            description: Text(
                                "Tap Add Task to plan your study."
                            )
                        )
                    }

                    ForEach(todayTasks.sorted {
                        $0.date < $1.date
                    }) { task in
                        TaskRow(task: task) {
                            store.toggle(task)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }

    private var progress: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(completed) / Double(todayTasks.count)
    }

    private func statCard(_ title: String,
                          value: String,
                          color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.largeTitle.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct TasksView: View {
    @ObservedObject var store: StudyPlannerStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.tasks.sorted {
                    $0.date < $1.date
                }) { task in
                    TaskRow(task: task) {
                        store.toggle(task)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.delete(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("My Study Tasks")
        }
    }
}

struct TaskRow: View {
    let task: StudyTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted
                      ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        task.isCompleted ? .green : .indigo
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)

                Text(task.subject)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(task.duration) minutes • \(task.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 5)
    }
}

struct AddTaskScreen: View {
    @ObservedObject var store: StudyPlannerStore

    @State private var title = ""
    @State private var subject = ""
    @State private var date = Date.now
    @State private var duration = 30

    private let durations = [15, 25, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task name", text: $title)
                    TextField("Subject name", text: $subject)
                }

                Section("Study Schedule") {
                    DatePicker(
                        "Date and Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) minutes")
                                .tag(minutes)
                        }
                    }
                }

                Section {
                    Button("Save Study Task") {
                        saveTask()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(
                        title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty ||
                        subject.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
            .navigationTitle("Add Study Task")
        }
    }

    private func saveTask() {
        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let cleanSubject = subject.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanTitle.isEmpty, !cleanSubject.isEmpty else {
            return
        }

        store.addTask(
            title: cleanTitle,
            subject: cleanSubject,
            date: date,
            duration: duration
        )

        title = ""
        subject = ""
    }
}

struct FocusTimerView: View {
    @State private var minutes = 25
    @State private var secondsLeft = 25 * 60
    @State private var isRunning = false
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            Color.indigo.opacity(0.15),
                            lineWidth: 14
                        )

                    Circle()
                        .trim(
                            from: 0,
                            to: 1 - Double(secondsLeft) /
                                Double(minutes * 60)
                        )
                        .stroke(
                            .indigo,
                            style: StrokeStyle(
                                lineWidth: 14,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.title)
                            .foregroundStyle(.indigo)

                        Text(String(
                            format: "%02d:%02d",
                            secondsLeft / 60,
                            secondsLeft % 60
                        ))
                        .font(.system(size: 42, weight: .bold))
                        .monospacedDigit()

                        Text(secondsLeft == 0
                             ? "Session Complete"
                             : "Stay Focused")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)

                HStack {
                    ForEach([15, 25, 30, 45, 60], id: \.self) {
                        value in

                        Button("\(value)m") {
                            reset(to: value)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(minutes == value ? .indigo : .gray)
                        .disabled(isRunning)
                    }
                }

                HStack(spacing: 25) {
                    Button {
                        reset(to: minutes)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                    }

                    Button {
                        isRunning ? pause() : start()
                    } label: {
                        Label(
                            isRunning ? "Pause" : "Start",
                            systemImage: isRunning
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.headline)
                        .padding()
                        .background(.indigo, in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Study Focus Timer")
            .onDisappear {
                pause()
            }
        }
    }

    private func start() {
        guard !isRunning, secondsLeft > 0 else { return }

        isRunning = true
        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { _ in
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                pause()
            }
        }
    }

    private func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func reset(to value: Int) {
        pause()
        minutes = value
        secondsLeft = value * 60
    }
}

#Preview {
    ContentView()
}
