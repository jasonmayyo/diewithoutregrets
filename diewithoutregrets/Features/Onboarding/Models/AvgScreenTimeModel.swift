//
//  AvgScreenTimeModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct ScreenTimeOption: Identifiable, Equatable {
    let id = UUID()
    let range: String
    let hours: ClosedRange<Double>
}
