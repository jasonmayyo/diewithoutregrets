//
//  RegretViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/29.
//

import SwiftUI

class RegretViewModel: ObservableObject {
    @Published var currentQuestionIndex = 0
    
    func reset() {
        currentQuestionIndex = 0
    }
}
