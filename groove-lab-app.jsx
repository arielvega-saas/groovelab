import { useState, useEffect, useRef, useCallback, useMemo } from "react";

// ─── i18n Translations ───────────────────────────────────────────────────
const LANGUAGES = [
  { code: "en", label: "English", flag: "🇬🇧" },
  { code: "es", label: "Español", flag: "🇪🇸" },
  { code: "pt", label: "Português", flag: "🇧🇷" },
  { code: "fr", label: "Français", flag: "🇫🇷" },
  { code: "de", label: "Deutsch", flag: "🇩🇪" },
  { code: "it", label: "Italiano", flag: "🇮🇹" },
  { code: "ja", label: "日本語", flag: "🇯🇵" },
];

const i18n = {
  en: {
    // Tabs
    tabMetronome: "Metronome", tabDrums: "Drums", tabLooper: "Looper",
    tabPractice: "Practice", tabLibrary: "Library", tabStats: "Stats", tabSettings: "Settings",
    // Header
    subtitle: "Metronome & Rhythm Trainer",
    stage: "STAGE", exitStage: "EXIT STAGE",
    // Metronome
    timeSignature: "Time Signature", subdivision: "Subdivision",
    clickSound: "Click Sound", swingHuman: "Swing / Human Feel", swing: "Swing",
    // Subdivision names
    quarter: "Quarter", eighth: "Eighth", triplet: "Triplet", sixteenth: "16th",
    // Click sound names
    sndWood: "Wood", sndDigital: "Digital", sndHiHat: "Hi-Hat",
    sndClave: "Clave", sndCowbell: "Cowbell", sndBeep: "Beep",
    // Drums
    style: "Style", sequencer16: "Sequencer — 16 Steps", amount: "Amount",
    // Looper
    looper: "Looper", info: "Info", recording: "● RECORDING...",
    tapRec: "Tap REC to start",
    looperDesc: "Record audio loops from your microphone. The looper captures live audio and plays it back in a continuous loop. Tap REC to begin recording, then STOP to finish. Your loop will play automatically. Use OVERDUB to layer additional recordings on top.",
    // Practice
    autoBpmIncrease: "Auto BPM Increase",
    autoBpmDesc: "Gradually increase tempo during practice",
    every: "Every", bars: "bars",
    intervalTraining: "Interval Training",
    intervalDesc: "Alternate between click and silence",
    click: "Click", silent: "Silent",
    randomSilence: "Random Silence",
    randomDesc: "Random beats are muted to train internal timing",
    probability: "Probability",
    // Library
    saveCurrentSettings: "Save Current Settings",
    songPlaceholder: "Song name...",
    save: "SAVE", savedSongs: "Saved Songs",
    noSongsYet: "No saved songs yet. Configure your settings and save them here.",
    // Stats
    practiceStatistics: "Practice Statistics",
    totalTime: "Total Time", sessions: "Sessions",
    currentBpm: "Current BPM", tempo: "Tempo",
    sessionInfo: "Session Info",
    statsDesc: "Practice statistics are tracked per session. Each time you start and stop the metronome, a session is logged. Your total practice time and session count are displayed above. Stats reset when you reload the app — future versions will persist data locally.",
    // Settings
    language: "Language", settingsTitle: "Settings",
    appearance: "Appearance", flashOnDownbeat: "Flash on Downbeat",
    flashDesc: "Screen flash effect on beat 1",
    // Monetization
    freePlan: "Free", proPlan: "Pro", upgradeToPro: "Upgrade to Pro",
    proUnlock: "Unlock all features",
    freeFeatures: "Basic metronome, 3 time signatures, 2 drum styles, 5 saved songs",
    proFeatures: "All time signatures, all drum styles, looper, advanced practice, unlimited songs, no ads",
    proPrice: "$4.99/month",
    proPriceYear: "$39.99/year",
    monthly: "Monthly", yearly: "Yearly (save 33%)",
    subscribe: "Subscribe Now", restorePurchase: "Restore Purchase",
    proActive: "Pro Plan Active",
    proBadge: "PRO",
    featureLocked: "Pro Feature",
    featureLockedDesc: "Upgrade to Pro to unlock this feature",
    dataLoaded: "Data loaded", dataSaved: "Data saved",
  },
  es: {
    tabMetronome: "Metrónomo", tabDrums: "Batería", tabLooper: "Looper",
    tabPractice: "Práctica", tabLibrary: "Biblioteca", tabStats: "Estadísticas", tabSettings: "Ajustes",
    subtitle: "Metrónomo y Entrenador Rítmico",
    stage: "ESCENARIO", exitStage: "SALIR",
    timeSignature: "Compás", subdivision: "Subdivisión",
    clickSound: "Sonido de Click", swingHuman: "Swing / Sensación Humana", swing: "Swing",
    quarter: "Negra", eighth: "Corchea", triplet: "Tresillo", sixteenth: "Semicorchea",
    sndWood: "Madera", sndDigital: "Digital", sndHiHat: "Hi-Hat",
    sndClave: "Clave", sndCowbell: "Cencerro", sndBeep: "Beep",
    style: "Estilo", sequencer16: "Secuenciador — 16 Pasos", amount: "Cantidad",
    looper: "Looper", info: "Info", recording: "● GRABANDO...",
    tapRec: "Tocá REC para empezar",
    looperDesc: "Grabá loops de audio desde tu micrófono. El looper captura audio en vivo y lo reproduce en un loop continuo. Tocá REC para empezar a grabar, luego STOP para terminar. Tu loop se reproducirá automáticamente. Usá OVERDUB para grabar capas adicionales encima.",
    autoBpmIncrease: "Aumento Automático de BPM",
    autoBpmDesc: "Aumenta gradualmente el tempo durante la práctica",
    every: "Cada", bars: "compases",
    intervalTraining: "Entrenamiento por Intervalos",
    intervalDesc: "Alterna entre click y silencio",
    click: "Click", silent: "Silencio",
    randomSilence: "Silencio Aleatorio",
    randomDesc: "Beats aleatorios se silencian para entrenar el tempo interno",
    probability: "Probabilidad",
    saveCurrentSettings: "Guardar Configuración Actual",
    songPlaceholder: "Nombre de la canción...",
    save: "GUARDAR", savedSongs: "Canciones Guardadas",
    noSongsYet: "No hay canciones guardadas. Configurá tus ajustes y guardalos acá.",
    practiceStatistics: "Estadísticas de Práctica",
    totalTime: "Tiempo Total", sessions: "Sesiones",
    currentBpm: "BPM Actual", tempo: "Tempo",
    sessionInfo: "Info de Sesión",
    statsDesc: "Las estadísticas se registran por sesión. Cada vez que iniciás y detenés el metrónomo, se registra una sesión. Tu tiempo total y cantidad de sesiones se muestran arriba. Las estadísticas se reinician al recargar la app.",
    language: "Idioma", settingsTitle: "Ajustes",
    appearance: "Apariencia", flashOnDownbeat: "Flash en Tiempo 1",
    flashDesc: "Efecto de flash en la pantalla en el beat 1",
    freePlan: "Gratis", proPlan: "Pro", upgradeToPro: "Mejorar a Pro",
    proUnlock: "Desbloquea todas las funciones",
    freeFeatures: "Metrónomo básico, 3 compases, 2 estilos de batería, 5 canciones guardadas",
    proFeatures: "Todos los compases, todos los estilos, looper, práctica avanzada, canciones ilimitadas, sin anuncios",
    proPrice: "$4.99/mes",
    proPriceYear: "$39.99/año",
    monthly: "Mensual", yearly: "Anual (ahorrá 33%)",
    subscribe: "Suscribirse Ahora", restorePurchase: "Restaurar Compra",
    proActive: "Plan Pro Activo",
    proBadge: "PRO",
    featureLocked: "Función Pro",
    featureLockedDesc: "Mejorá a Pro para desbloquear esta función",
    dataLoaded: "Datos cargados", dataSaved: "Datos guardados",
  },
    tabMetronome: "Metrônomo", tabDrums: "Bateria", tabLooper: "Looper",
    tabPractice: "Prática", tabLibrary: "Biblioteca", tabStats: "Estatísticas", tabSettings: "Configurações",
    subtitle: "Metrônomo e Treinador Rítmico",
    stage: "PALCO", exitStage: "SAIR",
    timeSignature: "Compasso", subdivision: "Subdivisão",
    clickSound: "Som do Click", swingHuman: "Swing / Sensação Humana", swing: "Swing",
    quarter: "Semínima", eighth: "Colcheia", triplet: "Tercina", sixteenth: "Semicolcheia",
    sndWood: "Madeira", sndDigital: "Digital", sndHiHat: "Hi-Hat",
    sndClave: "Clave", sndCowbell: "Cowbell", sndBeep: "Beep",
    style: "Estilo", sequencer16: "Sequenciador — 16 Passos", amount: "Quantidade",
    looper: "Looper", info: "Info", recording: "● GRAVANDO...",
    tapRec: "Toque REC para começar",
    looperDesc: "Grave loops de áudio do seu microfone. O looper captura áudio ao vivo e reproduz em loop contínuo. Toque REC para começar a gravar, depois STOP para finalizar. Seu loop será reproduzido automaticamente. Use OVERDUB para gravar camadas adicionais.",
    autoBpmIncrease: "Aumento Automático de BPM",
    autoBpmDesc: "Aumenta gradualmente o tempo durante a prática",
    every: "A cada", bars: "compassos",
    intervalTraining: "Treino por Intervalos",
    intervalDesc: "Alterna entre click e silêncio",
    click: "Click", silent: "Silêncio",
    randomSilence: "Silêncio Aleatório",
    randomDesc: "Beats aleatórios são silenciados para treinar o tempo interno",
    probability: "Probabilidade",
    saveCurrentSettings: "Salvar Configuração Atual",
    songPlaceholder: "Nome da música...",
    save: "SALVAR", savedSongs: "Músicas Salvas",
    noSongsYet: "Nenhuma música salva ainda. Configure seus ajustes e salve aqui.",
    practiceStatistics: "Estatísticas de Prática",
    totalTime: "Tempo Total", sessions: "Sessões",
    currentBpm: "BPM Atual", tempo: "Tempo",
    sessionInfo: "Info da Sessão",
    statsDesc: "As estatísticas são registradas por sessão. Cada vez que você inicia e para o metrônomo, uma sessão é registrada. Seu tempo total e número de sessões são exibidos acima. As estatísticas reiniciam ao recarregar o app.",
    language: "Idioma", settingsTitle: "Configurações",
    appearance: "Aparência", flashOnDownbeat: "Flash no Tempo 1",
    flashDesc: "Efeito de flash na tela no beat 1",
    freePlan: "Grátis", proPlan: "Pro", upgradeToPro: "Atualizar para Pro",
    proUnlock: "Desbloqueie todos os recursos",
    freeFeatures: "Metrônomo básico, 3 compassos, 2 estilos de bateria, 5 músicas salvas",
    proFeatures: "Todos os compassos, todos os estilos, looper, prática avançada, músicas ilimitadas, sem anúncios",
    proPrice: "$4.99/mês", proPriceYear: "$39.99/ano",
    monthly: "Mensal", yearly: "Anual (economize 33%)",
    subscribe: "Assinar Agora", restorePurchase: "Restaurar Compra",
    proActive: "Plano Pro Ativo", proBadge: "PRO",
    featureLocked: "Recurso Pro", featureLockedDesc: "Atualize para Pro para desbloquear",
    dataLoaded: "Dados carregados", dataSaved: "Dados salvos",
  },
  fr: {
    tabMetronome: "Métronome", tabDrums: "Batterie", tabLooper: "Looper",
    tabPractice: "Pratique", tabLibrary: "Bibliothèque", tabStats: "Statistiques", tabSettings: "Paramètres",
    subtitle: "Métronome et Entraîneur Rythmique",
    stage: "SCÈNE", exitStage: "QUITTER",
    timeSignature: "Signature", subdivision: "Subdivision",
    clickSound: "Son du Click", swingHuman: "Swing / Feeling Humain", swing: "Swing",
    quarter: "Noire", eighth: "Croche", triplet: "Triolet", sixteenth: "Double croche",
    sndWood: "Bois", sndDigital: "Digital", sndHiHat: "Hi-Hat",
    sndClave: "Clave", sndCowbell: "Cowbell", sndBeep: "Beep",
    style: "Style", sequencer16: "Séquenceur — 16 Pas", amount: "Quantité",
    looper: "Looper", info: "Info", recording: "● ENREGISTREMENT...",
    tapRec: "Appuyez REC pour commencer",
    looperDesc: "Enregistrez des boucles audio depuis votre microphone. Le looper capture l'audio en direct et le rejoue en boucle continue. Appuyez REC pour commencer, puis STOP pour terminer. Votre boucle sera jouée automatiquement. Utilisez OVERDUB pour superposer des enregistrements.",
    autoBpmIncrease: "Augmentation Auto du BPM",
    autoBpmDesc: "Augmente progressivement le tempo pendant la pratique",
    every: "Chaque", bars: "mesures",
    intervalTraining: "Entraînement par Intervalles",
    intervalDesc: "Alterne entre click et silence",
    click: "Click", silent: "Silence",
    randomSilence: "Silence Aléatoire",
    randomDesc: "Des beats aléatoires sont coupés pour entraîner le tempo interne",
    probability: "Probabilité",
    saveCurrentSettings: "Sauvegarder la Configuration",
    songPlaceholder: "Nom du morceau...",
    save: "SAUVER", savedSongs: "Morceaux Sauvegardés",
    noSongsYet: "Aucun morceau sauvegardé. Configurez vos paramètres et sauvegardez-les ici.",
    practiceStatistics: "Statistiques de Pratique",
    totalTime: "Temps Total", sessions: "Sessions",
    currentBpm: "BPM Actuel", tempo: "Tempo",
    sessionInfo: "Info de Session",
    statsDesc: "Les statistiques sont suivies par session. Chaque fois que vous démarrez et arrêtez le métronome, une session est enregistrée. Votre temps total et nombre de sessions sont affichés ci-dessus.",
    language: "Langue", settingsTitle: "Paramètres",
    appearance: "Apparence", flashOnDownbeat: "Flash sur le Temps 1",
    flashDesc: "Effet de flash à l'écran sur le beat 1",
    freePlan: "Gratuit", proPlan: "Pro", upgradeToPro: "Passer à Pro",
    proUnlock: "Débloquez toutes les fonctionnalités",
    freeFeatures: "Métronome basique, 3 signatures, 2 styles batterie, 5 morceaux sauvegardés",
    proFeatures: "Toutes les signatures, tous les styles, looper, pratique avancée, morceaux illimités, sans pub",
    proPrice: "4,99€/mois", proPriceYear: "39,99€/an",
    monthly: "Mensuel", yearly: "Annuel (économisez 33%)",
    subscribe: "S'abonner", restorePurchase: "Restaurer l'Achat",
    proActive: "Plan Pro Actif", proBadge: "PRO",
    featureLocked: "Fonction Pro", featureLockedDesc: "Passez à Pro pour débloquer",
    dataLoaded: "Données chargées", dataSaved: "Données sauvegardées",
  },
  de: {
    tabMetronome: "Metronom", tabDrums: "Schlagzeug", tabLooper: "Looper",
    tabPractice: "Übung", tabLibrary: "Bibliothek", tabStats: "Statistiken", tabSettings: "Einstellungen",
    subtitle: "Metronom und Rhythmus-Trainer",
    stage: "BÜHNE", exitStage: "VERLASSEN",
    timeSignature: "Taktart", subdivision: "Unterteilung",
    clickSound: "Click-Sound", swingHuman: "Swing / Menschliches Gefühl", swing: "Swing",
    quarter: "Viertel", eighth: "Achtel", triplet: "Triole", sixteenth: "Sechzehntel",
    sndWood: "Holz", sndDigital: "Digital", sndHiHat: "Hi-Hat",
    sndClave: "Clave", sndCowbell: "Kuhglocke", sndBeep: "Beep",
    style: "Stil", sequencer16: "Sequenzer — 16 Schritte", amount: "Menge",
    looper: "Looper", info: "Info", recording: "● AUFNAHME...",
    tapRec: "Tippe REC zum Starten",
    looperDesc: "Nehmen Sie Audio-Loops von Ihrem Mikrofon auf. Der Looper nimmt Live-Audio auf und spielt es in einer endlosen Schleife ab. Tippen Sie REC zum Starten, dann STOP zum Beenden. Ihr Loop wird automatisch abgespielt. Verwenden Sie OVERDUB für zusätzliche Aufnahmen.",
    autoBpmIncrease: "Automatische BPM-Erhöhung",
    autoBpmDesc: "Erhöht schrittweise das Tempo während des Übens",
    every: "Alle", bars: "Takte",
    intervalTraining: "Intervalltraining",
    intervalDesc: "Wechselt zwischen Click und Stille",
    click: "Click", silent: "Stille",
    randomSilence: "Zufällige Stille",
    randomDesc: "Zufällige Beats werden stummgeschaltet um das innere Timing zu trainieren",
    probability: "Wahrscheinlichkeit",
    saveCurrentSettings: "Aktuelle Einstellungen Speichern",
    songPlaceholder: "Songname...",
    save: "SPEICHERN", savedSongs: "Gespeicherte Songs",
    noSongsYet: "Noch keine gespeicherten Songs. Konfigurieren Sie Ihre Einstellungen und speichern Sie sie hier.",
    practiceStatistics: "Übungsstatistiken",
    totalTime: "Gesamtzeit", sessions: "Sitzungen",
    currentBpm: "Aktuelles BPM", tempo: "Tempo",
    sessionInfo: "Sitzungsinfo",
    statsDesc: "Statistiken werden pro Sitzung erfasst. Jedes Mal wenn Sie das Metronom starten und stoppen wird eine Sitzung protokolliert. Ihre Gesamtzeit und Anzahl der Sitzungen werden oben angezeigt.",
    language: "Sprache", settingsTitle: "Einstellungen",
    appearance: "Erscheinungsbild", flashOnDownbeat: "Flash auf Zählzeit 1",
    flashDesc: "Bildschirm-Blitzeffekt auf Beat 1",
    freePlan: "Kostenlos", proPlan: "Pro", upgradeToPro: "Auf Pro upgraden",
    proUnlock: "Alle Funktionen freischalten",
    freeFeatures: "Basis-Metronom, 3 Taktarten, 2 Schlagzeug-Stile, 5 gespeicherte Songs",
    proFeatures: "Alle Taktarten, alle Stile, Looper, erweitertes Üben, unbegrenzte Songs, keine Werbung",
    proPrice: "4,99€/Monat", proPriceYear: "39,99€/Jahr",
    monthly: "Monatlich", yearly: "Jährlich (33% sparen)",
    subscribe: "Jetzt Abonnieren", restorePurchase: "Kauf Wiederherstellen",
    proActive: "Pro Plan Aktiv", proBadge: "PRO",
    featureLocked: "Pro Funktion", featureLockedDesc: "Upgrade auf Pro zum Freischalten",
    dataLoaded: "Daten geladen", dataSaved: "Daten gespeichert",
  },
    tabMetronome: "Metronomo", tabDrums: "Batteria", tabLooper: "Looper",
    tabPractice: "Pratica", tabLibrary: "Libreria", tabStats: "Statistiche", tabSettings: "Impostazioni",
    subtitle: "Metronomo e Allenatore Ritmico",
    stage: "PALCO", exitStage: "ESCI",
    timeSignature: "Tempo", subdivision: "Suddivisione",
    clickSound: "Suono Click", swingHuman: "Swing / Sensazione Umana", swing: "Swing",
    quarter: "Semiminima", eighth: "Croma", triplet: "Terzina", sixteenth: "Semicroma",
    sndWood: "Legno", sndDigital: "Digitale", sndHiHat: "Hi-Hat",
    sndClave: "Clave", sndCowbell: "Cowbell", sndBeep: "Beep",
    style: "Stile", sequencer16: "Sequencer — 16 Passi", amount: "Quantità",
    looper: "Looper", info: "Info", recording: "● REGISTRAZIONE...",
    tapRec: "Tocca REC per iniziare",
    looperDesc: "Registra loop audio dal tuo microfono. Il looper cattura l'audio dal vivo e lo riproduce in loop continuo. Tocca REC per iniziare, poi STOP per finire. Il tuo loop verrà riprodotto automaticamente. Usa OVERDUB per sovrapporre registrazioni aggiuntive.",
    autoBpmIncrease: "Aumento Automatico BPM",
    autoBpmDesc: "Aumenta gradualmente il tempo durante la pratica",
    every: "Ogni", bars: "battute",
    intervalTraining: "Allenamento a Intervalli",
    intervalDesc: "Alterna tra click e silenzio",
    click: "Click", silent: "Silenzio",
    randomSilence: "Silenzio Casuale",
    randomDesc: "Beat casuali vengono silenziati per allenare il tempo interno",
    probability: "Probabilità",
    saveCurrentSettings: "Salva Impostazioni Attuali",
    songPlaceholder: "Nome del brano...",
    save: "SALVA", savedSongs: "Brani Salvati",
    noSongsYet: "Nessun brano salvato. Configura le tue impostazioni e salvale qui.",
    practiceStatistics: "Statistiche di Pratica",
    totalTime: "Tempo Totale", sessions: "Sessioni",
    currentBpm: "BPM Attuale", tempo: "Tempo",
    sessionInfo: "Info Sessione",
    statsDesc: "Le statistiche vengono tracciate per sessione. Ogni volta che avvii e fermi il metronomo, viene registrata una sessione. Il tuo tempo totale e il numero di sessioni sono visualizzati sopra.",
    language: "Lingua", settingsTitle: "Impostazioni",
    appearance: "Aspetto", flashOnDownbeat: "Flash sul Tempo 1",
    flashDesc: "Effetto flash sullo schermo sul beat 1",
    freePlan: "Gratis", proPlan: "Pro", upgradeToPro: "Passa a Pro",
    proUnlock: "Sblocca tutte le funzionalità",
    freeFeatures: "Metronomo base, 3 tempi, 2 stili batteria, 5 brani salvati",
    proFeatures: "Tutti i tempi, tutti gli stili, looper, pratica avanzata, brani illimitati, senza pubblicità",
    proPrice: "4,99€/mese", proPriceYear: "39,99€/anno",
    monthly: "Mensile", yearly: "Annuale (risparmia 33%)",
    subscribe: "Abbonati Ora", restorePurchase: "Ripristina Acquisto",
    proActive: "Piano Pro Attivo", proBadge: "PRO",
    featureLocked: "Funzione Pro", featureLockedDesc: "Passa a Pro per sbloccare",
    dataLoaded: "Dati caricati", dataSaved: "Dati salvati",
  },
  ja: {
    tabMetronome: "メトロノーム", tabDrums: "ドラム", tabLooper: "ルーパー",
    tabPractice: "練習", tabLibrary: "ライブラリ", tabStats: "統計", tabSettings: "設定",
    subtitle: "メトロノーム＆リズムトレーナー",
    stage: "ステージ", exitStage: "終了",
    timeSignature: "拍子", subdivision: "分割",
    clickSound: "クリック音", swingHuman: "スウィング / ヒューマンフィール", swing: "スウィング",
    quarter: "4分音符", eighth: "8分音符", triplet: "3連符", sixteenth: "16分音符",
    sndWood: "ウッド", sndDigital: "デジタル", sndHiHat: "ハイハット",
    sndClave: "クラーベ", sndCowbell: "カウベル", sndBeep: "ビープ",
    style: "スタイル", sequencer16: "シーケンサー — 16ステップ", amount: "量",
    looper: "ルーパー", info: "情報", recording: "● 録音中...",
    tapRec: "RECをタップして開始",
    looperDesc: "マイクからオーディオループを録音します。ルーパーはライブオーディオをキャプチャし、連続ループで再生します。RECをタップして録音開始、STOPで終了。ループは自動的に再生されます。OVERDUBで追加録音を重ねられます。",
    autoBpmIncrease: "BPM自動増加",
    autoBpmDesc: "練習中にテンポを徐々に上げます",
    every: "毎", bars: "小節",
    intervalTraining: "インターバルトレーニング",
    intervalDesc: "クリックとサイレンスを交互に",
    click: "クリック", silent: "サイレント",
    randomSilence: "ランダムサイレンス",
    randomDesc: "ランダムなビートをミュートして内部テンポを鍛えます",
    probability: "確率",
    saveCurrentSettings: "現在の設定を保存",
    songPlaceholder: "曲名...",
    save: "保存", savedSongs: "保存した曲",
    noSongsYet: "保存された曲はまだありません。設定を行い、ここに保存してください。",
    practiceStatistics: "練習統計",
    totalTime: "合計時間", sessions: "セッション",
    currentBpm: "現在のBPM", tempo: "テンポ",
    sessionInfo: "セッション情報",
    statsDesc: "統計はセッションごとに記録されます。メトロノームを開始・停止するたびにセッションが記録されます。合計練習時間とセッション数が上に表示されます。",
    language: "言語", settingsTitle: "設定",
    appearance: "外観", flashOnDownbeat: "1拍目にフラッシュ",
    flashDesc: "ビート1で画面フラッシュ効果",
    freePlan: "無料", proPlan: "Pro", upgradeToPro: "Proにアップグレード",
    proUnlock: "全機能をアンロック",
    freeFeatures: "基本メトロノーム、3拍子、2ドラムスタイル、5曲保存",
    proFeatures: "全拍子、全スタイル、ルーパー、高度な練習、無制限の曲、広告なし",
    proPrice: "¥600/月", proPriceYear: "¥4,800/年",
    monthly: "月額", yearly: "年額（33%お得）",
    subscribe: "今すぐ登録", restorePurchase: "購入を復元",
    proActive: "Proプランアクティブ", proBadge: "PRO",
    featureLocked: "Pro機能", featureLockedDesc: "Proにアップグレードしてアンロック",
    dataLoaded: "データ読み込み完了", dataSaved: "データ保存完了",
  },
};

