//
//  RecipeNutritionCalculator.swift
//  RecipePlannerIOS
//
//  Created by Codex on 22/02/2026.
//

import Foundation
import OpenFoodFactsSDK

struct NutritionValues: Equatable, Sendable {
    let calories: Double
    let carbohydrates: Double
    let fat: Double
    let protein: Double

    nonisolated func adding(_ other: NutritionValues) -> NutritionValues {
        NutritionValues(
            calories: calories + other.calories,
            carbohydrates: carbohydrates + other.carbohydrates,
            fat: fat + other.fat,
            protein: protein + other.protein
        )
    }

    nonisolated func scaled(by factor: Double) -> NutritionValues {
        NutritionValues(
            calories: calories * factor,
            carbohydrates: carbohydrates * factor,
            fat: fat * factor,
            protein: protein * factor
        )
    }
}

struct NutritionCalculationResult: Equatable, Sendable {
    let perServing: NutritionValues
    let servings: Int
    let matchedIngredients: Int
    let totalIngredients: Int
    let missingIngredients: [String]
}

extension NutritionCalculationResult {
    nonisolated func toStoredNutrition(at date: Date = Date()) -> RecipeNutrition {
        RecipeNutrition(
            caloriesPerServing: perServing.calories,
            carbohydratesPerServing: perServing.carbohydrates,
            fatPerServing: perServing.fat,
            proteinPerServing: perServing.protein,
            servings: servings,
            matchedIngredients: matchedIngredients,
            totalIngredients: totalIngredients,
            missingIngredients: missingIngredients,
            calculatedAt: date
        )
    }
}

extension RecipeNutrition {
    nonisolated var asCalculationResult: NutritionCalculationResult {
        NutritionCalculationResult(
            perServing: NutritionValues(
                calories: caloriesPerServing,
                carbohydrates: carbohydratesPerServing,
                fat: fatPerServing,
                protein: proteinPerServing
            ),
            servings: servings,
            matchedIngredients: matchedIngredients,
            totalIngredients: totalIngredients,
            missingIngredients: missingIngredients
        )
    }
}

