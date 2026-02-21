# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
xcodebuild -scheme SGFitness -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- Deployment target: iOS 26.2, Simulator: iPhone 17 Pro
- No test targets, linting, or CI/CD exist in this project

## Architecture

SwiftUI + SwiftData app using MVVM. Single-user fitness tracker with workout templates, active workout logging, workout history, and personal records.

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
- All weights stored in **kilograms** internally. `WeightUnit` enum converts at the view layer via `toKilograms()` / `fromKilograms()`. **Never store converted values.**
- SwiftData relationship arrays have **no guaranteed order** — always sort by the `order: Int` field present on ordered models.
- `nil` weight on `PerformedSet` or `SetGoal` means bodyweight exercise.

**Field notes:**
- `ExerciseDefinition.exerciseType: String` — `"strength"` (default) or `"cardio"`. Seeded exercises are all strength.
- `PerformedSet.durationSeconds: Int?` — nil for strength sets; for cardio: `reps` = distance in meters, `durationSeconds` = elapsed time.
- `SetGoal.targetDurationSeconds: Int?` — mirrors PerformedSet for template cardio goals.
- `ExerciseDefinition.muscleGroup` — nil for cardio exercises (no muscle group association).

### ViewModels (`SGFitness/ViewModels/`)

All ViewModels use `@Observable` (Observation framework), **not** `ObservableObject`. Views bind with `@Bindable var viewModel:`.

**Key VMs:**
- `ActiveWorkoutViewModel` — live workout session; PR detection; manual entry mode; `saveAsTemplate()`
- `TemplateEditorViewModel` — create/edit templates with buffered fields + `exercisesModified` flag
- `ExercisePickerViewModel` — catalog search + recently used; `createCustomExercise()` + `updateExercise()` accept `exerciseType`
- `PRsViewModel` — computes PRs on-demand from session data (no stored PersonalRecord model)
- `YearGridViewModel` — history calendar; has `prDates: Set<Date>` for PR day indicators
- `TemplateListViewModel`, `WorkoutHistoryViewModel`, `WorkoutDetailViewModel`

**Patterns:**
- `@ObservationIgnored` on Timer properties and PR baseline dicts to prevent spurious view updates
- `refreshCounter: Int` trick to force view invalidation when SwiftData relationship mutations don't trigger `@Observable`
- Explicit `modelContext.save()` after batch operations; rely on auto-save for individual mutations
- **ViewModel stability in sheets**: always store sheet VMs as `@State private var vm: SomeVM?` on the parent view and initialize only on button tap. Never create them inline in a sheet closure — the parent view may re-render frequently (e.g. the active workout timer ticks every second), which would recreate the VM and wipe its state.

### Views (`SGFitness/Views/`)

- `ContentView.swift` — Root TabView (Home, Templates, History, Profile), user bootstrapping, data seeding, onboarding sheet. Workout lifecycle: `startFromTemplate()`, `startAdHoc()`, `logWorkout()` (manual entry).
- `bootstrapUser()` runs once on first launch: creates User, seeds 27 exercises across 6 muscle groups, creates 3 example templates.
- Active workout presented via `.fullScreenCover`; exercise picker via `.sheet`.
- Navigation uses `NavigationStack` + `NavigationLink(value:)` + `.navigationDestination(for:)`.
- Input for reps/weight uses SwiftUI `.alert` with `TextField`.
- Empty states use `ContentUnavailableView`.

**HomeView** — 3 action buttons:
1. "Record Workout" → template picker sheet → `startFromTemplate()`
2. "Start from Scratch" → `startAdHoc()` (live timer)
3. "Log a Workout" → `logWorkout()` (manual entry, no timer)

**ActiveWorkoutView** — ellipsis menu: Finish Workout / Save as Template / Discard Workout. In manual entry mode (`viewModel.isManualEntry`), the timer shows `--:--` and Finish Workout prompts for duration in minutes.

**ExerciseCardView / SetCircleRow** — accept `weightUnit: WeightUnit` parameter. Always pass `viewModel.preferredWeightUnit` from `ActiveWorkoutViewModel`. Display values are converted from kg using `fromKilograms()`; user input is converted to kg using `toKilograms()` before passing to the VM.

**ProfileView** — has "Library" section with links to Personal Records and Exercise Library.

### Naming Clash — ExerciseDetailView

There are **two different** detail views:
- `Views/TemplateManagement/ExerciseDetailView.swift` → `struct ExerciseDetailView` — edits an `ExerciseTemplate` within a template
- `Views/ExerciseLibrary/ExerciseDefinitionDetailView.swift` → `struct ExerciseDefinitionDetailView` — displays an `ExerciseDefinition` with PR history

