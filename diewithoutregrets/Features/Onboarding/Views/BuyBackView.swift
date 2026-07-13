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
    @State private var didCompletePurchase: Bool = false
    private let confettiShownKey = "buyback_confetti_shown"
    
    var body: some View {
        ZStack {
            SGAuroraBackground(intensity: 1.0)

            if showConfetti {
                ForEach(confettiPieces) { piece in
                    ConfettiBuyBackView(piece: piece)
                }
                .transition(.opacity)
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(SGTheme.paper)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(SGTheme.glaze(0.08))
                                    .overlay(Circle().strokeBorder(SGTheme.hairline, lineWidth: 1))
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Text("One Time Offer")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(SGTheme.paper)
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 30)
                            .animation(.easeOut(duration: 1.0).delay(0.2), value: showTitle)

                        Text("You will never see this again")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(SGTheme.paperSecondary)
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 30)
                            .animation(.easeOut(duration: 1.0).delay(0.4), value: showTitle)
                    }

                    VStack(spacing: 25) {
                        ZStack {
                            Circle()
                                .fill(SGTheme.inkRaised)
                                .frame(width: 80, height: 80)
                                .overlay(Circle().strokeBorder(SGTheme.hairline, lineWidth: 1))

                            Image(systemName: "gift.fill")
                                .font(.system(size: 40))
                                .foregroundColor(SGTheme.mint)
                        }
                        .opacity(showOfferCard ? 1 : 0)
                        .scaleEffect(showOfferCard ? 1.0 : 0.5)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6), value: showOfferCard)

                        HStack() {
                            Text("Here's an")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(SGTheme.paper)

                            Text("70% off")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(SGTheme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(SGTheme.mint)
                                .cornerRadius(20)

                            Text("discount")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(SGTheme.paper)

                            Image(systemName: "hands.sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(SGTheme.mint)
                        }
                        .opacity(showOfferCard ? 1 : 0)
                        .offset(y: showOfferCard ? 0 : 20)
                        .animation(.easeOut(duration: 1.0).delay(0.8), value: showOfferCard)

                        VStack(spacing: 8) {
                            Text("Only $1.67 / month")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(SGTheme.paper)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(SGTheme.inkRaised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(SGTheme.hairline, lineWidth: 1)
                                        )
                                )

                            Text("Lowest price ever")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(SGTheme.paperSecondary)
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(SGTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(SGTheme.mint, in: Capsule(style: .continuous))
                }
                .buttonStyle(SGPressStyle())
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
            Analytics.paywallViewed(surface: "buyback")
            showTitle = true
            showOfferCard = true
            showButton = true
            
            let hasShown = UserDefaults.standard.bool(forKey: confettiShownKey)
            if !hasShown {
                UserDefaults.standard.set(true, forKey: confettiShownKey)
                startConfettiBurst()
            }
        }
        .onDisappear {
            Analytics.paywallDismissed(
                surface: "buyback",
                didPurchase: didCompletePurchase
            )
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
            Telemetry.breadcrumb("Purchase started", category: "paywall",
                                 data: ["surface": "buyback",
                                        "product_id": package.storeProduct.productIdentifier])
            let result = try await Purchases.shared.purchase(package: package)
            
            if result.customerInfo.entitlements.active.isEmpty == false {
                print("[BuyBackOfferView] Purchase success; completing onboarding and dismissing")
                
                let price = Double(truncating: package.storeProduct.price as NSNumber)
                let currency = package.storeProduct.currencyCode ?? "USD"
                AdsTracker.trackPurchase(
                    productId: package.storeProduct.productIdentifier,
                    productName: package.storeProduct.localizedTitle,
                    price: price,
                    currency: currency
                )

                Analytics.subscriptionStarted(
                    surface: "buyback",
                    productId: package.storeProduct.productIdentifier,
                    price: price,
                    currency: currency,
                    isTrial: false,
                    offeringId: nil,
                    entitlements: result.customerInfo.entitlements.active.keys.map { $0 }
                )
                didCompletePurchase = true
                
                NotificationManager.shared.resetPaywallTracking()
                NotificationManager.shared.markBuybackNotificationSeen()
                
                if hasCompletedOnboarding {
                    // Post-onboarding deep-link path: nothing to advance,
                    // keep existing behavior.
                    hasCompletedOnboarding = true
                } else {
                    // Purchased mid-onboarding: do NOT end onboarding here.
                    // Mark the paywall as seen and signal HardPaywallView to
                    // advance the buyer into post-purchase setup.
                    UserDefaults.standard.set(true, forKey: "hasSeenPaywall")
                    NavigationModel.shared.signalBuyBackPurchaseDuringOnboarding()
                }

                // Dismiss the buyback sheet
                dismiss()
            }
        } catch {
            let nsError = error as NSError
            // Code 1 = purchaseCancelledError. User cancellations aren't bugs;
            // don't surface to UI and don't ship to Sentry — they'd flood the
            // dashboard and there's nothing to fix.
            let isUserCancellation = nsError.domain == "RevenueCat.PurchasesErrorCode" && nsError.code == 1
            if !isUserCancellation {
                print("[BuyBackOfferView] Purchase error: \(nsError)")
                purchaseErrorMessage = nsError.localizedDescription
                Telemetry.capture(error,
                                  context: ["error_domain": nsError.domain,
                                            "error_code": nsError.code],
                                  tags: ["feature": "paywall", "surface": "buyback"])
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
        self.color = [SGTheme.mint, SGTheme.teal, SGTheme.paper, SGTheme.ember].randomElement() ?? SGTheme.mint
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