actor RecipeNutritionCalculator {
    static let shared = RecipeNutritionCalculator()
    private static let maxFallbackDepth = 3

    private let lookupService = OpenFoodFactsNutritionLookup()
    private let usdaLookupService = USDANutritionCSVLookup()

    private init() {}

    func calculate(
        ingredients: [Ingredient],
        servings: Int,
        relatedRecipes: [Recipe] = [],
        currentRecipeId: String? = nil,
        currentRecipeName: String? = nil
    ) async -> NutritionCalculationResult {
        if Task.isCancelled {
            let safeServings = max(servings, 1)
            return NutritionCalculationResult(
                perServing: NutritionValues(calories: 0, carbohydrates: 0, fat: 0, protein: 0),
                servings: safeServings,
                matchedIngredients: 0,
                totalIngredients: 0,
                missingIngredients: []
            )
        }

        var visitedRecipeIDs: Set<String> = []
        if let currentRecipeId {
            visitedRecipeIDs.insert(currentRecipeId)
        }

        var visitedRecipeNames: Set<String> = []
        if let currentRecipeName {
            let normalizedName = IngredientNameNormalizer.normalizedForMatching(currentRecipeName)
            if !normalizedName.isEmpty {
                visitedRecipeNames.insert(normalizedName)
            }
        }

        return await calculateInternal(
            ingredients: ingredients,
            servings: servings,
            relatedRecipes: relatedRecipes,
            visitedRecipeIDs: visitedRecipeIDs,
            visitedRecipeNames: visitedRecipeNames,
            depth: 0
        )
    }

    private func calculateInternal(
        ingredients: [Ingredient],
        servings: Int,
        relatedRecipes: [Recipe],
        visitedRecipeIDs: Set<String>,
        visitedRecipeNames: Set<String>,
        depth: Int
    ) async -> NutritionCalculationResult {
        if Task.isCancelled {
            let safeServings = max(servings, 1)
            return NutritionCalculationResult(
                perServing: NutritionValues(calories: 0, carbohydrates: 0, fat: 0, protein: 0),
                servings: safeServings,
                matchedIngredients: 0,
                totalIngredients: 0,
                missingIngredients: []
            )
        }

        let validIngredients = ingredients.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.quantity > 0
        }

        let safeServings = max(servings, 1)
        guard !validIngredients.isEmpty else {
            return NutritionCalculationResult(
                perServing: NutritionValues(calories: 0, carbohydrates: 0, fat: 0, protein: 0),
                servings: safeServings,
                matchedIngredients: 0,
                totalIngredients: 0,
                missingIngredients: []
            )
        }

        var totalValues = NutritionValues(calories: 0, carbohydrates: 0, fat: 0, protein: 0)
        var matchedIngredients = 0
        var missingIngredients: [String] = []

        for ingredient in validIngredients {
            if Task.isCancelled {
                break
            }

            let contribution = await contribution(
                for: ingredient,
                relatedRecipes: relatedRecipes,
                visitedRecipeIDs: visitedRecipeIDs,
                visitedRecipeNames: visitedRecipeNames,
                depth: depth
            )

            switch contribution {
            case .matched(let values):
                totalValues = totalValues.adding(values)
                matchedIngredients += 1
            case .missing(let ingredientName):
                missingIngredients.append(ingredientName)
            }
        }

        let perServing = totalValues.scaled(by: 1 / Double(safeServings))

        return NutritionCalculationResult(
            perServing: perServing,
            servings: safeServings,
            matchedIngredients: matchedIngredients,
            totalIngredients: validIngredients.count,
            missingIngredients: missingIngredients.sorted()
        )
    }

    private func contribution(
        for ingredient: Ingredient,
        relatedRecipes: [Recipe],
        visitedRecipeIDs: Set<String>,
        visitedRecipeNames: Set<String>,
        depth: Int
    ) async -> IngredientNutritionContribution {
        let trimmedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let recipeValues = await recipeFallbackContribution(
            for: ingredient,
            relatedRecipes: relatedRecipes,
            visitedRecipeIDs: visitedRecipeIDs,
            visitedRecipeNames: visitedRecipeNames,
            depth: depth
        ) {
            return .matched(recipeValues)
        }

        if let localValuesPer100g = LocalIngredientNutritionDatabase.nutrientsPer100g(for: trimmedName),
           let amountInGrams = IngredientAmountEstimator.grams(for: ingredient),
           amountInGrams > 0 {
            let scaledValues = localValuesPer100g.scaled(by: amountInGrams / 100)
            return .matched(scaledValues)
        }

        if let usdaValuesPer100g = await usdaLookupService.fetchNutrientsPer100g(for: trimmedName),
           let amountInGrams = IngredientAmountEstimator.grams(for: ingredient),
           amountInGrams > 0 {
            let scaledValues = usdaValuesPer100g.scaled(by: amountInGrams / 100)
            return .matched(scaledValues)
        }

        if let valuesPer100g = await lookupService.fetchNutrientsPer100g(for: trimmedName),
           let amountInGrams = IngredientAmountEstimator.grams(for: ingredient),
           amountInGrams > 0 {
            let scaledValues = valuesPer100g.scaled(by: amountInGrams / 100)
            return .matched(scaledValues)
        }

        return .missing(trimmedName)
    }

    private func recipeFallbackContribution(
        for ingredient: Ingredient,
        relatedRecipes: [Recipe],
        visitedRecipeIDs: Set<String>,
        visitedRecipeNames: Set<String>,
        depth: Int
    ) async -> NutritionValues? {
        guard depth < Self.maxFallbackDepth else {
            return nil
        }

        guard let matchedRecipe = Self.matchingRecipe(
            for: ingredient.name,
            in: relatedRecipes,
            excludingIDs: visitedRecipeIDs,
            excludingNames: visitedRecipeNames
        ) else {
            return nil
        }

        guard let servingMultiplier = Self.servingMultiplier(for: ingredient, subrecipe: matchedRecipe),
              servingMultiplier > 0 else {
            return nil
        }

        if let storedNutrition = matchedRecipe.nutrition?.asCalculationResult {
            let perServing = storedNutrition.perServing
            if perServing.calories > 0 || perServing.carbohydrates > 0 || perServing.fat > 0 || perServing.protein > 0 {
                return perServing.scaled(by: servingMultiplier)
            }
        }

        var nextVisitedIDs = visitedRecipeIDs
        if let recipeID = matchedRecipe.id {
            nextVisitedIDs.insert(recipeID)
        }

        var nextVisitedNames = visitedRecipeNames
        let recipeName = IngredientNameNormalizer.normalizedForMatching(matchedRecipe.name)
        if !recipeName.isEmpty {
            nextVisitedNames.insert(recipeName)
        }

        let subIngredients = Self.flattenedIngredients(from: matchedRecipe)

        let subRecipeResult = await calculateInternal(
            ingredients: subIngredients,
            servings: matchedRecipe.servings,
            relatedRecipes: relatedRecipes,
            visitedRecipeIDs: nextVisitedIDs,
            visitedRecipeNames: nextVisitedNames,
            depth: depth + 1
        )

        guard subRecipeResult.matchedIngredients > 0 else {
            return nil
        }

        return subRecipeResult.perServing.scaled(by: servingMultiplier)
    }

    private static func matchingRecipe(
        for ingredientName: String,
        in relatedRecipes: [Recipe],
        excludingIDs: Set<String>,
        excludingNames: Set<String>
    ) -> Recipe? {
        let candidateNames = IngredientNameNormalizer.candidates(from: ingredientName)
        guard !candidateNames.isEmpty else { return nil }

        let ingredientTokens = Set(IngredientNameNormalizer.tokens(from: ingredientName))
        var bestRecipe: Recipe?
        var bestScore = 0
        var bestLength = 0

        for recipe in relatedRecipes {
            if let recipeID = recipe.id, excludingIDs.contains(recipeID) {
                continue
            }

            let normalizedRecipeName = IngredientNameNormalizer.normalizedForMatching(recipe.name)
            if normalizedRecipeName.isEmpty || excludingNames.contains(normalizedRecipeName) {
                continue
            }

            let recipeTokens = Set(IngredientNameNormalizer.tokens(from: recipe.name))
            let sectionTitleTokens = Set((recipe.sections ?? []).flatMap { section in
                IngredientNameNormalizer.tokens(from: section.title)
            })
            let allRecipeTokens = recipeTokens.union(sectionTitleTokens)
            if allRecipeTokens.isEmpty {
                continue
            }

            var score = 0

            if candidateNames.contains(normalizedRecipeName) {
                score += 8
            }

            if candidateNames.contains(where: { $0.contains(normalizedRecipeName) || normalizedRecipeName.contains($0) }) {
                score += 5
            }

            let overlap = ingredientTokens.intersection(allRecipeTokens).count
            if overlap > 0 {
                score += overlap * 2
            }

            let coverage = Double(overlap) / Double(max(allRecipeTokens.count, 1))
            if coverage >= 0.6 {
                score += 2
            }

            if recipe.nutrition != nil {
                score += 1
            }

            guard score >= 4 else { continue }

            if score > bestScore || (score == bestScore && normalizedRecipeName.count > bestLength) {
                bestScore = score
                bestLength = normalizedRecipeName.count
                bestRecipe = recipe
            }
        }

        return bestRecipe
    }

    private static func flattenedIngredients(from recipe: Recipe) -> [Ingredient] {
        let sectionIngredients = (recipe.sections ?? []).flatMap { $0.ingredients }
        return sectionIngredients.isEmpty ? recipe.ingredients : sectionIngredients
    }

    private static func servingMultiplier(for ingredient: Ingredient, subrecipe: Recipe) -> Double? {
        let quantity = ingredient.quantity
        guard quantity > 0 else { return nil }

        let unit = ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if unit.isEmpty || servingLikeUnits.contains(unit) {
            return quantity
        }

        if let amountInGrams = IngredientAmountEstimator.grams(for: ingredient),
           let gramsPerServing = estimatedServingWeight(for: subrecipe),
           gramsPerServing > 0 {
            return amountInGrams / gramsPerServing
        }

        // Fallback: assume provided quantity represents "servings" of the subrecipe.
        return quantity
    }

    private static func estimatedServingWeight(for recipe: Recipe) -> Double? {
        let ingredients = flattenedIngredients(from: recipe)
        let totalWeight = ingredients.reduce(0.0) { partialResult, ingredient in
            partialResult + (IngredientAmountEstimator.grams(for: ingredient) ?? 0)
        }

        guard totalWeight > 0 else { return nil }
        return totalWeight / Double(max(recipe.servings, 1))
    }

    private static let servingLikeUnits: Set<String> = [
        "serving", "servings", "portion", "portions",
        "piece", "pieces", "pc", "pcs",
        "package", "packages", "pack", "packs",
        "can", "cans", "jar", "jars"
    ]
}

