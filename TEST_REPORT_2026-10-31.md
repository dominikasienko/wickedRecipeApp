# Wicked Recipe — Test Report (2026-10-31)

## Summary

This report records the final test run against the latest pushed `main` revision, after the calendar, hydration analytics, localization extraction, and asset changes were present.

- Commit under test: `bb547c8aaa132261a8cab6d990206bb17270b175` (`main`, same as `origin/main`)
- Execution date: 2026-10-31
- Execution interval: 05:26:56–05:28:03 CET (Europe/Warsaw)
- Xcode: 26.6 (17F113)
- macOS reported by Xcode: 26.6.2
- Scheme: `RecipePlannerIOS`
- Executed test target: `RecipePlannerIOSTests` (Test Scheme Action)
- Destination: iPhone 17 Pro simulator, iOS 26.5 (23F77), arm64
- Result: **59 passed, 0 failed, 0 skipped**
- Xcode result bundle: `/private/tmp/WickedRecipe-PostFinalCommit-20261031.xcresult`

The test action built the app and unit-test target, then executed all 59 cases in `RecipePlannerIOSTests`.

## Exact command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project RecipePlannerIOS.xcodeproj -scheme RecipePlannerIOS -destination 'platform=iOS Simulator,id=9AD8F895-5DD9-45D5-A09A-DA7DDC85E8A0' -derivedDataPath /private/tmp/wicked-meal-derived -clonedSourcePackagesDirPath '/Users/dominikasienko/Library/Developer/Xcode/DerivedData/RecipePlannerIOS-epahihiuznobsybnrjyigioitgkl/SourcePackages' -resultBundlePath /private/tmp/WickedRecipe-PostFinalCommit-20261031.xcresult -parallel-testing-enabled NO -only-testing:RecipePlannerIOSTests CODE_SIGNING_ALLOWED=NO test
```

Xcode version was read with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version`.

## Individual test results

| Test suite | Test name | Result | Execution date | Environment | Failure details |
|---|---|---|---|---|---|
| `RecipePlannerIOSTests` | `testAccountDeletionResetsAppPreferencesWithoutClearingOtherDefaults()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testAdolescentReceivesEFSAReferenceButNoAdultWeightEstimate()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testAdultMacroGuidanceUsesAMDRRangesNotSingleTargets()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testAgeEligibilityAndConsentAreRequiredForHealthTargets()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testDateStartOfDay()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testEFSAWaterReferenceIsSeparateFromWeightActivityAndDietEstimates()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testEFSAWaterReferenceValuesAndSupportedLifeStageAdjustments()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testEnergyEstimateDoesNotApplyWeightGoalOrDietMultipliers()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testEnergyEstimateRecalculatesFromCurrentProfileValues()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testExerciseHydrationAccountsForFluidAndUrineAndOnlyShowsRecoveryWithMassLoss()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testExerciseHydrationEstimateUsesMeasuredSessionInputs()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testExerciseHydrationRejectsInvalidOrIncompleteInputs()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testHydrationAnalyticsGroupsByLocalDaysAcrossDaylightSavingBoundary()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testHydrationAnalyticsUsesEarliestValidEntryAndKeepsGapsOutOfRecordedAverages()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testHydrationAnalyticsUsesLatestSavedTargetAndNeverBackfillsMissingTargets()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testHydrationAssessmentRecalculatesWithProfileChangesWithoutActivityMultiplier()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testHydrationDailyWeeklyAndMonthlyTrendsUseRecordedPeriodsAndCompareCompleteMonths()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testHydrationEditAndDeleteHelpersRecalculateFromUpdatedRecords()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testIngredientDescriptionForAPI()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testIngredientQuantityInputSupportsTwoDecimalsAndLocaleSeparators()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testInvalidAgeOrMeasurementsDoNotProduceEnergyEstimate()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testInvalidBodyMeasurementsDoNotProduceWeightBasedFluidEstimate()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testLegacyActivityLabelsMapToUpdatedPALCategories()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testLegacyShoppingListItemsDecodeWithNewOptionalMetadata()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testMealCalendarModeChangesPreserveDateAndPeriodNavigationUsesSelectedMode()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testMealCalendarMonthBoundariesLeapYearsAndClampedNavigation()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testMealCalendarSelectionKeepsPlannedEntriesAcrossModeSwitchesAndReduceMotion()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testMealEntriesAreFilteredByInclusiveLocalCalendarPeriod()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testMealPlanEntryValidationAndIndependentEditValues()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testMealPlanPeriodGenerationIntegratesScalingAggregationAndRecipeRefresh()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testNASEMAdolescentEquationIncludesGrowthAllowance()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testNASEMAdultEnergyEquationsForAllSexAndActivityCategories()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testNASEMAdultEquationBeginsAtAge19AndUpperAgeBoundaryIsEnforced()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testOpenFoodFactsSearchRateLimiterQueuesAfterTenPerMinuteLimit()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testOverweightFluidEstimateRequiresAValidProvidedReferenceWeight()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testPolishCalendarWeeksStartOnMondayAndContainSevenLocalDays()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testPrivacyPolicyUsesCanonicalURLWithoutLanguageFragment()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testProfileImageEditStatePreservesReplacesAndRemovesExplicitly()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testProfileMeasurementInputAcceptsCommaAndPeriodDecimalSeparators()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testRecipeDeletionValidatesOwnershipAndDeduplicatesIDs()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testRecipeSelectionStateSupportsMultiSelectCancelAndPruning()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testRepeatedRecipeAssignmentsAreCountedIndependently()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListChangesPeriodWithoutReintroducingCustomItems()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListCombinesNameFormattingAndAddsGramAmounts()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListKeepsDifferentIngredientsAndDimensionsSeparate()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListNormalizesMassVolumeAndCountUnits()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListPeriodExcludesRecipesOutsideLocalDateRange()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListPreservesUnquantifiedInvalidAndUnscaledIngredients()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListReconciliationPreservesEditsPurchaseCustomAndRemoval()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListScalesPlannedServingsBeforeAggregationAcrossRecipes()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testShoppingListUsesSectionIngredientsWithoutDoubleCountingFlatCopy()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testUnsupportedOrIneligibleProfilesDoNotReceivePersonalizedTargets()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testUserProfileAgeCalculation()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testWaterDailyTotalCountsUniqueSameDayEntriesOnceAndSwitchesDates()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testWaterDailyTotalsSeparateEntriesByTimestampAcrossDocuments()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testWaterDayKeysAndTotalsRespectLocalMidnightAndDaylightSavingTime()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testWaterLogOnNextDayUsesNewDocumentAndPreservesPreviousDay()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testWaterRecordTotalIntake()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |
| `RecipePlannerIOSTests` | `testWeightBasedFluidEstimateUsesThirtyMlPerKgFor60To80Kg()` | Passed | 2026-10-31 | iPhone 17 Pro simulator, iOS 26.5 (23F77) | — |

## UI test target and screenshot

`RecipePlannerIOSUITests` was not run. Its authenticated navigation setup requires `WICKED_RECIPE_UI_TEST_EMAIL` and `WICKED_RECIPE_UI_TEST_PASSWORD`; both were unset in this environment. The test helper fails navigation setup without them, and production authentication and consent were not bypassed.

No XCUITest Test Navigator screenshot is claimed. The result bundle and table above are genuine evidence for the executed unit-test target only. UI automation and visual iPad testing remain unverified.

## Result bundle details

Xcode reports 59 test cases, 59 passed, 0 failed, 0 skipped, and no expected failures. Device identifier: `9AD8F895-5DD9-45D5-A09A-DA7DDC85E8A0`.
