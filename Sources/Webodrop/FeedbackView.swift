import SwiftUI

/// Formulaire natif macOS pour envoyer une idée ou un bug directement à `support@webomatik.fr`.
struct FeedbackView: View {
    @Environment(WebodropEngine.self) private var engine
    @State var kind: FeedbackHelper.Kind
    @State private var senderEmail: String = ""
    @State private var message: String = ""
    @State private var isSending: Bool = false
    @State private var didSend: Bool = false
    @State private var errorMessage: String?

    let onClose: () -> Void

    var body: some View {
        Group {
            if didSend {
                successView
            } else {
                formView
            }
        }
        .padding(Space.xl)
        .frame(width: 440)
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Image(systemName: kind.symbol)
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Idée ou bug ?")
                        .font(.title3.weight(.semibold))
                    Text("Envoyé directement à \(FeedbackHelper.supportEmail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Type", selection: $kind) {
                ForEach(FeedbackHelper.Kind.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Votre email (optionnel, si vous souhaitez une réponse)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("prenom@exemple.fr", text: $senderEmail)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Votre message")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $message)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(height: 132)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                        )

                    if message.isEmpty {
                        Text(kind.placeholder)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                }
            }

            if let errorMessage {
                HStack(spacing: Space.sm) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Ouvrir Mail") {
                        FeedbackHelper.openEmailFallback(
                            kind: kind,
                            message: message,
                            appVersion: engine.updater.currentVersion
                        )
                    }
                    .controlSize(.small)
                }
            }

            HStack {
                Text("v\(engine.updater.currentVersion) • infos macOS jointes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Annuler") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    submit()
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 64)
                    } else {
                        Text("Envoyer")
                            .frame(minWidth: 64)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("Merci pour votre retour !")
                .font(.title3.weight(.semibold))

            Text("Votre message a bien été transmis à \(FeedbackHelper.supportEmail).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Fermer") {
                onClose()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.top, Space.xs)
        }
        .padding(.vertical, Space.md)
    }

    private func submit() {
        errorMessage = nil
        isSending = true
        let version = engine.updater.currentVersion
        let selectedKind = kind
        let email = senderEmail
        let body = message

        Task {
            do {
                try await FeedbackHelper.send(
                    kind: selectedKind,
                    senderEmail: email,
                    message: body,
                    appVersion: version
                )
                isSending = false
                didSend = true
            } catch {
                isSending = false
                errorMessage = "Envoi impossible hors-ligne."
            }
        }
    }
}
