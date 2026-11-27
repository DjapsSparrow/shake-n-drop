import AppKit
import Foundation

/// Envoie les idées d'amélioration et signalements de bugs vers `support@webomatik.fr`
/// via Formsubmit (sans clé secrète dans l'app), avec fallback `mailto:` si besoin.
enum FeedbackHelper {
    nonisolated static let supportEmail = "support@webomatik.fr"
    nonisolated static let formsubmitEndpoint = "https://formsubmit.co/ajax/support@webomatik.fr"

    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case idea
        case bug

        var id: String { rawValue }

        var title: String {
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
        guard let url = URL(string: formsubmitEndpoint) else {
            throw NSError(domain: "ShakeNDrop.Feedback", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Adresse d'envoi invalide."
            ])
        }

        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let trimmedEmail = senderEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: String] = [
            "_subject": "[Shake'n'Drop v\(appVersion)] \(kind.title)",
            "_template": "table",
            "_captcha": "false",
            "Type": kind.title,
            "Message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "Version App": "Shake'n'Drop v\(appVersion)",
            "macOS": macOSVersion,
        ]
        if !trimmedEmail.isEmpty {
            payload["Email"] = trimmedEmail
            payload["_replyto"] = trimmedEmail
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://github.com/DjapsSparrow/shake-n-drop", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ShakeNDrop.Feedback", code: code, userInfo: [
                NSLocalizedDescriptionKey: "Le serveur n'a pas accepté l'envoi (code \(code))."
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
