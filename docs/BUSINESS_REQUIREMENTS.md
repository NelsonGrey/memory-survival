# Memory-Allocation Survival — Business Requirements

**Document type:** Business Requirements Document (BRD)  
**Version:** 0.1  
**Status:** Proposed / discovery  
**Last updated:** August 11, 2026  
**Owner:** Mark Nelson  
**Working concept:** Memory-allocation survival; no final product title selected

Related document: [Technical Requirements](./TECHNICAL_REQUIREMENTS.md)  
Portfolio context: [Requirements Index](../../PORTFOLIO_REQUIREMENTS_INDEX.md)

## 1. Executive summary

The proposed game turns contiguous memory allocation into a spatial survival puzzle. Variable-size processes arrive with visible lifetimes and must be placed into a one-dimensional strip of memory. Completed processes release their cells, leaving gaps. The player must prevent allocation failures by anticipating lifetimes, managing fragmentation, and using limited compaction or cleanup actions.

The commercial opportunity is a legible, tactile game about fitting and timing—not a memory-management lesson. Its distinctive foundation is that total free space may be sufficient while no contiguous region is large enough, allowing players to understand fragmentation through play.

## 2. Customer problem and opportunity

Block-placement mobile games are familiar but often differ mainly in shape sets, themes, or scoring. Computer memory provides a less familiar rule system in which placement, lifetime, and future space interact. This creates strategic consequences that are not present in static packing puzzles.

The opportunity is to produce a calm but tense survival game with strong visual clarity, short sessions, and authentic systems behavior. The concept can appeal to general puzzle players while offering optional vocabulary and deeper allocation strategies for technical players.

## 3. Target audience

### Primary audiences

- Mobile spatial-puzzle players who enjoy planning and managing limited space.
- Strategy players seeking short sessions with meaningful future consequences.
- Existing portfolio players attracted to authentic mathematical or computational mechanics.

### Secondary audiences

- Students and educators exploring allocation, deallocation, fragmentation, and compaction.
- Programmers interested in optimization challenges and alternate allocator rules.

No player may be required to know terms such as heap, allocation, or fragmentation before beginning.

## 4. Product positioning

**Positioning statement:** For puzzle players who enjoy making limited space last, this game combines block placement with expiring processes, turning every gap into a future risk and every cleanup into a strategic cost.

### Product principles

1. The one-dimensional memory strip must remain visually distinct from falling tetromino games.
2. Process lifetime is as important as process size.
3. Allocation failure must be visually explainable.
4. Compaction is a costly strategic tool, not an automatic reset.
5. Technical terms may label mastered behavior but may not substitute for onboarding.

## 5. Goals and non-goals

### Goals

- Prove that fragmentation creates a satisfying and understandable survival loop.
- Support both authored scenarios and repeatable procedural runs.
- Create a visually marketable concept with clear before/after states.
- Encourage planning without requiring lengthy sessions.
- Support the portfolio's standard financial model (matching Modulo Squares): free-to-play with banner and interstitial advertising, plus a one-time purchase that removes all ads.

### Non-goals for MVP

- Accurately modeling a modern operating system or hardware memory manager.
- Teaching C/C++ allocation APIs or requiring code entry.
- Two-dimensional polyomino placement as the principal mechanic.
- Competitive multiplayer, player trading, live economies, or server-authoritative play.
- Simulating virtual memory, paging, multiple heaps, caches, and garbage collectors in the first release.

## 6. MVP product scope

The MVP must include:

- A one-dimensional memory strip divided into a fixed number of addressable cells.
- A queue of variable-size processes with visible or learnable lifetimes.
- Player-controlled selection of a valid contiguous allocation region.
- Automatic deallocation when a process completes, except for explicitly introduced leaks.
- A clear distinction between insufficient total space and external fragmentation.
- A limited compaction action with a visible cost in time, score, heat, or processing capacity.
- At least 36 authored scenarios across four mechanic chapters.
- One endless survival mode using deterministic seeded generation.
- Local progress, statistics, settings, and best scores.
- Account sign-in (Google or Apple) required before the first scenario; a complete experience thereafter that stays playable offline between sync points, with progress and leaderboard scores syncing to the cloud when connected.
- A global leaderboard for endless survival score, backed by cloud sync.

Virtual memory, multiple allocation algorithms, garbage-collection tracing, and daily challenges are post-MVP candidates.

## 7. Business requirements

