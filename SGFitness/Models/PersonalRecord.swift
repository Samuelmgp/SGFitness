import Foundation
import SwiftData

// MARK: - PersonalRecord
// Stored personal record model. Replaces on-demand computation for
// top-3 podium ranking (gold/silver/bronze) and calendar PR indicators.
//
// Enum fields (recordType, medal) are backed by String raw storage to
// satisfy SwiftData — @Model classes cannot store non-trivial Codable enums
// directly as stored properties without using raw String backing.

@Model
final class PersonalRecord {
    @Attribute(.unique) var id: UUID

    /// Raw storage for PRRecordType enum.
    var recordTypeRaw: String

    /// Raw storage for PRMedal enum.
    var medalRaw: String

    /// Weight or volume in kilograms (strength only; nil for cardio).
    var valueKg: Double?

    /// Reps at max weight (maxWeight record type only).
    var reps: Int?

    /// Cardio bucket key — distance in meters (nil for strength records).
    var distanceMeters: Int?

    /// Fastest time in seconds (cardio only).
    var durationSeconds: Int?

    /// When this PR was achieved.
    var achievedAt: Date

    /// The exercise this PR belongs to. Nullified when definition is deleted.
    var exerciseDefinition: ExerciseDefinition?

    /// The session in which this PR was set. No inverse on WorkoutSession.
    @Relationship(deleteRule: .nullify)
    var workoutSession: WorkoutSession?

    // MARK: - Computed Wrappers

    var recordType: PRRecordType {
        get { PRRecordType(rawValue: recordTypeRaw) ?? .maxWeight }
        set { recordTypeRaw = newValue.rawValue }
    }

    var medal: PRMedal {
        get { PRMedal(rawValue: medalRaw) ?? .gold }
        set { medalRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        recordType: PRRecordType,
        medal: PRMedal,
        valueKg: Double? = nil,
        reps: Int? = nil,
        distanceMeters: Int? = nil,
        durationSeconds: Int? = nil,
        achievedAt: Date,
        exerciseDefinition: ExerciseDefinition? = nil,
        workoutSession: WorkoutSession? = nil
    ) {
        self.id = id
        self.recordTypeRaw = recordType.rawValue
        self.medalRaw = medal.rawValue
        self.valueKg = valueKg
        self.reps = reps
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.achievedAt = achievedAt
        self.exerciseDefinition = exerciseDefinition
        self.workoutSession = workoutSession
    }
}
