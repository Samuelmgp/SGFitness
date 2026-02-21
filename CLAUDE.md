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
- `User.heightMeters: Double?` — stored in metres regardless of display preference.
- `User.bodyWeightKg: Double?` — stored in kg regardless of display preference.
- `User.targetWorkoutDaysPerWeek: Int?` — nil = no goal; drives calendar missed-day threshold via `ceil(7/freq)`.
- `User.targetWorkoutMinutes: Int?` — nil = no goal; set as default `targetDurationMinutes` on new sessions.

### ViewModels (`SGFitness/ViewModels/`)

All ViewModels use `@Observable` (Observation framework), **not** `ObservableObject`. Views bind with `@Bindable var viewModel:`.

**Key VMs:**
- `ActiveWorkoutViewModel` — live workout session; PR detection; manual entry mode; `saveAsTemplate()`; `uncompleteSet()`
- `TemplateEditorViewModel` — create/edit templates with buffered fields + `exercisesModified` flag
- `ExercisePickerViewModel` — catalog search + recently used; `createCustomExercise()` + `updateExercise()` accept `exerciseType`
- `PRsViewModel` — computes PRs on-demand from session data (no stored PersonalRecord model)
- `YearGridViewModel` — history calendar; `prDates: Set<Date>` for PR day indicators; missed-day threshold driven by `User.targetWorkoutDaysPerWeek`
- `TemplateListViewModel`, `WorkoutHistoryViewModel`, `WorkoutDetailViewModel`

**Patterns:**
- `@ObservationIgnored` on Timer properties and PR baseline dicts to prevent spurious view updates
- `refreshCounter: Int` trick to force view invalidation when SwiftData relationship mutations don't trigger `@Observable`
- Explicit `modelContext.save()` after batch operations; rely on auto-save for individual mutations
- **ViewModel stability in sheets**: always store sheet VMs as `@State private var vm: SomeVM?` on the parent view and initialize only on button tap. Never create them inline in a sheet closure — the parent view may re-render frequently (e.g. the active workout timer ticks every second), which would recreate the VM and wipe its state.

### Views (`SGFitness/Views/`)

- `ContentView.swift` — Root TabView (Home, Templates, History, Profile), user bootstrapping, data seeding, onboarding sheet. Workout lifecycle: `startFromTemplate()`, `startAdHoc()`, `logWorkout()` (manual entry), `logWorkoutFromTemplate()`.
- `bootstrapUser()` runs once on first launch: creates User, seeds 27 exercises across 6 muscle groups, creates 3 example templates.
- Active workout presented via `.fullScreenCover`; exercise picker via `.sheet`.
- Navigation uses `NavigationStack` + `NavigationLink(value:)` + `.navigationDestination(for:)`.
- Input for reps/weight uses SwiftUI `.alert` with `TextField`.
- Empty states use `ContentUnavailableView`.

**HomeView** — 3 action buttons:
1. "Record Workout" → `RecordWorkoutTemplatePickerSheet` (modal with Cancel) → `startFromTemplate()`
2. "Start from Scratch" → `startAdHoc()` (live timer)
3. "Log a Workout" → `LogWorkoutSetupSheet` (single sheet with internal `NavigationStack`):
   - Form root: optional template selector (NavigationLink pushes `LogTemplatePickerView`) + date + name (name hidden when template selected)
   - On Continue: dismiss sheet + 0.3 s delay → `onLogWorkoutFromTemplate` or `onLogWorkout`

**ActiveWorkoutViewModel — manual entry from template** (`startManualEntryFromTemplate(_:name:startedAt:)`):
- Copies exercises + set goals from template, creating `PerformedSet` with `isCompleted: true` and `completedAt: startedAt`.
- Sets `isManualEntry = true`; no elapsed timer; no PR baselines loaded.
- `uncompleteSet(_ set:)` — clears `isCompleted` and `completedAt` on a previously completed set.

**ActiveWorkoutView** — ellipsis menu: Finish Workout / Save as Template / Discard Workout. In manual entry mode (`viewModel.isManualEntry`), the timer shows `--:--` and Finish Workout opens a half-sheet with side-by-side Hours/Minutes wheel pickers. Save as Template also opens a half-sheet with the same wheel picker for duration.

**ExerciseCardView / SetCircleRow** — accept `weightUnit`, `onRemoveSet`, `onDeselectSet` parameters.
- Circle button tap: completed set → `onDeselectSet`; incomplete set → `onComplete` with current values.
- Long-press: opens edit alert for **both** complete and incomplete sets. Alert title = "Edit Set" / "Edit & Complete"; button = "Save" / "Complete".
- Swipe left (when `onRemoveSet` provided): reveals a red Delete button via `DragGesture(minimumDistance: 20)` registered with `.simultaneousGesture` (avoids consuming vertical scroll).
- All sets start pre-completed in "Log from Template" mode (unique to that flow).

**Weight unit propagation in template editor:**
- `TemplateListView` → `TemplateEditorView(weightUnit:)` → `ExerciseDetailView(weightUnit:)` / `ExerciseConfigView(weightUnit:)`
- All weight inputs go through `weightUnit.toKilograms()` before saving; display uses `weightUnit.fromKilograms()`.

