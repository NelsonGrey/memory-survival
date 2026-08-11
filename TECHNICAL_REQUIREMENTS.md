# Memory-Allocation Survival — Technical Requirements

**Document type:** Technical Requirements Document (TRD)  
**Version:** 0.1  
**Status:** Proposed / architecture discovery  
**Last updated:** August 11, 2026  
**Owner:** Mark Nelson

Related document: [Business Requirements](./BUSINESS_REQUIREMENTS.md)  
Portfolio context: [Requirements Index](../../PORTFOLIO_REQUIREMENTS_INDEX.md)

## 1. Purpose

This document specifies the deterministic simulation and mobile-client capabilities required for the memory-allocation survival concept. The system must make capacity, contiguity, lifetime, fragmentation, deallocation, and compaction accurate within the game's declared simplified model.

## 2. System scope

### MVP components

- Cross-platform iOS and Android client.
- Deterministic one-dimensional memory simulation.
- Authored scenario loader and validator.
- Seeded endless-run generator.
- Placement, preview, compaction, scoring, and failure systems.
- Local progression, settings, statistics, and save migrations.
- Accessible presentation, audio, and haptics.
- Optional privacy-minimized analytics and crash reporting.
- Store purchase support only if the free-sample model is selected.

### Excluded from MVP

- Required backend, cloud saves, accounts, leaderboards, multiplayer, user-generated content, virtual memory, paging, real garbage collectors, or executable code.

## 3. Core simulation

### 3.1 Memory model

The authoritative model shall represent a fixed ordered address space:

```text
MemoryState
  cellCount: positive integer
  cells: ordered collection of free or process-owned cells
  processes: active process records
  requestQueue: ordered pending allocation requests
  cycle: monotonic simulation tick
  compactionState: availability, cost, and active movement
  scoreState: survival, utilization, combo, objectives
  seed: deterministic generator seed
  eventHistory: allocations, releases, moves, failures
```

Every active process shall have a stable instance ID, requested size, start address, remaining lifetime, type, release policy, and optional special behavior. A process allocation must occupy exactly one contiguous cell range.

### 3.2 Allocation rules

- The player shall select the start address of a request or choose among clearly identified valid gaps.
- A placement is valid only when every required cell is free and inside the address space.
- The engine shall calculate total free cells, largest free block, number of free blocks, utilization, and external-fragmentation indicator from authoritative state.
- A request failure shall be classified as insufficient total capacity, insufficient contiguous capacity, deadline expiry, or another explicitly declared scenario rule.
- Deallocation shall occur on a deterministic simulation boundary after lifetime completion.

### 3.3 Compaction

Compaction must have a declared ordering and cost. The MVP default should preserve process order while moving active processes toward the lowest address. Content may define whether simulation time advances during compaction, whether incoming requests wait, and whether certain pinned or leaking processes cannot move.

Animations shall visualize already-decided movement and may not determine final addresses.

### 3.4 Leaks

A leaking process is an explicit game object whose release policy differs from a normal process. The UI must distinguish an intentional game rule from a software defect. Leak behavior must be content-defined and deterministic.

## 4. Content model

Every authored scenario shall define:

- Stable scenario ID and schema version.
- Cell count and initial allocations.
- Request sequence or seeded distribution.
- Process sizes, lifetimes, deadlines, and special behaviors.
- Compaction availability and cost.
- Success, failure, scoring, and star/medal conditions.
- Tutorial prompts and accessible descriptions.
- Reference solution or machine-verified solvability evidence.

CI validation must reject overlaps, invalid ranges, orphaned process ownership, impossible sizes, duplicate IDs, unsupported behaviors, and scenarios that violate declared solvability requirements.

## 5. Input and presentation

- Players shall be able to drag a process preview into a gap or select the process and then a valid region.
- A tap-only alternative shall be available for all drag actions.
- Placement preview shall show exact occupied cells, validity, and the reason an invalid placement fails.
- Free regions, allocated regions, remaining lifetime, pinned state, and leaks must remain distinguishable without color.
- Address labels and advanced metrics shall scale or collapse without obscuring core play.
- Reduced-motion mode shall replace block-travel animations with concise before/after transitions.
- Audio, haptics, and animation timing shall not affect the simulation result.

## 6. Architecture requirements

The client shall isolate the domain simulation from rendering, content, persistence, analytics, purchases, and platform lifecycle. The simulation shall be runnable without a UI and shall expose state snapshots suitable for tests and failure explanations.