private enum IngredientNutritionContribution: Sendable {
    case matched(NutritionValues)
    case missing(String)
}

actor OpenFoodFactsSearchRateLimiter {
    static let shared = OpenFoodFactsSearchRateLimiter()

    private let maximumRequests: Int
    private let interval: TimeInterval
    private var requestTimes: [Date] = []

    init(maximumRequests: Int = 10, interval: TimeInterval = 60) {
        self.maximumRequests = max(1, maximumRequests)
        self.interval = max(0.1, interval)
    }

    func waitForTurn() async throws {
        while true {
            try Task.checkCancellation()
            let now = Date()
            requestTimes.removeAll { now.timeIntervalSince($0) >= interval }

            if requestTimes.count < maximumRequests {
                requestTimes.append(now)
                return
            }

            guard let firstRequest = requestTimes.first else { continue }
            let waitSeconds = max(0, interval - now.timeIntervalSince(firstRequest))
            let nanoseconds = UInt64(waitSeconds * 1_000_000_000)
            try await Task.sleep(nanoseconds: max(1, nanoseconds))
        }
    }
}

private actor OpenFoodFactsNutritionLookup {
    private var cache: [String: NutritionValues] = [:]
    private var remoteLookupSuspendedUntil: Date?
    private var consecutiveNetworkFailures = 0
    private let session: URLSession
    private static let requestTimeout: TimeInterval = 2
    private static let resourceTimeout: TimeInterval = 4
    private static let maxCandidateQueries = 2
    private static let maxProductsToScore = 20
    private static let maxConsecutiveNetworkFailures = 2
    private static let lookupSuspendDuration: TimeInterval = 30
    private static let fromHeader = "recipeplanner-ios"
    private static let userAgentHeader: String = {
        let bundle = Bundle.main
        let appVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        return "WickedRecipe/\(appVersion) (\(LegalLinks.contactEmail))"
    }()
    private static let userAgentQueryItems: [URLQueryItem] = {
        let bundle = Bundle.main
        let appVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        return [
            URLQueryItem(name: "app_name", value: "WickedRecipe"),
            URLQueryItem(name: "app_version", value: appVersion),
            URLQueryItem(name: "app_platform", value: "iOS")
        ]
    }()

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = Self.requestTimeout
        config.timeoutIntervalForResource = Self.resourceTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func fetchNutrientsPer100g(for ingredientName: String) async -> NutritionValues? {
        if Task.isCancelled { return nil }
        if let suspendedUntil = remoteLookupSuspendedUntil {
            if suspendedUntil > Date() {
                return nil
            }
            remoteLookupSuspendedUntil = nil
            consecutiveNetworkFailures = 0
        }

        let candidates = Array(IngredientNameNormalizer.candidates(from: ingredientName).prefix(Self.maxCandidateQueries))

        for candidate in candidates {
            if Task.isCancelled { return nil }

            if let cachedValue = cache[candidate] {
                return cachedValue
            }

            if let nutrients = await requestNutrients(query: candidate) {
                cache[candidate] = nutrients
                return nutrients
            }
        }

        return nil
    }

    private func requestNutrients(query: String) async -> NutritionValues? {
        if Task.isCancelled { return nil }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }

        let preferredLanguageCode = Self.currentLanguageCode()
        var attemptedKeys: Set<String> = []
        var attempts: [(languageCode: String, includeCountry: Bool)] = [
            (preferredLanguageCode, false)
        ]
        if preferredLanguageCode != "en" {
            attempts.append(("en", false))
        }

        for attempt in attempts {
            if Task.isCancelled { return nil }

            let attemptKey = "\(attempt.languageCode)|\(attempt.includeCountry)"
            if attemptedKeys.contains(attemptKey) {
                continue
            }
            attemptedKeys.insert(attemptKey)

            guard let products = await fetchProducts(
                query: trimmedQuery,
                languageCode: attempt.languageCode,
                includeCountry: attempt.includeCountry
            ) else {
                continue
            }

            if let bestMatch = Self.bestMatch(
                in: products,
                query: trimmedQuery
            ) {
                return bestMatch
            }
        }

        return nil
    }

    private func fetchProducts(
        query: String,
        languageCode: String,
        includeCountry: Bool
    ) async -> [[String: Any]]? {
        if Task.isCancelled { return nil }

        guard let requestURL = searchURL(
            for: query,
            languageCode: languageCode,
            includeCountry: includeCountry
        ) else {
            return nil
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgentHeader, forHTTPHeaderField: "User-Agent")
        request.setValue(Self.fromHeader, forHTTPHeaderField: "From")

        do {
            try await OpenFoodFactsSearchRateLimiter.shared.waitForTurn()
            guard !Task.isCancelled else { return nil }
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = root["products"] as? [[String: Any]],
                  !products.isEmpty else {
                return nil
            }

            consecutiveNetworkFailures = 0
            return products
        } catch {
            if Self.isNetworkError(error) {
                consecutiveNetworkFailures += 1
                if consecutiveNetworkFailures >= Self.maxConsecutiveNetworkFailures {
                    remoteLookupSuspendedUntil = Date().addingTimeInterval(Self.lookupSuspendDuration)
                }
            }
            return nil
        }
    }

    private func searchURL(
        for query: String,
        languageCode: String,
        includeCountry: Bool
    ) -> URL? {
        let countryCode = OFFConfig.shared.country.rawValue
        let host = OFFConfig.shared.apiEnv == .staging
            ? "world.openfoodfacts.net"
            : "world.openfoodfacts.org"
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "fields", value: "product_name,product_name_en,_keywords,categories_tags,nutriments,serving_quantity,code"),
            URLQueryItem(name: "lc", value: languageCode)
        ]
        components.queryItems?.append(contentsOf: Self.userAgentQueryItems)
        
        if includeCountry {
            components.queryItems?.append(URLQueryItem(name: "cc", value: countryCode))
        }
        
        return components.url
    }

    private static func extractValuesPer100g(
        nutriments: [String: Any],
        servingQuantity: Double?
    ) -> NutritionValues? {
        let carbs = nutrientValue(
            keys: ["carbohydrates_100g", "carbohydrates", "carbohydrates_value"],
            servingKey: "carbohydrates_serving",
            nutriments: nutriments,
            servingQuantity: servingQuantity
        ) ?? 0

        let fat = nutrientValue(
            keys: ["fat_100g", "fat", "fat_value"],
            servingKey: "fat_serving",
            nutriments: nutriments,
            servingQuantity: servingQuantity
        ) ?? 0

        let protein = nutrientValue(
            keys: ["proteins_100g", "proteins", "proteins_value"],
            servingKey: "proteins_serving",
            nutriments: nutriments,
            servingQuantity: servingQuantity
        ) ?? 0

        var calories = nutrientValue(
            keys: ["energy-kcal_100g", "energy-kcal", "energy-kcal_value"],
            servingKey: "energy-kcal_serving",
            nutriments: nutriments,
            servingQuantity: servingQuantity
        )

        if calories == nil {
            if let kilojoules = nutrientValue(
                keys: ["energy-kj_100g", "energy_100g", "energy-kj", "energy", "energy_value", "energy-kj_value"],
                servingKey: "energy-kj_serving",
                nutriments: nutriments,
                servingQuantity: servingQuantity
            ) {
                calories = kilojoules / 4.184
            } else {
                calories = (carbs * 4) + (protein * 4) + (fat * 9)
            }
        }

        let resolvedCalories = max(0, calories ?? 0)
        let resolvedCarbs = max(0, carbs)
        let resolvedFat = max(0, fat)
        let resolvedProtein = max(0, protein)

        guard resolvedCalories > 0 || resolvedCarbs > 0 || resolvedFat > 0 || resolvedProtein > 0 else {
            return nil
        }

        return NutritionValues(
            calories: resolvedCalories,
            carbohydrates: resolvedCarbs,
            fat: resolvedFat,
            protein: resolvedProtein
        )
    }

    private static func nutrientValue(
        keys: [String],
        servingKey: String,
        nutriments: [String: Any],
        servingQuantity: Double?
    ) -> Double? {
        for key in keys {
            if let value = asDouble(nutriments[key]) {
                return value
            }
        }

        if let servingValue = asDouble(nutriments[servingKey]),
           let servingQuantity,
           servingQuantity > 0 {
            return (servingValue / servingQuantity) * 100
        }

        return nil
    }

    private static func asDouble(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let number as Double:
            return number
        case let number as Float:
            return Double(number)
        case let number as Int:
            return Double(number)
        case let string as String:
            return extractNumericValue(from: string)
        default:
            return nil
        }
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .networkConnectionLost,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private static func extractNumericValue(from raw: String) -> Double? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        if let direct = Double(normalized) {
            return direct
        }

        guard let regex = try? NSRegularExpression(pattern: "[-+]?[0-9]*\\.?[0-9]+") else {
            return nil
        }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.firstMatch(in: normalized, options: [], range: range),
              let matchRange = Range(match.range, in: normalized) else {
            return nil
        }

        return Double(String(normalized[matchRange]))
    }

    private static func currentLanguageCode() -> String {
        if let preferred = Locale.preferredLanguages.first {
            let code = preferred
                .components(separatedBy: CharacterSet(charactersIn: "-_"))
                .first?
                .lowercased()
            if let code, code.count == 2 {
                return code
            }
        }
        return "en"
    }

    private static func bestMatch(in products: [[String: Any]], query: String) -> NutritionValues? {
        var bestScoredResult: (score: Int, values: NutritionValues)?
        let normalizedQuery = IngredientNameNormalizer.normalizedForMatching(query)
        let queryTokens = Set(IngredientNameNormalizer.tokens(from: query))

        for product in products.prefix(Self.maxProductsToScore) {
            guard let nutriments = product["nutriments"] as? [String: Any] else { continue }
            let servingQuantity = Self.asDouble(product["serving_quantity"])

            guard let values = Self.extractValuesPer100g(
                nutriments: nutriments,
                servingQuantity: servingQuantity
            ) else {
                continue
            }

            let score = Self.productScore(
                product: product,
                normalizedQuery: normalizedQuery,
                queryTokens: queryTokens
            )

            if let currentBest = bestScoredResult {
                if score > currentBest.score {
                    bestScoredResult = (score, values)
                }
            } else {
                bestScoredResult = (score, values)
            }
        }

        return bestScoredResult?.values
    }

    private static func productScore(
        product: [String: Any],
        normalizedQuery: String,
        queryTokens: Set<String>
    ) -> Int {
        var score = 0
        let queryTokenCount = max(queryTokens.count, 1)

        let nameCandidates: [String] = [
            product["product_name"] as? String,
            product["product_name_en"] as? String
        ]
        .compactMap { $0 }

        for name in nameCandidates {
            let normalizedName = IngredientNameNormalizer.normalizedForMatching(name)
            guard !normalizedName.isEmpty else { continue }
            let nameTokens = Set(IngredientNameNormalizer.tokens(from: name))
            let overlap = queryTokens.intersection(nameTokens).count

            if normalizedName == normalizedQuery {
                score += 40
            }

            if normalizedName.contains(normalizedQuery) || normalizedQuery.contains(normalizedName) {
                score += 18
            }

            if overlap > 0 {
                score += overlap * 8
                let coverage = Double(overlap) / Double(queryTokenCount)
                if coverage >= 0.6 {
                    score += 8
                }
            }
        }

        if let keywords = product["_keywords"] as? [String] {
            let normalizedKeywords = keywords
                .map(IngredientNameNormalizer.normalizedForMatching)
                .filter { !$0.isEmpty }

            if normalizedKeywords.contains(normalizedQuery) {
                score += 16
            }

            for token in queryTokens {
                if normalizedKeywords.contains(where: { $0.contains(token) || token.contains($0) }) {
                    score += 3
                }
            }
        }

        if let categories = product["categories_tags"] as? [String] {
            let normalizedCategories = categories.map {
                IngredientNameNormalizer.normalizedForMatching(
                    $0.replacingOccurrences(of: "en:", with: "")
                )
            }
            for token in queryTokens {
                if normalizedCategories.contains(where: { $0.contains(token) || token.contains($0) }) {
                    score += 2
                }
            }
        }

        return score
    }
}

