//
//  AIViewModel.swift
//  SpendlyAI
//

import Foundation
import SwiftUI

@Observable
final class AIViewModel {
    var question = ""
    var answer = String(localized: "ai.emptyAnswer")
    var isLoading = false
    var lastError: AIServiceError?

    private let aiService: AIService

    init(aiService: AIService = AIService()) {
        self.aiService = aiService
    }

    var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func ask(using budgetContext: AIBudgetContext?) async {
        guard let budgetContext else {
            answer = String(localized: "ai.fallback.noBudget")
            lastError = nil
            return
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let request = AIRequest(question: trimmedQuestion, budgetContext: budgetContext)
        let result = await aiService.answer(request)

        switch result {
        case .success(let response):
            answer = response.message
            lastError = nil
        case .failure(let error):
            let fallback = aiService.fallbackAnswer(for: request, after: error)
            answer = fallback.message
            lastError = error
        }
    }
}