| ID         | Requirement                                                                                                                    | Priority | Acceptance evidence                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------ | -------- | --------------------------------------------------------------- |
| MAS-BR-001 | The player shall understand valid and invalid contiguous placement through direct manipulation and visual feedback.            | Must     | At least 80% first-allocation success in usability tests        |
| MAS-BR-002 | Process size and expected lifetime shall both affect optimal placement.                                                        | Must     | Design analysis and playtest examples with divergent strategies |
| MAS-BR-003 | The game shall distinguish allocation failure caused by total capacity from failure caused by fragmentation.                   | Must     | Failure-state acceptance tests and comprehension results        |
| MAS-BR-004 | Compaction shall impose a meaningful, visible cost and shall not erase all strategic consequences.                             | Must     | Balance rules and player-choice telemetry                       |
| MAS-BR-005 | The MVP shall provide at least 36 authored scenarios and one endless survival mode.                                            | Must     | Content inventory and release build                             |
| MAS-BR-006 | Players shall sign in with Google or Apple before the first scenario; the signed-in session shall then support offline play with progress syncing when connectivity returns.                       | Must     | Sign-in and offline-sync end-to-end test                        |
| MAS-BR-007 | The commercial model shall be free-to-play with banner and interstitial advertising, plus a one-time purchase that removes all ads. | Must | Approved pricing configuration                                  |
| MAS-BR-008 | Technical overlays such as addresses, utilization, and fragmentation percentage shall be optional or progressively introduced. | Should   | UX and accessibility review                                     |
| MAS-BR-009 | The product shall use an original visual metaphor, UI, audio identity, content set, and store presentation.                    | Must     | Originality review and asset register                           |
| MAS-BR-010 | The final title and icon shall pass comprehensive clearance before announcement.                                               | Must     | Signed clearance checklist                                      |
| MAS-BR-011 | Production approval shall require evidence that non-programmers enjoy the loop without an educational prompt.                  | Must     | Discovery report covering at least 15 target players            |
| MAS-BR-012 | The game shall explain every failure from visible state and recent decisions.                                                  | Must     | Usability and state-reconstruction tests                        |
| MAS-BR-013 | Information shall not rely only on color, audio, fine motor precision, or rapid reading.                                       | Must     | Accessibility test report                                       |
| MAS-BR-014 | Store materials shall avoid claims of complete or professionally transferable memory-management training.                      | Must     | Store-listing review                                            |
| MAS-BR-015 | Free players shall see a persistent banner ad on every non-gameplay screen, including the pause overlay, and one interstitial ad when a scenario ends and the player returns to a non-gameplay screen. Ads shall never appear during active placement, shall never gate the start of a scenario, and shall never fire on ordinary menu navigation. | Must | Ad-placement review and playtest evidence |
| MAS-BR-016 | Logged-in players shall be able to view a global leaderboard and submit scores from endless survival score; paid (ad-removal) players retain full access. | Must | Leaderboard integration test |

## 8. Progression and content strategy

### Proposed chapters

1. **Allocate:** size, contiguous space, process completion, and released cells.
2. **Fragment:** mixed lifetimes and allocations that leave dangerous gaps.
3. **Compact:** limited space recovery with a visible operational cost.
4. **Leak:** processes that persist unexpectedly and force adaptation.

Authored scenarios should constrain the queue or objective to teach a single insight. Endless mode should vary request distributions and lifetime correlations rather than simply accelerate until touch input becomes impossible.

## 9. Monetization hypothesis

The game follows the portfolio's standard financial model, matching Modulo Squares: free-to-play with advertising, plus a one-time purchase that removes all ads.

- **Free tier:** the complete game, supported by a persistent banner ad (top of screen) on every non-gameplay screen — menu, scenario select, settings, results, and the pause overlay — plus one interstitial ad when a scenario ends and the player returns to a non-gameplay screen. Ads never appear during active placement, never gate the start of a scenario, and never fire on ordinary menu navigation.
- **Access tiers** (matching Modulo Squares): guest/unauthenticated players get no gameplay entry — sign-in is required before the first scenario. Logged-in free players get full gameplay plus leaderboard participation. Paid logged-in players get full gameplay with ads disabled. This is the default; a future guest mode would need its own local-progress and conversion rules defined before it could ship.
- **Ad removal:** a single one-time in-app purchase disables all ads permanently. This is the only purchase in the MVP.
- **Never monetized:** compaction actions, undos, favorable process queues, or scoring advantages. No consumable currencies or energy timers.
- Optional visual themes may be evaluated after launch but are never required to enjoy the free ad-supported experience.

Ad presentation must comply with Google Play and Apple App Store policies and applicable consent requirements (GDPR/UMP, App Tracking Transparency) before any regional rollout.

## 10. Success measures

- At least 80% of first-time usability participants complete the initial allocation unaided.
- At least 70% correctly explain one fragmentation failure in nontechnical language after onboarding.
- At least 60% of prototype participants voluntarily start a second run.
- At least 70% of players who start onboarding complete the first chapter.
- Crash-free sessions meet or exceed 99.5% during staged rollout.
- At least two meaningfully different placement strategies remain viable in representative mid-game scenarios.
- Paid conversion, completion, and retention are segmented by acquisition channel if a free sample is used.

## 11. Originality and IP gates

Before production approval, the team must:

- Refresh research covering memory-management teaching games, packing games, queue-management games, and inside-a-computer adventures.
- Maintain a feature-distance matrix covering board dimensionality, object lifetime, allocation control, failure rules, compaction, pacing, and presentation.
- Preserve the distinctive combination of one-dimensional contiguous placement, visible lifetime, and costly compaction.
- Avoid imitating the art direction, narrative premise, UI, or data-structure presentation of existing computer-themed games.
- Complete final title, logo, and store-metadata clearance.
- Seek patent advice if the frozen interaction model presents a credible concern.

## 12. Release decision

This candidate may advance only if prototype players understand fragmentation from the visual result and choose to replay for strategic improvement. If the experience is perceived primarily as static block fitting, the concept must be revised before production to strengthen process timing and the cost of compaction.
