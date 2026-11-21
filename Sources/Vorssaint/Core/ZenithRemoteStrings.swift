// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Settings → iPhone Remote. What the island and the iPhone read
// is English (RemoteText); the page itself follows the app's language.

struct ZenithRemoteStrings {
    let title: String
    let subtitle: String
    let enable: String
    let enableCaption: String
    // Checklist.
    let checklist: String
    let remoteLogin: String
    let remoteLoginOn: String
    let remoteLoginOff: String
    let tailscale: String
    /// `{host}` is this Mac's Tailscale name.
    let tailscaleConnected: String
    let tailscaleSignedOut: String
    let tailscaleMissing: String
    let checkAgain: String
    // Devices.
    let devices: String
    let devicesCaption: String
    let deviceName: String
    let publicKey: String
    let add: String
    let remove: String
    let noDevices: String
    let invalidKey: String
    let conflict: String
    let isLink: String
    let failed: String
    let added: String
    // The Shortcut's fields.
    let shortcut: String
    let shortcutCaption: String
    let host: String
    let user: String
    let port: String
    let lockScript: String
    let statusScript: String
    let copy: String
    // Test.
    let test: String
    let testCaption: String
    let testOff: String
    // Hardening.
    let hardening: String
    let hardeningCaption: String
    // Recent requests.
    let recent: String
    let recentEmpty: String
    let verbLock: String
    let verbStatus: String
    let refused: String

    func connected(_ host: String) -> String { tailscaleConnected.replacingOccurrences(of: "{host}", with: host) }

    /// Every string, for the coverage tests.
    var all: [String] {
        [title, subtitle, enable, enableCaption, checklist, remoteLogin, remoteLoginOn, remoteLoginOff, tailscale,
         tailscaleConnected, tailscaleSignedOut, tailscaleMissing, checkAgain, devices, devicesCaption, deviceName,
         publicKey, add, remove, noDevices, invalidKey, conflict, isLink, failed, added, shortcut, shortcutCaption,
         host, user, port, lockScript, statusScript, copy, test, testCaption, testOff, hardening, hardeningCaption,
         recent, recentEmpty, verbLock, verbStatus, refused]
    }
}

