//
//  AIService.swift
//  SpendlyAI
//

import Foundation

struct AIBudgetContext: Codable, Equatable {
    let currencyCode: String
    let safeToSpendToday: Decimal
    let spentToday: Decimal
    let remainingToday: Decimal
    let daysUntilNextIncome: Int
    let upcomingFixedExpenses: Decimal
    let plannedSavings: Decimal
    let minimumBuffer: Decimal
    let isBudgetUnderPressure: Bool
}

struct AIRequest: Codable, Equatable {
    let question: String
    let budgetContext: AIBudgetContext
}

struct AIResponse: Codable, Equatable {
    let message: String
}

enum AIServiceError: LocalizedError, Equatable {
    case missingAccess
    case networkUnavailable
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAccess:
            "AI access is not configured."
        case .networkUnavailable:
            "The AI service could not be reached."
        case .apiError(let message):
            message
        case .invalidResponse:
            "The AI service returned an invalid response."
        }
    }
}

struct AIService {
    nonisolated static let systemInstructions = """
    You are Spendly AI, a short, friendly personal budget explainer.
    Use only the budget numbers provided in the structured input.
    Never invent balances, expenses, transaction totals, dates, or calculations.
    Keep answers to one to three short sentences.
    Be concrete and non-judgmental. Avoid guilt, shame, or moralizing.
    Explain tradeoffs and consequences without telling the person what they must do.
    Clearly separate budgeting guidance from professional financial advice.
    """

    private let backendURL: URL?
    private let urlSession: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    nonisolated init(backendURL: URL? = nil, urlSession: URLSession? = nil) {
        self.backendURL = backendURL
        self.urlSession = urlSession ?? .shared
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
    }

    nonisolated func answer(_ request: AIRequest) async -> Result<AIResponse, AIServiceError> {
        guard let backendURL else {
            return .failure(.missingAccess)
        }

        var urlRequest = URLRequest(url: backendURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try jsonEncoder.encode(BackendRequest(
                systemInstructions: Self.systemInstructions,
                request: request
            ))

            let (data, response) = try await urlSession.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.apiError("AI request failed with status \(httpResponse.statusCode)."))
            }

            let backendResponse = try jsonDecoder.decode(BackendResponse.self, from: data)
            return .success(AIResponse(message: backendResponse.message))
        } catch is URLError {
            return .failure(.networkUnavailable)
        } catch {
            return .failure(.invalidResponse)
        }
    }

    nonisolated func fallbackAnswer(for request: AIRequest, after error: AIServiceError? = nil) -> AIResponse {
        let context = request.budgetContext
        let question = request.question.lowercased()
        let locale = Locale.current
        let remaining = MoneyFormatter.string(
            from: context.remainingToday,
            currencyCode: context.currencyCode,
            locale: locale
        )
        let fixedExpenses = MoneyFormatter.string(
            from: context.upcomingFixedExpenses,
            currencyCode: context.currencyCode,
            locale: locale
        )
        let savings = MoneyFormatter.string(
            from: context.plannedSavings,
            currencyCode: context.currencyCode,
            locale: locale
        )
        let usesNorwegian = locale.language.languageCode?.identifier == "no"
            || locale.language.languageCode?.identifier == "nb"
            || locale.language.languageCode?.identifier == "nn"

        if question.contains("mål") || question.contains("spare") || question.contains("goal") || question.contains("sav") {
            let message = usesNorwegian
                ? "Det er satt av \(savings) til sparemål før neste inntekt. Beløpet er allerede trukket fra det du trygt kan bruke."
                : "\(savings) is reserved for savings goals before your next income. It is already deducted from what is safe to spend."
            return AIResponse(message: message)
        }

        if question.contains("lav") || question.contains("hvorfor") || question.contains("lower") || question.contains("why") {
            let message = usesNorwegian
                ? "Dagsbudsjettet tar høyde for \(fixedExpenses) i kommende faste utgifter, sparemål og bufferen din. Du har \(remaining) igjen å bruke i dag."
                : "Your daily budget accounts for \(fixedExpenses) in upcoming fixed expenses, savings goals, and your buffer. You have \(remaining) left today."
            return AIResponse(message: message)
        }

        if context.isBudgetUnderPressure || context.remainingToday < 0 {
            let message = usesNorwegian
                ? "Du har \(remaining) igjen i dagens budsjett. Budsjettet er presset, så nye kjøp vil redusere bufferen frem til neste inntekt."
                : "You have \(remaining) left in today’s budget. The budget is under pressure, so new purchases will reduce your buffer until the next income."
            return AIResponse(message: message)
        }

        let message = usesNorwegian
            ? "Du har \(remaining) igjen å bruke i dag etter faste utgifter, sparemål og buffer."
            : "You have \(remaining) left to spend today after fixed expenses, savings goals, and your buffer."
        return AIResponse(message: message)
    }
}

private struct BackendRequest: Codable {
    let systemInstructions: String
    let request: AIRequest
}

private struct BackendResponse: Codable {
    let message: String
}
