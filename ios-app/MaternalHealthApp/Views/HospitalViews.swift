// HospitalViews.swift
// SwiftUI views for hospital list, detail, and filters

import SwiftUI
import MapKit

struct HospitalListView: View {
    @StateObject private var viewModel = HospitalListViewModel()
    @State private var searchText = ""
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Finding hospitals nearby...")
                } else if viewModel.hospitals.isEmpty {
                    EmptyStateView()
                } else {
                    hospitalList
                }
            }
            .navigationTitle("Find a Hospital")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search hospitals")
            .sheet(isPresented: $showFilters) {
                FilterView(filters: $viewModel.filters)
            }
            .onAppear {
                viewModel.loadHospitals()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    private var hospitalList: some View {
        List {
            ForEach(filteredHospitals) { hospitalWithDistance in
                NavigationLink(destination: HospitalDetailView(hospital: hospitalWithDistance.hospital)) {
                    HospitalRowView(hospital: hospitalWithDistance.hospital, distance: hospitalWithDistance.distanceMiles)
                }
            }
        }
        .listStyle(.plain)
    }

    private var filteredHospitals: [HospitalWithDistance] {
        if searchText.isEmpty {
            return viewModel.hospitals
        } else {
            return viewModel.hospitals.filter {
                $0.hospital.name.localizedCaseInsensitiveContains(searchText) ||
                $0.hospital.city.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct HospitalRowView: View {
    let hospital: Hospital
    let distance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(hospital.name).font(.headline)
                Spacer()
                Text("\(String(format: "%.1f", distance)) mi")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(hospital.city + ", " + hospital.state)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                if let rating = hospital.overallRating {
                    MetricBadge(icon: "star.fill", value: String(format: "%.1f", rating), color: ratingColor(rating))
                }
                if hospital.hasNICU {
                    MetricBadge(icon: "heart.text.square.fill", value: "NICU", color: .blue)
                }
                if hospital.doulaAccessible {
                    MetricBadge(icon: "figure.2.arms.open", value: "Doula", color: .purple)
                }
                if let blackRate = hospital.blackMaternalMortalityRate {
                    MetricBadge(icon: "waveform.path.ecg", value: String(format: "%.1f%%", blackRate), color: mortalityColor(blackRate))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func ratingColor(_ rating: Double) -> Color {
        switch rating {
        case 4.5...: return .green
        case 3.5..<4.5: return .orange
        default: return .red
        }
    }

    private func mortalityColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<10: return .green
        case 10..<20: return .orange
        default: return .red
        }
    }
}

struct MetricBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption)
            Text(value).font(.caption).fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Hospitals Found").font(.title2).fontWeight(.semibold)
            Text("Try adjusting your filters or search radius")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct FilterView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var filters: HospitalFilters

    var body: some View {
        NavigationStack {
            Form {
                Section("Search Radius") {
                    Picker("Radius", selection: $filters.radius) {
                        Text("10 miles").tag(10)
                        Text("25 miles").tag(25)
                        Text("50 miles").tag(50)
                        Text("100 miles").tag(100)
                    }
                }
                Section("Minimum Rating") {
                    Picker("Rating", selection: $filters.minRating) {
                        Text("Any").tag(nil as Double?)
                        Text("3.0+").tag(3.0 as Double?)
                        Text("4.0+").tag(4.0 as Double?)
                        Text("4.5+").tag(4.5 as Double?)
                    }
                }
                Section("Services") {
                    Toggle("Has NICU", isOn: Binding(
                        get: { filters.hasNICU ?? false },
                        set: { filters.hasNICU = $0 }
                    ))
                    Toggle("Doula Accessible", isOn: Binding(
                        get: { filters.doulaAccessible ?? false },
                        set: { filters.doulaAccessible = $0 }
                    ))
                    Toggle("Birth Plan Friendly", isOn: Binding(
                        get: { filters.birthPlanFriendly ?? false },
                        set: { filters.birthPlanFriendly = $0 }
                    ))
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") { filters = HospitalFilters() }
                }
            }
        }
    }
}

struct HospitalDetailView: View {
    let hospital: Hospital

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hospital.name).font(.title).fontWeight(.bold)
                    Text(hospital.fullAddress).font(.subheadline).foregroundColor(.secondary)
                    if let rating = hospital.overallRating {
                        HStack {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", rating)).font(.subheadline)
                            Text("(\(hospital.reviewCount) reviews)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Key Metrics").font(.headline).padding(.horizontal)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        if let blackRate = hospital.blackMaternalMortalityRate {
                            StatCard(title: "Black Maternal Mortality", value: String(format: "%.1f%%", blackRate), subtitle: "per 100,000 births", color: mortalityColor(blackRate))
                        }
                        if let cSection = hospital.blackCSectionRate {
                            StatCard(title: "Black C-Section Rate", value: String(format: "%.1f%%", cSection), subtitle: "of all births", color: .blue)
                        }
                        if let diversity = hospital.staffDiversityScore {
                            StatCard(title: "Black OB-GYN Staff", value: String(format: "%.0f%%", diversity), subtitle: "of total staff", color: .purple)
                        }
                        if let satisfaction = hospital.patientSatisfactionScore {
                            StatCard(title: "Patient Satisfaction", value: String(format: "%.1f/5", satisfaction), subtitle: "average rating", color: .green)
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Services & Amenities").font(.headline).padding(.horizontal)
                    VStack(alignment: .leading, spacing: 8) {
                        ServiceRow(icon: "heart.text.square.fill", text: hospital.hasLevelIIINICU ? "Level III NICU" : hospital.hasNICU ? "NICU Available" : "No NICU", available: hospital.hasNICU)
                        ServiceRow(icon: "figure.2.arms.open", text: "Doula Accessible", available: hospital.doulaAccessible)
                        ServiceRow(icon: "doc.text.fill", text: "Birth Plan Friendly", available: hospital.birthPlanFriendly)
                    }
                    .padding(.horizontal)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Contact Information").font(.headline).padding(.horizontal)
                    if let phone = hospital.phone {
                        Button {
                            if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text(phone)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    if let website = hospital.website, let url = URL(string: website) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Visit Website")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        // Save hospital
                    } label: {
                        Label("Save", systemImage: "bookmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Button {
                        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: hospital.coordinate))
                        mapItem.name = hospital.name
                        mapItem.openInMaps()
                    } label: {
                        Label("Directions", systemImage: "map")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mortalityColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<10: return .green
        case 10..<20: return .orange
        default: return .red
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(subtitle).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ServiceRow: View {
    let icon: String
    let text: String
    let available: Bool

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(available ? .green : .gray)
            Text(text).foregroundColor(available ? .primary : .secondary)
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(available ? .green : .gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HospitalListView()
}

#Preview("Hospital Detail") {
    NavigationStack {
        HospitalDetailView(hospital: Hospital.mockHospitals[0])
    }
}
