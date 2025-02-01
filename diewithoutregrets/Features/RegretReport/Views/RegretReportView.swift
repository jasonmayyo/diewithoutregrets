//
//  RegretReportView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretReportView: View {
    @State private var userDefaultsValues: [String: Any] = [:]
    let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
    
    // Add timer for automatic refresh
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    func refreshUserDefaults() {
        // Get all relevant UserDefaults values
        userDefaultsValues = [
            "OpenedFromIntent": sharedDefaults?.bool(forKey: "OpenedFromIntent") ?? false,
            "UserAllowedBreak": sharedDefaults?.bool(forKey: "UserAllowedBreak") ?? false,
            "LastBreakTime": sharedDefaults?.double(forKey: "LastBreakTime") ?? 0,
            "ShowRegretView": sharedDefaults?.bool(forKey: "ShowRegretView") ?? false
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UserDefaults Debug Values:")
                .font(.headline)
                .padding(.bottom)
            
            ForEach(Array(userDefaultsValues.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text("\(String(describing: userDefaultsValues[key] ?? "nil"))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            Button("Refresh Values") {
                refreshUserDefaults()
            }
            .padding(.top)
        }
        .padding()
        .onAppear {
            refreshUserDefaults()
        }
        .onReceive(timer) { _ in
            refreshUserDefaults()
        }
    }
}

#Preview {
    RegretReportView()
}
