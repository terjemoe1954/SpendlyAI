//
//  PurchaseService.swift
//  SpendlyAI
//

import Foundation
import StoreKit

enum PurchaseConfiguration {
    static let plusMonthlyProductID = "spendlyai.plus.monthly"
    static let plusProductIDs: [String] = [plusMonthlyProductID]
}

struct PurchaseProduct: Equatable, Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
}

enum PurchaseState: Equatable {
    case unavailable
    case notPurchased
    case purchased
}

enum PurchaseServiceError: LocalizedError, Equatable {
    case productUnavailable
    case pending
    case unverified
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "Product is unavailable."
        case .pending:
            "Purchase is pending."
        case .unverified:
            "Purchase could not be verified."
        case .cancelled:
            "Purchase was cancelled."
        case .unknown:
            "Purchase failed."
        }
    }
}

struct PurchaseService {
    func loadPlusProduct() async -> PurchaseProduct? {
        guard let product = try? await Product.products(for: PurchaseConfiguration.plusProductIDs).first else {
            return nil
        }

        return PurchaseProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice
        )
    }

    func purchasePlus() async -> Result<PurchaseState, PurchaseServiceError> {
        do {
            guard let product = try await Product.products(for: PurchaseConfiguration.plusProductIDs).first else {
                return .failure(.productUnavailable)
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try verifiedTransaction(from: verificationResult)
                await transaction.finish()
                return .success(.purchased)
            case .pending:
                return .failure(.pending)
            case .userCancelled:
                return .failure(.cancelled)
            @unknown default:
                return .failure(.unknown)
            }
        } catch is StoreKitError {
            return .failure(.unknown)
        } catch {
            return .failure(.unverified)
        }
    }

    func restorePurchases() async -> Result<PurchaseState, PurchaseServiceError> {
        do {
            try await AppStore.sync()
            return .success(await currentPlusState())
        } catch {
            return .failure(.unknown)
        }
    }

    func currentPlusState() async -> PurchaseState {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }

            if PurchaseConfiguration.plusProductIDs.contains(transaction.productID) {
                return .purchased
            }
        }

        return .notPurchased
    }

    private func verifiedTransaction(
        from result: VerificationResult<StoreKit.Transaction>
    ) throws -> StoreKit.Transaction {
        switch result {
        case .verified(let transaction):
            transaction
        case .unverified:
            throw PurchaseServiceError.unverified
        }
    }
}
