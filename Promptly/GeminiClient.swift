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

    let model: String = "gemini-2.5-flash"   // change to whatever you like

    func improvePrompt(raw: String, completion: @escaping (Result<String, Error>) -> Void) {
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

        let prompt = """
        You are an expert prompt engineer for large language models.

        Rewrite the following user prompt so that it is:
        - Clear and unambiguous
        - Well-structured (with bullet points / sections where helpful)
        - Optimized for another AI assistant (like ChatGPT) to answer

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

            do {
                let jsonAny = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonAny as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]] else {
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
