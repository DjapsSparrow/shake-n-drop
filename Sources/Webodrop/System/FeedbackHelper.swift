import AppKit
import Foundation

/// Ouvre le client mail par défaut pré-rempli vers `support@webomatik.fr`
/// pour soumettre une idée d'amélioration ou signaler un bug.
enum FeedbackHelper {
    static let supportEmail = "support@webomatik.fr"

    enum Kind {
        case idea
        case bug

        var subjectTag: String {
            switch self {
            case .idea: "Idée d'amélioration"
            case .bug: "Signalement de bug"
            }
        }

        var promptBody: String {
            switch self {
            case .idea:
                """
                Bonjour l'équipe Webomatik,

                Voici une idée d'amélioration pour Shake'n'Drop :

                [Décrivez votre idée ici]

                """
            case .bug:
                """
                Bonjour l'équipe Webomatik,

                J'ai rencontré un bug dans Shake'n'Drop :

                - Ce que je faisais :
                - Ce qui s'est passé :
                - Ce que j'attendais :

                """
            }
        }
    }

    static func openEmail(kind: Kind, appVersion: String) {
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let subject = "[Shake'n'Drop v\(appVersion)] \(kind.subjectTag)"
        let body = """
        \(kind.promptBody)
        ---
        Diagnostic automatique :
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