**ProfileView** — "Settings" section (name, weight unit), "Goals" section (weekly target + session duration, tap-to-edit half-sheets), "Body Measurements" section (height + body weight display with edit sheet using wheel pickers), "Stats" section, "Library" section (Personal Records, Exercise Library).

**OnboardingView** — first-launch sheet. Collects name, weight unit, height (metric: single cm wheel 100–250; imperial: ft 4–7 + in 0–11 side-by-side wheels), body weight (TextField), and workout goals (frequency 1–7 days/week wheel + segmented duration picker). All optional except name.

### Exercise Icons

Every exercise in lists and cards now shows a coloured icon badge (muscle-group symbol on a tinted rounded-square background).

**`MuscleGroup`** (imports SwiftUI) has two display properties:
- `sfSymbol: String` — per-group SF Symbol name:
  - chest: `figure.strengthtraining.traditional`, back: `figure.rowing`, legs: `figure.run`
  - shoulders: `figure.handball`, arms: `figure.boxing`, core: `figure.core.training`
- `color: Color` — accent colour (blue / green / orange / purple / red / amber)

**`ExerciseType.sfSymbol`**: strength = `"dumbbell.fill"`, cardio = `"figure.run"`.

Icon badge pattern used consistently in `ExercisePickerView`, `ExerciseLibraryView`, `TemplateEditorView`, and `ExerciseCardView` (active workout header):
```swift
ZStack {
    RoundedRectangle(cornerRadius: 7/8)
        .fill(iconColor.opacity(0.15))
        .frame(width: 32/38, height: 32/38)
    Image(systemName: iconSymbol)
        .font(.system(size: 15/18, weight: .medium))
        .foregroundStyle(iconColor)
}
```
Fallback chain: `muscleGroup?.sfSymbol ?? exerciseType.sfSymbol ?? "dumbbell"`.

### App Icon

`SGFitness/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` — 1024×1024 px PNG.
- Dark navy→indigo gradient background, large white `dumbbell.fill` centred slightly above mid, smaller `note.text` symbol lower-right at 50 % opacity.
- `Contents.json` references this file for all three idioms (default, dark, tinted).

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

When the user taps "Log a Workout", `ContentView` calls `vm.startManualEntry(name:startedAt:)` which:
- Creates the session without starting the elapsed timer.
- Sets `isManualEntry = true`.

When a template is selected, `vm.startManualEntryFromTemplate(_:name:startedAt:)` is called instead — all sets are pre-marked completed.

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
  Assets.xcassets/
    AppIcon.appiconset/
      AppIcon-1024.png            — 1024×1024 app icon (dumbbell + notepad, dark gradient)
  Models/
    ExerciseDefinition.swift      — exerciseType ("strength"|"cardio"), muscleGroup (nil for cardio)
    ExerciseType.swift            — sfSymbol: strength="dumbbell.fill", cardio="figure.run"
    MuscleGroup.swift             — sfSymbol + color per group (imports SwiftUI)
    PerformedSet.swift            — durationSeconds (cardio), weight in kg
    SetGoal.swift                 — targetDurationSeconds
    User.swift                    — targetWorkoutDaysPerWeek, targetWorkoutMinutes (goals)
    WorkoutSession.swift
    WorkoutTemplate.swift
  ViewModels/
    ActiveWorkoutViewModel.swift  — live session, PR detection, manual entry, saveAsTemplate, uncompleteSet
    PRsViewModel.swift            — on-demand PR computation
    ExercisePickerViewModel.swift — catalog + search + createCustomExercise(exerciseType:)
    TemplateEditorViewModel.swift
    YearGridViewModel.swift       — prDates: Set<Date>; missed threshold from User.targetWorkoutDaysPerWeek
  Views/
    ContentView.swift             — root TabView, bootstrapUser, workout lifecycle (+ logWorkoutFromTemplate)
    HomeView.swift                — Record/Scratch/Log buttons; LogWorkoutSetupSheet (single sheet + NavStack)
    ActiveWorkout/
      ActiveWorkoutView.swift     — fullScreenCover, PR banner, manual duration alert
      ExerciseRowView.swift       — ExerciseCardView(onRemoveSet:onDeselectSet:), SetCircleRow with swipe+deselect
    ExerciseLibrary/
      ExerciseLibraryView.swift   — coloured icon badge per row; navigates to ExerciseDefinitionDetailView
      ExerciseDefinitionDetailView.swift — PR history + recent sessions; chip uses muscleGroup.sfSymbol
      ExerciseEditorView.swift    — type picker; muscle group hidden for cardio
    PersonalRecords/
      PersonalRecordsView.swift   — all-time PRs grouped by muscle group
    Shared/
      ExercisePickerView.swift    — coloured icon badge per row
    TemplateManagement/
      ExerciseDetailView.swift    — edits ExerciseTemplate (NOT ExerciseDefinition); weightUnit param
      TemplateEditorView.swift    — coloured icon badge per exercise row; weightUnit param
      ExerciseConfigView.swift    — weightUnit param; converts input via toKilograms()
      TemplateListView.swift      — passes weightUnit to TemplateEditorView
    WorkoutHistory/
      YearGridView.swift          — yellow border on PR days
      YearGridViewModel.swift
    ProfileView.swift             — Settings, Goals (edit sheet), Body Measurements, Stats, Library sections
    OnboardingView.swift          — name, unit, height (wheel pickers), body weight, workout goals
```
