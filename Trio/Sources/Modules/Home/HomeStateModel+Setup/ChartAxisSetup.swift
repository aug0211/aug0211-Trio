import CoreData
import Foundation

extension Home.StateModel {
    /// Sets the main glucose chart Y axis bounds from the fetched glucose objects.
    /// Auggie: the floor is pinned to 0 and the ceiling to 300 mg/dL; the ceiling
    /// jumps to 400 only when an actual reading exceeds 300. Forecasts are ignored.
    /// Runs on the main actor since the inputs are viewContext managed objects.
    @MainActor func updateGlucoseChartYAxis(glucoseValues: [GlucoseStored]) {
        let maxGlucose = glucoseValues.map { Decimal($0.glucose) }.max() ?? 0

        minYAxisValue = 0
        maxYAxisValue = maxGlucose > 300 ? 400 : 300
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
