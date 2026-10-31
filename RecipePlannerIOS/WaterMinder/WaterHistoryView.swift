import Charts
import SwiftUI

struct WaterHistoryView: View {
    @Environment(WaterManager.self) private var waterManager
    @Environment(\.locale) private var locale
    @AppStorage("selectedWickedCharacter") private var selectedCharacterRaw: String = WickedCharacter.glinda.rawValue
    @AppStorage("weekStartDay") private var weekStartDay: Int = 2

    @State private var selectedGranularity: HydrationTrendGranularity = .daily
    @State private var anchorDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedChartDate: Date?
    @State private var showingAllHistory = false
    @State private var editingEntry: WaterEntry?
    @State private var entryToDelete: WaterEntry?
    @State private var showingDeleteConfirmation = false
    @State private var operationError: String?

    private var selectedCharacter: WickedCharacter {
        WickedCharacter(rawValue: selectedCharacterRaw) ?? .glinda
    }

    private var calendar: Calendar {
        MealPlanningCalendar.configured(locale: locale, firstWeekday: weekStartDay)
    }

    private var today: Date { calendar.startOfDay(for: waterManager.currentDate) }

    private var anchorDateBinding: Binding<Date> {
        Binding(
            get: { anchorDate },
            set: { newDate in
                anchorDate = calendar.startOfDay(for: newDate)
                selectedChartDate = nil
                showingAllHistory = false
            }
        )
    }

    private var analytics: HydrationAnalyticsSnapshot {
        waterManager.hydrationAnalytics(calendar: calendar, asOf: today)
    }

    private var trendPoints: [HydrationChartPoint] {
        switch selectedGranularity {
        case .daily:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else { return [] }
            let daySummaries = Dictionary(uniqueKeysWithValues: analytics.dailySummaries.map { ($0.date, $0) })
            return (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
                let day = calendar.startOfDay(for: date)
                let summary = daySummaries[day]
                return HydrationChartPoint(
                    date: day,
                    intakeMl: summary?.totalBeverageVolumeMl,
                    targetMl: summary?.targetMl
                )
            }
        case .weekly:
            guard let selectedWeek = calendar.dateInterval(of: .weekOfYear, for: anchorDate),
                  let start = calendar.date(byAdding: .weekOfYear, value: -11, to: selectedWeek.start) else { return [] }
            return analytics.weeklySummaries
                .filter { $0.startDate >= start && $0.startDate < selectedWeek.end }
                .map {
                    HydrationChartPoint(
                        date: $0.startDate,
                        intakeMl: $0.averagePerRecordedDayMl,
                        targetMl: $0.averageTargetMl
                    )
                }
        case .monthly:
            guard let selectedMonth = calendar.dateInterval(of: .month, for: anchorDate) else { return [] }
            if showingAllHistory {
                return analytics.monthlySummaries.map {
                    HydrationChartPoint(
                        date: $0.startDate,
                        intakeMl: $0.averagePerRecordedDayMl,
                        targetMl: $0.averageTargetMl
                    )
                }
            }
            guard let start = calendar.date(byAdding: .month, value: -11, to: selectedMonth.start) else { return [] }
            return analytics.monthlySummaries
                .filter { $0.startDate >= start && $0.startDate < selectedMonth.end }
                .map {
                    HydrationChartPoint(
                        date: $0.startDate,
                        intakeMl: $0.averagePerRecordedDayMl,
                        targetMl: $0.averageTargetMl
                    )
                }
        }
    }

    private var selectedDailySummary: HydrationDailySummary? {
        let date = calendar.startOfDay(for: selectedChartDate ?? anchorDate)
        return analytics.dailySummaries.first { $0.date == date }
    }

    private var selectedPeriodSummary: HydrationPeriodSummary? {
        let selectedDate = selectedChartDate ?? anchorDate
        let component: Calendar.Component = selectedGranularity == .weekly ? .weekOfYear : .month
        guard selectedGranularity != .daily,
              let interval = calendar.dateInterval(of: component, for: selectedDate) else { return nil }
        let periods = selectedGranularity == .weekly ? analytics.weeklySummaries : analytics.monthlySummaries
        return periods.first { $0.startDate == interval.start }
    }

