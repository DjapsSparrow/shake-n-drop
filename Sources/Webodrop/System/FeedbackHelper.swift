import AppKit
import Foundation

/// Envoie les idées d'amélioration et signalements de bugs vers `support@webomatik.fr`
/// via Web3Forms (clé publique prévue pour les clients front-end/apps), avec fallback `mailto:`.
enum FeedbackHelper {
    nonisolated static let supportEmail = "support@webomatik.fr"
    nonisolated static let web3FormsEndpoint = "https://api.web3forms.com/submit"
    nonisolated static let web3FormsAccessKey = "93fed49f-f041-45f9-ad44-2760ca3441bb"

    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case idea
        case bug

        var id: String { rawValue }

        nonisolated var title: String {
            switch self {
            case .idea: "Idée d'amélioration"
            case .bug: "Signaler un bug"
            }
        }

        var symbol: String {
            switch self {
            case .idea: "lightbulb.fill"
            case .bug: "ladybug.fill"
            }
        }

        var placeholder: String {
            switch self {
            case .idea: "Décrivez la fonctionnalité ou l'amélioration que vous aimeriez voir dans Shake'n'Drop…"
            case .bug: "Que faisiez-vous ? Que s'est-il passé ? (étapes pour reproduire le bug…)"
            }
        }
    }

    nonisolated static func send(
        kind: Kind,
        senderEmail: String,
        message: String,
        appVersion: String
    ) async throws {
        guard let url = URL(string: web3FormsEndpoint) else {
            throw NSError(domain: "ShakeNDrop.Feedback", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Adresse d'envoi invalide."
            ])
        }

        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let trimmedEmail = senderEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: String] = [
            "access_key": web3FormsAccessKey,
            "subject": "[Shake'n'Drop v\(appVersion)] \(kind.title)",
            "from_name": "Shake'n'Drop App",
            "type": kind.title,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "app_version": "Shake'n'Drop v\(appVersion)",
            "macos_version": macOSVersion,
        ]
        if !trimmedEmail.isEmpty {
            payload["email"] = trimmedEmail
            payload["replyto"] = trimmedEmail
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ShakeNDrop.Feedback", code: code, userInfo: [
                NSLocalizedDescriptionKey: "Le serveur n'a pas accepté l'envoi (code \(code))."
            ])
        }

        struct Web3Response: Decodable {
            let success: Bool
            let message: String?
        }
        if let decoded = try? JSONDecoder().decode(Web3Response.self, from: data), !decoded.success {
            throw NSError(domain: "ShakeNDrop.Feedback", code: -2, userInfo: [
                NSLocalizedDescriptionKey: decoded.message ?? "Envoi refusé par Web3Forms."
            ])
        }
    }

    static func openEmailFallback(kind: Kind, message: String, appVersion: String) {
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let subject = "[Shake'n'Drop v\(appVersion)] \(kind.title)"
        let body = """
        \(message)

        ---
        • App : Shake'n'Drop v\(appVersion)
        • macOS : \(macOSVersion)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}