private enum IngredientNameNormalizer {
    nonisolated static func normalizedForMatching(_ raw: String) -> String {
        candidates(from: raw).first ?? ""
    }

    nonisolated static func tokens(from raw: String) -> [String] {
        tokenize(clean(raw))
    }

    nonisolated static func candidates(from raw: String) -> [String] {
        var candidates: [String] = []
        var seen: Set<String> = []
        
        let withoutBrackets = removeBracketedContent(from: raw)
        let segments = splitSegments(from: withoutBrackets)
        let segmentsForAnalysis = segments.isEmpty ? [withoutBrackets] : segments
        
        for segment in segmentsForAnalysis {
            let rawTokens = tokenize(clean(segment))
            guard !rawTokens.isEmpty else { continue }
            
            let filteredTokens = rawTokens.filter { !descriptorWords.contains($0) }
            let coreTokens = filteredTokens.isEmpty ? rawTokens : filteredTokens
            
            appendCandidate(coreTokens.joined(separator: " "), to: &candidates, seen: &seen)
            appendCandidate(rawTokens.joined(separator: " "), to: &candidates, seen: &seen)
            
            if coreTokens.count >= 2 {
                appendCandidate(coreTokens.suffix(2).joined(separator: " "), to: &candidates, seen: &seen)
            }
            
            if rawTokens.count >= 2 {
                appendCandidate(rawTokens.prefix(2).joined(separator: " "), to: &candidates, seen: &seen)
                appendCandidate(rawTokens.suffix(2).joined(separator: " "), to: &candidates, seen: &seen)
            }
            
            if let lastCore = coreTokens.last {
                appendCandidate(lastCore, to: &candidates, seen: &seen)
            }
            
            if let ofIndex = rawTokens.lastIndex(of: "of"), rawTokens.count > ofIndex + 1 {
                let candidate = rawTokens[ofIndex + 1]
                if !descriptorWords.contains(candidate) {
                    appendCandidate(candidate, to: &candidates, seen: &seen)
                }
            }
        }
        
        // Previous normalization strategy fallback.
        appendCandidate(legacyNormalized(withoutBrackets), to: &candidates, seen: &seen)
        
        // Last safety fallback with minimally cleaned phrase.
        appendCandidate(clean(withoutBrackets), to: &candidates, seen: &seen)

        return candidates
    }

