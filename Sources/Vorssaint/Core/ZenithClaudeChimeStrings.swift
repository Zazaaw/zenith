// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: what the island says when a Claude Code session waits for the
// person, and the choice Settings → Dynamic Island → AI Agents offers for it.

struct ZenithClaudeChimeStrings {
    /// The choice's title and caption.
    let alert: String
    let alertCaption: String
    /// Its options.
    let off: String
    let soundAndIsland: String
    /// The island's burst.
    let needsYou: String
}

extension ZenithStrings {
    static func claudeChime(_ language: AppLanguage) -> ZenithClaudeChimeStrings {
        switch language {
        case .enUS:
            return .init(alert: "When Claude needs you",
                         alertCaption: "A soft sound with the island showing which project, at most once per session every 3 minutes",
                         off: "Off", soundAndIsland: "Sound + island", needsYou: "Claude needs you")
        case .ptBR:
            return .init(alert: "Quando o Claude precisar de você",
                         alertCaption: "Um som suave com a ilha mostrando o projeto, no máximo uma vez por sessão a cada 3 minutos",
                         off: "Desligado", soundAndIsland: "Som + ilha", needsYou: "O Claude precisa de você")
        case .tr:
            return .init(alert: "Claude sana ihtiyaç duyduğunda",
                         alertCaption: "Hangi proje olduğunu gösteren adayla yumuşak bir ses, oturum başına en fazla 3 dakikada bir",
                         off: "Kapalı", soundAndIsland: "Ses + ada", needsYou: "Claude seni bekliyor")
        case .ru:
            return .init(alert: "Когда Claude нужна ваша помощь",
                         alertCaption: "Тихий звук и остров с названием проекта, не чаще раза в 3 минуты на сеанс",
                         off: "Выкл.", soundAndIsland: "Звук + остров", needsYou: "Claude ждёт вас")
        case .es:
            return .init(alert: "Cuando Claude te necesite",
                         alertCaption: "Un sonido suave con la isla mostrando el proyecto, como mucho una vez por sesión cada 3 minutos",
                         off: "Desactivado", soundAndIsland: "Sonido + isla", needsYou: "Claude te necesita")
        case .sk:
            return .init(alert: "Keď ťa Claude potrebuje",
                         alertCaption: "Jemný zvuk a ostrov s názvom projektu, najviac raz za 3 minúty na reláciu",
                         off: "Vypnuté", soundAndIsland: "Zvuk + ostrov", needsYou: "Claude ťa potrebuje")
        case .de:
            return .init(alert: "Wenn Claude dich braucht",
                         alertCaption: "Ein leiser Ton mit der Insel, die das Projekt zeigt, höchstens einmal pro Sitzung alle 3 Minuten",
                         off: "Aus", soundAndIsland: "Ton + Insel", needsYou: "Claude braucht dich")
        case .fr:
            return .init(alert: "Quand Claude a besoin de vous",
                         alertCaption: "Un son discret avec l’île qui montre le projet, au plus une fois par session toutes les 3 minutes",
                         off: "Désactivé", soundAndIsland: "Son + île", needsYou: "Claude a besoin de vous")
        case .it:
            return .init(alert: "Quando Claude ha bisogno di te",
                         alertCaption: "Un suono leggero con l’isola che mostra il progetto, al massimo una volta per sessione ogni 3 minuti",
                         off: "Disattivato", soundAndIsland: "Suono + isola", needsYou: "Claude ha bisogno di te")
        case .ja:
            return .init(alert: "Claude があなたを待っているとき",
                         alertCaption: "控えめな音とプロジェクト名を表示するアイランド。1 セッションにつき最大 3 分に 1 回",
                         off: "オフ", soundAndIsland: "サウンド + アイランド", needsYou: "Claude が待っています")
        case .ko:
            return .init(alert: "Claude가 기다릴 때",
                         alertCaption: "프로젝트를 보여 주는 아일랜드와 부드러운 소리, 세션당 최대 3분에 한 번",
                         off: "끔", soundAndIsland: "소리 + 아일랜드", needsYou: "Claude가 기다리고 있어요")
        case .uk:
            return .init(alert: "Коли Claude потрібна ваша допомога",
                         alertCaption: "Тихий звук і острів із назвою проєкту, не частіше разу на 3 хвилини для сеансу",
                         off: "Вимк.", soundAndIsland: "Звук + острів", needsYou: "Claude чекає на вас")
        case .zhHans:
            return .init(alert: "Claude 需要你时",
                         alertCaption: "轻柔的提示音，灵动岛显示是哪个项目；每个会话最多每 3 分钟一次",
                         off: "关闭", soundAndIsland: "声音 + 灵动岛", needsYou: "Claude 需要你")
        case .zhTW:
            return .init(alert: "Claude 需要你時",
                         alertCaption: "輕柔的提示音，動態島顯示是哪個專案；每個工作階段最多每 3 分鐘一次",
                         off: "關閉", soundAndIsland: "聲音 + 動態島", needsYou: "Claude 需要你")
        case .zhHK:
            return .init(alert: "Claude 需要你時",
                         alertCaption: "輕柔的提示音，動態島顯示係邊個專案；每個工作階段最多每 3 分鐘一次",
                         off: "關閉", soundAndIsland: "聲音 + 動態島", needsYou: "Claude 需要你")
        }
    }
}
