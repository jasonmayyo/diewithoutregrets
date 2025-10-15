//
//  BuyBackView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/09/08.
//

import SwiftUI
import RevenueCat

struct BuyBackOfferView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showTitle = false
    @State private var showOfferCard = false
    @State private var showButton = false
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var showConfetti: Bool = false
    @State private var isPurchasing = false
    @State private var purchaseErrorMessage: String?
    private let confettiShownKey = "buyback_confetti_shown"
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x3FA4AE),
                    Color(hex: 0x2BC391)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if showConfetti {
                ForEach(confettiPieces) { piece in
                    ConfettiBuyBackView(piece: piece)
                }
                .transition(.opacity)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Text("One Time Offer")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 30)
                            .animation(.easeOut(duration: 1.0).delay(0.2), value: showTitle)
                        
                        Text("You will never see this again")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 30)
                            .animation(.easeOut(duration: 1.0).delay(0.4), value: showTitle)
                    }
                    
                    VStack(spacing: 25) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            Image(systemName: "gift.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.brown)
                        }
                        .opacity(showOfferCard ? 1 : 0)
                        .scaleEffect(showOfferCard ? 1.0 : 0.5)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6), value: showOfferCard)
                        
                        HStack() {
                            Text("Here's an")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                            
                            Text("70% off")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .cornerRadius(20)
                            
                            Text("discount")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                            
                            Image(systemName: "hands.sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .opacity(showOfferCard ? 1 : 0)
                        .offset(y: showOfferCard ? 0 : 20)
                        .animation(.easeOut(duration: 1.0).delay(0.8), value: showOfferCard)
                        
                        VStack(spacing: 8) {
                            Text("Only $1.67 / month")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .white.opacity(0.2), radius: 3, x: 0, y: 1)
                            
                            Text("Lowest price ever")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white)
                        }
                        .opacity(showOfferCard ? 1 : 0)
                        .offset(y: showOfferCard ? 0 : 20)
                        .animation(.easeOut(duration: 1.0).delay(1.0), value: showOfferCard)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    Task { await startWinBackPurchase() }
                }) {
                    Text("Claim your limited offer now!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 20)
                .disabled(isPurchasing)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeOut(duration: 1.0).delay(1.2), value: showButton)
                .accessibilityLabel("Claim your limited offer now!")
                .accessibilityHint("Tap to claim your special discount")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
                    .frame(height: 30)
            }
            
            if isPurchasing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isPurchasing)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.4)
                }
                .accessibilityLabel("Processing your purchase")
            }
        }
        .onAppear {
            print("[BuyBackOfferView] onAppear: triggering animations & analytics")
            showTitle = true
            showOfferCard = true
            showButton = true
            
            let hasShown = UserDefaults.standard.bool(forKey: confettiShownKey)
            if !hasShown {
                UserDefaults.standard.set(true, forKey: confettiShownKey)
                startConfettiBurst()
            }
        }
        .alert("Purchase Error", isPresented: .constant(purchaseErrorMessage != nil)) {
            Button("OK") { purchaseErrorMessage = nil }
        } message: {
            Text(purchaseErrorMessage ?? "Unknown error")
        }
    }
    
    private func startWinBackPurchase() async {
        print("[BuyBackOfferView] startWinBackPurchase called")
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            let winbackOffering = offerings.all["winback"]
            
            let candidatePackage =
                winbackOffering?.availablePackages.first(where: { $0.storeProduct.productIdentifier == "buy_back_offer" }) ??
                offerings.current?.availablePackages.first(where: { $0.storeProduct.productIdentifier == "buy_back_offer" }) ??
                offerings.current?.availablePackages.first(where: { $0.packageType == .annual })
            
            guard let package = candidatePackage ?? offerings.current?.availablePackages.first else {
                purchaseErrorMessage = "No package available for purchase."
                return
            }
            
            print("[BuyBackOfferView] Purchasing package: \(package.identifier)")
            let result = try await Purchases.shared.purchase(package: package)
            
            if result.customerInfo.entitlements.active.isEmpty == false {
                print("[BuyBackOfferView] Purchase success; completing onboarding and dismissing")
                
                // Reset tracking flags since user purchased
                NotificationManager.shared.resetPaywallTracking()
                NotificationManager.shared.markBuybackNotificationSeen()
                
                // Complete onboarding (same as paywall purchase)
                hasCompletedOnboarding = true
                
                // Dismiss the buyback sheet
                dismiss()
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain != "RevenueCat.PurchasesErrorCode" || nsError.code != 1 {
                print("[BuyBackOfferView] Purchase error: \(nsError)")
                purchaseErrorMessage = nsError.localizedDescription
            }
        }
    }
    
    private func startConfettiBurst() {
        confettiPieces = (0..<24).map { _ in ConfettiPiece(startY: -80) }
        showConfetti = true
        
        withAnimation(.linear(duration: 2.2)) {
            for i in confettiPieces.indices {
                confettiPieces[i].y = UIScreen.main.bounds.height + 60
                confettiPieces[i].rotation += Double.random(in: 120...360)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            showConfetti = false
            confettiPieces.removeAll()
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var color: Color
    var size: CGFloat
    
    init(startY: CGFloat = -50) {
        let width = UIScreen.main.bounds.width
        self.x = CGFloat.random(in: 0...width)
        self.y = startY
        self.rotation = Double.random(in: 0...180)
        self.color = [.yellow, .blue, .cyan, .orange, .pink, .purple].randomElement() ?? .yellow
        self.size = CGFloat.random(in: 4...8)
    }
}

struct ConfettiBuyBackView: View {
    let piece: ConfettiPiece
    
    var body: some View {
        Circle()
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size)
            .position(x: piece.x, y: piece.y)
            .rotationEffect(.degrees(piece.rotation))
    }
}

#Preview {
    BuyBackOfferView()
}


