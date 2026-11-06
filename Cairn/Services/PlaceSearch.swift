import Foundation
import MapKit

/// Place autocomplete (towns, addresses, parks and other outdoor spots) using
/// Apple's built-in MapKit search. Free, and no API key needed. Shops,
/// restaurants and the like are filtered out.
@MainActor
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var onResults: ([MKLocalSearchCompletion]) -> Void = { _ in }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.outdoorCategories)
    }

    private static var outdoorCategories: [MKPointOfInterestCategory] {
        var categories: [MKPointOfInterestCategory] = [.nationalPark, .park, .beach, .campground, .marina]
        if #available(iOS 18.0, *) {
            categories += [.hiking, .skiing, .rockClimbing, .kayaking, .surfing, .landmark, .nationalMonument]
        }
        return categories
    }

    /// Starts (or replaces) an autocomplete query. Results arrive through `handler`.
    func update(_ query: String, handler: @escaping ([MKLocalSearchCompletion]) -> Void) {
        onResults = handler
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            completer.cancel()
            handler([])
        } else {
            completer.queryFragment = query
        }
    }

    /// Looks up the coordinate for a suggestion the user picked.
    func coordinate(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let response = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
        return response?.mapItems.first?.placemark.coordinate
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results.prefix(8))
        MainActor.assumeIsolated { onResults(results) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { onResults([]) }
    }
}
