import FirebaseFirestore
import FirebaseAuth
import Foundation

struct HydrationDailySummary: Identifiable, Equatable {
    let date: Date
    let totalBeverageVolumeMl: Double
    let entryCount: Int
    let targetMl: Double?
    let metTarget: Bool?

    var id: Date { date }
}

enum HydrationTrendGranularity: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }
}

struct HydrationPeriodSummary: Identifiable, Equatable {
    let granularity: HydrationTrendGranularity
    let startDate: Date
    let endDateExclusive: Date
    let totalBeverageVolumeMl: Double
    let averagePerRecordedDayMl: Double
    let recordedDays: Int
    let eligibleGoalDays: Int
    let daysMeetingGoal: Int
    let averageTargetMl: Double?
    let averageDifferenceFromPreviousPeriodMl: Double?
    let isCompletePeriod: Bool

    var id: Date { startDate }

    var goalAchievementRate: Double? {
        guard eligibleGoalDays > 0 else { return nil }
        return Double(daysMeetingGoal) / Double(eligibleGoalDays)
    }
}

struct HydrationAnalyticsSnapshot: Equatable {
    let trackingStartDate: Date?
    let asOfDate: Date
    let calendarDaysCovered: Int
    let daysWithRecordedIntake: Int
    let daysWithoutRecordedIntake: Int
    let totalRecordedBeverageVolumeMl: Double
    let averagePerRecordedDayMl: Double?
    let highestIntakeDay: HydrationDailySummary?
    let lowestIntakeDay: HydrationDailySummary?
    let eligibleGoalDays: Int
    let daysMeetingGoal: Int
    let longestConsecutiveTrackedGoalDays: Int
    let last7DayGoalDays: Int
    let last7DayEligibleDays: Int
    let last30DayGoalDays: Int
    let last30DayEligibleDays: Int
    let dailySummaries: [HydrationDailySummary]
    let weeklySummaries: [HydrationPeriodSummary]
    let monthlySummaries: [HydrationPeriodSummary]

    var goalAchievementRate: Double? {
        guard eligibleGoalDays > 0 else { return nil }
        return Double(daysMeetingGoal) / Double(eligibleGoalDays)
    }

    var last7DayGoalRate: Double? {
        guard last7DayEligibleDays > 0 else { return nil }
        return Double(last7DayGoalDays) / Double(last7DayEligibleDays)
    }

    var last30DayGoalRate: Double? {
        guard last30DayEligibleDays > 0 else { return nil }
        return Double(last30DayGoalDays) / Double(last30DayEligibleDays)
    }
}

enum HydrationAnalyticsService {
    static func summarize(
        records: [WaterRecord],
        calendar: Calendar = .autoupdatingCurrent,
        asOf date: Date = Date()
    ) -> HydrationAnalyticsSnapshot {
        let asOfDay = calendar.startOfDay(for: date)
        let dayAfterAsOf = calendar.date(byAdding: .day, value: 1, to: asOfDay) ?? asOfDay
        let validEntries = WaterIntakeDay.entries(in: records).filter {
            $0.timestamp < dayAfterAsOf
                && $0.amountMl.isFinite
                && $0.amountMl > 0
                && $0.timestamp.timeIntervalSince1970.isFinite
        }

        let targetByDate = latestTargets(in: records, calendar: calendar)
        let groupedEntries = Dictionary(grouping: validEntries) {
            calendar.startOfDay(for: $0.timestamp)
        }
        let daily = groupedEntries.keys.sorted().compactMap { day -> HydrationDailySummary? in
            guard let entries = groupedEntries[day], !entries.isEmpty else { return nil }
            let total = entries.reduce(Decimal.zero) { partial, entry in
                partial + (decimal(from: entry.amountMl) ?? .zero)
            }
            let totalDouble = NSDecimalNumber(decimal: total).doubleValue
            guard totalDouble.isFinite, totalDouble > 0 else { return nil }
            let target = targetByDate[day]?.dailyTargetMl
            let validTarget = target.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }

            return HydrationDailySummary(
                date: day,
                totalBeverageVolumeMl: totalDouble,
                entryCount: entries.count,
                targetMl: validTarget,
                metTarget: validTarget.map { totalDouble >= $0 }
            )
        }

        guard let trackingStart = daily.first?.date else {
            return HydrationAnalyticsSnapshot(
                trackingStartDate: nil,
                asOfDate: asOfDay,
                calendarDaysCovered: 0,
                daysWithRecordedIntake: 0,
                daysWithoutRecordedIntake: 0,
                totalRecordedBeverageVolumeMl: 0,
                averagePerRecordedDayMl: nil,
                highestIntakeDay: nil,
                lowestIntakeDay: nil,
                eligibleGoalDays: 0,
                daysMeetingGoal: 0,
                longestConsecutiveTrackedGoalDays: 0,
                last7DayGoalDays: 0,
                last7DayEligibleDays: 0,
                last30DayGoalDays: 0,
                last30DayEligibleDays: 0,
                dailySummaries: [],
                weeklySummaries: [],
                monthlySummaries: []
            )
        }

