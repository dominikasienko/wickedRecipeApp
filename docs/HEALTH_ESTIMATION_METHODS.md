# Health Estimate Methods and Limitations

This document describes the app's general energy, macronutrient, and water references. They are population estimates for planning, not diagnosis, medical advice, or a clinician-prescribed intake target.

## Energy

The app uses the 2023 National Academies of Sciences, Engineering, and Medicine (NASEM) Estimated Energy Requirement (EER) equations. These predict energy intake for weight maintenance, using age, height, weight, sex-reference category, and a physical-activity-level (PAL) category. Adult equations are for ages 19 and over. The adolescent equations for ages 14 to under 19 include the published 20 kcal/day growth term. Values are calculated in kcal/day with age in years, height in centimeters, and weight in kilograms.

For adults, the coefficients implemented are:

| Reference category | PAL | EER (kcal/day) |
| --- | --- | --- |
| Male | Inactive | 753.07 - 10.83a + 6.50h + 14.10w |
| Male | Low active | 581.47 - 10.83a + 8.30h + 14.94w |
| Male | Active | 1004.82 - 10.83a + 6.52h + 15.91w |
| Male | Very active | -517.88 - 10.83a + 15.61h + 19.11w |
| Female | Inactive | 584.90 - 7.01a + 5.72h + 11.71w |
| Female | Low active | 575.77 - 7.01a + 6.60h + 12.14w |
| Female | Active | 710.25 - 7.01a + 6.54h + 12.34w |
| Female | Very active | 511.83 - 7.01a + 9.07h + 12.56w |

Here, `a` is age in years, `h` is height in cm, and `w` is weight in kg. The corresponding adolescent coefficients and the growth term are implemented directly in `UserProfile.calculateEstimatedEnergyRequirementKcal()`.

For ages 14 to under 19, the implemented equations are:

| Reference category | PAL | EER (kcal/day) |
| --- | --- | --- |
| Male | Inactive | -447.51 + 3.68a + 13.01h + 13.15w + 20 |
| Male | Low active | 19.12 + 3.68a + 8.62h + 20.28w + 20 |
| Male | Active | -388.19 + 3.68a + 12.66h + 20.46w + 20 |
| Male | Very active | -671.75 + 3.68a + 15.38h + 23.25w + 20 |
| Female | Inactive | 55.59 - 22.25a + 8.43h + 17.07w + 20 |
| Female | Low active | -297.54 - 22.25a + 12.77h + 14.73w + 20 |
| Female | Active | -189.55 - 22.25a + 11.74h + 18.34w + 20 |
| Female | Very active | -709.59 - 22.25a + 18.22h + 14.25w + 20 |

The four activity choices are NASEM PAL categories, not exercise-frequency multipliers. PAL reflects an entire day, including work, transport, recreation, and daily activity. Existing stored activity values are mapped for compatibility: sedentary -> inactive; low -> low active; moderate -> active; high and very high -> very active. Values are not rewritten merely by reading a profile.

NASEM's equations were developed from U.S. and Canadian data and have not been calibrated specifically for Polish users. They are estimates with individual prediction error. The app supports ages 14-100 and metric measurements within the existing profile validation limits (30-300 kg and 120-250 cm). No estimate is returned for an unsupported equation category, invalid inputs, or a profile that has not opted into general estimates. The app does not calculate pregnancy, breastfeeding, weight-loss, or weight-gain energy prescriptions. Weight goal and dietary preferences do not change EER.

## Macronutrients

The former single 25/30/45 split and diet/goal adjustments have been removed. The app displays broad Acceptable Macronutrient Distribution Ranges (AMDRs) converted to gram ranges from the estimated maintenance energy:

| Age | Protein | Fat | Carbohydrate |
| --- | --- | --- | --- |
| 14-18 | 10-30% of energy | 25-35% | 45-65% |
| 19+ | 10-35% of energy | 20-35% | 45-65% |

The conversion uses 4 kcal/g for protein and carbohydrate and 9 kcal/g for fat. These are ranges, not personalized gram prescriptions; the three ranges are not intended to be independently maximized. Dietary preferences and weight goal do not alter these reference ranges.

## Water

The tracker uses the European Food Safety Authority's adequate intake (AI) for **total water** as a reference: 2,000 ml/day for females and 2,500 ml/day for males, for ages 14 and older. EFSA defines this as water from drinking water, all beverages, and food moisture, under moderate temperature and physical activity (PAL 1.6). It is not a target for plain water alone and is not individualized by body weight, diet, activity, or weight goal.

The tracker only records drinks. Its progress display therefore compares logged beverage volume with the total-water AI and explicitly notes that food moisture is not counted. Reaching that displayed beverage volume does not mean the app measured total water intake. The reference is not adjusted for heat, intense exercise, pregnancy, breastfeeding, or medical fluid restrictions. Users with those circumstances should not enable general estimates and should follow qualified clinical advice.

All beverage entries now contribute their recorded volume equally. The former per-drink hydration percentages were not supported by evidence that would justify precise coefficients for each listed beverage and milk choice. A short beverage-hydration-index trial measured short-term urine output for specific drinks and does not establish universal per-ml hydration factors. Existing Firestore `hydrationFactor` fields remain decodable for compatibility, but calculations ignore them. No historical documents are rewritten; history reports the actual logged drink volumes.

## Eligibility, Persistence, and Compatibility

- Registration requires a user-entered date of birth, weight, height, equation reference category, activity category, and weight goal; weight and height are stored and calculated in kg and cm.
- The general-estimate setting is explicit and defaults to off. It advises against using these estimates during pregnancy/breastfeeding or with clinician-directed calorie/fluid limits. Unsupported or incomplete profiles receive no personalized estimate; there is no weight-based fallback.
- Older profiles without this setting decode safely as not opted in. Users must review their profile and opt in before estimates appear.
- The calorie estimate and macro ranges are computed from the current profile when requested; no calorie result is persisted. The water AI is placed in the existing in-memory tracker goal; it is not a per-user physiological calculation.
- Existing water entries and their raw amount, timestamp, beverage ID/name, and legacy factor are preserved in Firestore. Only the derived total changes to use recorded volume rather than the unsupported legacy factor.

## Sources

- NASEM, *Dietary Reference Intakes for Energy* (2023), EER equations and PAL definitions: <https://www.nationalacademies.org/read/26818/chapter/7>
- NASEM, *Rethinking the Acceptable Macronutrient Distribution Range for the 21st Century* (2024), AMDR table: <https://www.nationalacademies.org/read/27957/chapter/5>
- EFSA, *Scientific Opinion on Dietary Reference Values for Water* (2010): <https://efsa.onlinelibrary.wiley.com/doi/10.2903/j.efsa.2010.1459>
- Maughan et al., beverage hydration index randomized trial (2016): <https://pubmed.ncbi.nlm.nih.gov/26702122/>