    private var selectedDateEntries: [WaterEntry] {
        let selectedDate = calendar.startOfDay(for: selectedChartDate ?? anchorDate)
        return WaterIntakeDay.entries(in: waterManager.allRecords, on: selectedDate, calendar: calendar)
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var periodTitle: String {
        if selectedGranularity == .daily,
           let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate) {
            let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
            return "\(formattedDate(week.start)) – \(formattedDate(lastDay))"
        }
        if selectedGranularity == .weekly,
           let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate),
           let start = calendar.date(byAdding: .weekOfYear, value: -11, to: week.start) {
            let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
            return "\(formattedDate(start)) – \(formattedDate(lastDay))"
        }
        if selectedGranularity == .monthly,
           let month = calendar.dateInterval(of: .month, for: anchorDate) {
            if showingAllHistory, let start = analytics.trackingStartDate {
                return "\(formattedDate(start)) – \(formattedDate(today) )"
            }
            let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end) ?? month.end
            guard let start = calendar.date(byAdding: .month, value: -11, to: month.start) else {
                return formattedMonth(anchorDate)
            }
            return "\(formattedMonth(start)) – \(formattedMonth(lastDay))"
        }
        return formattedDate(anchorDate)
    }

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            WickedAmbientGlowLayer(pinkOpacity: 0.36, greenOpacity: 0.12)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    lifetimeSummary
                    trendSection
                    if selectedGranularity == .daily {
                        selectedDaySection
                    } else {
                        selectedPeriodSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .wickedReadableWidth(1_100)
            }
        }
        .navigationTitle("Hydration History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEntry) { entry in
            WaterEntryEditorSheet(entry: entry) { updatedEntry in
                try await waterManager.updateEntry(updatedEntry)
            }
        }
        .confirmationDialog(
            "Delete this drink record?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let entryToDelete else { return }
                Task {
                    do {
                        try await waterManager.deleteEntry(id: entryToDelete.id)
                    } catch {
                        operationError = error.localizedDescription
                    }
                    self.entryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("This removes only the selected hydration record.")
        }
        .alert("Hydration history could not be updated", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: {
            Text(operationError ?? "")
        }
        .task {
            waterManager.refreshCurrentDate()
            await waterManager.loadHistoricalRecords()
        }
        .onChange(of: selectedGranularity) { _, _ in
            selectedChartDate = nil
            showingAllHistory = false
        }
    }

    private var lifetimeSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Since hydration tracking began")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if let trackingStart = analytics.trackingStartDate {
                let columns = [GridItem(.adaptive(minimum: 230), alignment: .top)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    HydrationMetricCard(
                        title: "Tracking started",
                        value: formattedDate(trackingStart),
                        detail: "\(analytics.calendarDaysCovered) calendar days covered",
                        symbol: "calendar"
                    )
                    HydrationMetricCard(
                        title: "Total recorded beverages",
                        value: formattedVolume(analytics.totalRecordedBeverageVolumeMl),
                        detail: "Summed from unique, valid drink records",
                        symbol: "drop.fill"
                    )
                    HydrationMetricCard(
                        title: "Average on recorded days",
                        value: analytics.averagePerRecordedDayMl.map(formattedVolume) ?? "—",
                        detail: "Average daily beverage volume across \(analytics.daysWithRecordedIntake) days with entries",
                        symbol: "chart.bar"
                    )
                    HydrationMetricCard(
                        title: "Goal estimate achieved",
                        value: analytics.goalAchievementRate.map(formattedPercent) ?? "—",
                        detail: analytics.eligibleGoalDays > 0
                            ? "\(analytics.daysMeetingGoal) of \(analytics.eligibleGoalDays) recorded days with a saved target"
                            : "No saved daily target is available for recorded days",
                        symbol: "target"
                    )
                    HydrationMetricCard(
                        title: "Days with recorded drinks",
                        value: "\(analytics.daysWithRecordedIntake)",
                        detail: "\(analytics.daysWithoutRecordedIntake) calendar days have no entries; they are not counted as zero intake",
                        symbol: "checkmark.circle"
                    )
                    HydrationMetricCard(
                        title: "Longest tracked goal streak",
                        value: "\(analytics.longestConsecutiveTrackedGoalDays) days",
                        detail: "Only consecutive days with both entries and a saved target count",
                        symbol: "flame"
                    )
                    if let highest = analytics.highestIntakeDay {
                        HydrationMetricCard(
                            title: "Highest recorded day",
                            value: formattedVolume(highest.totalBeverageVolumeMl),
                            detail: formattedDate(highest.date),
                            symbol: "arrow.up.circle"
                        )
                    }
                    if let lowest = analytics.lowestIntakeDay {
                        HydrationMetricCard(
                            title: "Lowest recorded day",
                            value: formattedVolume(lowest.totalBeverageVolumeMl),
                            detail: formattedDate(lowest.date),
                            symbol: "arrow.down.circle"
                        )
                    }
                }

                HStack(spacing: 10) {
                    RecentGoalCard(
                        title: "Last 7 days",
                        met: analytics.last7DayGoalDays,
                        eligible: analytics.last7DayEligibleDays,
                        rate: analytics.last7DayGoalRate.map(formattedPercent)
                    )
                    RecentGoalCard(
                        title: "Last 30 days",
                        met: analytics.last30DayGoalDays,
                        eligible: analytics.last30DayEligibleDays,
                        rate: analytics.last30DayGoalRate.map(formattedPercent)
                    )
                }

                Text("Recorded volume includes water and other logged beverages. The saved comparison is the profile-based approximate minimum shown by the daily tracker (30 ml/kg), not a medical prescription. Days without a saved target are excluded from goal rates.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView {
                    Label("No recorded hydration data", systemImage: "drop.circle")
                } description: {
                    Text("Your summary will begin after you record a drink. No history or target values are generated for missing days.")
                }
                .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Hydration trends")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                if selectedGranularity == .monthly {
                    Button(showingAllHistory ? "Last 12 months" : "Full history") {
                        showingAllHistory.toggle()
                        selectedChartDate = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.wickedGreen)
                    .disabled(analytics.monthlySummaries.isEmpty)
                }
            }

            Picker("Trend period", selection: $selectedGranularity) {
                Text("Daily").tag(HydrationTrendGranularity.daily)
                Text("Weekly").tag(HydrationTrendGranularity.weekly)
                Text("Monthly").tag(HydrationTrendGranularity.monthly)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Button { navigateTrend(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Previous hydration period"))

                VStack(spacing: 6) {
                    Text(periodTitle)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                    DatePicker("Choose a date", selection: anchorDateBinding, in: ...today, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.wickedGreen)
                        .accessibilityLabel(Text("Choose a date in this period"))
                }

                Button { navigateTrend(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(calendar.isDate(anchorDate, inSameDayAs: today))
                .accessibilityLabel(Text("Next hydration period"))
            }
            .foregroundStyle(.white)

            if trendPoints.contains(where: { $0.intakeMl != nil || $0.targetMl != nil }) {
                HydrationTrendChart(
                    points: trendPoints,
                    granularity: selectedGranularity,
                    selection: $selectedChartDate,
                    locale: locale
                )
                .frame(height: 240)

                HStack(spacing: 18) {
                    Label("Recorded beverage volume", systemImage: "square.fill")
                        .foregroundStyle(Color.wickedBlue)
                    Label("Saved daily estimate", systemImage: "line.diagonal")
                        .foregroundStyle(Color.glindaPink)
                }
                .font(.caption)

                Text(chartMethodDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                ContentUnavailableView(
                    "No data in this period",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Choose an earlier period or record a drink to add real data to this chart.")
                )
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: 170)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var selectedDaySection: some View {
        let selectedDate = calendar.startOfDay(for: selectedChartDate ?? anchorDate)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recorded drinks for \(formattedDate(selectedDate))")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if let summary = selectedDailySummary {
                HStack {
                    Text("Recorded volume")
                    Spacer()
                    Text(formattedVolume(summary.totalBeverageVolumeMl))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                if let target = summary.targetMl {
                    HStack {
                        Text("Saved estimate for this day")
                        Spacer()
                        Text(formattedVolume(target))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    if let met = summary.metTarget {
                        Text(met ? "Recorded intake met the saved estimate." : "Recorded intake was below the saved estimate.")
                            .font(.caption)
                            .foregroundStyle(met ? Color.wickedGreen : Color.glindaPink)
                    }
                } else {
                    Text("No historical target was saved for this date, so it is excluded from goal statistics.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            if selectedDateEntries.isEmpty {
                ContentUnavailableView {
                    Label("No drink entries for this date", systemImage: "drop")
                } description: {
                    Text("A date without entries is missing information, not a zero-consumption day.")
                }
                .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(selectedDateEntries) { entry in
                    LogEntryRow(
                        entry: entry,
                        waterColor: selectedCharacter.waterColor,
                        onEdit: { editingEntry = entry },
                        onDelete: {
                            entryToDelete = entry
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var selectedPeriodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedGranularity == .weekly ? "Selected week" : "Selected month")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if let summary = selectedPeriodSummary {
                periodMetric("Recorded beverage total", formattedVolume(summary.totalBeverageVolumeMl))
                periodMetric(
                    "Average on recorded days",
                    "\(formattedVolume(summary.averagePerRecordedDayMl)) (\(summary.recordedDays) days)"
                )
                if summary.eligibleGoalDays > 0 {
                    periodMetric(
                        "Goal estimate achieved",
                        "\(summary.daysMeetingGoal) / \(summary.eligibleGoalDays) (\(formattedPercent(summary.goalAchievementRate ?? 0)))"
                    )
                } else {
                    Text("No saved daily targets are available for recorded days in this period.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                if let change = summary.averageDifferenceFromPreviousPeriodMl {
                    let sign = change >= 0 ? "+" : "−"
                    periodMetric(
                        "Average per recorded day vs previous complete period",
                        "\(sign)\(formattedVolume(abs(change)))"
                    )
                } else if selectedGranularity == .monthly {
                    Text("Month comparisons appear only when both months are complete and have recorded data.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                if selectedGranularity == .weekly {
                    let weekRange = DateInterval(start: summary.startDate, end: summary.endDateExclusive)
                    ForEach(HydrationAnalyticsService.dailySummaries(in: weekRange, snapshot: analytics, calendar: calendar)) { day in
                        Button {
                            selectedGranularity = .daily
                            anchorDate = day.date
                            selectedChartDate = day.date
                        } label: {
                            HStack {
                                Text(day.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
                                Spacer()
                                Text(formattedVolume(day.totalBeverageVolumeMl))
                                if let met = day.metTarget {
                                    Image(systemName: met ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(met ? Color.wickedGreen : Color.glindaPink)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No recorded drinks in this period. Missing days are not counted as zero.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var chartMethodDescription: String {
        switch selectedGranularity {
        case .daily:
            "Daily bars show only dates with valid entries; the line appears only for dates with a saved estimate."
        case .weekly:
            "Weekly bars are average beverage volume per recorded day. Weeks without entries are omitted."
        case .monthly:
            "Monthly bars are average beverage volume per recorded day. Months without entries are omitted; complete months alone are compared."
        }
    }

    private func navigateTrend(by offset: Int) {
        let component: Calendar.Component = selectedGranularity == .monthly ? .month : .weekOfYear
        let step = selectedGranularity == .daily ? 1 : 12
        guard let date = calendar.date(byAdding: component, value: offset * step, to: anchorDate) else { return }
        anchorDate = calendar.startOfDay(for: date)
        selectedChartDate = nil
        showingAllHistory = false
    }

    private func periodMetric(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.white.opacity(0.76))
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white)
        }
        .font(.subheadline)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    private func formattedMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year().locale(locale))
    }

    private func formattedPercent(_ rate: Double) -> String {
        rate.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    private func formattedVolume(_ millilitres: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = millilitres >= 1_000 ? 1 : 0
        formatter.minimumFractionDigits = 0
        if millilitres >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: millilitres / 1_000)) ?? "0") l"
        }
        return "\(formatter.string(from: NSNumber(value: millilitres)) ?? "0") ml"
    }
}

private struct HydrationChartPoint: Identifiable {
    let date: Date
    let intakeMl: Double?
    let targetMl: Double?

    var id: Date { date }
}

private struct HydrationTrendChart: View {
    let points: [HydrationChartPoint]
    let granularity: HydrationTrendGranularity
    @Binding var selection: Date?
    let locale: Locale

    private var dateComponent: Calendar.Component {
        switch granularity {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                if let intake = point.intakeMl {
                    BarMark(
                        x: .value("Date", point.date, unit: dateComponent),
                        y: .value("Recorded beverages", intake)
                    )
                    .foregroundStyle(Color.wickedBlue)
                    .accessibilityLabel(Text("Recorded beverage volume"))
                }
                if let target = point.targetMl {
                    LineMark(
                        x: .value("Date", point.date, unit: dateComponent),
                        y: .value("Saved estimate", target),
                        series: .value("Series", "Saved estimate")
                    )
                    .foregroundStyle(Color.glindaPink)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
        }
        .chartXSelection(value: $selection)
        .chartYAxisLabel("ml")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: granularity == .daily ? 7 : 5)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        if granularity == .monthly {
                            Text(date, format: .dateTime.month(.abbreviated).year(.twoDigits).locale(locale))
                        } else {
                            Text(date, format: .dateTime.day().month(.abbreviated).locale(locale))
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel().foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .accessibilityLabel(Text("Recorded beverage volume and saved daily estimate chart"))
    }
}

private struct HydrationMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.wickedGreen)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct RecentGoalCard: View {
    let title: String
    let met: Int
    let eligible: Int
    let rate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.glindaPink)
            Text(rate ?? "—").font(.title3.bold()).foregroundStyle(.white)
            Text(eligible > 0 ? "\(met) of \(eligible) eligible recorded days" : "No eligible days with saved targets")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LogEntryRow: View {
    let entry: WaterEntry
    let waterColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var selection: HydrationDrinkSelection {
        HydrationDrinkCatalog.selection(for: entry)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: selection.iconName)
                .foregroundStyle(selection.type == .water ? waterColor : selection.liquidColor)

            VStack(alignment: .leading, spacing: 2) {
                selection.localizedName
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(Int(entry.amountMl)) ml logged")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 8)
            Text(entry.timestamp, style: .time)
                .foregroundStyle(.gray)
                .font(.subheadline)

            Menu {
                Button("Edit drink record", systemImage: "pencil", action: onEdit)
                Button("Delete drink record", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Color.wickedGreen)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Actions for drink record"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}

private struct WaterEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let entry: WaterEntry
    let onSave: (WaterEntry) async throws -> Void

    @State private var amountText: String
    @State private var timestamp: Date
    @State private var drinkType: HydrationDrinkType
    @State private var milkChoice: MilkChoice
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(entry: WaterEntry, onSave: @escaping (WaterEntry) async throws -> Void) {
        self.entry = entry
        self.onSave = onSave
        _amountText = State(initialValue: String(entry.amountMl))
        _timestamp = State(initialValue: entry.timestamp)
        let selection = HydrationDrinkCatalog.selection(for: entry)
        _drinkType = State(initialValue: selection.type)
        _milkChoice = State(initialValue: selection.milkChoice ?? .regular)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Drink details") {
                    Picker("Beverage", selection: $drinkType) {
                        ForEach(HydrationDrinkType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    if drinkType.supportsMilkChoice {
                        Picker("Milk type", selection: $milkChoice) {
                            ForEach(MilkChoice.allCases) { choice in
                                Text(choice.displayName).tag(choice)
                            }
                        }
                    }
                    TextField("Amount (ml)", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                Section("Recorded time") {
                    DatePicker("Date and time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground)
            .navigationTitle("Edit drink record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .alert("Check the drink record", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let normalizedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalizedAmount), amount.isFinite, amount > 0,
              timestamp.timeIntervalSince1970.isFinite else {
            errorMessage = String(localized: "Enter a valid positive amount and date.")
            return
        }

        var updated = entry
        updated.amountMl = amount
        updated.timestamp = timestamp
        let selection = HydrationDrinkCatalog.selection(
            for: drinkType,
            milkChoice: drinkType.supportsMilkChoice ? milkChoice : nil
        )
        updated.beverageId = selection.id
        updated.beverageName = selection.englishName

        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await onSave(updated)
                dismiss()
            } catch {
                errorMessage = String(localized: "We couldn't save this drink record. Please try again.")
            }
        }
    }
}
