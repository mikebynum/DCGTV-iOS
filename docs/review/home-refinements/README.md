# Home tab refinements

Based on main `534ce1ca075c63a4486117f71cb0316c96a0ef9a`.

## Changes

- Preserve the Home hero asset, renderer, edge-to-edge placement, safe-area handling, pull-to-refresh, and native tab bar exactly.
- Remove the Featured thumbnail's center play overlay. Use a smaller title/time block and one 44-point action, with a calendar icon for upcoming broadcasts. The existing playback sheet and HTTPS validation remain in use.
- When a scheduled date is available, remove a recognizable trailing numeric date/time suffix from the Featured display title. Keep the original title for accessibility and all other broadcast cards. Other title formats remain intact.
- Keep three upcoming games and favorite-sport filtering. Open game details from the game information block with a chevron, replacing the separate duplicate details row. Keep location, DCGTV and away stream links, and provider notes. Date tiles grow with text size.
- Show two compact recent results on Home, with explicit DCG-first scores, final/outcome accessibility wording, date, and the existing HTTPS details links. At narrow widths or larger text sizes, the compact layout can stack. Schedule retains its full result cards and ten-result limit.
- Remove Home's Live & Recent Broadcasts, Explore DCGTV Shows, and See All Away Streams shortcuts. Watch and Shows remain accessible through the native tabs. Keep contextual Schedule links, favorites, and Booster Club support.

## Validation

Validation results are recorded in the pull request. Automated checks cover hero proportions and horizontal edges, rotation and return to Home, sponsor acknowledgment, Schedule/Watch navigation, accessibility text size, absence of redundant shortcuts, and the footer clearing the iPhone tab bar. The title suffix cleanup has unit coverage for recognized suffixes and preservation of unrelated titles or titles without a separate scheduled date.

Hero SHA-256: `2459e2eae86a53f37ffff39a815440da0aae5b2a9f0f1da94e9b3546c5289ae7` (unchanged from main). A source comparison also confirms the hero renderer and Home's GeometryReader/ScrollView safe-area and refresh implementation match main exactly.

## Review limits

Simulator validation only; no physical-device playback or external provider availability checks. UI tests use the connected CMS data and cached content, so the displayed events may change. The existing dark-mode launch override is exercised but does not establish actual simulator dark appearance. Physical notch masking, real-device rotation, and iPad multitasking remain release QA.