    nonisolated private static func removeBracketedContent(from value: String) -> String {
        value.replacingOccurrences(
            of: "\\([^)]*\\)|\\[[^\\]]*\\]|\\{[^}]*\\}",
            with: " ",
            options: .regularExpression
        )
    }

    nonisolated private static func splitSegments(from value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet(charactersIn: ",;/|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    nonisolated private static func clean(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
        
        return folded
            .replacingOccurrences(of: "[^\\p{L}0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func tokenize(_ value: String) -> [String] {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .map(singularize)
            .filter { $0.count >= 2 }
    }

    nonisolated private static func singularize(_ word: String) -> String {
        if word == "leaves" {
            return "leaf"
        }
        if word.count > 4 && word.hasSuffix("ves") {
            return String(word.dropLast())
        }
        if word.count > 4 && word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if word.count > 4 && word.hasSuffix("oes") {
            return String(word.dropLast(2))
        }
        if word.count > 4 &&
            (word.hasSuffix("ches") || word.hasSuffix("shes") || word.hasSuffix("xes") || word.hasSuffix("zes")) {
            return String(word.dropLast(2))
        }
        if word.count > 3 && word.hasSuffix("s") && !word.hasSuffix("ss") {
            return String(word.dropLast())
        }
        return word
    }

    nonisolated private static func appendCandidate(_ value: String?, to candidates: inout [String], seen: inout Set<String>) {
        guard let value else { return }
        let normalized = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count >= 2 else { return }
        guard !seen.contains(normalized) else { return }

        seen.insert(normalized)
        candidates.append(normalized)
    }
    
    nonisolated private static func legacyNormalized(_ value: String) -> String {
        clean(value)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !descriptorWords.contains($0) }
            .joined(separator: " ")
    }

    nonisolated private static let descriptorWords: Set<String> = [
        "and", "or", "of", "the", "a", "an", "to", "taste", "for",
        "chopped", "diced", "sliced", "minced", "grated", "crushed", "ground",
        "finely", "roughly", "fresh", "freshly", "dried", "optional", "homemade",
        "large", "small", "medium", "extra", "virgin",
        "peeled", "seeded", "skinless", "boneless",
        "cooked", "uncooked", "boiled", "roasted", "baked",
        "drained", "rinsed", "squeezed"
    ]
}

private enum IngredientAmountEstimator {
    nonisolated static func grams(for ingredient: Ingredient) -> Double? {
        let quantity = ingredient.quantity
        guard quantity > 0 else { return nil }

        let unit = ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ingredientName = ingredient.name.lowercased()

        switch unit {
        case "g", "gram", "grams":
            return quantity
        case "kg":
            return quantity * 1_000
        case "mg":
            return quantity / 1_000
        case "ml":
            return quantity * gramsPerMilliliter(for: ingredientName)
        case "l", "liter", "liters":
            return quantity * 1_000 * gramsPerMilliliter(for: ingredientName)
        case "cup", "cups":
            return quantity * gramsPerCup(for: ingredientName)
        case "tbsp", "tablespoon", "tablespoons":
            return quantity * (gramsPerCup(for: ingredientName) / 16)
        case "tsp", "teaspoon", "teaspoons":
            return quantity * (gramsPerCup(for: ingredientName) / 48)
        case "oz":
            return quantity * 28.3495
        case "lb", "lbs":
            return quantity * 453.592
        case "pinch", "pinches":
            return quantity * 0.36
        case "piece", "pieces", "pc", "pcs":
            return quantity * gramsPerPiece(for: ingredientName)
        case "clove", "cloves":
            return quantity * 5
        case "slice", "slices":
            return quantity * 30
        case "package", "packages", "pack", "packs":
            return quantity * 250
        case "can", "cans":
            return quantity * 400
        case "jar", "jars":
            return quantity * 300
        default:
            return quantity * 100
        }
    }

