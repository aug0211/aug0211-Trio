import CoreData
import Foundation

extension Home.StateModel {
    @MainActor
    func updateGlucoseChartYAxis(glucoseValues _: [GlucoseStored]) {
        minYAxisValue = 0
        maxYAxisValue = 300
    }

    /// Recomputes the COB chart Y axis bounds from the fetched determination objects.
    @MainActor func yAxisChartDataCobChart(determinations: [OrefDetermination]) {
        let cobMapped = determinations.map { Decimal($0.cob) }

        if let maxCob = cobMapped.max() {
            minValueCobChart = 0
            maxValueCobChart = maxCob == 0 ? 20 : maxCob + 20
        } else {
            minValueCobChart = 0
            maxValueCobChart = 20
        }
    }

    /// Recomputes the IOB chart Y axis bounds from the fetched determination objects.
    @MainActor func yAxisChartDataIobChart(determinations: [OrefDetermination]) {
        let iobMapped = determinations.compactMap { $0.iob?.decimalValue }

        if let minIob = iobMapped.min(), let maxIob = iobMapped.max() {
            minValueIobChart = minIob
            maxValueIobChart = maxIob
        } else {
            minValueIobChart = 0
            maxValueIobChart = 5
        }
    }
}