**Do not** rename or create a new `ExerciseDetailView` — the name collision causes a build error ("Multiple commands produce ExerciseDetailView.stringsdata").

### Personal Records

PRs are **computed on-demand** from existing `ExerciseSession`/`PerformedSet` data — there is no stored `PersonalRecord` model.

- `PRsViewModel` scans completed sessions per `ExerciseDefinition`.
- Strength PRs: max weight (`maxWeightKg`), best session volume (`bestVolumeKg`).
- Cardio PRs: keyed by distance in meters → best time in seconds (`CardioRecord`).
- `ActiveWorkoutViewModel` caches pre-workout baselines in `prBaselines: [UUID: PRBaseline]` (marked `@ObservationIgnored`). After each set, `checkForPR()` compares against baseline and sets `latestPRAlert` if beaten.
- `ActiveWorkoutView` observes `latestPRAlert` and shows a 3-second animated banner, then calls `viewModel.clearPRAlert()`.
- `YearGridViewModel.prDates` marks days where a new PR weight was set (strength only); displayed as a yellow border on the calendar day cell.

### Cardio Exercises

- `ExerciseDefinition.exerciseType == "cardio"` — no muscle group, no equipment.
- `PerformedSet`: `reps` = distance in meters, `durationSeconds` = elapsed time, `weight` = nil.
- `ExerciseCardView` detects cardio via `exercise.exerciseDefinition?.exerciseType == "cardio"` and shows distance/time columns instead of reps/weight.
- `ActiveWorkoutViewModel.logSet(exerciseIndex:distanceMeters:durationSeconds:)` — cardio overload.
- `ExerciseEditorView` hides muscle group picker when type is "Cardio".

### Manual Entry Workout

When the user taps "Log a Workout", `ContentView` calls `vm.startManualEntry(name:)` which:
- Creates the session without starting the elapsed timer.
- Sets `isManualEntry = true`.

On finish, `finishWorkout(manualDurationMinutes:)` sets `completedAt = startedAt + duration` so history shows the correct elapsed time.

### Save as Template

`ActiveWorkoutViewModel.saveAsTemplate()` creates a `WorkoutTemplate` from the current session's exercises and completed sets, preserving `ExerciseDefinition` links and rest seconds. Available from the ellipsis menu in `ActiveWorkoutView`.

## Build Settings to Know

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor`
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — any file calling `modelContext.save()` must have `import SwiftData`
- Xcode project uses `objectVersion 77` (filesystem-synced) — new source files are automatically picked up but **may need adding to `membershipExceptions`** in the project file (`SGFitness.xcodeproj/project.pbxproj`) to avoid "no such module" or missing-file build errors

## Key File Map

```
SGFitness/
  Models/
    ExerciseDefinition.swift    — exerciseType ("strength"|"cardio"), muscleGroup (nil for cardio)
    PerformedSet.swift          — durationSeconds (cardio), weight in kg
    SetGoal.swift               — targetDurationSeconds
    WorkoutSession.swift
    WorkoutTemplate.swift
  ViewModels/
    ActiveWorkoutViewModel.swift — live session, PR detection, manual entry, saveAsTemplate
    PRsViewModel.swift           — on-demand PR computation
    ExercisePickerViewModel.swift — catalog + search + createCustomExercise(exerciseType:)
    TemplateEditorViewModel.swift
    YearGridViewModel.swift      — prDates: Set<Date>
  Views/
    ContentView.swift            — root TabView, bootstrapUser, workout lifecycle
    HomeView.swift               — 3 buttons: Record/Scratch/Log
    ActiveWorkout/
      ActiveWorkoutView.swift    — fullScreenCover, PR banner, manual duration alert
      ExerciseRowView.swift      — ExerciseCardView(weightUnit:), SetCircleRow(weightUnit:)
    ExerciseLibrary/
      ExerciseLibraryView.swift  — navigates to ExerciseDefinitionDetailView
      ExerciseDefinitionDetailView.swift — PR history + recent sessions
      ExerciseEditorView.swift   — type picker; muscle group hidden for cardio
    PersonalRecords/
      PersonalRecordsView.swift  — all-time PRs grouped by muscle group
    TemplateManagement/
      ExerciseDetailView.swift   — edits ExerciseTemplate (NOT ExerciseDefinition)
      TemplateEditorView.swift
    WorkoutHistory/
      YearGridView.swift         — yellow border on PR days
      YearGridViewModel.swift
    ProfileView.swift            — Library section: Personal Records + Exercise Library
```