    nonisolated private static func gramsPerMilliliter(for ingredientName: String) -> Double {
        if ingredientName.contains("oil") { return 0.92 }
        if ingredientName.contains("honey") { return 1.42 }
        if ingredientName.contains("milk") { return 1.03 }
        return 1.0
    }

    nonisolated private static func gramsPerCup(for ingredientName: String) -> Double {
        if ingredientName.contains("flour") { return 120 }
        if ingredientName.contains("sugar") { return 200 }
        if ingredientName.contains("rice") { return 185 }
        if ingredientName.contains("oat") { return 80 }
        if ingredientName.contains("butter") { return 227 }
        if ingredientName.contains("oil") { return 218 }
        if ingredientName.contains("milk") { return 245 }
        return 240
    }

    nonisolated private static func gramsPerPiece(for ingredientName: String) -> Double {
        if ingredientName.contains("egg") { return 50 }
        if ingredientName.contains("onion") { return 110 }
        if ingredientName.contains("garlic") { return 5 }
        if ingredientName.contains("carrot") { return 60 }
        if ingredientName.contains("tomato") { return 120 }
        if ingredientName.contains("potato") { return 170 }
        if ingredientName.contains("apple") { return 180 }
        if ingredientName.contains("banana") { return 120 }
        return 100
    }
}

private actor USDANutritionCSVLookup {
    private struct Entry {
        let normalizedDescription: String
        let tokens: Set<String>
        let dataType: String
        let valuesPer100g: NutritionValues
    }

    private var entries: [Entry] = []
    private var loaded = false

    func fetchNutrientsPer100g(for ingredientName: String) async -> NutritionValues? {
        if !loaded {
            loadIfNeeded()
        }

        guard !entries.isEmpty else { return nil }

        let normalizedCandidates = Set(
            IngredientNameNormalizer.candidates(from: ingredientName)
                .map(IngredientNameNormalizer.normalizedForMatching)
                .filter { !$0.isEmpty }
        )
        let candidateTokens = Set(IngredientNameNormalizer.tokens(from: ingredientName))

        guard !normalizedCandidates.isEmpty || !candidateTokens.isEmpty else { return nil }

        var bestMatch: (score: Int, values: NutritionValues)?

        for entry in entries {
            var score = 0

            if normalizedCandidates.contains(entry.normalizedDescription) {
                score += 16
            }

            if normalizedCandidates.contains(where: { candidate in
                candidate.count >= 4 &&
                (entry.normalizedDescription.contains(candidate) || candidate.contains(entry.normalizedDescription))
            }) {
                score += 6
            }

            let overlap = candidateTokens.intersection(entry.tokens).count
            if overlap > 0 {
                score += overlap * 3
            }

            let tokenCoverage = Double(overlap) / Double(max(candidateTokens.count, 1))
            if tokenCoverage >= 0.7 {
                score += 4
            } else if tokenCoverage >= 0.5 {
                score += 2
            }

            // Prefer generic USDA foods over branded rows.
            switch entry.dataType {
            case "sr_legacy_food", "foundation_food":
                score += 2
            case "survey_fndds_food":
                score += 1
            default:
                break
            }

            guard score >= 4 else { continue }

            if let currentBest = bestMatch {
                if score > currentBest.score {
                    bestMatch = (score, entry.valuesPer100g)
                }
            } else {
                bestMatch = (score, entry.valuesPer100g)
            }
        }

        return bestMatch?.values
    }

    private func loadIfNeeded() {
        loaded = true

        guard let fileURL = findLookupFile() else {
            return
        }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }

        var parsedEntries: [Entry] = []
        parsedEntries.reserveCapacity(14_000)

        var isFirstLine = true
        for rawLine in content.split(whereSeparator: \.isNewline) {
            if isFirstLine {
                isFirstLine = false
                continue
            }

            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            let columns = parseCSVLine(line)
            guard columns.count >= 7 else { continue }

            let description = columns[1]
            let dataType = columns[2]

            guard let calories = Double(columns[3]),
                  let carbohydrates = Double(columns[4]),
                  let fat = Double(columns[5]),
                  let protein = Double(columns[6]) else {
                continue
            }

            if calories <= 0 && carbohydrates <= 0 && fat <= 0 && protein <= 0 {
                continue
            }

            let normalized = IngredientNameNormalizer.normalizedForMatching(description)
            let tokens = Set(IngredientNameNormalizer.tokens(from: description))
            if normalized.isEmpty && tokens.isEmpty {
                continue
            }

            parsedEntries.append(
                Entry(
                    normalizedDescription: normalized,
                    tokens: tokens,
                    dataType: dataType,
                    valuesPer100g: NutritionValues(
                        calories: calories,
                        carbohydrates: carbohydrates,
                        fat: fat,
                        protein: protein
                    )
                )
            )
        }

        entries = parsedEntries
    }

