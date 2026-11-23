// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

// Zenith fork: text for the island's third round: the battery notices, the
// charging and prayer bursts, the collapsed capture controls and the
// calendar's week or month. Every AppLanguage has an entry. `%@` takes a
// duration already formatted for the language (ZenithPowerFormat).

struct ZenithIslandStrings {
    // Battery notices.
    let batteryLow: String
    let batteryLowHint: String
    let plugInSoon: String
    /// `%@` is the time left, as in “about 25 min left”.
    let aboutLeft: String
    let lowPowerPill: String
    let on: String
    // Charging.
    /// `%@` is the time to full, as in “Full in 1h 10m”.
    let fullIn: String
    let onHold: String
    /// macOS’s own name for the feature that holds the charge.
    let optimizedCharging: String
    let charged: String
    /// `%@` is the time left on battery, as in “4h 20m left”.
    let left: String
    // Prayer time.
    let next: String
    // Collapsed capture controls, one hint per tool.
    let dragArea: String
    let dragRecording: String
    let dragText: String
    let clickColor: String
    let dragScrolling: String
    // Calendar.
    let week: String
    let month: String
    let pickDay: String
}

extension ZenithStrings {
    static func island(_ language: AppLanguage) -> ZenithIslandStrings {
        switch language {
        case .enUS:
            return .init(batteryLow: "Battery low", batteryLowHint: "Turn on Low Power Mode to last longer",
                         plugInSoon: "Plug in soon", aboutLeft: "about %@ left", lowPowerPill: "Low Power", on: "On",
                         fullIn: "Full in %@", onHold: "On hold", optimizedCharging: "Optimized Battery Charging",
                         charged: "Fully charged", left: "%@ left", next: "Next",
                         dragArea: "Drag to choose an area", dragRecording: "Drag to choose what to record",
                         dragText: "Drag over the text to copy", clickColor: "Click to pick a color",
                         dragScrolling: "Drag over the area to scroll",
                         week: "Week", month: "Month", pickDay: "Click a day to see its events")
        case .ptBR:
            return .init(batteryLow: "Bateria fraca", batteryLowHint: "Ative o Modo Pouca Energia para durar mais",
                         plugInSoon: "Conecte logo", aboutLeft: "cerca de %@ restantes", lowPowerPill: "Pouca Energia", on: "Ativado",
                         fullIn: "Completa em %@", onHold: "Em espera", optimizedCharging: "Carregamento Otimizado",
                         charged: "Carga completa", left: "%@ restantes", next: "Próxima",
                         dragArea: "Arraste para escolher uma área", dragRecording: "Arraste para escolher o que gravar",
                         dragText: "Arraste sobre o texto para copiar", clickColor: "Clique para escolher uma cor",
                         dragScrolling: "Arraste sobre a área a rolar",
                         week: "Semana", month: "Mês", pickDay: "Clique em um dia para ver os eventos")
        case .tr:
            return .init(batteryLow: "Pil zayıf", batteryLowHint: "Daha uzun sürmesi için Düşük Güç Modu’nu aç",
                         plugInSoon: "Yakında şarja tak", aboutLeft: "yaklaşık %@ kaldı", lowPowerPill: "Düşük Güç", on: "Açık",
                         fullIn: "%@ içinde dolacak", onHold: "Beklemede", optimizedCharging: "Optimize Edilmiş Pil Şarjı",
                         charged: "Tamamen şarj oldu", left: "%@ kaldı", next: "Sıradaki",
                         dragArea: "Alan seçmek için sürükle", dragRecording: "Kaydedilecek alanı seçmek için sürükle",
                         dragText: "Kopyalamak için metnin üzerinde sürükle", clickColor: "Renk seçmek için tıkla",
                         dragScrolling: "Kaydırılacak alanın üzerinde sürükle",
                         week: "Hafta", month: "Ay", pickDay: "Etkinlikleri görmek için bir güne tıkla")
        case .ru:
            return .init(batteryLow: "Низкий заряд", batteryLowHint: "Включите режим энергосбережения, чтобы продлить работу",
                         plugInSoon: "Скоро подключите зарядку", aboutLeft: "осталось около %@", lowPowerPill: "Энергосбережение", on: "Вкл.",
                         fullIn: "Полный заряд через %@", onHold: "Приостановлено", optimizedCharging: "Оптимизированная зарядка",
                         charged: "Полностью заряжен", left: "Осталось %@", next: "Далее",
                         dragArea: "Перетащите, чтобы выбрать область", dragRecording: "Перетащите, чтобы выбрать область записи",
                         dragText: "Проведите по тексту, чтобы скопировать", clickColor: "Нажмите, чтобы выбрать цвет",
                         dragScrolling: "Проведите по области для прокрутки",
                         week: "Неделя", month: "Месяц", pickDay: "Нажмите на день, чтобы увидеть события")
        case .es:
            return .init(batteryLow: "Batería baja", batteryLowHint: "Activa el modo de bajo consumo para que dure más",
                         plugInSoon: "Conéctalo pronto", aboutLeft: "quedan unos %@", lowPowerPill: "Bajo consumo", on: "Activado",
                         fullIn: "Llena en %@", onHold: "En espera", optimizedCharging: "Carga optimizada",
                         charged: "Carga completa", left: "Quedan %@", next: "Siguiente",
                         dragArea: "Arrastra para elegir un área", dragRecording: "Arrastra para elegir qué grabar",
                         dragText: "Arrastra sobre el texto para copiarlo", clickColor: "Haz clic para elegir un color",
                         dragScrolling: "Arrastra sobre el área que se desplaza",
                         week: "Semana", month: "Mes", pickDay: "Haz clic en un día para ver sus eventos")
        case .sk:
            return .init(batteryLow: "Slabá batéria", batteryLowHint: "Zapnite režim nízkej spotreby, aby vydržala dlhšie",
                         plugInSoon: "Čoskoro pripojte nabíjačku", aboutLeft: "zostáva asi %@", lowPowerPill: "Nízka spotreba", on: "Zapnuté",
                         fullIn: "Nabitá o %@", onHold: "Pozastavené", optimizedCharging: "Optimalizované nabíjanie",
                         charged: "Úplne nabitá", left: "Zostáva %@", next: "Ďalej",
                         dragArea: "Ťahaním vyberte oblasť", dragRecording: "Ťahaním vyberte, čo nahrať",
                         dragText: "Ťahaním cez text ho skopírujete", clickColor: "Kliknutím vyberte farbu",
                         dragScrolling: "Ťahajte cez oblasť na posúvanie",
                         week: "Týždeň", month: "Mesiac", pickDay: "Kliknite na deň a uvidíte jeho udalosti")
        case .de:
            return .init(batteryLow: "Batterie schwach", batteryLowHint: "Stromsparmodus einschalten, damit sie länger hält",
                         plugInSoon: "Bald anschließen", aboutLeft: "noch etwa %@", lowPowerPill: "Stromsparen", on: "Ein",
                         fullIn: "Voll in %@", onHold: "Angehalten", optimizedCharging: "Optimiertes Laden",
                         charged: "Vollständig geladen", left: "Noch %@", next: "Als Nächstes",
                         dragArea: "Ziehen, um einen Bereich zu wählen", dragRecording: "Ziehen, um den Aufnahmebereich zu wählen",
                         dragText: "Über den Text ziehen, um ihn zu kopieren", clickColor: "Klicken, um eine Farbe zu wählen",
                         dragScrolling: "Über den scrollenden Bereich ziehen",
                         week: "Woche", month: "Monat", pickDay: "Klicke auf einen Tag, um seine Termine zu sehen")
        case .fr:
            return .init(batteryLow: "Batterie faible", batteryLowHint: "Activez le mode économie d’énergie pour tenir plus longtemps",
                         plugInSoon: "Branchez bientôt", aboutLeft: "environ %@ restantes", lowPowerPill: "Économie", on: "Activé",
                         fullIn: "Pleine dans %@", onHold: "En pause", optimizedCharging: "Recharge optimisée",
                         charged: "Charge complète", left: "%@ restantes", next: "Suivante",
                         dragArea: "Faites glisser pour choisir une zone", dragRecording: "Faites glisser pour choisir quoi enregistrer",
                         dragText: "Faites glisser sur le texte pour le copier", clickColor: "Cliquez pour choisir une couleur",
                         dragScrolling: "Faites glisser sur la zone à faire défiler",
                         week: "Semaine", month: "Mois", pickDay: "Cliquez sur un jour pour voir ses événements")
        case .it:
            return .init(batteryLow: "Batteria scarica", batteryLowHint: "Attiva la modalità Risparmio energetico per durare di più",
                         plugInSoon: "Collegalo presto", aboutLeft: "circa %@ rimanenti", lowPowerPill: "Risparmio", on: "Attiva",
                         fullIn: "Carica in %@", onHold: "In pausa", optimizedCharging: "Ricarica ottimizzata",
                         charged: "Carica completa", left: "%@ rimanenti", next: "Prossima",
                         dragArea: "Trascina per scegliere un’area", dragRecording: "Trascina per scegliere cosa registrare",
                         dragText: "Trascina sul testo per copiarlo", clickColor: "Fai clic per scegliere un colore",
                         dragScrolling: "Trascina sull’area da scorrere",
                         week: "Settimana", month: "Mese", pickDay: "Fai clic su un giorno per vederne gli eventi")
        case .ja:
            return .init(batteryLow: "バッテリー残量低下", batteryLowHint: "低電力モードをオンにすると長持ちします",
                         plugInSoon: "まもなく電源に接続してください", aboutLeft: "残り約%@", lowPowerPill: "低電力", on: "オン",
                         fullIn: "あと%@で満充電", onHold: "一時停止中", optimizedCharging: "バッテリー充電の最適化",
                         charged: "充電完了", left: "残り%@", next: "次",
                         dragArea: "ドラッグして範囲を選択", dragRecording: "ドラッグして収録範囲を選択",
                         dragText: "テキストをなぞってコピー", clickColor: "クリックして色を取得",
                         dragScrolling: "スクロールする範囲をドラッグ",
                         week: "週", month: "月", pickDay: "日付をクリックして予定を表示")
        case .ko:
            return .init(batteryLow: "배터리 부족", batteryLowHint: "저전력 모드를 켜면 더 오래 사용할 수 있습니다",
                         plugInSoon: "곧 전원에 연결하세요", aboutLeft: "약 %@ 남음", lowPowerPill: "저전력", on: "켬",
                         fullIn: "%@ 후 완충", onHold: "대기 중", optimizedCharging: "최적화된 배터리 충전",
                         charged: "충전 완료", left: "%@ 남음", next: "다음",
                         dragArea: "드래그하여 영역 선택", dragRecording: "드래그하여 녹화할 영역 선택",
                         dragText: "텍스트 위로 드래그하여 복사", clickColor: "클릭하여 색상 선택",
                         dragScrolling: "스크롤할 영역 위로 드래그",
                         week: "주", month: "월", pickDay: "날짜를 클릭하면 일정을 볼 수 있습니다")
        case .uk:
            return .init(batteryLow: "Низький заряд", batteryLowHint: "Увімкніть режим енергозбереження, щоб подовжити роботу",
                         plugInSoon: "Незабаром підключіть заряджання", aboutLeft: "лишилося близько %@", lowPowerPill: "Енергозбереження", on: "Увімк.",
                         fullIn: "Повний заряд за %@", onHold: "Призупинено", optimizedCharging: "Оптимізоване заряджання",
                         charged: "Повністю заряджено", left: "Лишилося %@", next: "Далі",
                         dragArea: "Перетягніть, щоб вибрати область", dragRecording: "Перетягніть, щоб вибрати область запису",
                         dragText: "Проведіть по тексту, щоб скопіювати", clickColor: "Натисніть, щоб вибрати колір",
                         dragScrolling: "Проведіть по області для прокручування",
                         week: "Тиждень", month: "Місяць", pickDay: "Натисніть на день, щоб побачити події")
        case .zhHans:
            return .init(batteryLow: "电量不足", batteryLowHint: "打开低电量模式以延长使用时间",
                         plugInSoon: "请尽快接通电源", aboutLeft: "约剩 %@", lowPowerPill: "低电量", on: "已开启",
                         fullIn: "%@后充满", onHold: "已暂停", optimizedCharging: "优化电池充电",
                         charged: "已充满", left: "剩余 %@", next: "下一个",
                         dragArea: "拖移以选择区域", dragRecording: "拖移以选择录制区域",
                         dragText: "在文字上拖移以拷贝", clickColor: "点按以选取颜色",
                         dragScrolling: "在要滚动的区域上拖移",
                         week: "周", month: "月", pickDay: "点按某天查看日程")
        case .zhTW:
            return .init(batteryLow: "電量不足", batteryLowHint: "開啟低耗電模式以延長使用時間",
                         plugInSoon: "請盡快接上電源", aboutLeft: "約剩 %@", lowPowerPill: "低耗電", on: "已開啟",
                         fullIn: "%@後充滿", onHold: "已暫停", optimizedCharging: "最佳化電池充電",
                         charged: "已充滿", left: "剩餘 %@", next: "下一個",
                         dragArea: "拖移以選擇區域", dragRecording: "拖移以選擇錄製區域",
                         dragText: "在文字上拖移以拷貝", clickColor: "按一下以選取顏色",
                         dragScrolling: "在要捲動的區域上拖移",
                         week: "週", month: "月", pickDay: "按一下某天以查看行程")
        case .zhHK:
            return .init(batteryLow: "電量不足", batteryLowHint: "開啟低耗電模式以延長使用時間",
                         plugInSoon: "請盡快接上電源", aboutLeft: "約剩 %@", lowPowerPill: "低耗電", on: "已開啟",
                         fullIn: "%@後充滿", onHold: "已暫停", optimizedCharging: "最佳化電池充電",
                         charged: "已充滿", left: "剩餘 %@", next: "下一個",
                         dragArea: "拖移以選擇範圍", dragRecording: "拖移以選擇錄影範圍",
                         dragText: "在文字上拖移以拷貝", clickColor: "按一下以選取顏色",
                         dragScrolling: "在要捲動的範圍上拖移",
                         week: "週", month: "月", pickDay: "按一下某天以查看行程")
        }
    }
}
