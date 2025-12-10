import Foundation

enum GeminiError: Error, LocalizedError {
    case missingAPIKey
    case badResponse
    case noTextCandidate

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GEMINI_API_KEY environment variable is not set."
        case .badResponse:
            return "Gemini API returned an unexpected response."
        case .noTextCandidate:
            return "Gemini response did not contain any text."
        }
    }
}

struct GeminiClient {

    let model: String = "gemini-2.5-flash"

    func improvePrompt(raw: String,
                       style: String,
                       completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
              !apiKey.isEmpty else {
            completion(.failure(GeminiError.missingAPIKey))
            return
        }

        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        ) else {
            completion(.failure(GeminiError.badResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let styleInstruction: String
        switch style {
        case "Concise":
            styleInstruction = "Make the rewritten prompt as concise and minimal as possible while keeping all constraints."
        case "Detailed":
            styleInstruction = "Expand structure and clarify assumptions; prefer detailed bullet points and explicit constraints."
        case "Code Helper":
            styleInstruction = "Optimize the prompt for coding help. Emphasize examples, edge cases, and clear input/output expectations."
        default:
            styleInstruction = "Use a neutral, clear style that balances structure and brevity."
        }

        let prompt = """
        You are an expert prompt engineer for large language models.

        Rewrite the following user prompt so that it is:
        - Clear and unambiguous
        - Well-structured (with bullet points / sections where helpful)
        - Optimized for another AI assistant (like ChatGPT) to answer

        Style preference:
        \(styleInstruction)

        Keep the original intent, constraints, and important details.
        DO NOT answer the prompt.
        Return ONLY the rewritten prompt, no extra commentary.

        ---
        \(raw)
        """

        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [[ "text": prompt ]]
            ]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(GeminiError.badResponse))
                return
            }

            // Debug log
            if let debugString = String(data: data, encoding: .utf8) {
                print("Gemini raw response:\n\(debugString)")
            }

            do {
                let jsonAny = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonAny as? [String: Any] else {
                    completion(.failure(GeminiError.badResponse))
                    return
                }

                // API error
                if let errorDict = json["error"] as? [String: Any] {
                    let code = errorDict["code"] as? Int ?? 0
                    let status = errorDict["status"] as? String ?? ""
                    let message = errorDict["message"] as? String ?? "Unknown Gemini API error."

                    if code == 503 || status == "UNAVAILABLE" {
                        let friendly = "Gemini is currently overloaded. Your request is fine — just try again in a bit."
                        let apiError = NSError(
                            domain: "GeminiAPI",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: friendly]
                        )
                        completion(.failure(apiError))
                        return
                    }

                    let apiError = NSError(
                        domain: "GeminiAPI",
                        code: code,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                    completion(.failure(apiError))
                    return
                }

                guard let candidates = json["candidates"] as? [[String: Any]] else {
                    completion(.failure(GeminiError.badResponse))
                    return
                }

                for cand in candidates {
                    if let content = cand["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        for part in parts {
                            if let text = part["text"] as? String, !text.isEmpty {
                                completion(.success(text))
                                return
                            }
                        }
                    }
                }

                completion(.failure(GeminiError.noTextCandidate))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