    private func findLookupFile() -> URL? {
        let bundle = Bundle.main

        if let exact = bundle.url(forResource: "usda_macro_lookup", withExtension: "csv", subdirectory: "Resources/Nutrition") {
            return exact
        }
        if let nested = bundle.url(forResource: "usda_macro_lookup", withExtension: "csv", subdirectory: "Nutrition") {
            return nested
        }
        if let root = bundle.url(forResource: "usda_macro_lookup", withExtension: "csv") {
            return root
        }

        return nil
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var isInQuotes = false

        let characters = Array(line)
        var index = 0
        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                if isInQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    isInQuotes.toggle()
                }
            } else if character == ",", !isInQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(character)
            }

            index += 1
        }

        result.append(current)
        return result
    }
}

private enum LocalIngredientNutritionDatabase {
    private struct Entry: Sendable {
        let aliases: [String]
        let valuesPer100g: NutritionValues
    }

    nonisolated static func nutrientsPer100g(for ingredientName: String) -> NutritionValues? {
        let candidates = IngredientNameNormalizer.candidates(from: ingredientName)
        guard !candidates.isEmpty else { return nil }

        let normalizedCandidates = Set(candidates.map(IngredientNameNormalizer.normalizedForMatching).filter { !$0.isEmpty })
        let candidateTokens = Set(candidates.flatMap { IngredientNameNormalizer.tokens(from: $0) })

        var best: (score: Int, values: NutritionValues)?

        for entry in entries {
            let aliasCandidates = entry.aliases
                .map(IngredientNameNormalizer.normalizedForMatching)
                .filter { !$0.isEmpty }
            guard !aliasCandidates.isEmpty else { continue }

            let aliasSet = Set(aliasCandidates)
            let aliasTokens = Set(aliasCandidates.flatMap { IngredientNameNormalizer.tokens(from: $0) })

            var score = 0

            if !normalizedCandidates.intersection(aliasSet).isEmpty {
                score += 10
            }

            let overlap = candidateTokens.intersection(aliasTokens).count
            if overlap > 0 {
                score += overlap * 2
            }
            if overlap >= 2 {
                score += 2
            }

            guard score >= 2 else { continue }

            if let currentBest = best {
                if score > currentBest.score {
                    best = (score, entry.valuesPer100g)
                }
            } else {
                best = (score, entry.valuesPer100g)
            }
        }

        return best?.values
    }

