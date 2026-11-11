# Focused Home follow-up

Based on main `206e695c2d5fad62596a085dfa229adadce796ae`, after PR #22 was merged.

- Keep the Featured card's explicit black background and white text in light and dark mode. Remove the separate upcoming-status row and express it in the calendar action, “View Upcoming Stream.” Keep live/stale-live status labels, the accessible title, scheduled date/time, and the existing playback sheet. Reduce information-block spacing from 6 to 4 points and vertical padding from 12 to 10 points; keep a 44-point action target.
- Reduce Home section gaps from 20 to 16 points and inner gaps from 12 to 10 points. Compact results use 8-point section gaps, 4-point internal gaps, and 8-point vertical padding; preserve horizontal padding, text wrapping, and 44-point details targets. Schedule's full result cards are unchanged.
- The earlier iPhone scroll captures showed game/result text behind the status-bar clock. Add a noninteractive, accessibility-hidden background limited to the iPhone's measured top safe area while Home is scrolled. At the top, remove that cover to preserve the original hero artwork and decorative extension. Landscape follows the measured top inset. Leave iPad's native tab presentation and the existing bottom safe-area clearance unchanged.
- Preserve the hero asset and `DCGHomeBrandHeader` renderer exactly.

## Validation status

Swift syntax parsing and `git diff --check` pass. The previous PR's standard/XXXL footer-clearance checks passed on iPhone, but those runs precede this follow-up and do not verify its new status-bar cover.

A fresh Xcode build was attempted. The current execution policy denies Simulator access and Swift macro-plugin execution (`sandbox_apply: Operation not permitted` / StateMacro plugin failure), so no new build, simulator UI test, or screenshot validation can be claimed. A request for expanded Simulator access was rejected by the approval policy. This PR remains draft pending runtime review.

Added a scroll-away/return-to-top UI check with screenshots. Run it alongside `testCompactHomeKeepsFooterAboveTabsAndRemovesShortcuts`, `testCompactHomeAtAccessibilityTextSize`, the existing hero rotation checks, and Home/Schedule navigation checks. Review standard and XXXL text in actual light/dark appearance on an iPhone, plus landscape and iPad. Confirm the status clock stays readable while scrolling, the top cover disappears at Home's initial position, and the last link scrolls above the floating tabs. Physical-device notch/Dynamic Island checks remain necessary.