function t(lang, key) {
  return (i18n[lang] && i18n[lang][key]) || i18n.en[key] || key;
}

// ─── Constants ───────────────────────────────────────────────────────────
const TEMPO_NAMES = [
  { min: 20, max: 40, name: "Grave" },
  { min: 40, max: 60, name: "Largo" },
  { min: 60, max: 66, name: "Larghetto" },
  { min: 66, max: 76, name: "Adagio" },
  { min: 76, max: 108, name: "Andante" },
  { min: 108, max: 120, name: "Moderato" },
  { min: 120, max: 156, name: "Allegro" },
  { min: 156, max: 176, name: "Vivace" },
  { min: 176, max: 200, name: "Presto" },
  { min: 200, max: 500, name: "Prestissimo" },
];

const TIME_SIGNATURES = [
  { num: 2, den: 4, label: "2/4" },
  { num: 3, den: 4, label: "3/4" },
  { num: 4, den: 4, label: "4/4" },
  { num: 5, den: 4, label: "5/4" },
  { num: 6, den: 8, label: "6/8" },
  { num: 7, den: 8, label: "7/8" },
  { num: 9, den: 8, label: "9/8" },
  { num: 12, den: 8, label: "12/8" },
];

const SUBDIVISIONS = [
  { value: 1, label: "♩", name: "Quarter" },
  { value: 2, label: "♫", name: "Eighth" },
  { value: 3, label: "♫3", name: "Triplet" },
  { value: 4, label: "♬", name: "16th" },
];