    nonisolated private static let entries: [Entry] = [
        Entry(aliases: ["potato", "white potato", "ziemniak", "kartofel"], valuesPer100g: NutritionValues(calories: 77, carbohydrates: 17.0, fat: 0.1, protein: 2.0)),
        Entry(aliases: ["sweet potato", "batat"], valuesPer100g: NutritionValues(calories: 86, carbohydrates: 20.1, fat: 0.1, protein: 1.6)),
        Entry(aliases: ["onion", "yellow onion", "red onion", "cebula"], valuesPer100g: NutritionValues(calories: 40, carbohydrates: 9.3, fat: 0.1, protein: 1.1)),
        Entry(aliases: ["garlic", "czosnek"], valuesPer100g: NutritionValues(calories: 149, carbohydrates: 33.1, fat: 0.5, protein: 6.4)),
        Entry(aliases: ["tomato", "pomidor"], valuesPer100g: NutritionValues(calories: 18, carbohydrates: 3.9, fat: 0.2, protein: 0.9)),
        Entry(aliases: ["carrot", "marchew"], valuesPer100g: NutritionValues(calories: 41, carbohydrates: 9.6, fat: 0.2, protein: 0.9)),
        Entry(aliases: ["cucumber", "ogorek"], valuesPer100g: NutritionValues(calories: 15, carbohydrates: 3.6, fat: 0.1, protein: 0.7)),
        Entry(aliases: ["pepper", "bell pepper", "papryka"], valuesPer100g: NutritionValues(calories: 31, carbohydrates: 6.0, fat: 0.3, protein: 1.0)),
        Entry(aliases: ["broccoli", "brokul"], valuesPer100g: NutritionValues(calories: 34, carbohydrates: 6.6, fat: 0.4, protein: 2.8)),
        Entry(aliases: ["cauliflower", "kalafior"], valuesPer100g: NutritionValues(calories: 25, carbohydrates: 5.0, fat: 0.3, protein: 1.9)),
        Entry(aliases: ["spinach", "szpinak"], valuesPer100g: NutritionValues(calories: 23, carbohydrates: 3.6, fat: 0.4, protein: 2.9)),
        Entry(aliases: ["mushroom", "pieczarka"], valuesPer100g: NutritionValues(calories: 22, carbohydrates: 3.3, fat: 0.3, protein: 3.1)),
        Entry(aliases: ["zucchini", "cukinia"], valuesPer100g: NutritionValues(calories: 17, carbohydrates: 3.1, fat: 0.3, protein: 1.2)),
        Entry(aliases: ["eggplant", "aubergine", "baklazan"], valuesPer100g: NutritionValues(calories: 25, carbohydrates: 5.9, fat: 0.2, protein: 1.0)),
        Entry(aliases: ["cabbage", "kapusta"], valuesPer100g: NutritionValues(calories: 25, carbohydrates: 5.8, fat: 0.1, protein: 1.3)),
        Entry(aliases: ["rice", "cooked rice", "ryz"], valuesPer100g: NutritionValues(calories: 130, carbohydrates: 28.0, fat: 0.3, protein: 2.7)),
        Entry(aliases: ["pasta", "cooked pasta", "spaghetti", "makaron"], valuesPer100g: NutritionValues(calories: 131, carbohydrates: 25.0, fat: 1.1, protein: 5.0)),
        Entry(aliases: ["oat", "oats", "rolled oats"], valuesPer100g: NutritionValues(calories: 389, carbohydrates: 66.3, fat: 6.9, protein: 16.9)),
        Entry(aliases: ["flour", "wheat flour", "maka"], valuesPer100g: NutritionValues(calories: 364, carbohydrates: 76.0, fat: 1.0, protein: 10.0)),
        Entry(aliases: ["sugar", "white sugar", "brown sugar", "cukier"], valuesPer100g: NutritionValues(calories: 387, carbohydrates: 100.0, fat: 0.0, protein: 0.0)),
        Entry(aliases: ["butter", "maslo"], valuesPer100g: NutritionValues(calories: 717, carbohydrates: 0.1, fat: 81.0, protein: 0.9)),
        Entry(aliases: ["olive oil", "oil", "vegetable oil", "oliwa", "olej"], valuesPer100g: NutritionValues(calories: 884, carbohydrates: 0.0, fat: 100.0, protein: 0.0)),
        Entry(aliases: ["milk", "whole milk", "mleko"], valuesPer100g: NutritionValues(calories: 61, carbohydrates: 4.8, fat: 3.3, protein: 3.2)),
        Entry(aliases: ["yogurt", "plain yogurt", "jogurt"], valuesPer100g: NutritionValues(calories: 61, carbohydrates: 4.7, fat: 3.3, protein: 3.5)),
        Entry(aliases: ["cream", "smietana"], valuesPer100g: NutritionValues(calories: 340, carbohydrates: 3.0, fat: 36.0, protein: 2.0)),
        Entry(aliases: ["cheese", "ser"], valuesPer100g: NutritionValues(calories: 350, carbohydrates: 2.0, fat: 28.0, protein: 22.0)),
        Entry(aliases: ["feta"], valuesPer100g: NutritionValues(calories: 264, carbohydrates: 4.1, fat: 21.5, protein: 14.2)),
        Entry(aliases: ["mozzarella"], valuesPer100g: NutritionValues(calories: 280, carbohydrates: 2.2, fat: 17.0, protein: 28.0)),
        Entry(aliases: ["egg", "jajko"], valuesPer100g: NutritionValues(calories: 143, carbohydrates: 0.7, fat: 9.5, protein: 12.6)),
        Entry(aliases: ["chicken breast", "chicken", "kurczak"], valuesPer100g: NutritionValues(calories: 165, carbohydrates: 0.0, fat: 3.6, protein: 31.0)),
        Entry(aliases: ["turkey", "indyk"], valuesPer100g: NutritionValues(calories: 189, carbohydrates: 0.0, fat: 7.4, protein: 29.0)),
        Entry(aliases: ["beef", "wolowina"], valuesPer100g: NutritionValues(calories: 250, carbohydrates: 0.0, fat: 15.0, protein: 26.0)),
        Entry(aliases: ["pork", "wieprzowina"], valuesPer100g: NutritionValues(calories: 242, carbohydrates: 0.0, fat: 14.0, protein: 27.0)),
        Entry(aliases: ["salmon", "losos"], valuesPer100g: NutritionValues(calories: 208, carbohydrates: 0.0, fat: 13.0, protein: 20.0)),
        Entry(aliases: ["tuna", "tunczyk"], valuesPer100g: NutritionValues(calories: 132, carbohydrates: 0.0, fat: 1.0, protein: 29.0)),
        Entry(aliases: ["shrimp", "krewetka"], valuesPer100g: NutritionValues(calories: 99, carbohydrates: 0.2, fat: 0.3, protein: 24.0)),
        Entry(aliases: ["lentil", "cooked lentil", "soczewica"], valuesPer100g: NutritionValues(calories: 116, carbohydrates: 20.1, fat: 0.4, protein: 9.0)),
        Entry(aliases: ["chickpea", "cooked chickpea", "ciecierzyca"], valuesPer100g: NutritionValues(calories: 164, carbohydrates: 27.4, fat: 2.6, protein: 8.9)),
        Entry(aliases: ["bean", "cooked bean", "fasola"], valuesPer100g: NutritionValues(calories: 127, carbohydrates: 22.8, fat: 0.5, protein: 8.7)),
        Entry(aliases: ["pea", "green pea", "groszek"], valuesPer100g: NutritionValues(calories: 81, carbohydrates: 14.5, fat: 0.4, protein: 5.4)),
        Entry(aliases: ["corn", "kukurydza"], valuesPer100g: NutritionValues(calories: 86, carbohydrates: 19.0, fat: 1.4, protein: 3.2)),
        Entry(aliases: ["bread", "chleb"], valuesPer100g: NutritionValues(calories: 265, carbohydrates: 49.0, fat: 3.2, protein: 9.0)),
        Entry(aliases: ["apple", "jablko"], valuesPer100g: NutritionValues(calories: 52, carbohydrates: 14.0, fat: 0.2, protein: 0.3)),
        Entry(aliases: ["banana", "banan"], valuesPer100g: NutritionValues(calories: 89, carbohydrates: 23.0, fat: 0.3, protein: 1.1)),
        Entry(aliases: ["lemon", "cytryna"], valuesPer100g: NutritionValues(calories: 29, carbohydrates: 9.3, fat: 0.3, protein: 1.1)),
        Entry(aliases: ["honey", "miod"], valuesPer100g: NutritionValues(calories: 304, carbohydrates: 82.4, fat: 0.0, protein: 0.3)),
        Entry(aliases: ["cocoa", "kakao"], valuesPer100g: NutritionValues(calories: 228, carbohydrates: 57.9, fat: 13.7, protein: 19.6)),
        Entry(aliases: ["water", "woda"], valuesPer100g: NutritionValues(calories: 0, carbohydrates: 0.0, fat: 0.0, protein: 0.0)),
        Entry(aliases: ["salt", "sea salt", "sol"], valuesPer100g: NutritionValues(calories: 0, carbohydrates: 0.0, fat: 0.0, protein: 0.0)),
        Entry(aliases: ["black pepper", "pieprz"], valuesPer100g: NutritionValues(calories: 251, carbohydrates: 64.0, fat: 3.3, protein: 10.4))
    ]
}
