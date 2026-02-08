# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
xcodebuild -scheme SGFitness -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- Deployment target: iOS 26.2, Simulator: iPhone 17 Pro
- No test targets, linting, or CI/CD exist in this project

## Architecture

SwiftUI + SwiftData app using MVVM. Single-user fitness tracker with workout templates, active workout logging, and workout history.

### Data Layer (SwiftData Models in `SGFitness/Models/`)

All models use `@Model` with `@Attribute(.unique) var id: UUID`.

**Relationship graph:**
```
User ──< WorkoutTemplate ──< ExerciseTemplate ──< SetGoal
User ──< WorkoutSession  ──< ExerciseSession  ──< PerformedSet
User ──< BadgeAward >── Badge
ExerciseDefinition >──< ExerciseTemplate (nullify)
ExerciseDefinition >──< ExerciseSession (nullify)
WorkoutSession >── WorkoutTemplate (nullify — deleting template preserves history)
```

**Critical rules:**
- All weights stored in **kilograms** internally. `WeightUnit` enum converts at the view layer via `toKilograms()` / `fromKilograms()`. Never store converted values.
- SwiftData relationship arrays have **no guaranteed order** — always sort by the `order: Int` field present on ordered models.
- `nil` weight on `PerformedSet` or `SetGoal` means bodyweight exercise.

### ViewModels (`SGFitness/ViewModels/`)

All ViewModels use `@Observable` (Observation framework), **not** `ObservableObject`. Views bind with `@Bindable var viewModel:`.

Key VMs: `ActiveWorkoutViewModel` (live workout session), `TemplateEditorViewModel` (create/edit templates with buffered fields), `ExercisePickerViewModel` (catalog search + recently used), `TemplateListViewModel`, `WorkoutHistoryViewModel`, `WorkoutDetailViewModel`.

**Patterns:**
- `@ObservationIgnored` on Timer properties to prevent spurious view updates
- `refreshCounter: Int` trick to force view invalidation when SwiftData relationship mutations don't trigger `@Observable`
- Explicit `modelContext.save()` after batch operations; rely on auto-save for individual mutations

### Views (`SGFitness/Views/`)

- `ContentView.swift` — Root TabView (Workout, Templates, History, Profile), user bootstrapping, data seeding, onboarding sheet
- `bootstrapUser()` runs once on first launch: creates User, seeds 27 exercises across 6 muscle groups, creates 3 example templates
- Active workout presented via `.fullScreenCover`; exercise picker via `.sheet`
- Navigation uses `NavigationStack` + `NavigationLink(value:)` + `.navigationDestination(for:)`
- Input for reps/weight uses SwiftUI `.alert` with `TextField`
- Empty states use `ContentUnavailableView`

## Build Settings to Know

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor`
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — any file calling `modelContext.save()` must have `import SwiftData`
- Xcode project uses `objectVersion 77` (filesystem-synced) — new source files are automatically picked up but may need adding to `membershipExceptions` in the project file
