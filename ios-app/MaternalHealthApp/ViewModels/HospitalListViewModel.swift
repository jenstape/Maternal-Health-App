// HospitalListViewModel.swift
// ViewModel for hospital list with business logic

import Foundation
import Combine
import CoreLocation

// MARK: - Hospital Filters
struct HospitalFilters {
    var radius: Int = 25
    var minRating: Double? = nil
    var hasNICU: Bool? = nil
    var doulaAccessible: Bool? = nil
    var birthPlanFriendly: Bool? = nil
}

// MARK: - Hospital List ViewModel
@MainActor
class HospitalListViewModel: ObservableObject {
    @Published var hospitals: [HospitalWithDistance] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filters = HospitalFilters()

    private var cancellables = Set<AnyCancellable>()
    private let locationService = LocationService.shared
    private let networkService = NetworkService.shared

    // For development/testing without backend
    private let useMockData = true // Set to false when backend is ready

    init() {
        $filters
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadHospitals()
            }
            .store(in: &cancellables)
    }

    func loadHospitals() {
        isLoading = true
        errorMessage = nil

        locationService.requestLocation()
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] location in
                self?.fetchHospitals(latitude: location.latitude, longitude: location.longitude)
            }
            .store(in: &cancellables)
    }

    private func fetchHospitals(latitude: Double, longitude: Double) {
        if useMockData {
            MockNetworkService.shared.searchHospitals()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                } receiveValue: { [weak self] response in
                    self?.hospitals = response.hospitals
                }
                .store(in: &cancellables)
        } else {
            networkService.searchHospitals(
                latitude: latitude,
                longitude: longitude,
                radius: filters.radius,
                minRating: filters.minRating,
                hasNICU: filters.hasNICU,
                doulaAccessible: filters.doulaAccessible
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.hospitals = response.hospitals
            }
            .store(in: &cancellables)
        }
    }
}

// MARK: - Location Service
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private var locationSubject = PassthroughSubject<CLLocationCoordinate2D, LocationError>()

    enum LocationError: Error, LocalizedError {
        case denied
        case restricted
        case unknown

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access denied. Please enable in Settings."
            case .restricted: return "Location access is restricted."
            case .unknown: return "Unable to determine location."
            }
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() -> AnyPublisher<CLLocationCoordinate2D, LocationError> {
        let authStatus = locationManager.authorizationStatus

        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            return Fail(error: .restricted).eraseToAnyPublisher()
        case .denied:
            return Fail(error: .denied).eraseToAnyPublisher()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        @unknown default:
            return Fail(error: .unknown).eraseToAnyPublisher()
        }

        return locationSubject
            .first()
            .eraseToAnyPublisher()
    }

    func checkAuthorizationStatus() -> Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            locationSubject.send(completion: .failure(.unknown))
            return
        }
        locationSubject.send(location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationSubject.send(completion: .failure(.unknown))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied:
            locationSubject.send(completion: .failure(.denied))
        case .restricted:
            locationSubject.send(completion: .failure(.restricted))
        default:
            break
        }
    }
}

// MARK: - Hospital Detail ViewModel
@MainActor
class HospitalDetailViewModel: ObservableObject {
    @Published var hospital: Hospital
    @Published var reviews: [Review] = []
    @Published var isLoadingReviews = false
    @Published var isSaved = false

    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService.shared

    init(hospital: Hospital) {
        self.hospital = hospital
        checkIfSaved()
        loadReviews()
    }

    func loadReviews() {
        isLoadingReviews = true
        networkService.getHospitalReviews(hospitalId: hospital.id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingReviews = false
            } receiveValue: { [weak self] reviews in
                self?.reviews = reviews
            }
            .store(in: &cancellables)
    }

    func toggleSave() {
        if isSaved {
            removeSave()
        } else {
            saveHospital()
        }
    }

    private func saveHospital() {
        networkService.saveHospital(hospitalId: hospital.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                // Handle error
            } receiveValue: { [weak self] _ in
                self?.isSaved = true
            }
            .store(in: &cancellables)
    }

    private func removeSave() {
        networkService.removeSavedHospital(hospitalId: hospital.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                // Handle error
            } receiveValue: { [weak self] _ in
                self?.isSaved = false
            }
            .store(in: &cancellables)
    }

    private func checkIfSaved() {
        networkService.getSavedHospitals()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                // Handle error
            } receiveValue: { [weak self] savedHospitals in
                self?.isSaved = savedHospitals.contains { $0.id == self?.hospital.id }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Auth ViewModel
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService.shared

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        isAuthenticated = networkService.isAuthenticated()
        if isAuthenticated {
            loadCurrentUser()
        }
    }

    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        networkService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.currentUser = response.user
                self?.isAuthenticated = true
            }
            .store(in: &cancellables)
    }

    func register(email: String, password: String, firstName: String?, lastName: String?) {
        isLoading = true
        errorMessage = nil
        networkService.register(email: email, password: password, firstName: firstName, lastName: lastName)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.currentUser = response.user
                self?.isAuthenticated = true
            }
            .store(in: &cancellables)
    }

    func logout() {
        networkService.clearAuthToken()
        currentUser = nil
        isAuthenticated = false
    }

    private func loadCurrentUser() {
        networkService.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.logout()
                }
            } receiveValue: { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }
}