const CLICK_SOUNDS = ["Wood", "Digital", "Hi-Hat", "Clave", "Cowbell", "Beep"];

const DRUM_STYLES = ["Rock", "Pop", "Funk", "Blues", "Jazz", "Shuffle", "Latin"];

const ACCENT_LEVELS = { mute: 0, ghost: 0.3, normal: 0.7, accent: 1.0 };

// Drum patterns per style (16-step grid: K=kick, S=snare, H=hihat, R=ride)
const DRUM_PATTERNS = {
  Rock: {
    kick:   [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0],
    snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    hihat:  [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    ride:   [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  Pop: {
    kick:   [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],
    snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    hihat:  [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
    ride:   [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  Funk: {
    kick:   [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0],
    snare:  [0,0,0,0, 1,0,0,1, 0,0,1,0, 1,0,0,0],
    hihat:  [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
    ride:   [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  Blues: {
    kick:   [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0],
    snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    hihat:  [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    ride:   [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  Jazz: {
    kick:   [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0],
    snare:  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
    hihat:  [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],
    ride:   [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1],
  },
  Shuffle: {
    kick:   [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],
    snare:  [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    hihat:  [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    ride:   [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  Latin: {
    kick:   [1,0,0,0, 0,0,1,0, 0,0,1,0, 0,0,0,0],
    snare:  [0,0,0,1, 0,0,0,0, 0,0,0,1, 0,1,0,0],
    hihat:  [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    ride:   [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
};

// ─── Audio Engine ────────────────────────────────────────────────────────
class AudioEngine {
  constructor() {
    this.ctx = null;
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.initialized = true;
  }

  playClick(freq = 1000, duration = 0.03, volume = 0.8, time = null) {
    if (!this.ctx) return;
    const t = time || this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(freq, t);
    gain.gain.setValueAtTime(volume, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + duration);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(t);
    osc.stop(t + duration);
  }

  playNoise(duration = 0.05, volume = 0.5, highpass = 5000, time = null) {
    if (!this.ctx) return;
    const t = time || this.ctx.currentTime;
    const bufferSize = this.ctx.sampleRate * duration;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) data[i] = Math.random() * 2 - 1;
    const source = this.ctx.createBufferSource();
    source.buffer = buffer;
    const hp = this.ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.setValueAtTime(highpass, t);
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(volume, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + duration);
    source.connect(hp);
    hp.connect(gain);
    gain.connect(this.ctx.destination);
    source.start(t);
    source.stop(t + duration);
  }

  playKick(time = null) {
    if (!this.ctx) return;
    const t = time || this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(150, t);
    osc.frequency.exponentialRampToValueAtTime(40, t + 0.12);
    gain.gain.setValueAtTime(1, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(t);
    osc.stop(t + 0.3);
  }

  playSnare(time = null) {
    if (!this.ctx) return;
    const t = time || this.ctx.currentTime;
    this.playClick(200, 0.08, 0.4, t);
    this.playNoise(0.12, 0.6, 3000, t);
  }

  playHiHat(time = null, open = false) {
    if (!this.ctx) return;
    const dur = open ? 0.15 : 0.04;
    this.playNoise(dur, 0.35, 8000, time);
  }

  playRide(time = null) {
    if (!this.ctx) return;
    const t = time || this.ctx.currentTime;
    this.playNoise(0.2, 0.25, 6000, t);
    this.playClick(800, 0.08, 0.15, t);
  }

  get currentTime() {
    return this.ctx ? this.ctx.currentTime : 0;
  }
}

const audioEngine = new AudioEngine();

// ─── Helpers ─────────────────────────────────────────────────────────────
function getTempoName(bpm) {
  const found = TEMPO_NAMES.find((t) => bpm >= t.min && bpm < t.max);
  return found ? found.name : "Prestissimo";
}

function formatTime(seconds) {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

// ─── Icons (inline SVG components) ──────────────────────────────────────
const PlayIcon = () => (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor">
    <path d="M8 5v14l11-7z" />
  </svg>
);
const StopIcon = () => (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor">
    <rect x="6" y="6" width="12" height="12" rx="1" />
  </svg>
);
const PlusIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
    <line x1="12" y1="5" x2="12" y2="19" />
    <line x1="5" y1="12" x2="19" y2="12" />
  </svg>
);
const MinusIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
    <line x1="5" y1="12" x2="19" y2="12" />
  </svg>
);

// ─── Styles ──────────────────────────────────────────────────────────────
const CSS = `
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700;800&family=Outfit:wght@300;400;500;600;700;800;900&display=swap');

:root {
  --bg-deepest: #08090c;
  --bg-dark: #0d0f14;
  --bg-card: #12151c;
  --bg-elevated: #181c26;
  --bg-input: #1a1e28;
  --border: #1e2330;
  --border-light: #2a3040;
  --text-primary: #e8ecf4;
  --text-secondary: #7a8499;
  --text-muted: #4a5266;
  --accent: #00d4ff;
  --accent-dim: #00a3cc;
  --accent-glow: rgba(0, 212, 255, 0.15);
  --accent-glow-strong: rgba(0, 212, 255, 0.35);
  --accent2: #00ff88;
  --accent2-dim: #00cc6a;
  --accent2-glow: rgba(0, 255, 136, 0.15);
  --accent3: #ff6b35;
  --accent3-glow: rgba(255, 107, 53, 0.15);
  --danger: #ff3b5c;
  --warning: #ffb020;
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body, #root {
  background: var(--bg-deepest);
  color: var(--text-primary);
  font-family: 'Outfit', sans-serif;
  min-height: 100vh;
  overflow-x: hidden;
}

.app-container {
  max-width: 480px;
  margin: 0 auto;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--bg-dark);
  position: relative;
  overflow: hidden;
}

.app-container::before {
  content: '';
  position: absolute;
  top: -200px;
  left: 50%;
  transform: translateX(-50%);
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, var(--accent-glow) 0%, transparent 70%);
  pointer-events: none;
  z-index: 0;
}

/* ── Header ── */
.app-header {
  padding: 16px 20px 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  position: relative;
  z-index: 1;
}

.app-logo {
  display: flex;
  align-items: center;
  gap: 10px;
}

.logo-mark {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'JetBrains Mono', monospace;
  font-weight: 800;
  font-size: 16px;
  color: var(--bg-deepest);
}

.logo-text-group {
  display: flex;
  flex-direction: column;
  line-height: 1.1;
}

.logo-text {
  font-weight: 700;
  font-size: 20px;
  letter-spacing: -0.5px;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.logo-subtitle {
  font-size: 9px;
  font-weight: 500;
  letter-spacing: 1.5px;
  text-transform: uppercase;
  color: var(--text-muted);
  margin-top: 1px;
}

.stage-btn {
  padding: 6px 14px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--bg-elevated);
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}
.stage-btn:hover { border-color: var(--accent); color: var(--accent); }
.stage-btn.active { background: var(--accent); color: var(--bg-deepest); border-color: var(--accent); font-weight: 600; }

/* ── Navigation ── */
.nav-bar {
  display: flex;
  gap: 4px;
  padding: 4px 16px 8px;
  position: relative;
  z-index: 1;
  overflow-x: auto;
  scrollbar-width: none;
}
.nav-bar::-webkit-scrollbar { display: none; }

.nav-tab {
  padding: 8px 16px;
  border-radius: 10px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  font-family: 'Outfit', sans-serif;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.2s;
}
.nav-tab:hover { color: var(--text-secondary); background: var(--bg-elevated); }
.nav-tab.active {
  color: var(--accent);
  background: var(--accent-glow);
  font-weight: 600;
}

/* ── Main Content ── */
.main-content {
  flex: 1;
  padding: 0 20px 100px;
  position: relative;
  z-index: 1;
  overflow-y: auto;
}

/* ── Tempo Wheel ── */
.tempo-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: 8px;
}

.tempo-name {
  font-size: 13px;
  font-weight: 500;
  color: var(--accent);
  text-transform: uppercase;
  letter-spacing: 3px;
  margin-bottom: 8px;
}

.tempo-wheel-container {
  position: relative;
  width: 240px;
  height: 240px;
  margin: 0 auto 12px;
}

.tempo-wheel-bg {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: conic-gradient(from 180deg, var(--bg-card), var(--bg-elevated), var(--bg-card));
  border: 2px solid var(--border);
}

.tempo-wheel-track {
  position: absolute;
  inset: 8px;
  border-radius: 50%;
  background: var(--bg-deepest);
  border: 1px solid var(--border);
}

.tempo-wheel-progress {
  position: absolute;
  inset: 6px;
  border-radius: 50%;
  background: conic-gradient(
    from 220deg,
    var(--accent) 0%,
    var(--accent) var(--progress),
    transparent var(--progress)
  );
  mask: radial-gradient(circle, transparent 72%, black 73%);
  -webkit-mask: radial-gradient(circle, transparent 72%, black 73%);
  opacity: 0.8;
}

.tempo-display {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  user-select: none;
}

.tempo-number {
  font-family: 'JetBrains Mono', monospace;
  font-size: 64px;
  font-weight: 800;
  line-height: 1;
  color: var(--text-primary);
  text-shadow: 0 0 40px var(--accent-glow-strong);
}

.tempo-bpm-label {
  font-size: 12px;
  font-weight: 500;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 4px;
  margin-top: 4px;
}

/* ── Controls Row ── */
.controls-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-bottom: 16px;
}

.ctrl-btn {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s;
  font-family: 'JetBrains Mono', monospace;
  font-weight: 600;
  font-size: 14px;
}
.ctrl-btn:hover { border-color: var(--accent); color: var(--accent); }
.ctrl-btn:active { transform: scale(0.95); background: var(--accent-glow); }

.play-btn {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 2px solid var(--accent);
  background: var(--accent-glow);
  color: var(--accent);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 0 30px var(--accent-glow), inset 0 0 20px var(--accent-glow);
}
.play-btn:hover { background: var(--accent); color: var(--bg-deepest); box-shadow: 0 0 50px var(--accent-glow-strong); }
.play-btn.playing { background: var(--accent); color: var(--bg-deepest); animation: pulse-glow 1s infinite; }

@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 30px var(--accent-glow); }
  50% { box-shadow: 0 0 60px var(--accent-glow-strong); }
}

.tap-btn {
  padding: 10px 24px;
  border-radius: 12px;
  border: 1px solid var(--accent2-dim);
  background: var(--accent2-glow);
  color: var(--accent2);
  font-family: 'Outfit', sans-serif;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.15s;
}
.tap-btn:hover { background: var(--accent2); color: var(--bg-deepest); }
.tap-btn:active { transform: scale(0.95); }

/* ── Beat Visualizer ── */
.beat-vis {
  display: flex;
  justify-content: center;
  gap: 8px;
  margin-bottom: 20px;
}

.beat-dot {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--bg-elevated);
  border: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'JetBrains Mono', monospace;
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
  transition: all 0.1s;
}

.beat-dot.active {
  background: var(--accent);
  color: var(--bg-deepest);
  border-color: var(--accent);
  box-shadow: 0 0 20px var(--accent-glow-strong);
  transform: scale(1.15);
}

.beat-dot.accent-beat {
  border-color: var(--accent3);
}

.beat-dot.accent-beat.active {
  background: var(--accent3);
  border-color: var(--accent3);
  box-shadow: 0 0 20px var(--accent3-glow);
}

/* ── Panels / Cards ── */
.panel {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 16px;
  margin-bottom: 12px;
}

.panel-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 2px;
  margin-bottom: 12px;
}

/* ── Selector Chips ── */
.chip-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.chip {
  padding: 6px 14px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--bg-input);
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s;
  font-family: 'JetBrains Mono', monospace;
}
.chip:hover { border-color: var(--accent); color: var(--accent); }
.chip.active { background: var(--accent); color: var(--bg-deepest); border-color: var(--accent); font-weight: 600; }

/* ── Slider ── */
.slider-container {
  display: flex;
  align-items: center;
  gap: 12px;
}

.slider-label {
  font-size: 12px;
  color: var(--text-muted);
  font-weight: 500;
  min-width: 60px;
}

.slider-value {
  font-family: 'JetBrains Mono', monospace;
  font-size: 13px;
  color: var(--accent);
  min-width: 40px;
  text-align: right;
}

input[type="range"] {
  -webkit-appearance: none;
  appearance: none;
  flex: 1;
  height: 6px;
  border-radius: 3px;
  background: var(--bg-input);
  outline: none;
}
input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--accent);
  cursor: pointer;
  box-shadow: 0 0 10px var(--accent-glow);
}

/* ── Drum Grid ── */
.drum-grid {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.drum-row {
  display: flex;
  align-items: center;
  gap: 4px;
}

.drum-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: var(--text-muted);
  width: 36px;
  text-align: right;
  padding-right: 4px;
  text-transform: uppercase;
}

.drum-cell {
  width: 20px;
  height: 24px;
  border-radius: 4px;
  border: 1px solid var(--border);
  background: var(--bg-input);
  cursor: pointer;
  transition: all 0.1s;
  position: relative;
}
.drum-cell:nth-child(4n+2) { margin-left: 2px; }
.drum-cell.on {
  background: var(--accent);
  border-color: var(--accent);
  box-shadow: 0 0 6px var(--accent-glow);
}
.drum-cell.on.kick-cell { background: var(--accent3); border-color: var(--accent3); }
.drum-cell.on.snare-cell { background: var(--warning); border-color: var(--warning); }
.drum-cell.on.hihat-cell { background: var(--accent2); border-color: var(--accent2); }
.drum-cell.on.ride-cell { background: #a78bfa; border-color: #a78bfa; }

.drum-cell.current {
  border-color: #fff;
  box-shadow: 0 0 8px rgba(255,255,255,0.3);
}

/* ── Looper ── */
.loop-waveform {
  width: 100%;
  height: 80px;
  background: var(--bg-input);
  border-radius: 12px;
  border: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  margin-bottom: 12px;
}

.loop-bars {
  display: flex;
  align-items: center;
  gap: 1px;
  height: 60px;
}

.loop-bar {
  width: 3px;
  background: var(--accent);
  border-radius: 2px;
  opacity: 0.6;
  transition: height 0.1s;
}

.loop-controls {
  display: flex;
  gap: 8px;
  justify-content: center;
}

.loop-btn {
  padding: 10px 20px;
  border-radius: 12px;
  border: 1px solid var(--border);
  background: var(--bg-elevated);
  color: var(--text-secondary);
  font-family: 'Outfit', sans-serif;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
}
.loop-btn:hover { border-color: var(--accent); color: var(--accent); }
.loop-btn.recording { background: var(--danger); border-color: var(--danger); color: #fff; animation: rec-pulse 0.8s infinite; }
.loop-btn.overdub { background: var(--warning); border-color: var(--warning); color: var(--bg-deepest); }

@keyframes rec-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

/* ── Practice Mode ── */
.practice-card {
  background: var(--bg-elevated);
  border-radius: 12px;
  padding: 14px;
  margin-bottom: 8px;
  border: 1px solid var(--border);
}

.practice-card-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 4px;
}

.practice-card-desc {
  font-size: 12px;
  color: var(--text-muted);
  margin-bottom: 10px;
}

.toggle-switch {
  width: 44px;
  height: 24px;
  border-radius: 12px;
  background: var(--bg-input);
  border: 1px solid var(--border);
  position: relative;
  cursor: pointer;
  transition: all 0.2s;
}
.toggle-switch.on {
  background: var(--accent);
  border-color: var(--accent);
}
.toggle-switch::after {
  content: '';
  position: absolute;
  top: 2px;
  left: 2px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--text-primary);
  transition: transform 0.2s;
}
.toggle-switch.on::after {
  transform: translateX(20px);
  background: var(--bg-deepest);
}

/* ── Stats ── */
.stat-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}

.stat-card {
  background: var(--bg-elevated);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 14px;
  text-align: center;
}

.stat-value {
  font-family: 'JetBrains Mono', monospace;
  font-size: 28px;
  font-weight: 700;
  color: var(--accent);
}

.stat-label {
  font-size: 11px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-top: 2px;
}

/* ── Library ── */
.song-item {
  display: flex;
  align-items: center;
  padding: 12px;
  background: var(--bg-elevated);
  border: 1px solid var(--border);
  border-radius: 12px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: all 0.15s;
}
.song-item:hover { border-color: var(--accent); }

.song-bpm {
  font-family: 'JetBrains Mono', monospace;
  font-size: 22px;
  font-weight: 700;
  color: var(--accent);
  margin-right: 14px;
  min-width: 50px;
}

.song-info { flex: 1; }
.song-name { font-weight: 600; font-size: 14px; }
.song-meta { font-size: 11px; color: var(--text-muted); margin-top: 2px; }

.song-del {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.song-del:hover { color: var(--danger); }

/* ── Miscellaneous ── */
.inline-input {
  background: var(--bg-input);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 6px 12px;
  color: var(--text-primary);
  font-family: 'Outfit', sans-serif;
  font-size: 13px;
  outline: none;
  width: 100%;
  transition: border-color 0.15s;
}
.inline-input:focus { border-color: var(--accent); }

.flex-between {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.gap-8 { gap: 8px; }
.mb-8 { margin-bottom: 8px; }
.mb-12 { margin-bottom: 12px; }
.mb-16 { margin-bottom: 16px; }

/* Scrollbar */
::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }

/* ── Pro Badge ── */
.pro-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 8px;
  border-radius: 6px;
  background: linear-gradient(135deg, #f59e0b, #f97316);
  color: #000;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
}

.pro-lock-overlay {
  position: relative;
}

.pro-lock-overlay.locked::after {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(8, 9, 12, 0.7);
  border-radius: 16px;
  backdrop-filter: blur(2px);
  z-index: 2;
}

.pro-lock-badge {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 3;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}

.pro-lock-badge .lock-icon {
  font-size: 28px;
}

.pro-lock-badge .lock-text {
  font-size: 12px;
  font-weight: 600;
  color: #f59e0b;
  text-align: center;
}

.pro-upgrade-card {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.1), rgba(249, 115, 22, 0.1));
  border: 1px solid rgba(245, 158, 11, 0.3);
  border-radius: 16px;
  padding: 20px;
  text-align: center;
  margin-bottom: 16px;
}

.pro-upgrade-card h3 {
  font-size: 20px;
  font-weight: 700;
  background: linear-gradient(135deg, #f59e0b, #f97316);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  margin-bottom: 4px;
}

.pro-upgrade-card .pro-desc {
  font-size: 13px;
  color: var(--text-muted);
  margin-bottom: 16px;
}

.pro-plan-toggle {
  display: flex;
  background: var(--bg-input);
  border-radius: 10px;
  padding: 3px;
  margin-bottom: 16px;
}

.pro-plan-toggle button {
  flex: 1;
  padding: 8px;
  border: none;
  border-radius: 8px;
  background: transparent;
  color: var(--text-muted);
  font-family: 'Outfit', sans-serif;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.pro-plan-toggle button.active {
  background: linear-gradient(135deg, #f59e0b, #f97316);
  color: #000;
  font-weight: 700;
}

.pro-price {
  font-family: 'JetBrains Mono', monospace;
  font-size: 32px;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 4px;
}

.pro-subscribe-btn {
  width: 100%;
  padding: 14px;
  border-radius: 12px;
  border: none;
  background: linear-gradient(135deg, #f59e0b, #f97316);
  color: #000;
  font-family: 'Outfit', sans-serif;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
  margin-bottom: 8px;
}
.pro-subscribe-btn:hover { opacity: 0.9; transform: scale(1.01); }

.pro-restore-btn {
  background: none;
  border: none;
  color: var(--text-muted);
  font-size: 12px;
  cursor: pointer;
  text-decoration: underline;
  font-family: 'Outfit', sans-serif;
}

.pro-features-list {
  text-align: left;
  margin: 16px 0;
}

.pro-feature-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 0;
  font-size: 13px;
  color: var(--text-secondary);
}

.pro-feature-item .check {
  color: #f59e0b;
  font-weight: 700;
}

.pro-active-banner {
  background: linear-gradient(135deg, rgba(0, 255, 136, 0.1), rgba(0, 212, 255, 0.1));
  border: 1px solid var(--accent2-dim);
  border-radius: 12px;
  padding: 16px;
  text-align: center;
  margin-bottom: 16px;
}

.pro-active-banner .check-big {
  font-size: 36px;
  margin-bottom: 4px;
}

.pro-active-banner h4 {
  color: var(--accent2);
  font-size: 16px;
  margin-bottom: 2px;
}

.save-indicator {
  position: fixed;
  bottom: 16px;
  right: 16px;
  background: var(--accent2);
  color: var(--bg-deepest);
  padding: 6px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  z-index: 50;
  animation: fade-in-out 1.5s ease;
}

@keyframes fade-in-out {
  0% { opacity: 0; transform: translateY(10px); }
  15% { opacity: 1; transform: translateY(0); }
  85% { opacity: 1; }
  100% { opacity: 0; }
}

.chip.locked {
  opacity: 0.4;
  position: relative;
}

.chip.locked::after {
  content: '🔒';
  font-size: 10px;
  margin-left: 4px;
}

/* Flash animation for beat */
@keyframes beat-flash {
  0% { opacity: 1; }
  100% { opacity: 0; }
}

.flash-overlay {
  position: fixed;
  inset: 0;
  background: var(--accent);
  opacity: 0;
  pointer-events: none;
  z-index: 100;
  animation: beat-flash 0.15s ease-out;
}

/* Stage mode */
.stage-mode .tempo-number { font-size: 120px; }
.stage-mode .beat-dot { width: 48px; height: 48px; font-size: 18px; }
`;

// ─── Main App Component ──────────────────────────────────────────────────
export default function GrooveLabApp() {
  // Navigation
  const [activeTab, setActiveTab] = useState("metro");
  const [stageMode, setStageMode] = useState(false);
  const [lang, setLang] = useState("es");
  const [isPro, setIsPro] = useState(false);
  const [proInterval, setProInterval] = useState("monthly");
  const [dataReady, setDataReady] = useState(false);
  const [saveStatus, setSaveStatus] = useState("");

  // Metronome state
  const [bpm, setBpm] = useState(120);
  const [playing, setPlaying] = useState(false);
  const [timeSig, setTimeSig] = useState({ num: 4, den: 4, label: "4/4" });
  const [subdivision, setSubdivision] = useState(1);
  const [currentBeat, setCurrentBeat] = useState(-1);
  const [clickSound, setClickSound] = useState("Wood");
  const [accentPattern, setAccentPattern] = useState([1, 0.7, 0.7, 0.7]);
  const [swingAmount, setSwingAmount] = useState(0);
  const [showFlash, setShowFlash] = useState(false);

  // Tap tempo
  const tapTimesRef = useRef([]);

  // Drum machine
  const [drumStyle, setDrumStyle] = useState("Rock");
  const [drumPattern, setDrumPattern] = useState(DRUM_PATTERNS.Rock);
  const [drumStep, setDrumStep] = useState(-1);
  const [drumMutes, setDrumMutes] = useState({ kick: false, snare: false, hihat: false, ride: false });

  // Looper
  const [loopState, setLoopState] = useState("idle"); // idle, recording, playing, overdub
  const [loopBars, setLoopBars] = useState([]);
  const [loopDuration, setLoopDuration] = useState(0);
  const loopMediaRef = useRef(null);
  const loopChunksRef = useRef([]);
  const loopAudioRef = useRef(null);

  // Practice mode
  const [practiceAutoIncrease, setPracticeAutoIncrease] = useState(false);
  const [practiceIncrement, setPracticeIncrement] = useState(5);
  const [practiceInterval, setPracticeInterval] = useState(4); // bars
  const [randomSilence, setRandomSilence] = useState(false);
  const [silenceProb, setSilenceProb] = useState(25);
  const [intervalTraining, setIntervalTraining] = useState(false);
  const [clickBars, setClickBars] = useState(4);
  const [silentBars, setSilentBars] = useState(2);

  // Library
  const [library, setLibrary] = useState([
    { id: 1, name: "Blues Jam", bpm: 80, timeSig: "12/8", style: "Blues" },
    { id: 2, name: "Rock Groove", bpm: 120, timeSig: "4/4", style: "Rock" },
    { id: 3, name: "Funk Practice", bpm: 100, timeSig: "4/4", style: "Funk" },
  ]);
  const [newSongName, setNewSongName] = useState("");

  // Stats
  const [totalPracticeTime, setTotalPracticeTime] = useState(0);
  const [sessionCount, setSessionCount] = useState(0);
  const sessionStartRef = useRef(null);

  // Scheduling refs
  const schedulerRef = useRef(null);
  const nextNoteTimeRef = useRef(0);
  const currentBeatRef = useRef(0);
  const barCountRef = useRef(0);
  const isSilentBarRef = useRef(false);

  // ─── Persistent Storage ─────────────────────────────────────────────
  // Load all user data on mount
  useEffect(() => {
    const loadData = async () => {
      try {
        const result = await window.storage.get("groovelab-userdata");
        if (result && result.value) {
          const data = JSON.parse(result.value);
          if (data.lang) setLang(data.lang);
          if (data.isPro) setIsPro(data.isPro);
          if (data.bpm) setBpm(data.bpm);
          if (data.timeSig) setTimeSig(data.timeSig);
          if (data.subdivision) setSubdivision(data.subdivision);
          if (data.clickSound) setClickSound(data.clickSound);
          if (data.swingAmount !== undefined) setSwingAmount(data.swingAmount);
          if (data.drumStyle) setDrumStyle(data.drumStyle);
          if (data.library) setLibrary(data.library);
          if (data.totalPracticeTime) setTotalPracticeTime(data.totalPracticeTime);
          if (data.sessionCount) setSessionCount(data.sessionCount);
        }
      } catch (e) {
        console.log("No saved data yet");
      }
      setDataReady(true);
    };
    loadData();
  }, []);

  // Save user data whenever key states change
  const saveData = useCallback(async () => {
    if (!dataReady) return;
    try {
      const data = {
        lang, isPro, bpm,
        timeSig, subdivision, clickSound, swingAmount,
        drumStyle, library, totalPracticeTime, sessionCount,
        lastSaved: new Date().toISOString(),
      };
      await window.storage.set("groovelab-userdata", JSON.stringify(data));
      setSaveStatus("✓");
      setTimeout(() => setSaveStatus(""), 1500);
    } catch (e) {
      console.error("Save failed:", e);
    }
  }, [dataReady, lang, isPro, bpm, timeSig, subdivision, clickSound, swingAmount, drumStyle, library, totalPracticeTime, sessionCount]);

  // Auto-save on key state changes (debounced)
  const saveTimerRef = useRef(null);
  useEffect(() => {
    if (!dataReady) return;
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
    saveTimerRef.current = setTimeout(() => saveData(), 1500);
    return () => { if (saveTimerRef.current) clearTimeout(saveTimerRef.current); };
  }, [lang, isPro, bpm, timeSig, subdivision, clickSound, swingAmount, drumStyle, library, totalPracticeTime, sessionCount, dataReady, saveData]);

  // ─── Pro Gating Helper ──────────────────────────────────────────────
  const FREE_TIME_SIGS = ["2/4", "3/4", "4/4"];
  const FREE_DRUM_STYLES = ["Rock", "Pop"];
  const FREE_MAX_SONGS = 5;

  const isTimeSigLocked = (ts) => !isPro && !FREE_TIME_SIGS.includes(ts.label);
  const isDrumStyleLocked = (s) => !isPro && !FREE_DRUM_STYLES.includes(s);
  const isLooperLocked = !isPro;
  const isPracticeLocked = !isPro;
  const canSaveSong = isPro || library.length < FREE_MAX_SONGS;

  // ─── Audio Init ──────────────────────────────────────────────────────
  const initAudio = useCallback(() => {
    audioEngine.init();
  }, []);

  // ─── Click sound player ──────────────────────────────────────────────
  const playMetronomeClick = useCallback(
    (beatIndex, time) => {
      const vol = accentPattern[beatIndex % accentPattern.length] || 0.7;
      if (vol === 0) return;

      // Random silence mode
      if (randomSilence && Math.random() * 100 < silenceProb && beatIndex !== 0) return;

      // Interval training silence
      if (intervalTraining && isSilentBarRef.current) return;

      const isAccent = beatIndex === 0;
      const freq = isAccent ? 1200 : 800;
      switch (clickSound) {
        case "Wood":
          audioEngine.playClick(freq, 0.025, vol * 0.8, time);
          break;
        case "Digital":
          audioEngine.playClick(isAccent ? 1500 : 1000, 0.015, vol * 0.9, time);
          break;
        case "Hi-Hat":
          audioEngine.playNoise(0.03, vol * 0.5, 8000, time);
          break;
        case "Clave":
          audioEngine.playClick(isAccent ? 2500 : 2000, 0.02, vol * 0.7, time);
          break;
        case "Cowbell":
          audioEngine.playClick(isAccent ? 800 : 600, 0.06, vol * 0.7, time);
          audioEngine.playClick(isAccent ? 1200 : 900, 0.04, vol * 0.4, time);
          break;
        case "Beep":
          audioEngine.playClick(isAccent ? 880 : 660, 0.04, vol * 0.6, time);
          break;
        default:
          audioEngine.playClick(freq, 0.025, vol * 0.8, time);
      }
    },
    [accentPattern, clickSound, randomSilence, silenceProb, intervalTraining]
  );

  // ─── Drum sound player ──────────────────────────────────────────────
  const playDrumStep = useCallback(
    (step, time) => {
      if (!drumMutes.kick && drumPattern.kick[step]) audioEngine.playKick(time);
      if (!drumMutes.snare && drumPattern.snare[step]) audioEngine.playSnare(time);
      if (!drumMutes.hihat && drumPattern.hihat[step]) audioEngine.playHiHat(time);
      if (!drumMutes.ride && drumPattern.ride[step]) audioEngine.playRide(time);
    },
    [drumPattern, drumMutes]
  );

  // ─── Metronome Scheduler ────────────────────────────────────────────
  const startScheduler = useCallback(() => {
    if (!audioEngine.ctx) return;

    const scheduleAheadTime = 0.1;
    const lookahead = 25; // ms

    currentBeatRef.current = 0;
    barCountRef.current = 0;
    nextNoteTimeRef.current = audioEngine.ctx.currentTime + 0.05;

    const scheduler = () => {
      while (nextNoteTimeRef.current < audioEngine.ctx.currentTime + scheduleAheadTime) {
        const beatInBar = currentBeatRef.current % timeSig.num;
        const totalSubBeats = timeSig.num * subdivision;
        const subBeatInBar = currentBeatRef.current % totalSubBeats;
        const isMainBeat = subBeatInBar % subdivision === 0;
        const mainBeatIndex = Math.floor(subBeatInBar / subdivision);

        // Calculate note duration
        let noteDuration = 60.0 / bpm / subdivision;

        // Apply swing to even-numbered sub-beats
        if (swingAmount > 0 && subdivision >= 2) {
          const isEven = subBeatInBar % 2 === 0;
          const swingRatio = 0.5 + (swingAmount / 200);
          if (isEven) {
            noteDuration = (60.0 / bpm / subdivision) * 2 * swingRatio;
          } else {
            noteDuration = (60.0 / bpm / subdivision) * 2 * (1 - swingRatio);
          }
        }

        // Play sounds
        if (activeTab === "metro" || activeTab === "practice") {
          if (isMainBeat) {
            playMetronomeClick(mainBeatIndex, nextNoteTimeRef.current);
          } else {
            // Sub-beat click (quieter)
            const vol = 0.3;
            audioEngine.playClick(600, 0.015, vol, nextNoteTimeRef.current);
          }
        }

        if (activeTab === "drums") {
          const drumStepIndex = currentBeatRef.current % 16;
          playDrumStep(drumStepIndex, nextNoteTimeRef.current);
          // Schedule UI update
          const stepTime = nextNoteTimeRef.current - audioEngine.ctx.currentTime;
          setTimeout(() => setDrumStep(drumStepIndex), stepTime * 1000);
        }

        // Schedule beat display update
        if (isMainBeat) {
          const beatTime = nextNoteTimeRef.current - audioEngine.ctx.currentTime;
          const b = mainBeatIndex;
          setTimeout(() => {
            setCurrentBeat(b);
            if (b === 0) setShowFlash(true);
          }, beatTime * 1000);
        }

        // Track bars for practice
        if (isMainBeat && mainBeatIndex === 0) {
          barCountRef.current++;

          // Interval training bar tracking
          if (intervalTraining) {
            const totalCycle = clickBars + silentBars;
            const posInCycle = (barCountRef.current - 1) % totalCycle;
            isSilentBarRef.current = posInCycle >= clickBars;
          }

          // Auto BPM increase
          if (practiceAutoIncrease && barCountRef.current > 0 && barCountRef.current % practiceInterval === 0) {
            setBpm((prev) => Math.min(prev + practiceIncrement, 500));
          }
        }

        nextNoteTimeRef.current += noteDuration;
        currentBeatRef.current++;
      }
    };

    schedulerRef.current = setInterval(scheduler, lookahead);
  }, [
    bpm, timeSig, subdivision, clickSound, swingAmount, activeTab,
    playMetronomeClick, playDrumStep, practiceAutoIncrease, practiceIncrement,
    practiceInterval, randomSilence, silenceProb, intervalTraining, clickBars, silentBars,
  ]);

  // ─── Play / Stop ────────────────────────────────────────────────────
  const togglePlay = useCallback(() => {
    initAudio();
    if (playing) {
      clearInterval(schedulerRef.current);
      setPlaying(false);
      setCurrentBeat(-1);
      setDrumStep(-1);
      // Track session time
      if (sessionStartRef.current) {
        const elapsed = (Date.now() - sessionStartRef.current) / 1000;
        setTotalPracticeTime((prev) => prev + elapsed);
        setSessionCount((prev) => prev + 1);
        sessionStartRef.current = null;
      }
    } else {
      sessionStartRef.current = Date.now();
      barCountRef.current = 0;
      isSilentBarRef.current = false;
      setPlaying(true);
    }
  }, [playing, initAudio]);

  useEffect(() => {
    if (playing) {
      startScheduler();
    }
    return () => {
      if (schedulerRef.current) clearInterval(schedulerRef.current);
    };
  }, [playing, startScheduler]);

  // Flash effect cleanup
  useEffect(() => {
    if (showFlash) {
      const t = setTimeout(() => setShowFlash(false), 150);
      return () => clearTimeout(t);
    }
  }, [showFlash]);

  // ─── Tap Tempo ──────────────────────────────────────────────────────
  const handleTap = useCallback(() => {
    initAudio();
    const now = Date.now();
    const taps = tapTimesRef.current;
    taps.push(now);
    // Keep last 6 taps
    if (taps.length > 6) taps.shift();
    if (taps.length >= 2) {
      const intervals = [];
      for (let i = 1; i < taps.length; i++) {
        const diff = taps[i] - taps[i - 1];
        if (diff < 3000) intervals.push(diff);
      }
      if (intervals.length > 0) {
        const avg = intervals.reduce((a, b) => a + b) / intervals.length;
        const newBpm = Math.round(60000 / avg);
        if (newBpm >= 20 && newBpm <= 500) setBpm(newBpm);
      }
    }
    // Reset if gap too long
    if (taps.length >= 2 && now - taps[taps.length - 2] > 3000) {
      tapTimesRef.current = [now];
    }
  }, [initAudio]);

  // ─── Tempo Wheel Drag ──────────────────────────────────────────────
  const wheelRef = useRef(null);
  const isDraggingRef = useRef(false);
  const lastAngleRef = useRef(0);

  const handleWheelStart = (e) => {
    isDraggingRef.current = true;
    const rect = wheelRef.current.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    lastAngleRef.current = Math.atan2(clientY - cy, clientX - cx);
  };

  const handleWheelMove = useCallback(
    (e) => {
      if (!isDraggingRef.current || !wheelRef.current) return;
      const rect = wheelRef.current.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const angle = Math.atan2(clientY - cy, clientX - cx);
      let delta = angle - lastAngleRef.current;
      if (delta > Math.PI) delta -= 2 * Math.PI;
      if (delta < -Math.PI) delta += 2 * Math.PI;
      const bpmChange = Math.round(delta * 30);
      if (bpmChange !== 0) {
        setBpm((prev) => Math.max(20, Math.min(500, prev + bpmChange)));
        lastAngleRef.current = angle;
      }
    },
    []
  );

  const handleWheelEnd = () => {
    isDraggingRef.current = false;
  };

  useEffect(() => {
    const move = (e) => handleWheelMove(e);
    const end = () => handleWheelEnd();
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", end);
    window.addEventListener("touchmove", move);
    window.addEventListener("touchend", end);
    return () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", end);
      window.removeEventListener("touchmove", move);
      window.removeEventListener("touchend", end);
    };
  }, [handleWheelMove]);

  // ─── Update accent pattern when time sig changes ───────────────────
  useEffect(() => {
    const newAccents = Array(timeSig.num).fill(0.7);
    newAccents[0] = 1;
    setAccentPattern(newAccents);
  }, [timeSig.num]);

  // ─── Drum pattern change ───────────────────────────────────────────
  useEffect(() => {
    setDrumPattern({ ...DRUM_PATTERNS[drumStyle] });
  }, [drumStyle]);

  // Toggle drum cell
  const toggleDrumCell = (instrument, step) => {
    setDrumPattern((prev) => {
      const next = { ...prev };
      next[instrument] = [...prev[instrument]];
      next[instrument][step] = next[instrument][step] ? 0 : 1;
      return next;
    });
  };

  // ─── Looper ────────────────────────────────────────────────────────
  const startLoopRecording = async () => {
    try {
      initAudio();
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      loopChunksRef.current = [];
      const recorder = new MediaRecorder(stream);
      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) loopChunksRef.current.push(e.data);
      };
      recorder.onstop = () => {
        const blob = new Blob(loopChunksRef.current, { type: "audio/webm" });
        const url = URL.createObjectURL(blob);
        if (loopAudioRef.current) {
          loopAudioRef.current.pause();
          URL.revokeObjectURL(loopAudioRef.current.src);
        }
        const audio = new Audio(url);
        audio.loop = true;
        loopAudioRef.current = audio;
        // Generate random waveform bars for visual
        const bars = Array.from({ length: 60 }, () => Math.random() * 50 + 10);
        setLoopBars(bars);
        setLoopState("playing");
        audio.play();
      };
      loopMediaRef.current = recorder;
      recorder.start();
      setLoopState("recording");
      setLoopDuration(0);
    } catch (err) {
      console.error("Mic access denied", err);
    }
  };

  const stopLoopRecording = () => {
    if (loopMediaRef.current && loopMediaRef.current.state !== "inactive") {
      loopMediaRef.current.stop();
      loopMediaRef.current.stream.getTracks().forEach((t) => t.stop());
    }
  };

  const clearLoop = () => {
    if (loopAudioRef.current) {
      loopAudioRef.current.pause();
      URL.revokeObjectURL(loopAudioRef.current.src);
      loopAudioRef.current = null;
    }
    setLoopState("idle");
    setLoopBars([]);
    setLoopDuration(0);
  };

  // ─── Library ───────────────────────────────────────────────────────
  const saveSong = () => {
    if (!newSongName.trim()) return;
    if (!canSaveSong) return;
    setLibrary((prev) => [
      ...prev,
      {
        id: Date.now(),
        name: newSongName,
        bpm,
        timeSig: timeSig.label,
        style: drumStyle,
      },
    ]);
    setNewSongName("");
  };

  const loadSong = (song) => {
    setBpm(song.bpm);
    const ts = TIME_SIGNATURES.find((t) => t.label === song.timeSig);
    if (ts) setTimeSig(ts);
    if (DRUM_PATTERNS[song.style]) setDrumStyle(song.style);
    setActiveTab("metro");
  };

  const deleteSong = (id) => {
    setLibrary((prev) => prev.filter((s) => s.id !== id));
  };

  // ─── Computed ──────────────────────────────────────────────────────
  const tempoName = getTempoName(bpm);
  const progressPct = ((bpm - 20) / 480) * 100;

  // ─── Accent toggle ────────────────────────────────────────────────
  const cycleAccent = (idx) => {
    setAccentPattern((prev) => {
      const next = [...prev];
      const levels = [0, 0.3, 0.7, 1];
      const currentIdx = levels.indexOf(next[idx]);
      next[idx] = levels[(currentIdx + 1) % levels.length];
      return next;
    });
  };

  // ─── Render Tabs ───────────────────────────────────────────────────
  const tabs = [
    { id: "metro", label: t(lang, "tabMetronome") },
    { id: "drums", label: t(lang, "tabDrums") },
    { id: "looper", label: t(lang, "tabLooper") },
    { id: "practice", label: t(lang, "tabPractice") },
    { id: "library", label: t(lang, "tabLibrary") },
    { id: "stats", label: t(lang, "tabStats") },
    { id: "settings", label: "⚙" },
  ];

  return (
    <>
      <style>{CSS}</style>
      <div className={`app-container ${stageMode ? "stage-mode" : ""}`}>
        {showFlash && <div className="flash-overlay" />}
        {saveStatus && <div className="save-indicator">{saveStatus} {t(lang, "dataSaved")}</div>}

        {/* Header */}
        <div className="app-header">
          <div className="app-logo">
            <div className="logo-mark">GL</div>
            <div className="logo-text-group">
              <span className="logo-text">GrooveLab {isPro && <span className="pro-badge">PRO</span>}</span>
              <span className="logo-subtitle">{t(lang, "subtitle")}</span>
            </div>
          </div>
          <button
            className={`stage-btn ${stageMode ? "active" : ""}`}
            onClick={() => setStageMode(!stageMode)}
          >
            {stageMode ? t(lang, "exitStage") : t(lang, "stage")}
          </button>
        </div>

        {/* Nav */}
        <div className="nav-bar">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={`nav-tab ${activeTab === tab.id ? "active" : ""}`}
              onClick={() => setActiveTab(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="main-content">
          {/* ══════════════ METRONOME TAB ══════════════ */}
          {activeTab === "metro" && (
            <>
              <div className="tempo-section">
                <div className="tempo-name">{tempoName}</div>

                {/* Tempo Wheel */}
                <div
                  className="tempo-wheel-container"
                  ref={wheelRef}
                  onMouseDown={handleWheelStart}
                  onTouchStart={handleWheelStart}
                >
                  <div className="tempo-wheel-bg" />
                  <div
                    className="tempo-wheel-progress"
                    style={{ "--progress": `${progressPct}%` }}
                  />
                  <div className="tempo-wheel-track" />
                  <div className="tempo-display">
                    <div className="tempo-number">{bpm}</div>
                    <div className="tempo-bpm-label">BPM</div>
                  </div>
                </div>

                {/* Tempo Slider */}
                <div style={{ width: "100%", padding: "0 20px", marginBottom: 12 }}>
                  <input
                    type="range"
                    min="20"
                    max="500"
                    value={bpm}
                    onChange={(e) => setBpm(parseInt(e.target.value))}
                    style={{ width: "100%" }}
                  />
                </div>

                {/* Main Controls */}
                <div className="controls-row">
                  <button className="ctrl-btn" onClick={() => setBpm((p) => Math.max(20, p - 1))}>
                    <MinusIcon />
                  </button>
                  <button
                    className={`play-btn ${playing ? "playing" : ""}`}
                    onClick={togglePlay}
                  >
                    {playing ? <StopIcon /> : <PlayIcon />}
                  </button>
                  <button className="ctrl-btn" onClick={() => setBpm((p) => Math.min(500, p + 1))}>
                    <PlusIcon />
                  </button>
                  <button className="tap-btn" onClick={handleTap}>
                    TAP
                  </button>
                </div>

                {/* Beat Visualizer */}
                <div className="beat-vis">
                  {Array.from({ length: timeSig.num }, (_, i) => (
                    <div
                      key={i}
                      className={`beat-dot ${currentBeat === i ? "active" : ""} ${
                        accentPattern[i] === 1 ? "accent-beat" : ""
                      }`}
                      onClick={() => cycleAccent(i)}
                    >
                      {i + 1}
                    </div>
                  ))}
                </div>
              </div>

              {/* Time Signature */}
              <div className="panel">
                <div className="panel-title">{t(lang, "timeSignature")}</div>
                <div className="chip-row">
                  {TIME_SIGNATURES.map((ts) => (
                    <button
                      key={ts.label}
                      className={`chip ${timeSig.label === ts.label ? "active" : ""} ${isTimeSigLocked(ts) ? "locked" : ""}`}
                      onClick={() => {
                        if (isTimeSigLocked(ts)) { setActiveTab("settings"); return; }
                        setTimeSig(ts);
                      }}
                    >
                      {ts.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Subdivisions */}
              <div className="panel">
                <div className="panel-title">{t(lang, "subdivision")}</div>
                <div className="chip-row">
                  {SUBDIVISIONS.map((sub) => {
                    const subNames = { Quarter: t(lang, "quarter"), Eighth: t(lang, "eighth"), Triplet: t(lang, "triplet"), "16th": t(lang, "sixteenth") };
                    return (
                    <button
                      key={sub.value}
                      className={`chip ${subdivision === sub.value ? "active" : ""}`}
                      onClick={() => setSubdivision(sub.value)}
                    >
                      {sub.label} {subNames[sub.name] || sub.name}
                    </button>
                    );
                  })}
                </div>
              </div>

              {/* Click Sound */}
              <div className="panel">
                <div className="panel-title">{t(lang, "clickSound")}</div>
                <div className="chip-row">
                  {CLICK_SOUNDS.map((s) => {
                    const sndNames = { Wood: t(lang, "sndWood"), Digital: t(lang, "sndDigital"), "Hi-Hat": t(lang, "sndHiHat"), Clave: t(lang, "sndClave"), Cowbell: t(lang, "sndCowbell"), Beep: t(lang, "sndBeep") };
                    return (
                    <button
                      key={s}
                      className={`chip ${clickSound === s ? "active" : ""}`}
                      onClick={() => setClickSound(s)}
                    >
                      {sndNames[s] || s}
                    </button>
                    );
                  })}
                </div>
              </div>

              {/* Swing */}
              <div className="panel">
                <div className="panel-title">{t(lang, "swingHuman")}</div>
                <div className="slider-container">
                  <span className="slider-label">{t(lang, "swing")}</span>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    value={swingAmount}
                    onChange={(e) => setSwingAmount(parseInt(e.target.value))}
                  />
                  <span className="slider-value">{swingAmount}%</span>
                </div>
              </div>
            </>
          )}

          {/* ══════════════ DRUMS TAB ══════════════ */}
          {activeTab === "drums" && (
            <>
              {/* Style selector */}
              <div className="panel">
                <div className="panel-title">{t(lang, "style")}</div>
                <div className="chip-row mb-12">
                  {DRUM_STYLES.map((s) => (
                    <button
                      key={s}
                      className={`chip ${drumStyle === s ? "active" : ""} ${isDrumStyleLocked(s) ? "locked" : ""}`}
                      onClick={() => {
                        if (isDrumStyleLocked(s)) { setActiveTab("settings"); return; }
                        setDrumStyle(s);
                      }}
                    >
                      {s}
                    </button>
                  ))}
                </div>

                {/* BPM + Play */}
                <div className="controls-row">
                  <button className="ctrl-btn" onClick={() => setBpm((p) => Math.max(20, p - 5))}>
                    <MinusIcon />
                  </button>
                  <span style={{ fontFamily: "'JetBrains Mono'", fontSize: 24, fontWeight: 700, color: "var(--accent)", minWidth: 60, textAlign: "center" }}>
                    {bpm}
                  </span>
                  <button className="ctrl-btn" onClick={() => setBpm((p) => Math.min(500, p + 5))}>
                    <PlusIcon />
                  </button>
                  <button className={`play-btn ${playing ? "playing" : ""}`} onClick={togglePlay} style={{ width: 56, height: 56 }}>
                    {playing ? <StopIcon /> : <PlayIcon />}
                  </button>
                </div>
              </div>

              {/* Sequencer Grid */}
              <div className="panel">
                <div className="panel-title">{t(lang, "sequencer16")}</div>
                <div className="drum-grid">
                  {["kick", "snare", "hihat", "ride"].map((inst) => (
                    <div className="drum-row" key={inst}>
                      <span
                        className="drum-label"
                        style={{
                          cursor: "pointer",
                          textDecoration: drumMutes[inst] ? "line-through" : "none",
                          opacity: drumMutes[inst] ? 0.4 : 1,
                        }}
                        onClick={() =>
                          setDrumMutes((prev) => ({ ...prev, [inst]: !prev[inst] }))
                        }
                      >
                        {inst.slice(0, 2)}
                      </span>
                      {drumPattern[inst].map((on, step) => (
                        <div
                          key={step}
                          className={`drum-cell ${on ? `on ${inst}-cell` : ""} ${
                            drumStep === step ? "current" : ""
                          }`}
                          onClick={() => toggleDrumCell(inst, step)}
                        />
                      ))}
                    </div>
                  ))}
                </div>
              </div>

              {/* Swing */}
              <div className="panel">
                <div className="panel-title">{t(lang, "swing")}</div>
                <div className="slider-container">
                  <span className="slider-label">{t(lang, "amount")}</span>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    value={swingAmount}
                    onChange={(e) => setSwingAmount(parseInt(e.target.value))}
                  />
                  <span className="slider-value">{swingAmount}%</span>
                </div>
              </div>
            </>
          )}

          {/* ══════════════ LOOPER TAB ══════════════ */}
          {activeTab === "looper" && (
            <>
              {isLooperLocked && (
                <div className="pro-upgrade-card" style={{ marginBottom: 16 }}>
                  <div style={{ fontSize: 40, marginBottom: 8 }}>🔒</div>
                  <h3>{t(lang, "featureLocked")}</h3>
                  <p className="pro-desc">{t(lang, "featureLockedDesc")}</p>
                  <button className="pro-subscribe-btn" onClick={() => setActiveTab("settings")}>
                    {t(lang, "upgradeToPro")} →
                  </button>
                </div>
              )}
              <div className={`pro-lock-overlay ${isLooperLocked ? "locked" : ""}`} style={{ pointerEvents: isLooperLocked ? "none" : "auto" }}>
              <div className="panel">
                <div className="panel-title">{t(lang, "looper")}</div>

                {/* Waveform Display */}
                <div className="loop-waveform">
                  {loopBars.length === 0 ? (
                    <span style={{ color: "var(--text-muted)", fontSize: 13 }}>
                      {loopState === "recording" ? t(lang, "recording") : t(lang, "tapRec")}
                    </span>
                  ) : (
                    <div className="loop-bars">
                      {loopBars.map((h, i) => (
                        <div
                          key={i}
                          className="loop-bar"
                          style={{ height: `${h}%` }}
                        />
                      ))}
                    </div>
                  )}
                </div>

                {/* Loop Controls */}
                <div className="loop-controls">
                  {loopState === "idle" && (
                    <button className="loop-btn" onClick={startLoopRecording}>
                      ● REC
                    </button>
                  )}
                  {loopState === "recording" && (
                    <button className="loop-btn recording" onClick={stopLoopRecording}>
                      ■ STOP
                    </button>
                  )}
                  {loopState === "playing" && (
                    <>
                      <button
                        className="loop-btn"
                        onClick={() => {
                          if (loopAudioRef.current) {
                            loopAudioRef.current.pause();
                            setLoopState("idle");
                          }
                        }}
                      >
                        ■ STOP
                      </button>
                      <button className="loop-btn" onClick={startLoopRecording}>
                        ● OVERDUB
                      </button>
                      <button className="loop-btn" onClick={clearLoop}>
                        ✕ CLEAR
                      </button>
                    </>
                  )}
                </div>
              </div>

              {/* Info */}
              <div className="panel">
                <div className="panel-title">{t(lang, "info")}</div>
                <p style={{ fontSize: 13, color: "var(--text-muted)", lineHeight: 1.6 }}>
                  {t(lang, "looperDesc")}
                </p>
              </div>
              </div>
            </>
          )}

          {/* ══════════════ PRACTICE TAB ══════════════ */}
          {activeTab === "practice" && (
            <>
              {isPracticeLocked && (
                <div className="pro-upgrade-card" style={{ marginBottom: 16 }}>
                  <div style={{ fontSize: 40, marginBottom: 8 }}>🔒</div>
                  <h3>{t(lang, "featureLocked")}</h3>
                  <p className="pro-desc">{t(lang, "featureLockedDesc")}</p>
                  <button className="pro-subscribe-btn" onClick={() => setActiveTab("settings")}>
                    {t(lang, "upgradeToPro")} →
                  </button>
                </div>
              )}
              <div style={{ opacity: isPracticeLocked ? 0.3 : 1, pointerEvents: isPracticeLocked ? "none" : "auto" }}>
              {/* Auto BPM Increase */}
              <div className="practice-card">
                <div className="flex-between mb-8">
                  <div>
                    <div className="practice-card-title">{t(lang, "autoBpmIncrease")}</div>
                    <div className="practice-card-desc">{t(lang, "autoBpmDesc")}</div>
                  </div>
                  <div
                    className={`toggle-switch ${practiceAutoIncrease ? "on" : ""}`}
                    onClick={() => setPracticeAutoIncrease(!practiceAutoIncrease)}
                  />
                </div>
                {practiceAutoIncrease && (
                  <>
                    <div className="slider-container mb-8">
                      <span className="slider-label">+BPM</span>
                      <input
                        type="range"
                        min="1"
                        max="20"
                        value={practiceIncrement}
                        onChange={(e) => setPracticeIncrement(parseInt(e.target.value))}
                      />
                      <span className="slider-value">+{practiceIncrement}</span>
                    </div>
                    <div className="slider-container">
                      <span className="slider-label">{t(lang, "every")}</span>
                      <input
                        type="range"
                        min="1"
                        max="16"
                        value={practiceInterval}
                        onChange={(e) => setPracticeInterval(parseInt(e.target.value))}
                      />
                      <span className="slider-value">{practiceInterval} {t(lang, "bars")}</span>
                    </div>
                  </>
                )}
              </div>

              {/* Interval Training */}
              <div className="practice-card">
                <div className="flex-between mb-8">
                  <div>
                    <div className="practice-card-title">{t(lang, "intervalTraining")}</div>
                    <div className="practice-card-desc">{t(lang, "intervalDesc")}</div>
                  </div>
                  <div
                    className={`toggle-switch ${intervalTraining ? "on" : ""}`}
                    onClick={() => setIntervalTraining(!intervalTraining)}
                  />
                </div>
                {intervalTraining && (
                  <>
                    <div className="slider-container mb-8">
                      <span className="slider-label">{t(lang, "click")}</span>
                      <input
                        type="range"
                        min="1"
                        max="16"
                        value={clickBars}
                        onChange={(e) => setClickBars(parseInt(e.target.value))}
                      />
                      <span className="slider-value">{clickBars} {t(lang, "bars")}</span>
                    </div>
                    <div className="slider-container">
                      <span className="slider-label">{t(lang, "silent")}</span>
                      <input
                        type="range"
                        min="1"
                        max="16"
                        value={silentBars}
                        onChange={(e) => setSilentBars(parseInt(e.target.value))}
                      />
                      <span className="slider-value">{silentBars} {t(lang, "bars")}</span>
                    </div>
                  </>
                )}
              </div>

              {/* Random Silence */}
              <div className="practice-card">
                <div className="flex-between mb-8">
                  <div>
                    <div className="practice-card-title">{t(lang, "randomSilence")}</div>
                    <div className="practice-card-desc">{t(lang, "randomDesc")}</div>
                  </div>
                  <div
                    className={`toggle-switch ${randomSilence ? "on" : ""}`}
                    onClick={() => setRandomSilence(!randomSilence)}
                  />
                </div>
                {randomSilence && (
                  <div className="slider-container">
                    <span className="slider-label">{t(lang, "probability")}</span>
                    <input
                      type="range"
                      min="5"
                      max="80"
                      value={silenceProb}
                      onChange={(e) => setSilenceProb(parseInt(e.target.value))}
                    />
                    <span className="slider-value">{silenceProb}%</span>
                  </div>
                )}
              </div>

              {/* Quick Play */}
              <div style={{ textAlign: "center", marginTop: 16 }}>
                <button className={`play-btn ${playing ? "playing" : ""}`} onClick={togglePlay}>
                  {playing ? <StopIcon /> : <PlayIcon />}
                </button>
                <div style={{ marginTop: 8, fontSize: 14, color: "var(--text-muted)" }}>
                  {bpm} BPM · {timeSig.label}
                </div>
              </div>
              </div>
            </>
          )}

          {/* ══════════════ LIBRARY TAB ══════════════ */}
          {activeTab === "library" && (
            <>
              {/* Save current */}
              <div className="panel mb-16">
                <div className="panel-title">{t(lang, "saveCurrentSettings")}</div>
                <div style={{ display: "flex", gap: 8 }}>
                  <input
                    className="inline-input"
                    placeholder={t(lang, "songPlaceholder")}
                    value={newSongName}
                    onChange={(e) => setNewSongName(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && saveSong()}
                  />
                  <button className="tap-btn" onClick={saveSong} style={{ whiteSpace: "nowrap", opacity: canSaveSong ? 1 : 0.4 }}>
                    {t(lang, "save")}
                  </button>
                </div>
                {!canSaveSong && (
                  <p style={{ fontSize: 11, color: "#f59e0b", marginTop: 8 }}>
                    🔒 {t(lang, "featureLockedDesc")} ({FREE_MAX_SONGS} max)
                  </p>
                )}
              </div>

              {/* Song list */}
              <div className="panel-title">{t(lang, "savedSongs")}</div>
              {library.map((song) => (
                <div key={song.id} className="song-item" onClick={() => loadSong(song)}>
                  <span className="song-bpm">{song.bpm}</span>
                  <div className="song-info">
                    <div className="song-name">{song.name}</div>
                    <div className="song-meta">
                      {song.timeSig} · {song.style}
                    </div>
                  </div>
                  <button
                    className="song-del"
                    onClick={(e) => {
                      e.stopPropagation();
                      deleteSong(song.id);
                    }}
                  >
                    ×
                  </button>
                </div>
              ))}
              {library.length === 0 && (
                <p style={{ color: "var(--text-muted)", fontSize: 13, textAlign: "center", marginTop: 24 }}>
                  {t(lang, "noSongsYet")}
                </p>
              )}
            </>
          )}

          {/* ══════════════ STATS TAB ══════════════ */}
          {activeTab === "stats" && (
            <>
              <div className="panel-title mb-12">{t(lang, "practiceStatistics")}</div>
              <div className="stat-grid">
                <div className="stat-card">
                  <div className="stat-value">{formatTime(totalPracticeTime)}</div>
                  <div className="stat-label">{t(lang, "totalTime")}</div>
                </div>
                <div className="stat-card">
                  <div className="stat-value">{sessionCount}</div>
                  <div className="stat-label">{t(lang, "sessions")}</div>
                </div>
                <div className="stat-card">
                  <div className="stat-value">{bpm}</div>
                  <div className="stat-label">{t(lang, "currentBpm")}</div>
                </div>
                <div className="stat-card">
                  <div className="stat-value">{tempoName}</div>
                  <div className="stat-label" style={{ fontSize: 10 }}>{t(lang, "tempo")}</div>
                </div>
              </div>

              <div className="panel" style={{ marginTop: 16 }}>
                <div className="panel-title">{t(lang, "sessionInfo")}</div>
                <p style={{ fontSize: 13, color: "var(--text-muted)", lineHeight: 1.6 }}>
                  {t(lang, "statsDesc")}
                </p>
              </div>
            </>
          )}

          {/* ══════════════ SETTINGS TAB ══════════════ */}
          {activeTab === "settings" && (
            <>
              <div className="panel-title mb-12">{t(lang, "settingsTitle")}</div>

              {/* Pro Status / Upgrade */}
              {isPro ? (
                <div className="pro-active-banner">
                  <div className="check-big">✓</div>
                  <h4>{t(lang, "proActive")}</h4>
                  <p style={{ fontSize: 12, color: "var(--text-muted)" }}>{t(lang, "proUnlock")}</p>
                </div>
              ) : (
                <div className="pro-upgrade-card">
                  <h3>{t(lang, "upgradeToPro")}</h3>
                  <p className="pro-desc">{t(lang, "proUnlock")}</p>

                  <div className="pro-plan-toggle">
                    <button className={proInterval === "monthly" ? "active" : ""} onClick={() => setProInterval("monthly")}>
                      {t(lang, "monthly")}
                    </button>
                    <button className={proInterval === "yearly" ? "active" : ""} onClick={() => setProInterval("yearly")}>
                      {t(lang, "yearly")}
                    </button>
                  </div>

                  <div className="pro-price">
                    {proInterval === "monthly" ? t(lang, "proPrice") : t(lang, "proPriceYear")}
                  </div>

                  <div className="pro-features-list">
                    {t(lang, "proFeatures").split(", ").map((f, i) => (
                      <div className="pro-feature-item" key={i}>
                        <span className="check">✓</span> {f}
                      </div>
                    ))}
                  </div>

                  <button className="pro-subscribe-btn" onClick={() => setIsPro(true)}>
                    {t(lang, "subscribe")}
                  </button>
                  <button className="pro-restore-btn" onClick={() => setIsPro(true)}>
                    {t(lang, "restorePurchase")}
                  </button>
                </div>
              )}

              {/* Free plan info */}
              {!isPro && (
                <div className="panel" style={{ marginBottom: 12 }}>
                  <div className="panel-title">{t(lang, "freePlan")}</div>
                  <div className="pro-features-list">
                    {t(lang, "freeFeatures").split(", ").map((f, i) => (
                      <div className="pro-feature-item" key={i}>
                        <span className="check" style={{ color: "var(--text-muted)" }}>•</span> {f}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Language selector */}
              <div className="panel">
                <div className="panel-title">{t(lang, "language")}</div>
                <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                  {LANGUAGES.map((l) => (
                    <button
                      key={l.code}
                      onClick={() => setLang(l.code)}
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 12,
                        padding: "12px 16px",
                        borderRadius: 12,
                        border: lang === l.code ? "1px solid var(--accent)" : "1px solid var(--border)",
                        background: lang === l.code ? "var(--accent-glow)" : "var(--bg-elevated)",
                        color: lang === l.code ? "var(--accent)" : "var(--text-secondary)",
                        cursor: "pointer",
                        fontFamily: "'Outfit', sans-serif",
                        fontSize: 14,
                        fontWeight: lang === l.code ? 600 : 400,
                        transition: "all 0.15s",
                        textAlign: "left",
                      }}
                    >
                      <span style={{ fontSize: 22 }}>{l.flag}</span>
                      <span>{l.label}</span>
                      {lang === l.code && (
                        <span style={{ marginLeft: "auto", fontSize: 16 }}>✓</span>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              {/* Deactivate Pro (for testing) */}
              {isPro && (
                <div className="panel" style={{ marginTop: 12 }}>
                  <button
                    style={{
                      width: "100%", padding: 10, borderRadius: 10,
                      border: "1px solid var(--border)", background: "var(--bg-input)",
                      color: "var(--text-muted)", fontFamily: "'Outfit'", fontSize: 12,
                      cursor: "pointer"
                    }}
                    onClick={() => setIsPro(false)}
                  >
                    Deactivate Pro (testing)
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </>
  );
}
