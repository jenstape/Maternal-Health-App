// Hospital.swift
// Core data model for hospitals in the iOS app

import Foundation
import CoreLocation

// MARK: - Hospital Model
struct Hospital: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let latitude: Double
    let longitude: Double
    let phone: String?
    let website: String?

    // Quality Metrics
    let maternalMortalityRate: Double?
    let blackMaternalMortalityRate: Double?
    let cSectionRate: Double?
    let blackCSectionRate: Double?
    let patientSatisfactionScore: Double?
    let overallRating: Double?

    // Staff & Services
    let hasNICU: Bool
    let hasLevelIIINICU: Bool
    let blackOBGYNCount: Int?
    let totalOBGYNCount: Int?
    let doulaAccessible: Bool
    let birthPlanFriendly: Bool

    // Community Data
    let reviewCount: Int
    let averageReview: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var fullAddress: String {
        "\(address), \(city), \(state) \(zipCode)"
    }

    var staffDiversityScore: Double? {
        guard let black = blackOBGYNCount,
              let total = totalOBGYNCount,
              total > 0 else { return nil }
        return Double(black) / Double(total) * 100
    }

    var blackMortalityRatio: Double? {
        guard let blackRate = blackMaternalMortalityRate,
              let overallRate = maternalMortalityRate,
              overallRate > 0 else { return nil }
        return blackRate / overallRate
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, city, state, phone, website
        case zipCode = "zip_code"
        case latitude, longitude
        case maternalMortalityRate = "maternal_mortality_rate"
        case blackMaternalMortalityRate = "black_maternal_mortality_rate"
        case cSectionRate = "c_section_rate"
        case blackCSectionRate = "black_c_section_rate"
        case patientSatisfactionScore = "patient_satisfaction_score"
        case overallRating = "overall_rating"
        case hasNICU = "has_nicu"
        case hasLevelIIINICU = "has_level_iii_nicu"
        case blackOBGYNCount = "black_obgyn_count"
        case totalOBGYNCount = "total_obgyn_count"
        case doulaAccessible = "doula_accessible"
        case birthPlanFriendly = "birth_plan_friendly"
        case reviewCount = "review_count"
        case averageReview = "average_review"
    }
}

// MARK: - Hospital Search Response
struct HospitalSearchResponse: Codable {
    let hospitals: [HospitalWithDistance]
    let total: Int
}

struct HospitalWithDistance: Codable, Identifiable {
    let hospital: Hospital
    let distanceMiles: Double

    var id: String { hospital.id }

    enum CodingKeys: String, CodingKey {
        case hospital
        case distanceMiles = "distance_miles"
    }
}

// MARK: - Mock Data for Development
extension Hospital {
    static let mockHospitals: [Hospital] = [
        Hospital(
            id: "1",
            name: "Emory University Hospital Midtown",
            address: "550 Peachtree St NE",
            city: "Atlanta",
            state: "GA",
            zipCode: "30308",
            latitude: 33.7711,
            longitude: -84.3858,
            phone: "(404) 686-4411",
            website: "https://www.emoryhealthcare.org",
            maternalMortalityRate: 12.5,
            blackMaternalMortalityRate: 18.2,
            cSectionRate: 28.5,
            blackCSectionRate: 32.1,
            patientSatisfactionScore: 4.3,
            overallRating: 4.5,
            hasNICU: true,
            hasLevelIIINICU: true,
            blackOBGYNCount: 8,
            totalOBGYNCount: 25,
            doulaAccessible: true,
            birthPlanFriendly: true,
            reviewCount: 127,
            averageReview: 4.4
        ),
        Hospital(
            id: "2",
            name: "Grady Memorial Hospital",
            address: "80 Jesse Hill Jr Dr SE",
            city: "Atlanta",
            state: "GA",
            zipCode: "30303",
            latitude: 33.7522,
            longitude: -84.3769,
            phone: "(404) 616-1000",
            website: "https://www.gradyhealth.org",
            maternalMortalityRate: 15.8,
            blackMaternalMortalityRate: 22.4,
            cSectionRate: 31.2,
            blackCSectionRate: 35.7,
            patientSatisfactionScore: 3.9,
            overallRating: 4.0,
            hasNICU: true,
            hasLevelIIINICU: true,
            blackOBGYNCount: 12,
            totalOBGYNCount: 30,
            doulaAccessible: true,
            birthPlanFriendly: true,
            reviewCount: 89,
            averageReview: 4.1
        ),
        Hospital(
            id: "3",
            name: "Piedmont Atlanta Hospital",
            address: "1968 Peachtree Rd NW",
            city: "Atlanta",
            state: "GA",
            zipCode: "30309",
            latitude: 33.8104,
            longitude: -84.3855,
            phone: "(404) 605-5000",
            website: "https://www.piedmont.org",
            maternalMortalityRate: 10.2,
            blackMaternalMortalityRate: 14.6,
            cSectionRate: 26.8,
            blackCSectionRate: 28.9,
            patientSatisfactionScore: 4.5,
            overallRating: 4.7,
            hasNICU: true,
            hasLevelIIINICU: false,
            blackOBGYNCount: 5,
            totalOBGYNCount: 22,
            doulaAccessible: false,
            birthPlanFriendly: true,
            reviewCount: 156,
            averageReview: 4.6
        )
    ]
}

// MARK: - Review Model
struct Review: Identifiable, Codable {
    let id: String
    let hospitalId: String
    let userId: String?
    let userName: String?

    let rating: Int // 1-5
    let title: String
    let content: String

    let culturalCompetencyRating: Int?
    let painManagementRating: Int?
    let communicationRating: Int?
    let respectfulCareRating: Int?

    let isVerified: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content, rating
        case hospitalId = "hospital_id"
        case userId = "user_id"
        case userName = "user_name"
        case culturalCompetencyRating = "cultural_competency_rating"
        case painManagementRating = "pain_management_rating"
        case communicationRating = "communication_rating"
        case respectfulCareRating = "respectful_care_rating"
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }
}

// MARK: - User Model
struct User: Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let dueDate: Date?
    let zipCode: String?

    let wantsDoula: Bool
    let wantsMidwife: Bool
    let prefersBlackProviders: Bool

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case dueDate = "due_date"
        case zipCode = "zip_code"
        case wantsDoula = "wants_doula"
        case wantsMidwife = "wants_midwife"
        case prefersBlackProviders = "prefers_black_providers"
    }
}

// MARK: - Auth Models
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}

// MARK: - Educational Resource Model
struct EducationalResource: Identifiable, Codable {
    let id: String
    let title: String
    let category: String
    let content: String
    let contentType: String // "article", "video", "checklist"
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, title, category, content
        case contentType = "content_type"
        case orderIndex = "order_index"
    }
}

// MARK: - Birth Plan Model
struct BirthPlan: Codable {
    var painManagement: String? // "epidural", "natural", "undecided"
    var laborSupport: [String] // ["partner", "doula", "family"]
    var deliveryPreference: String? // "vaginal", "scheduled_c_section"
    var feedingPreference: String? // "breastfeeding", "formula", "both"
    var specialRequests: String?

    var continuousFetalMonitoring: Bool?
    var ivFluids: Bool?
    var episiotomy: Bool?

    enum CodingKeys: String, CodingKey {
        case painManagement = "pain_management"
        case laborSupport = "labor_support"
        case deliveryPreference = "delivery_preference"
        case feedingPreference = "feeding_preference"
        case specialRequests = "special_requests"
        case continuousFetalMonitoring = "continuous_fetal_monitoring"
        case ivFluids = "iv_fluids"
        case episiotomy
    }
}