Random request generation shall use a versioned pseudo-random algorithm and stored seed. A ruleset version shall be stored with every best score so balance changes do not silently compare incompatible runs.

## 7. Technical requirements

| ID         | Requirement                                                                                                                           | Maps to                |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| MAS-TR-001 | Identical state, seed, ruleset, tick sequence, and player actions shall produce identical allocations, releases, failures, and score. | MAS-BR-002, MAS-BR-012 |
| MAS-TR-002 | The engine shall enforce single-range contiguous ownership for every active process.                                                  | MAS-BR-001, MAS-BR-003 |
| MAS-TR-003 | Capacity and fragmentation failures shall be separately classified and presented.                                                     | MAS-BR-003, MAS-BR-012 |
| MAS-TR-004 | Compaction shall be simulated as a documented deterministic transition with configurable cost.                                        | MAS-BR-004             |
| MAS-TR-005 | Authored scenarios shall be schema validated and solvability checked before packaging.                                                | MAS-BR-005             |
| MAS-TR-006 | Endless runs shall be reproducible from seed and ruleset version.                                                                     | MAS-BR-005             |
| MAS-TR-007 | Core play and purchased content shall function offline after entitlement caching.                                                     | MAS-BR-006, MAS-BR-007 |
| MAS-TR-008 | Save writes shall be atomic and data migrations versioned and tested.                                                                 | MAS-BR-005             |
| MAS-TR-009 | All drag actions shall have tap-only equivalents, and status shall not rely exclusively on color, sound, motion, or fine text.        | MAS-BR-013             |
| MAS-TR-010 | The renderer shall sustain 60 frames per second on baseline devices while simulation is frame-rate independent.                       | MAS-BR-001             |
| MAS-TR-011 | Cold launch to an interactive local menu shall target three seconds or less on baseline devices.                                      | MAS-BR-001             |
| MAS-TR-012 | Analytics shall avoid personally identifying data and shall never include a raw device interaction recording by default.              | MAS-BR-011             |
| MAS-TR-013 | Every third-party dependency and asset shall have retained provenance and license metadata.                                           | MAS-BR-009             |
| MAS-TR-014 | Purchase failure, cancellation, restore, pending status, and offline entitlement shall not corrupt progression.                       | MAS-BR-007             |

## 8. Scoring and balance

The scoring model must reward survival and intentional space management without making a single utilization metric dominant. Candidate components include completed process work, consecutive accepted requests, remaining largest-free-block size, limited compaction, and scenario objectives.

Balance simulations shall evaluate representative placement policies and random agents. Procedural generation must not produce an unavoidable failure unless the mode explicitly declares that every run eventually ends and the generated prefix meets a minimum fairness rule.

## 9. Persistence and interruption

The game shall persist progression, settings, statistics, entitlement state, best scores with ruleset versions, and an interrupted-run snapshot if resumption is supported. Backgrounding must pause or advance simulation according to an explicit mode policy; it may not silently consume process lifetimes while the player cannot interact.

## 10. Telemetry

The minimum event catalog should include:

- Scenario or run started/completed/failed.
- Allocation size, gap size band, and placement outcome.
- Failure category: capacity, fragmentation, deadline, or rule-specific.
- Compaction offered/used and summarized result.
- Tutorial step outcome.
- Endless-run score and duration bands.
- Purchase outcome if applicable.
- Accessibility setting enabled.

Telemetry shall use aggregate numeric or enum fields rather than process names or user-entered text.

## 11. Testing strategy

- Unit tests for allocation, deallocation, compaction, leaks, metrics, deadlines, and failure classification.
- Property tests asserting no overlapping ownership, size conservation, valid address ranges, and compaction order.
- Deterministic replay tests across supported platforms.
- Content-schema, overlap, and solvability validation.
- Generator simulations across large seed samples to detect impossible early sequences and dominant policies.
- Golden tests at supported sizes, orientations, themes, and text scales.
- Integration tests for interruption, restore, migration, offline play, and purchase states.
- Accessibility and device-performance testing across the approved matrix.

## 12. Release gates

- Zero known severity-one gameplay, purchase, save-loss, or accessibility defects.
- All packaged scenarios valid and solvable according to their declared rules.
- No allocation-overlap or state-conservation failure across automated simulation runs.
- Generator fairness thresholds approved from recorded simulations.
- Performance and cold-launch targets met on baseline devices.
- Crash-free staged rollout meets the business target.
- Dependency, asset-license, privacy, analytics, and store-purchase audits complete.