        let coveredDays = max(0, (calendar.dateComponents([.day], from: trackingStart, to: asOfDay).day ?? -1) + 1)
        let totalDecimal = daily.reduce(Decimal.zero) { $0 + (decimal(from: $1.totalBeverageVolumeMl) ?? .zero) }
        let total = NSDecimalNumber(decimal: totalDecimal).doubleValue
        let eligible = daily.filter { $0.metTarget != nil }
        let met = eligible.filter { $0.metTarget == true }.count
        let last7Start = calendar.date(byAdding: .day, value: -6, to: asOfDay) ?? asOfDay
        let last30Start = calendar.date(byAdding: .day, value: -29, to: asOfDay) ?? asOfDay
        let last7Eligible = daily.filter { $0.date >= last7Start && $0.date <= asOfDay && $0.metTarget != nil }
        let last30Eligible = daily.filter { $0.date >= last30Start && $0.date <= asOfDay && $0.metTarget != nil }

        return HydrationAnalyticsSnapshot(
            trackingStartDate: trackingStart,
            asOfDate: asOfDay,
            calendarDaysCovered: coveredDays,
            daysWithRecordedIntake: daily.count,
            daysWithoutRecordedIntake: max(0, coveredDays - daily.count),
            totalRecordedBeverageVolumeMl: total,
            averagePerRecordedDayMl: daily.isEmpty ? nil : total / Double(daily.count),
            highestIntakeDay: daily.max { $0.totalBeverageVolumeMl < $1.totalBeverageVolumeMl },
            lowestIntakeDay: daily.min { $0.totalBeverageVolumeMl < $1.totalBeverageVolumeMl },
            eligibleGoalDays: eligible.count,
            daysMeetingGoal: met,
            longestConsecutiveTrackedGoalDays: longestConsecutiveGoalDays(daily, calendar: calendar),
            last7DayGoalDays: last7Eligible.filter { $0.metTarget == true }.count,
            last7DayEligibleDays: last7Eligible.count,
            last30DayGoalDays: last30Eligible.filter { $0.metTarget == true }.count,
            last30DayEligibleDays: last30Eligible.count,
            dailySummaries: daily,
            weeklySummaries: periodSummaries(
                from: daily,
                component: .weekOfYear,
                granularity: .weekly,
                trackingStart: trackingStart,
                asOfDate: asOfDay,
                calendar: calendar
            ),
            monthlySummaries: periodSummaries(
                from: daily,
                component: .month,
                granularity: .monthly,
                trackingStart: trackingStart,
                asOfDate: asOfDay,
                calendar: calendar
            )
        )
    }

    static func dailySummaries(
        in range: DateInterval,
        snapshot: HydrationAnalyticsSnapshot,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [HydrationDailySummary] {
        let recordedByDate = Dictionary(uniqueKeysWithValues: snapshot.dailySummaries.map { ($0.date, $0) })
        var result: [HydrationDailySummary] = []
        var date = calendar.startOfDay(for: range.start)
        while date < range.end {
            if let recorded = recordedByDate[date] {
                result.append(recorded)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else { break }
            date = next
        }
        return result
    }

    static func longestConsecutiveGoalDays(
        _ daily: [HydrationDailySummary],
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        var longest = 0
        var current = 0
        var previousDate: Date?

        for summary in daily {
            guard summary.metTarget != nil else {
                current = 0
                previousDate = summary.date
                continue
            }

            let expectedNextDay = previousDate.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            if summary.metTarget == true {
                current = expectedNextDay == summary.date ? current + 1 : 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            previousDate = summary.date
        }
        return longest
    }

    private static func latestTargets(
        in records: [WaterRecord],
        calendar: Calendar
    ) -> [Date: WaterRecord] {
        var latest: [Date: WaterRecord] = [:]
        for record in records {
            guard let targetDate = record.dailyTargetDate else { continue }
            let day = calendar.startOfDay(for: targetDate)
            guard let current = latest[day] else {
                latest[day] = record
                continue
            }
            let currentTime = current.dailyTargetRecordedAt ?? .distantPast
            let newTime = record.dailyTargetRecordedAt ?? .distantPast
            if newTime >= currentTime { latest[day] = record }
        }
        return latest
    }

    private static func periodSummaries(
        from daily: [HydrationDailySummary],
        component: Calendar.Component,
        granularity: HydrationTrendGranularity,
        trackingStart: Date,
        asOfDate: Date,
        calendar: Calendar
    ) -> [HydrationPeriodSummary] {
        let grouped = Dictionary(grouping: daily) { summary in
            calendar.dateInterval(of: component, for: summary.date)?.start ?? summary.date
        }
        let dayAfterAsOf = calendar.date(byAdding: .day, value: 1, to: asOfDate) ?? asOfDate

        let base = grouped.keys.sorted().compactMap { start -> HydrationPeriodSummary? in
            guard let interval = calendar.dateInterval(of: component, for: start),
                  let days = grouped[start], !days.isEmpty else { return nil }
            let total = days.reduce(0) { $0 + $1.totalBeverageVolumeMl }
            let eligible = days.compactMap { $0.targetMl }
            let targetAverage = eligible.isEmpty ? nil : eligible.reduce(0, +) / Double(eligible.count)

            return HydrationPeriodSummary(
                granularity: granularity,
                startDate: interval.start,
                endDateExclusive: interval.end,
                totalBeverageVolumeMl: total,
                averagePerRecordedDayMl: total / Double(days.count),
                recordedDays: days.count,
                eligibleGoalDays: eligible.count,
                daysMeetingGoal: days.filter { $0.metTarget == true }.count,
                averageTargetMl: targetAverage,
                averageDifferenceFromPreviousPeriodMl: nil,
                isCompletePeriod: interval.start >= trackingStart && interval.end <= dayAfterAsOf
            )
        }
        let indexByStart = Dictionary(uniqueKeysWithValues: base.map { ($0.startDate, $0) })

        return base.map { period in
            guard period.isCompletePeriod,
                  let previousStart = calendar.date(byAdding: component, value: -1, to: period.startDate),
                  let previous = indexByStart[previousStart],
                  previous.isCompletePeriod else { return period }

            return HydrationPeriodSummary(
                granularity: period.granularity,
                startDate: period.startDate,
                endDateExclusive: period.endDateExclusive,
                totalBeverageVolumeMl: period.totalBeverageVolumeMl,
                averagePerRecordedDayMl: period.averagePerRecordedDayMl,
                recordedDays: period.recordedDays,
                eligibleGoalDays: period.eligibleGoalDays,
                daysMeetingGoal: period.daysMeetingGoal,
                averageTargetMl: period.averageTargetMl,
                averageDifferenceFromPreviousPeriodMl: period.averagePerRecordedDayMl - previous.averagePerRecordedDayMl,
                isCompletePeriod: true
            )
        }
    }

    private static func decimal(from value: Double) -> Decimal? {
        guard value.isFinite, value >= 0 else { return nil }
        return Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
    }
}

enum HydrationTargetHistoryStore {
    static func recordCurrentDay(
        profile: UserProfile,
        userID: String,
        at date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        firestore: Firestore = Firestore.firestore()
    ) async throws {
        guard Auth.auth().currentUser?.uid == userID else {
            throw WaterEntryMutationError.unauthenticated
        }

        let day = calendar.startOfDay(for: date)
        let documentID = WaterIntakeDay.documentID(for: day, calendar: calendar)
        let document = firestore.collection("users").document(userID)
            .collection("waterRecords").document(documentID)
        let estimate = profile.hydrationAssessment()?.dailyFluidEstimate?.estimatedMlPerDay
        let validEstimate = estimate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let method = validEstimate == nil ? "unavailable" : "ncez_30_ml_per_kg"
        let reason = unavailableReason(for: profile)

        _ = try await firestore.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(document)
                var fields = snapshot.data() ?? [
                    "userId": userID,
                    "entries": [[String: Any]](),
                    "amountMl": 0.0,
                    "timestamp": Timestamp(date: date)
                ]
                fields["userId"] = userID
                fields["entries"] = fields["entries"] ?? [[String: Any]]()
                fields["amountMl"] = fields["amountMl"] ?? 0.0
                fields["timestamp"] = fields["timestamp"] ?? Timestamp(date: date)
                fields["dailyTargetDate"] = Timestamp(date: day)
                fields["dailyTargetRecordedAt"] = Timestamp(date: date)
                fields["dailyTargetMethod"] = method
                fields["dailyTargetUnavailableReason"] = reason as Any? ?? NSNull()
                fields["dailyTargetMl"] = validEstimate as Any? ?? NSNull()
                transaction.setData(fields, forDocument: document)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private static func unavailableReason(for profile: UserProfile) -> String? {
        guard let assessment = profile.hydrationAssessment() else {
            return "consent_or_eligible_profile_unavailable"
        }
        switch assessment.fluidEstimateUnavailableReason {
        case .adultEstimateOnly: return "adult_estimate_only"
        case .validHeightAndWeightRequired: return "valid_height_and_weight_required"
        case .referenceWeightRequiredForBMI25OrHigher: return "clinician_reference_weight_required"
        case .validReferenceWeightRequired: return "valid_reference_weight_required"
        case nil:
            return assessment.dailyFluidEstimate == nil ? "estimate_unavailable" : nil
        }
    }
}
