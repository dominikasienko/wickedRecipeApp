//
//  SeasonalCalendarView.swift
//  RecipePlannerIOS
//
//  Created by Codex on 28/03/2026.
//

import SwiftUI
import UIKit

private struct SeasonalMonth: Identifiable, Hashable {
    let id: String
    let title: String
    let assetName: String
    let fruits: [String]
    let vegetables: [String]
    let note: String?

    var teaserItems: [String] {
        Array((fruits + vegetables).prefix(4))
    }

}

private enum SeasonalCalendarData {
    private static let winterFruits = [
        "Apples",
        "Pears",
        "Pineapple",
        "Tangerines",
        "Grapefruit",
        "Dried fruit",
        "Mango",
        "Oranges"
    ]

    private static let winterVegetables = [
        "Parsley (home-grown)",
        "Parsley root",
        "Leek",
        "Lamb's lettuce",
        "Celery root",
        "Potatoes",
        "Iceberg lettuce",
        "Legumes",
        "Garlic",
        "Broccoli",
        "Brussels sprouts",
        "Cauliflower",
        "Black truffles",
        "Beets",
        "Chicory",
        "Pumpkin",
        "Endive",
        "Fennel",
        "Cabbage",
        "Carrots",
        "Radishes"
    ]

    static let months: [SeasonalMonth] = [
        SeasonalMonth(
            id: "january_march",
            title: "January - March",
            assetName: "January : February : March",
            fruits: winterFruits,
            vegetables: winterVegetables,
            note: "Radishes and cauliflower become more common in March."
        ),
        SeasonalMonth(
            id: "april",
            title: "April",
            assetName: "April",
            fruits: ["Pears", "Rhubarb", "Mangoes", "Apples", "Blood oranges"],
            vegetables: [
                "New potatoes",
                "Bell peppers",
                "Carrots",
                "Onions",
                "Young cabbage",
                "Artichokes",
                "Legumes",
                "Iceberg lettuce",
                "Asparagus",
                "Morels",
                "Sorrel",
                "Radishes",
                "Endive",
                "Parsley",
                "Chicory"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "may",
            title: "May",
            assetName: "May",
            fruits: ["Strawberries", "Mangoes", "Gooseberries", "Cherries", "Rhubarb"],
            vegetables: [
                "Arugula",
                "Sorrel",
                "Swiss chard",
                "White onions",
                "Yellow onions",
                "Butterhead lettuce",
                "Broad beans",
                "Artichokes",
                "Peas"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "june",
            title: "June",
            assetName: "June",
            fruits: [
                "Elderberries",
                "Cherries",
                "Blueberries",
                "Currants",
                "Plums",
                "Sweet cherries",
                "Apricots",
                "Strawberries",
                "Rhubarb"
            ],
            vegetables: [
                "Spinach",
                "Broad beans",
                "Artichokes",
                "Eggplant",
                "Green beans",
                "Peas",
                "Squash",
                "Zucchini",
                "Kohlrabi",
                "Baby carrots",
                "Cucumbers",
                "Leeks",
                "Celery leaves"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "july",
            title: "July",
            assetName: "July",
            fruits: [
                "Apples",
                "Pears",
                "Gooseberries",
                "Apricots",
                "Blackberries",
                "Melons",
                "Nectarines",
                "Strawberries",
                "Raspberries",
                "Elderberries",
                "Currants",
                "Cherries",
                "Peaches",
                "Plums"
            ],
            vegetables: [
                "Swiss chard",
                "Broad beans",
                "Broccoli",
                "Zucchini",
                "Green beans",
                "Snow peas",
                "Cauliflower",
                "Kohlrabi",
                "Carrots",
                "Parsley",
                "Cucumbers",
                "Leeks",
                "Arugula",
                "Radishes",
                "Lettuce",
                "Celery leaves",
                "Sorrel",
                "Asparagus",
                "Spinach",
                "Potatoes",
                "Fennel",
                "Corn",
                "Bell peppers",
                "Tomatoes"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "august",
            title: "August",
            assetName: "August",
            fruits: [
                "Raspberries",
                "Melon",
                "Black currants",
                "Mirabelle plums",
                "Blackberries",
                "Grapes",
                "Nectarines",
                "Plums",
                "Wild strawberries",
                "Blueberries",
                "Watermelons"
            ],
            vegetables: [
                "Fennel",
                "Green beans",
                "Chanterelle mushrooms",
                "Leeks",
                "Artichokes",
                "Eggplant",
                "Zucchini",
                "Broccoli",
                "Kohlrabi",
                "Beans",
                "Cabbage"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "september",
            title: "September",
            assetName: "September",
            fruits: [
                "Quince",
                "Cranberries",
                "Figs",
                "Raspberries",
                "Blackberries",
                "Wild strawberries",
                "Apples",
                "Pears",
                "Kiwis",
                "Blueberries",
                "Grapes",
                "Elderberries",
                "Peaches",
                "Plums"
            ],
            vegetables: [
                "Horseradish",
                "Arugula",
                "Kale",
                "Chicory",
                "Pumpkin",
                "Celery",
                "Porcini mushrooms",
                "Eggplant",
                "Butterhead lettuce",
                "Squash",
                "Green beans",
                "Leeks",
                "Carrots",
                "Brussels sprouts"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "october",
            title: "October",
            assetName: "October",
            fruits: [
                "Figs",
                "Papaya",
                "Dates",
                "Grapes",
                "Apples",
                "Pears",
                "Plums",
                "Quince"
            ],
            vegetables: [
                "Sweet potatoes",
                "Beets",
                "Zucchini",
                "Kale",
                "Cauliflower",
                "Pumpkin",
                "Leeks",
                "Horseradish",
                "Chicory",
                "Arugula",
                "Young cabbage",
                "Iceberg lettuce",
                "Onions",
                "Endive",
                "Brussels sprouts",
                "Lamb's lettuce",
                "Corn"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "november",
            title: "November",
            assetName: "November",
            fruits: ["Apples", "Pears", "Grapefruit", "Pineapple", "Kiwi", "Rosehip"],
            vegetables: [
                "Brussels sprouts",
                "Beets",
                "Horseradish",
                "Fennel",
                "Chicory",
                "Pumpkin",
                "Parsley",
                "Leeks",
                "Morels",
                "Lamb's lettuce",
                "Arugula",
                "Kohlrabi",
                "Cabbage"
            ],
            note: nil
        ),
        SeasonalMonth(
            id: "december",
            title: "December",
            assetName: "December",
            fruits: ["Tangerines", "Oranges", "Pineapple", "Kiwi", "Papaya", "Apples", "Pears"],
            vegetables: [
                "Beets",
                "Chicory",
                "Brussels sprouts",
                "Pumpkin",
                "Kale",
                "Fennel",
                "Lamb's lettuce",
                "Leeks",
                "Celery",
                "Cabbage"
            ],
            note: nil
        )
    ]
}

struct SeasonalCalendarView: View {
    private let months = SeasonalCalendarData.months

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            Ellipse()
                .fill(Color.wickedGreen.opacity(0.32))
                .frame(width: 320, height: 320)
                .position(x: 40, y: 120)
                .blur(radius: 110)
                .ignoresSafeArea()

            Ellipse()
                .fill(Color.glindaPink.opacity(0.22))
                .frame(width: 260, height: 260)
                .position(x: 340, y: 760)
                .blur(radius: 90)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SeasonalHeroCard()

                    ForEach(months) { month in
                        NavigationLink {
                            SeasonalMonthDetailView(month: month)
                        } label: {
                            SeasonalMonthCard(month: month)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Seasonal Calendar")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct SeasonalHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasonal fruits and vegetables")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(.white)

            Text("Open a month to see what is freshest right now and plan recipes around produce that is naturally in season.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 10) {
                Label("12 months", systemImage: "calendar")
                Label("Fruit + veg", systemImage: "leaf.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.wickedGreen)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SeasonalMonthCard: View {
    @Environment(\.locale) private var locale
    let month: SeasonalMonth

    private var summaryText: some View {
        HStack(spacing: 0) {
            Text("\(month.fruits.count) fruits")
            Text(verbatim: " | ")
            Text("\(month.vegetables.count) vegetables")
        }
    }

    private var teaserText: String {
        month.teaserItems
            .map { String(localized: String.LocalizationValue($0), locale: locale) }
            .joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SeasonalMonthImage(assetName: month.assetName, title: month.title)
                .frame(height: 182)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(month.title))
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(.white)

                    Spacer()

                    summaryText
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.glindaPink)
                }

                Text(teaserText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)

                HStack {
                    Spacer()
                    Text("Open month")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.wickedGreen)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SeasonalMonthDetailView: View {
    let month: SeasonalMonth

    private var availabilityText: some View {
        HStack(spacing: 0) {
            if month.id == "january_march" {
                Text("Available from ")
            } else {
                Text("Available in ")
            }
            Text(LocalizedStringKey(month.title))
        }
    }

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SeasonalMonthImage(assetName: month.assetName, title: month.title)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(month.title))
                            .font(.system(.largeTitle, design: .serif).weight(.bold))
                            .foregroundStyle(.white)

                        availabilityText
                            .font(.subheadline)
                            .foregroundStyle(Color.wickedGreen)
                    }

                    if let note = month.note {
                        Text(LocalizedStringKey(note))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.glindaPink.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.glindaPink.opacity(0.28), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    SeasonalProduceSection(
                        title: "Fruits",
                        tint: Color.wickedGreen,
                        items: month.fruits
                    )

                    SeasonalProduceSection(
                        title: "Vegetables",
                        tint: Color.glindaPink,
                        items: month.vegetables
                    )
                }
                .padding()
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(LocalizedStringKey(month.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SeasonalProduceSection: View {
    let title: LocalizedStringKey
    let tint: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                Spacer()
                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }

            VStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tint.opacity(0.92))
                            .frame(width: 8, height: 8)

                        Text(LocalizedStringKey(item))
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SeasonalMonthImage: View {
    let assetName: String
    let title: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color.wickedGreen.opacity(0.9),
                        Color.glindaPink.opacity(0.65),
                        Color.darkBackground.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.92))

                    Text(LocalizedStringKey(title))
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.82))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(18)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(LocalizedStringKey(title))
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(.white)
                .padding(18)
        }
        .clipped()
    }
}
