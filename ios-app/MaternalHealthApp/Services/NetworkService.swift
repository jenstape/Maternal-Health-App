// NetworkService.swift
// Handles all API communication for the iOS app

import Foundation
import Combine

// MARK: - Network Error
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkFailure

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received from server"
        case .decodingError: return "Failed to decode server response"
        case .serverError(let message): return message
        case .unauthorized: return "Unauthorized. Please log in again."
        case .networkFailure: return "Network connection failed"
        }
    }
}

// MARK: - Network Service
class NetworkService {
    static let shared = NetworkService()

    // Change this to your backend URL
    private let baseURL = "http://localhost:3000/api" // Node.js
    // private let baseURL = "http://localhost:8000/api" // Python/FastAPI

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) -> AnyPublisher<T, NetworkError> {

        guard let url = URL(string: baseURL + endpoint) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: NetworkError.decodingError).eraseToAnyPublisher()
            }
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.networkFailure
                }
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 400...499:
                    if let errorMsg = try? JSONDecoder().decode([String: String].self, from: data),
                       let message = errorMsg["message"] {
                        throw NetworkError.serverError(message)
                    }
                    throw NetworkError.serverError("Client error")
                case 500...599:
                    throw NetworkError.serverError("Server error")
                default:
                    throw NetworkError.networkFailure
                }
            }
            .decode(type: T.self, decoder: JSONDecoder.customDecoder)
            .mapError { error in
                if let networkError = error as? NetworkError { return networkError }
                return NetworkError.decodingError
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Hospital Endpoints

    func searchHospitals(
        latitude: Double,
        longitude: Double,
        radius: Int = 25,
        minRating: Double? = nil,
        hasNICU: Bool? = nil,
        doulaAccessible: Bool? = nil
    ) -> AnyPublisher<HospitalSearchResponse, NetworkError> {

        var queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)")
        ]
        if let minRating = minRating {
            queryItems.append(URLQueryItem(name: "minRating", value: "\(minRating)"))
        }
        if let hasNICU = hasNICU {
            queryItems.append(URLQueryItem(name: "hasNICU", value: "\(hasNICU)"))
        }
        if let doulaAccessible = doulaAccessible {
            queryItems.append(URLQueryItem(name: "doulaAccessible", value: "\(doulaAccessible)"))
        }

        var components = URLComponents(string: baseURL + "/hospitals/search")
        components?.queryItems = queryItems

        guard let url = components?.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      200...299 ~= httpResponse.statusCode else {
                    throw NetworkError.serverError("Failed to fetch hospitals")
                }
                return data
            }
            .decode(type: HospitalSearchResponse.self, decoder: JSONDecoder.customDecoder)
            .mapError { _ in NetworkError.decodingError }
            .eraseToAnyPublisher()
    }

    func getHospitalDetail(id: String) -> AnyPublisher<Hospital, NetworkError> {
        return request(endpoint: "/hospitals/\(id)")
    }

    func compareHospitals(ids: [String]) -> AnyPublisher<[Hospital], NetworkError> {
        struct CompareRequest: Encodable { let hospitalIds: [String] }
        return request(endpoint: "/hospitals/compare", method: "POST", body: CompareRequest(hospitalIds: ids))
    }

    func getHospitalReviews(hospitalId: String, page: Int = 1, limit: Int = 20) -> AnyPublisher<[Review], NetworkError> {
        return request(endpoint: "/hospitals/\(hospitalId)/reviews?page=\(page)&limit=\(limit)")
    }

    func submitReview(hospitalId: String, review: Review) -> AnyPublisher<Review, NetworkError> {
        return request(endpoint: "/hospitals/\(hospitalId)/reviews", method: "POST", body: review, requiresAuth: true)
    }

    // MARK: - Auth Endpoints

    func login(email: String, password: String) -> AnyPublisher<AuthResponse, NetworkError> {
        let loginRequest = LoginRequest(email: email, password: password)
        return request(endpoint: "/auth/login", method: "POST", body: loginRequest)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.saveAuthToken(response.token)
            })
            .eraseToAnyPublisher()
    }

    func register(email: String, password: String, firstName: String?, lastName: String?) -> AnyPublisher<AuthResponse, NetworkError> {
        let registerRequest = RegisterRequest(email: email, password: password, firstName: firstName, lastName: lastName)
        return request(endpoint: "/auth/register", method: "POST", body: registerRequest)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.saveAuthToken(response.token)
            })
            .eraseToAnyPublisher()
    }

    func getCurrentUser() -> AnyPublisher<User, NetworkError> {
        return request(endpoint: "/auth/me", requiresAuth: true)
    }

    func updateProfile(user: User) -> AnyPublisher<User, NetworkError> {
        return request(endpoint: "/auth/profile", method: "PUT", body: user, requiresAuth: true)
    }

    // MARK: - User Endpoints

    func getSavedHospitals() -> AnyPublisher<[Hospital], NetworkError> {
        return request(endpoint: "/users/saved-hospitals", requiresAuth: true)
    }

    func saveHospital(hospitalId: String, notes: String? = nil) -> AnyPublisher<Hospital, NetworkError> {
        struct SaveRequest: Encodable { let hospitalId: String; let notes: String? }
        return request(endpoint: "/users/saved-hospitals", method: "POST", body: SaveRequest(hospitalId: hospitalId, notes: notes), requiresAuth: true)
    }

    func removeSavedHospital(hospitalId: String) -> AnyPublisher<Void, NetworkError> {
        struct EmptyResponse: Decodable {}
        return request(endpoint: "/users/saved-hospitals/\(hospitalId)", method: "DELETE", requiresAuth: true)
            .map { (_: EmptyResponse) in () }
            .eraseToAnyPublisher()
    }

    func getBirthPlan() -> AnyPublisher<BirthPlan, NetworkError> {
        return request(endpoint: "/users/birth-plan", requiresAuth: true)
    }

    func updateBirthPlan(plan: BirthPlan) -> AnyPublisher<BirthPlan, NetworkError> {
        return request(endpoint: "/users/birth-plan", method: "PUT", body: plan, requiresAuth: true)
    }

    // MARK: - Resource Endpoints

    func getEducationalResources(category: String? = nil) -> AnyPublisher<[EducationalResource], NetworkError> {
        let endpoint = category != nil ? "/resources/educational?category=\(category!)" : "/resources/educational"
        return request(endpoint: endpoint)
    }

    // MARK: - Token Management

    private func saveAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "authToken")
    }

    private func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }

    func clearAuthToken() {
        UserDefaults.standard.removeObject(forKey: "authToken")
    }

    func isAuthenticated() -> Bool {
        return getAuthToken() != nil
    }
}

// MARK: - JSON Decoder Extension
extension JSONDecoder {
    static var customDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

// MARK: - Mock Network Service (for testing without backend)
class MockNetworkService {
    static let shared = MockNetworkService()

    private init() {}

    func searchHospitals() -> AnyPublisher<HospitalSearchResponse, NetworkError> {
        let response = HospitalSearchResponse(
            hospitals: Hospital.mockHospitals.map { hospital in
                HospitalWithDistance(hospital: hospital, distanceMiles: Double.random(in: 1...20))
            },
            total: Hospital.mockHospitals.count
        )
        return Just(response)
            .delay(for: 1.0, scheduler: RunLoop.main)
            .setFailureType(to: NetworkError.self)
            .eraseToAnyPublisher()
    }

    func getHospitalDetail(id: String) -> AnyPublisher<Hospital, NetworkError> {
        if let hospital = Hospital.mockHospitals.first(where: { $0.id == id }) {
            return Just(hospital)
                .delay(for: 0.5, scheduler: RunLoop.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: NetworkError.serverError("Hospital not found"))
                .eraseToAnyPublisher()
        }
    }
}
