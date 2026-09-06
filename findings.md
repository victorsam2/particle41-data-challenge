# Findings

These results use the default January–March 2025 Divvy selection. All three marts reconcile to 588,724 trips, the same count as `fct_trips`.

## 1. Station demand by rider segment

The station-demand query ranks named start stations within each rider segment and reports the `unknown` start-station group separately.

| Rider segment | Top named start station | Trips | Valid-duration trips | Average valid duration |
| --- | --- | ---: | ---: | ---: |
| Casual | Streeter Dr & Grand Ave | 2,270 | 2,265 | 1,740.7 seconds |
| Member | Kingsbury St & Kinzie St | 5,330 | 5,329 | 469.1 seconds |

Unknown start stations account for 24,383 of 137,776 casual trips (17.70%) and 79,734 of 450,948 member trips (17.68%). Those trips are retained because missing station IDs represent real dockless endpoints, but they are excluded from named-station rankings because `unknown` is not a physical station.

The top known starting station differs by segment, and the average valid duration at the top casual station is much longer than at the top member station. This is descriptive demand, not evidence of causality or station quality.

## 2. Usage patterns by weekday and hour

The largest weekday × start-hour cell for casual riders is Friday at 17:00: 3,050 trips, 3,042 valid-duration trips, and a 1,181.1-second average valid duration. For members, the largest cell is Thursday at 17:00: 9,003 trips, 9,000 valid-duration trips, and a 655.3-second average valid duration.

Both segments peak late in the afternoon, but the member peak is almost three times the casual peak in this three-month selection. This is a volume pattern for the loaded period, not a claim about commuting intent. The mart aggregates by weekday and hour, so it does not separate holidays, weather, route, or availability effects.

## 3. Bike type by rider segment

| Rider segment | Bike type | Trips | Share within segment | Valid-duration trips | Average valid duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Casual | Classic bike | 45,484 | 33.01% | 45,188 | 1,446.3 seconds |
| Casual | Electric bike | 92,292 | 66.99% | 92,292 | 657.9 seconds |
| Member | Classic bike | 167,903 | 37.23% | 167,819 | 697.3 seconds |
| Member | Electric bike | 283,045 | 62.77% | 283,045 | 574.5 seconds |

Electric bikes are the majority of observed trips in both segments. Classic-bike trips have higher observed average valid durations in both segments, especially for casual riders. These measures describe the trips that occurred; they do not establish rider preference, causality, bike availability, price effects, or route differences.

## Data-quality context and limitations

- The fact contains 588,344 valid-duration trips. The remaining 380 retained trips are excluded only from duration averages because their duration is missing, non-positive, or over 24 hours.
- Named-station findings cover only trips with a known historical start station. The approximately 17.7% unknown-start share in each segment is a material coverage limitation.
- GBFS is a cached live snapshot. Its current station attributes are enrichment, not historical facts.
- Matching is intentionally conservative and name-based; unmatched and ambiguous historical stations are kept rather than guessed.
- The period is January–March 2025 only. Seasonal, weather, and operational effects are outside this analysis.