extension ZenithStrings {
    static func remote(_ language: AppLanguage) -> ZenithRemoteStrings {
        switch language {
        case .enUS:
            return .init(
                title: "iPhone Remote",
                subtitle: "Lock this Mac or check on it from your iPhone, through Shortcuts, Tailscale and SSH.",
                enable: "Lock and check status from iPhone",
                enableCaption: "Your iPhone can only lock this Mac or ask how it is. Zenith never unlocks it or runs anything else.",
                checklist: "Checklist", remoteLogin: "Remote Login", remoteLoginOn: "On, port 22 answers",
                remoteLoginOff: "Turn on System Settings → General → Sharing → Remote Login, allowed for your account only.",
                tailscale: "Tailscale", tailscaleConnected: "Connected as {host}",
                tailscaleSignedOut: "Installed. Open Tailscale and sign in, on this Mac and on your iPhone.",
                tailscaleMissing: "Install Tailscale on this Mac and on your iPhone, and sign in to the same account.",
                checkAgain: "Check again",
                devices: "Devices",
                devicesCaption: "In Shortcuts, add “Run Script over SSH”, open its SSH Key, share the public key and paste it here.",
                deviceName: "Device name", publicKey: "Public key (ssh-ed25519 …)", add: "Add", remove: "Remove",
                noDevices: "No devices yet.", invalidKey: "That doesn’t look like an SSH public key.",
                conflict: "This key is already in authorized_keys without Zenith’s limits. Remove that line first.",
                isLink: "authorized_keys is a link, so Zenith leaves it alone.",
                failed: "Couldn’t update authorized_keys.",
                added: "Added. The previous file is kept as authorized_keys.zenith-backup.",
                shortcut: "For the Shortcut",
                shortcutCaption: "Fill these into “Run Script over SSH”, with SSH Key as the authentication.",
                host: "Host", user: "User", port: "Port", lockScript: "Lock script", statusScript: "Status script",
                copy: "Copy",
                test: "Test", testCaption: "Asks for the status on this Mac, the way your iPhone does.",
                testOff: "Turn on the switch above to test.",
                hardening: "Optional: keys only",
                hardeningCaption: "Turns off password logins over SSH, so only keys get in. Run it yourself in Terminal; it asks for your password. Zenith never runs it.",
                recent: "Recent requests", recentEmpty: "Nothing yet.", verbLock: "Lock", verbStatus: "Status",
                refused: "Refused")
        case .ptBR:
            return .init(
                title: "iPhone Remoto",
                subtitle: "Bloqueie este Mac ou veja como ele está pelo iPhone, com Atalhos, Tailscale e SSH.",
                enable: "Bloquear e ver o estado pelo iPhone",
                enableCaption: "O iPhone só pode bloquear este Mac ou perguntar como ele está. O Zenith nunca o desbloqueia nem executa outra coisa.",
                checklist: "Verificação", remoteLogin: "Início de Sessão Remoto", remoteLoginOn: "Ativado, a porta 22 responde",
                remoteLoginOff: "Ative Ajustes do Sistema → Geral → Compartilhamento → Início de Sessão Remoto, só para a sua conta.",
                tailscale: "Tailscale", tailscaleConnected: "Conectado como {host}",
                tailscaleSignedOut: "Instalado. Abra o Tailscale e inicie sessão, neste Mac e no iPhone.",
                tailscaleMissing: "Instale o Tailscale neste Mac e no iPhone e inicie sessão na mesma conta.",
                checkAgain: "Verificar de novo",
                devices: "Dispositivos",
                devicesCaption: "Em Atalhos, adicione “Executar Script via SSH”, abra a Chave SSH, compartilhe a chave pública e cole aqui.",
                deviceName: "Nome do dispositivo", publicKey: "Chave pública (ssh-ed25519 …)", add: "Adicionar",
                remove: "Remover", noDevices: "Nenhum dispositivo ainda.",
                invalidKey: "Isso não parece uma chave pública SSH.",
                conflict: "Esta chave já está em authorized_keys sem os limites do Zenith. Remova essa linha primeiro.",
                isLink: "authorized_keys é um link, então o Zenith não mexe nele.",
                failed: "Não foi possível atualizar authorized_keys.",
                added: "Adicionado. O arquivo anterior fica em authorized_keys.zenith-backup.",
                shortcut: "Para o atalho",
                shortcutCaption: "Preencha estes campos em “Executar Script via SSH”, com Chave SSH como autenticação.",
                host: "Host", user: "Usuário", port: "Porta", lockScript: "Script de bloqueio",
                statusScript: "Script de estado", copy: "Copiar",
                test: "Testar", testCaption: "Pede o estado neste Mac, do mesmo jeito que o iPhone.",
                testOff: "Ative o botão acima para testar.",
                hardening: "Opcional: só chaves",
                hardeningCaption: "Desativa o início de sessão com senha por SSH, então só chaves entram. Execute você mesmo no Terminal; ele pede a sua senha. O Zenith nunca o executa.",
                recent: "Pedidos recentes", recentEmpty: "Nada ainda.", verbLock: "Bloquear", verbStatus: "Estado",
                refused: "Recusado")
        case .tr:
            return .init(
                title: "iPhone Uzaktan",
                subtitle: "Bu Mac’i iPhone’dan kilitleyin veya durumuna bakın; Kestirmeler, Tailscale ve SSH ile.",
                enable: "iPhone’dan kilitle ve durumu gör",
                enableCaption: "iPhone yalnızca bu Mac’i kilitleyebilir veya durumunu sorabilir. Zenith kilidi asla açmaz ve başka bir şey çalıştırmaz.",
                checklist: "Kontrol listesi", remoteLogin: "Uzaktan Giriş", remoteLoginOn: "Açık, 22 numaralı kapı yanıt veriyor",
                remoteLoginOff: "Sistem Ayarları → Genel → Paylaşma → Uzaktan Giriş’i açın, yalnızca sizin hesabınız için.",
                tailscale: "Tailscale", tailscaleConnected: "{host} olarak bağlı",
                tailscaleSignedOut: "Yüklü. Bu Mac’te ve iPhone’da Tailscale’i açıp giriş yapın.",
                tailscaleMissing: "Tailscale’i bu Mac’e ve iPhone’a yükleyin, aynı hesapla giriş yapın.",
                checkAgain: "Yeniden denetle",
                devices: "Aygıtlar",
                devicesCaption: "Kestirmeler’de “SSH Üzerinden Betik Çalıştır” ekleyin, SSH Anahtarı’nı açın, genel anahtarı paylaşıp buraya yapıştırın.",
                deviceName: "Aygıt adı", publicKey: "Genel anahtar (ssh-ed25519 …)", add: "Ekle", remove: "Kaldır",
                noDevices: "Henüz aygıt yok.", invalidKey: "Bu bir SSH genel anahtarına benzemiyor.",
                conflict: "Bu anahtar authorized_keys içinde Zenith sınırları olmadan zaten var. Önce o satırı kaldırın.",
                isLink: "authorized_keys bir bağlantı, bu yüzden Zenith ona dokunmuyor.",
                failed: "authorized_keys güncellenemedi.",
                added: "Eklendi. Önceki dosya authorized_keys.zenith-backup olarak saklandı.",
                shortcut: "Kestirme için",
                shortcutCaption: "Bunları “SSH Üzerinden Betik Çalıştır” içine girin; kimlik doğrulama SSH Anahtarı olsun.",
                host: "Sunucu", user: "Kullanıcı", port: "Kapı", lockScript: "Kilit betiği", statusScript: "Durum betiği",
                copy: "Kopyala",
                test: "Dene", testCaption: "Durumu bu Mac’te, iPhone’un yaptığı gibi sorar.",
                testOff: "Denemek için yukarıdaki anahtarı açın.",
                hardening: "İsteğe bağlı: yalnızca anahtarlar",
                hardeningCaption: "SSH üzerinden parolayla girişi kapatır, yalnızca anahtarlar girebilir. Terminal’de kendiniz çalıştırın; parolanızı sorar. Zenith bunu asla çalıştırmaz.",
                recent: "Son istekler", recentEmpty: "Henüz bir şey yok.", verbLock: "Kilitle", verbStatus: "Durum",
                refused: "Reddedildi")
        case .ru:
            return .init(
                title: "Пульт с iPhone",
                subtitle: "Блокируйте этот Mac или узнавайте его состояние с iPhone через Команды, Tailscale и SSH.",
                enable: "Блокировка и состояние с iPhone",
                enableCaption: "iPhone может только заблокировать этот Mac или спросить, как он. Zenith никогда не снимает блокировку и ничего больше не запускает.",
                checklist: "Проверка", remoteLogin: "Удалённый вход", remoteLoginOn: "Включён, порт 22 отвечает",
                remoteLoginOff: "Включите Системные настройки → Основные → Общий доступ → Удалённый вход, только для вашей учётной записи.",
                tailscale: "Tailscale", tailscaleConnected: "Подключён как {host}",
                tailscaleSignedOut: "Установлен. Откройте Tailscale и войдите на этом Mac и на iPhone.",
                tailscaleMissing: "Установите Tailscale на этот Mac и на iPhone и войдите в одну учётную запись.",
                checkAgain: "Проверить снова",
                devices: "Устройства",
                devicesCaption: "В Командах добавьте «Запустить скрипт по SSH», откройте ключ SSH, поделитесь открытым ключом и вставьте его сюда.",
                deviceName: "Имя устройства", publicKey: "Открытый ключ (ssh-ed25519 …)", add: "Добавить",
                remove: "Удалить", noDevices: "Устройств пока нет.",
                invalidKey: "Это не похоже на открытый ключ SSH.",
                conflict: "Этот ключ уже есть в authorized_keys без ограничений Zenith. Сначала удалите ту строку.",
                isLink: "authorized_keys является ссылкой, поэтому Zenith его не трогает.",
                failed: "Не удалось обновить authorized_keys.",
                added: "Добавлено. Прежний файл сохранён как authorized_keys.zenith-backup.",
                shortcut: "Для быстрой команды",
                shortcutCaption: "Заполните эти поля в «Запустить скрипт по SSH», аутентификация: ключ SSH.",
                host: "Хост", user: "Пользователь", port: "Порт", lockScript: "Скрипт блокировки",
                statusScript: "Скрипт состояния", copy: "Скопировать",
                test: "Проверить", testCaption: "Запрашивает состояние на этом Mac так же, как iPhone.",
                testOff: "Включите переключатель выше, чтобы проверить.",
                hardening: "Дополнительно: только ключи",
                hardeningCaption: "Отключает вход по паролю через SSH, остаются только ключи. Запустите это сами в Терминале; потребуется ваш пароль. Zenith никогда это не запускает.",
                recent: "Последние запросы", recentEmpty: "Пока ничего.", verbLock: "Блокировка", verbStatus: "Состояние",
                refused: "Отклонён")
        case .es:
            return .init(
                title: "iPhone remoto",
                subtitle: "Bloquea este Mac o mira cómo está desde tu iPhone, con Atajos, Tailscale y SSH.",
                enable: "Bloquear y ver el estado desde el iPhone",
                enableCaption: "Tu iPhone solo puede bloquear este Mac o preguntar cómo está. Zenith nunca lo desbloquea ni ejecuta nada más.",
                checklist: "Comprobación", remoteLogin: "Sesión remota", remoteLoginOn: "Activada, el puerto 22 responde",
                remoteLoginOff: "Activa Ajustes del Sistema → General → Compartir → Sesión remota, solo para tu cuenta.",
                tailscale: "Tailscale", tailscaleConnected: "Conectado como {host}",
                tailscaleSignedOut: "Instalado. Abre Tailscale e inicia sesión en este Mac y en tu iPhone.",
                tailscaleMissing: "Instala Tailscale en este Mac y en tu iPhone e inicia sesión con la misma cuenta.",
                checkAgain: "Comprobar de nuevo",
                devices: "Dispositivos",
                devicesCaption: "En Atajos, añade “Ejecutar script por SSH”, abre su clave SSH, comparte la clave pública y pégala aquí.",
                deviceName: "Nombre del dispositivo", publicKey: "Clave pública (ssh-ed25519 …)", add: "Añadir",
                remove: "Eliminar", noDevices: "Aún no hay dispositivos.",
                invalidKey: "Eso no parece una clave pública SSH.",
                conflict: "Esta clave ya está en authorized_keys sin los límites de Zenith. Elimina esa línea primero.",
                isLink: "authorized_keys es un enlace, así que Zenith no lo toca.",
                failed: "No se pudo actualizar authorized_keys.",
                added: "Añadido. El archivo anterior se guarda como authorized_keys.zenith-backup.",
                shortcut: "Para el atajo",
                shortcutCaption: "Rellena estos campos en “Ejecutar script por SSH”, con clave SSH como autenticación.",
                host: "Host", user: "Usuario", port: "Puerto", lockScript: "Script de bloqueo",
                statusScript: "Script de estado", copy: "Copiar",
                test: "Probar", testCaption: "Pide el estado en este Mac, igual que tu iPhone.",
                testOff: "Activa el interruptor de arriba para probar.",
                hardening: "Opcional: solo claves",
                hardeningCaption: "Desactiva el inicio de sesión con contraseña por SSH, así solo entran claves. Ejecútalo tú en Terminal; te pedirá la contraseña. Zenith nunca lo ejecuta.",
                recent: "Solicitudes recientes", recentEmpty: "Nada todavía.", verbLock: "Bloquear", verbStatus: "Estado",
                refused: "Rechazada")
        case .sk:
            return .init(
                title: "iPhone na diaľku",
                subtitle: "Zamknite tento Mac alebo zistite, ako sa má, z iPhonu cez Skratky, Tailscale a SSH.",
                enable: "Zamykať a zisťovať stav z iPhonu",
                enableCaption: "iPhone môže tento Mac iba zamknúť alebo sa spýtať, ako sa má. Zenith ho nikdy neodomkne ani nespustí nič iné.",
                checklist: "Kontrola", remoteLogin: "Vzdialené prihlásenie", remoteLoginOn: "Zapnuté, port 22 odpovedá",
                remoteLoginOff: "Zapnite Systémové nastavenia → Všeobecné → Zdieľanie → Vzdialené prihlásenie, len pre váš účet.",
                tailscale: "Tailscale", tailscaleConnected: "Pripojené ako {host}",
                tailscaleSignedOut: "Nainštalované. Otvorte Tailscale a prihláste sa na tomto Macu aj v iPhone.",
                tailscaleMissing: "Nainštalujte Tailscale na tento Mac aj do iPhonu a prihláste sa do rovnakého účtu.",
                checkAgain: "Skontrolovať znova",
                devices: "Zariadenia",
                devicesCaption: "V Skratkách pridajte „Spustiť skript cez SSH“, otvorte jeho kľúč SSH, zdieľajte verejný kľúč a vložte ho sem.",
                deviceName: "Názov zariadenia", publicKey: "Verejný kľúč (ssh-ed25519 …)", add: "Pridať",
                remove: "Odstrániť", noDevices: "Zatiaľ žiadne zariadenia.",
                invalidKey: "Toto nevyzerá ako verejný kľúč SSH.",
                conflict: "Tento kľúč už je v authorized_keys bez obmedzení Zenithu. Najprv odstráňte ten riadok.",
                isLink: "authorized_keys je odkaz, preto ho Zenith nechá tak.",
                failed: "authorized_keys sa nepodarilo upraviť.",
                added: "Pridané. Predchádzajúci súbor je uložený ako authorized_keys.zenith-backup.",
                shortcut: "Pre skratku",
                shortcutCaption: "Vyplňte tieto polia v „Spustiť skript cez SSH“, s overením cez kľúč SSH.",
                host: "Hostiteľ", user: "Používateľ", port: "Port", lockScript: "Skript zamknutia",
                statusScript: "Skript stavu", copy: "Kopírovať",
                test: "Vyskúšať", testCaption: "Opýta sa na stav na tomto Macu rovnako ako iPhone.",
                testOff: "Na vyskúšanie zapnite prepínač vyššie.",
                hardening: "Voliteľné: iba kľúče",
                hardeningCaption: "Vypne prihlasovanie heslom cez SSH, dnu sa dostanú iba kľúče. Spustite to sami v Termináli; vypýta si vaše heslo. Zenith to nikdy nespúšťa.",
                recent: "Posledné požiadavky", recentEmpty: "Zatiaľ nič.", verbLock: "Zamknúť", verbStatus: "Stav",
                refused: "Odmietnuté")
        case .de:
            return .init(
                title: "iPhone-Fernbedienung",
                subtitle: "Sperre diesen Mac oder sieh nach, wie es ihm geht, vom iPhone aus, mit Kurzbefehlen, Tailscale und SSH.",
                enable: "Vom iPhone sperren und Status abfragen",
                enableCaption: "Dein iPhone kann diesen Mac nur sperren oder nach seinem Zustand fragen. Zenith entsperrt ihn nie und führt nichts anderes aus.",
                checklist: "Checkliste", remoteLogin: "Entfernte Anmeldung", remoteLoginOn: "Ein, Port 22 antwortet",
                remoteLoginOff: "Aktiviere Systemeinstellungen → Allgemein → Teilen → Entfernte Anmeldung, nur für deinen Account.",
                tailscale: "Tailscale", tailscaleConnected: "Verbunden als {host}",
                tailscaleSignedOut: "Installiert. Öffne Tailscale und melde dich an, auf diesem Mac und auf dem iPhone.",
                tailscaleMissing: "Installiere Tailscale auf diesem Mac und auf dem iPhone und melde dich mit demselben Account an.",
                checkAgain: "Erneut prüfen",
                devices: "Geräte",
                devicesCaption: "Füge in Kurzbefehle „Skript über SSH ausführen“ hinzu, öffne den SSH-Schlüssel, teile den öffentlichen Schlüssel und füge ihn hier ein.",
                deviceName: "Gerätename", publicKey: "Öffentlicher Schlüssel (ssh-ed25519 …)", add: "Hinzufügen",
                remove: "Entfernen", noDevices: "Noch keine Geräte.",
                invalidKey: "Das sieht nicht nach einem öffentlichen SSH-Schlüssel aus.",
                conflict: "Dieser Schlüssel steht schon ohne die Grenzen von Zenith in authorized_keys. Entferne zuerst diese Zeile.",
                isLink: "authorized_keys ist ein Link, deshalb lässt Zenith die Datei in Ruhe.",
                failed: "authorized_keys konnte nicht aktualisiert werden.",
                added: "Hinzugefügt. Die bisherige Datei liegt als authorized_keys.zenith-backup bereit.",
                shortcut: "Für den Kurzbefehl",
                shortcutCaption: "Trage das in „Skript über SSH ausführen“ ein, mit SSH-Schlüssel als Authentifizierung.",
                host: "Host", user: "Benutzer", port: "Port", lockScript: "Sperr-Skript", statusScript: "Status-Skript",
                copy: "Kopieren",
                test: "Testen", testCaption: "Fragt den Status auf diesem Mac ab, so wie dein iPhone.",
                testOff: "Schalte oben den Schalter ein, um zu testen.",
                hardening: "Optional: nur Schlüssel",
                hardeningCaption: "Schaltet die Anmeldung per Passwort über SSH ab, nur Schlüssel kommen noch rein. Führe es selbst im Terminal aus; es fragt nach deinem Passwort. Zenith führt es nie aus.",
                recent: "Letzte Anfragen", recentEmpty: "Noch nichts.", verbLock: "Sperren", verbStatus: "Status",
                refused: "Abgelehnt")
        case .fr:
            return .init(
                title: "iPhone à distance",
                subtitle: "Verrouillez ce Mac ou voyez comment il va depuis votre iPhone, avec Raccourcis, Tailscale et SSH.",
                enable: "Verrouiller et voir l’état depuis l’iPhone",
                enableCaption: "Votre iPhone peut seulement verrouiller ce Mac ou demander comment il va. Zenith ne le déverrouille jamais et n’exécute rien d’autre.",
                checklist: "Vérifications", remoteLogin: "Session à distance", remoteLoginOn: "Activée, le port 22 répond",
                remoteLoginOff: "Activez Réglages Système → Général → Partage → Session à distance, pour votre compte seulement.",
                tailscale: "Tailscale", tailscaleConnected: "Connecté en tant que {host}",
                tailscaleSignedOut: "Installé. Ouvrez Tailscale et connectez-vous, sur ce Mac et sur l’iPhone.",
                tailscaleMissing: "Installez Tailscale sur ce Mac et sur l’iPhone, et connectez-vous au même compte.",
                checkAgain: "Vérifier à nouveau",
                devices: "Appareils",
                devicesCaption: "Dans Raccourcis, ajoutez « Exécuter le script via SSH », ouvrez sa clé SSH, partagez la clé publique et collez-la ici.",
                deviceName: "Nom de l’appareil", publicKey: "Clé publique (ssh-ed25519 …)", add: "Ajouter",
                remove: "Supprimer", noDevices: "Aucun appareil pour l’instant.",
                invalidKey: "Cela ne ressemble pas à une clé publique SSH.",
                conflict: "Cette clé est déjà dans authorized_keys sans les limites de Zenith. Supprimez d’abord cette ligne.",
                isLink: "authorized_keys est un lien, Zenith n’y touche donc pas.",
                failed: "Impossible de mettre à jour authorized_keys.",
                added: "Ajouté. L’ancien fichier est conservé sous authorized_keys.zenith-backup.",
                shortcut: "Pour le raccourci",
                shortcutCaption: "Remplissez ces champs dans « Exécuter le script via SSH », avec la clé SSH comme authentification.",
                host: "Hôte", user: "Utilisateur", port: "Port", lockScript: "Script de verrouillage",
                statusScript: "Script d’état", copy: "Copier",
                test: "Tester", testCaption: "Demande l’état sur ce Mac, comme le fait votre iPhone.",
                testOff: "Activez l’interrupteur ci-dessus pour tester.",
                hardening: "Facultatif : clés seulement",
                hardeningCaption: "Désactive la connexion par mot de passe via SSH, seules les clés entrent. Lancez-le vous-même dans Terminal ; il demande votre mot de passe. Zenith ne le lance jamais.",
                recent: "Demandes récentes", recentEmpty: "Rien pour l’instant.", verbLock: "Verrouiller",
                verbStatus: "État", refused: "Refusée")
        case .it:
            return .init(
                title: "iPhone remoto",
                subtitle: "Blocca questo Mac o guarda come sta dall’iPhone, con Comandi rapidi, Tailscale e SSH.",
                enable: "Blocca e controlla lo stato dall’iPhone",
                enableCaption: "L’iPhone può solo bloccare questo Mac o chiedere come sta. Zenith non lo sblocca mai e non esegue nient’altro.",
                checklist: "Controlli", remoteLogin: "Login remoto", remoteLoginOn: "Attivo, la porta 22 risponde",
                remoteLoginOff: "Attiva Impostazioni di Sistema → Generali → Condivisione → Login remoto, solo per il tuo account.",
                tailscale: "Tailscale", tailscaleConnected: "Connesso come {host}",
                tailscaleSignedOut: "Installato. Apri Tailscale e accedi, su questo Mac e sull’iPhone.",
                tailscaleMissing: "Installa Tailscale su questo Mac e sull’iPhone e accedi con lo stesso account.",
                checkAgain: "Controlla di nuovo",
                devices: "Dispositivi",
                devicesCaption: "In Comandi rapidi aggiungi “Esegui script via SSH”, apri la chiave SSH, condividi la chiave pubblica e incollala qui.",
                deviceName: "Nome del dispositivo", publicKey: "Chiave pubblica (ssh-ed25519 …)", add: "Aggiungi",
                remove: "Rimuovi", noDevices: "Ancora nessun dispositivo.",
                invalidKey: "Non sembra una chiave pubblica SSH.",
                conflict: "Questa chiave è già in authorized_keys senza i limiti di Zenith. Rimuovi prima quella riga.",
                isLink: "authorized_keys è un collegamento, quindi Zenith non lo tocca.",
                failed: "Impossibile aggiornare authorized_keys.",
                added: "Aggiunto. Il file precedente è conservato come authorized_keys.zenith-backup.",
                shortcut: "Per il comando rapido",
                shortcutCaption: "Compila questi campi in “Esegui script via SSH”, con la chiave SSH come autenticazione.",
                host: "Host", user: "Utente", port: "Porta", lockScript: "Script di blocco",
                statusScript: "Script di stato", copy: "Copia",
                test: "Prova", testCaption: "Chiede lo stato su questo Mac, come fa l’iPhone.",
                testOff: "Attiva l’interruttore qui sopra per provare.",
                hardening: "Facoltativo: solo chiavi",
                hardeningCaption: "Disattiva l’accesso con password via SSH, così entrano solo le chiavi. Eseguilo tu nel Terminale; chiede la tua password. Zenith non lo esegue mai.",
                recent: "Richieste recenti", recentEmpty: "Ancora niente.", verbLock: "Blocca", verbStatus: "Stato",
                refused: "Rifiutata")
        case .ja:
            return .init(
                title: "iPhone リモート",
                subtitle: "ショートカット、Tailscale、SSH で、iPhone からこの Mac をロックしたり様子を確認したりできます。",
                enable: "iPhone からロックと状態の確認",
                enableCaption: "iPhone ができるのはこの Mac のロックと状態の確認だけです。Zenith がロックを解除したり、ほかのものを実行したりすることはありません。",
                checklist: "チェックリスト", remoteLogin: "リモートログイン", remoteLoginOn: "オン、ポート 22 が応答",
                remoteLoginOff: "システム設定 → 一般 → 共有 → リモートログインをオンにし、自分のアカウントだけに許可してください。",
                tailscale: "Tailscale", tailscaleConnected: "{host} として接続中",
                tailscaleSignedOut: "インストール済み。この Mac と iPhone で Tailscale を開いてサインインしてください。",
                tailscaleMissing: "この Mac と iPhone に Tailscale をインストールし、同じアカウントでサインインしてください。",
                checkAgain: "もう一度確認",
                devices: "デバイス",
                devicesCaption: "ショートカットで「SSH 経由でスクリプトを実行」を追加し、SSH 鍵を開いて公開鍵を共有し、ここに貼り付けてください。",
                deviceName: "デバイス名", publicKey: "公開鍵 (ssh-ed25519 …)", add: "追加", remove: "削除",
                noDevices: "デバイスはまだありません。", invalidKey: "SSH の公開鍵ではないようです。",
                conflict: "この鍵は Zenith の制限なしで authorized_keys にすでにあります。先にその行を削除してください。",
                isLink: "authorized_keys はリンクなので、Zenith は変更しません。",
                failed: "authorized_keys を更新できませんでした。",
                added: "追加しました。以前のファイルは authorized_keys.zenith-backup として残っています。",
                shortcut: "ショートカット用",
                shortcutCaption: "「SSH 経由でスクリプトを実行」にこれらを入力し、認証は SSH 鍵にしてください。",
                host: "ホスト", user: "ユーザ", port: "ポート", lockScript: "ロックのスクリプト",
                statusScript: "状態のスクリプト", copy: "コピー",
                test: "テスト", testCaption: "iPhone と同じ方法で、この Mac で状態を問い合わせます。",
                testOff: "テストするには上のスイッチをオンにしてください。",
                hardening: "オプション: 鍵のみ",
                hardeningCaption: "SSH のパスワードログインをオフにし、鍵だけで入れるようにします。ターミナルで自分で実行してください。パスワードを求められます。Zenith が実行することはありません。",
                recent: "最近のリクエスト", recentEmpty: "まだありません。", verbLock: "ロック", verbStatus: "状態",
                refused: "拒否")
        case .ko:
            return .init(
                title: "iPhone 원격",
                subtitle: "단축어, Tailscale, SSH로 iPhone에서 이 Mac을 잠그거나 상태를 확인하세요.",
                enable: "iPhone에서 잠그고 상태 확인",
                enableCaption: "iPhone은 이 Mac을 잠그거나 상태를 묻는 것만 할 수 있습니다. Zenith는 잠금을 해제하거나 다른 것을 실행하지 않습니다.",
                checklist: "확인 목록", remoteLogin: "원격 로그인", remoteLoginOn: "켜짐, 포트 22 응답",
                remoteLoginOff: "시스템 설정 → 일반 → 공유 → 원격 로그인을 켜고 내 계정만 허용하세요.",
                tailscale: "Tailscale", tailscaleConnected: "{host}(으)로 연결됨",
                tailscaleSignedOut: "설치됨. 이 Mac과 iPhone에서 Tailscale을 열고 로그인하세요.",
                tailscaleMissing: "이 Mac과 iPhone에 Tailscale을 설치하고 같은 계정으로 로그인하세요.",
                checkAgain: "다시 확인",
                devices: "기기",
                devicesCaption: "단축어에서 ‘SSH를 통해 스크립트 실행’을 추가하고 SSH 키를 열어 공개 키를 공유한 다음 여기에 붙여 넣으세요.",
                deviceName: "기기 이름", publicKey: "공개 키(ssh-ed25519 …)", add: "추가", remove: "제거",
                noDevices: "아직 기기가 없습니다.", invalidKey: "SSH 공개 키가 아닌 것 같습니다.",
                conflict: "이 키는 Zenith 제한 없이 authorized_keys에 이미 있습니다. 먼저 그 줄을 제거하세요.",
                isLink: "authorized_keys가 링크이므로 Zenith는 건드리지 않습니다.",
                failed: "authorized_keys를 업데이트할 수 없습니다.",
                added: "추가했습니다. 이전 파일은 authorized_keys.zenith-backup으로 보관됩니다.",
                shortcut: "단축어용",
                shortcutCaption: "‘SSH를 통해 스크립트 실행’에 이 값을 입력하고 인증은 SSH 키로 하세요.",
                host: "호스트", user: "사용자", port: "포트", lockScript: "잠금 스크립트", statusScript: "상태 스크립트",
                copy: "복사",
                test: "테스트", testCaption: "iPhone과 같은 방식으로 이 Mac에서 상태를 요청합니다.",
                testOff: "테스트하려면 위의 스위치를 켜세요.",
                hardening: "선택 사항: 키만 허용",
                hardeningCaption: "SSH 암호 로그인을 꺼서 키로만 들어올 수 있게 합니다. 터미널에서 직접 실행하세요. 암호를 묻습니다. Zenith는 절대 실행하지 않습니다.",
                recent: "최근 요청", recentEmpty: "아직 없습니다.", verbLock: "잠금", verbStatus: "상태",
                refused: "거부됨")
        case .uk:
            return .init(
                title: "Пульт з iPhone",
                subtitle: "Блокуйте цей Mac або дізнавайтеся його стан з iPhone через Швидкі команди, Tailscale і SSH.",
                enable: "Блокування й стан з iPhone",
                enableCaption: "iPhone може лише заблокувати цей Mac або спитати, як він. Zenith ніколи не знімає блокування і нічого іншого не запускає.",
                checklist: "Перевірка", remoteLogin: "Віддалений вхід", remoteLoginOn: "Увімкнено, порт 22 відповідає",
                remoteLoginOff: "Увімкніть Системні параметри → Загальні → Спільний доступ → Віддалений вхід, лише для вашого облікового запису.",
                tailscale: "Tailscale", tailscaleConnected: "Підключено як {host}",
                tailscaleSignedOut: "Встановлено. Відкрийте Tailscale і увійдіть на цьому Mac та на iPhone.",
                tailscaleMissing: "Встановіть Tailscale на цей Mac і на iPhone та увійдіть в один обліковий запис.",
                checkAgain: "Перевірити знову",
                devices: "Пристрої",
                devicesCaption: "У Швидких командах додайте «Виконати скрипт через SSH», відкрийте ключ SSH, поділіться відкритим ключем і вставте його сюди.",
                deviceName: "Назва пристрою", publicKey: "Відкритий ключ (ssh-ed25519 …)", add: "Додати",
                remove: "Вилучити", noDevices: "Пристроїв ще немає.",
                invalidKey: "Це не схоже на відкритий ключ SSH.",
                conflict: "Цей ключ уже є в authorized_keys без обмежень Zenith. Спершу вилучіть той рядок.",
                isLink: "authorized_keys є посиланням, тож Zenith його не чіпає.",
                failed: "Не вдалося оновити authorized_keys.",
                added: "Додано. Попередній файл збережено як authorized_keys.zenith-backup.",
                shortcut: "Для швидкої команди",
                shortcutCaption: "Заповніть ці поля у «Виконати скрипт через SSH», автентифікація: ключ SSH.",
                host: "Хост", user: "Користувач", port: "Порт", lockScript: "Скрипт блокування",
                statusScript: "Скрипт стану", copy: "Скопіювати",
                test: "Перевірити", testCaption: "Запитує стан на цьому Mac так само, як iPhone.",
                testOff: "Увімкніть перемикач вище, щоб перевірити.",
                hardening: "Додатково: лише ключі",
                hardeningCaption: "Вимикає вхід за паролем через SSH, лишаються тільки ключі. Запустіть це самі в Терміналі; знадобиться ваш пароль. Zenith ніколи цього не запускає.",
                recent: "Останні запити", recentEmpty: "Поки нічого.", verbLock: "Блокування", verbStatus: "Стан",
                refused: "Відхилено")
        case .zhHans:
            return .init(
                title: "iPhone 遥控",
                subtitle: "通过快捷指令、Tailscale 和 SSH，在 iPhone 上锁定这台 Mac 或查看它的状态。",
                enable: "从 iPhone 锁定并查看状态",
                enableCaption: "iPhone 只能锁定这台 Mac 或询问它的状态。Zenith 绝不会解锁，也不会运行其他任何东西。",
                checklist: "检查清单", remoteLogin: "远程登录", remoteLoginOn: "已开启，端口 22 有响应",
                remoteLoginOff: "打开系统设置 → 通用 → 共享 → 远程登录，仅允许你的账户。",
                tailscale: "Tailscale", tailscaleConnected: "已连接为 {host}",
                tailscaleSignedOut: "已安装。在这台 Mac 和 iPhone 上打开 Tailscale 并登录。",
                tailscaleMissing: "在这台 Mac 和 iPhone 上安装 Tailscale，并登录同一个账户。",
                checkAgain: "再次检查",
                devices: "设备",
                devicesCaption: "在快捷指令中添加“通过 SSH 运行脚本”，打开它的 SSH 密钥，共享公钥并粘贴到这里。",
                deviceName: "设备名称", publicKey: "公钥（ssh-ed25519 …）", add: "添加", remove: "移除",
                noDevices: "还没有设备。", invalidKey: "这看起来不像 SSH 公钥。",
                conflict: "这个密钥已经在 authorized_keys 中，且没有 Zenith 的限制。请先移除那一行。",
                isLink: "authorized_keys 是一个链接，因此 Zenith 不会改动它。",
                failed: "无法更新 authorized_keys。",
                added: "已添加。之前的文件保存为 authorized_keys.zenith-backup。",
                shortcut: "用于快捷指令",
                shortcutCaption: "在“通过 SSH 运行脚本”中填写这些内容，认证方式选 SSH 密钥。",
                host: "主机", user: "用户", port: "端口", lockScript: "锁定脚本", statusScript: "状态脚本", copy: "拷贝",
                test: "测试", testCaption: "像 iPhone 一样在这台 Mac 上请求状态。",
                testOff: "打开上方的开关后即可测试。",
                hardening: "可选：仅限密钥",
                hardeningCaption: "关闭 SSH 的密码登录，只允许密钥进入。请自己在终端中运行，它会要求你的密码。Zenith 绝不会运行它。",
                recent: "最近的请求", recentEmpty: "还没有。", verbLock: "锁定", verbStatus: "状态", refused: "已拒绝")
        case .zhTW:
            return .init(
                title: "iPhone 遙控",
                subtitle: "透過捷徑、Tailscale 和 SSH，在 iPhone 上鎖定這台 Mac 或查看它的狀態。",
                enable: "從 iPhone 鎖定並查看狀態",
                enableCaption: "iPhone 只能鎖定這台 Mac 或詢問它的狀態。Zenith 絕不會解鎖，也不會執行其他任何東西。",
                checklist: "檢查清單", remoteLogin: "遠端登入", remoteLoginOn: "已開啟，埠 22 有回應",
                remoteLoginOff: "開啟系統設定 → 一般 → 共享 → 遠端登入，僅允許你的帳號。",
                tailscale: "Tailscale", tailscaleConnected: "已連線為 {host}",
                tailscaleSignedOut: "已安裝。在這台 Mac 和 iPhone 上打開 Tailscale 並登入。",
                tailscaleMissing: "在這台 Mac 和 iPhone 上安裝 Tailscale，並登入同一個帳號。",
                checkAgain: "再次檢查",
                devices: "裝置",
                devicesCaption: "在捷徑中加入「透過 SSH 執行工序指令」，打開它的 SSH 密鑰，分享公鑰並貼到這裡。",
                deviceName: "裝置名稱", publicKey: "公鑰（ssh-ed25519 …）", add: "加入", remove: "移除",
                noDevices: "還沒有裝置。", invalidKey: "這看起來不像 SSH 公鑰。",
                conflict: "這個密鑰已經在 authorized_keys 中，且沒有 Zenith 的限制。請先移除那一行。",
                isLink: "authorized_keys 是一個連結，因此 Zenith 不會更動它。",
                failed: "無法更新 authorized_keys。",
                added: "已加入。先前的檔案保留為 authorized_keys.zenith-backup。",
                shortcut: "用於捷徑",
                shortcutCaption: "在「透過 SSH 執行工序指令」中填入這些內容，認證方式選 SSH 密鑰。",
                host: "主機", user: "使用者", port: "埠", lockScript: "鎖定工序指令", statusScript: "狀態工序指令",
                copy: "拷貝",
                test: "測試", testCaption: "像 iPhone 一樣在這台 Mac 上要求狀態。",
                testOff: "打開上方的開關後即可測試。",
                hardening: "選用：僅限密鑰",
                hardeningCaption: "關閉 SSH 的密碼登入，只允許密鑰進入。請自己在終端機中執行，它會要求你的密碼。Zenith 絕不會執行它。",
                recent: "最近的要求", recentEmpty: "還沒有。", verbLock: "鎖定", verbStatus: "狀態", refused: "已拒絕")
        case .zhHK:
            return .init(
                title: "iPhone 遙控",
                subtitle: "透過捷徑、Tailscale 同 SSH，喺 iPhone 鎖定呢部 Mac 或者睇吓佢嘅狀態。",
                enable: "由 iPhone 鎖定同查看狀態",
                enableCaption: "iPhone 只可以鎖定呢部 Mac 或者問佢嘅狀態。Zenith 絕對唔會解鎖，亦唔會執行其他嘢。",
                checklist: "檢查清單", remoteLogin: "遠端登入", remoteLoginOn: "已開啟，埠 22 有回應",
                remoteLoginOff: "開啟系統設定 → 一般 → 共享 → 遠端登入，只容許你嘅帳戶。",
                tailscale: "Tailscale", tailscaleConnected: "已連線為 {host}",
                tailscaleSignedOut: "已安裝。喺呢部 Mac 同 iPhone 打開 Tailscale 並登入。",
                tailscaleMissing: "喺呢部 Mac 同 iPhone 安裝 Tailscale，並登入同一個帳戶。",
                checkAgain: "再檢查",
                devices: "裝置",
                devicesCaption: "喺捷徑加入「透過 SSH 執行工序指令」，打開佢嘅 SSH 密鑰，分享公鑰再貼喺呢度。",
                deviceName: "裝置名稱", publicKey: "公鑰（ssh-ed25519 …）", add: "加入", remove: "移除",
                noDevices: "仲未有裝置。", invalidKey: "呢個睇落唔似 SSH 公鑰。",
                conflict: "呢個密鑰已經喺 authorized_keys 入面，而且冇 Zenith 嘅限制。請先移除嗰一行。",
                isLink: "authorized_keys 係一個連結，所以 Zenith 唔會郁佢。",
                failed: "無法更新 authorized_keys。",
                added: "已加入。之前嘅檔案保留為 authorized_keys.zenith-backup。",
                shortcut: "用於捷徑",
                shortcutCaption: "喺「透過 SSH 執行工序指令」填入呢啲內容，認證方式揀 SSH 密鑰。",
                host: "主機", user: "使用者", port: "埠", lockScript: "鎖定工序指令", statusScript: "狀態工序指令",
                copy: "拷貝",
                test: "測試", testCaption: "好似 iPhone 咁喺呢部 Mac 要求狀態。",
                testOff: "打開上面嘅開關就可以測試。",
                hardening: "可選：只限密鑰",
                hardeningCaption: "關閉 SSH 嘅密碼登入，只容許密鑰入嚟。請自己喺終端機執行，佢會要求你嘅密碼。Zenith 絕對唔會執行佢。",
                recent: "最近嘅要求", recentEmpty: "仲未有。", verbLock: "鎖定", verbStatus: "狀態", refused: "已拒絕")
        }
    }
}

/// Settings search for the iPhone Remote page: its labels in the app's
/// language, and English and Indonesian words a label does not use.
enum ZenithRemoteSearch {
    static let aliases = ["kunci dari iphone", "kunci mac dari iphone", "cek status mac", "tailscale", "remote",
                          "remote login", "ssh", "lock from iphone", "iphone remote", "shortcuts", "pintasan"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.remote(language)
        return [text.enable, text.remoteLogin, text.tailscale, text.devices, text.shortcut, text.recent]
    }
}
