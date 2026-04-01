//
//  TranscriptionLanguage.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// Transcription language
enum TranscriptionLanguage: String, Codable, CaseIterable {
    // Base languages (available with any model)
    case english = "en"
    case japanese = "ja"

    // Extended languages (require multilingual kit / small model)
    case korean = "ko"
    case chinese = "zh"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chinese: return "中文"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        case .italian: return "Italiano"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .portuguese: return "🇧🇷"
        case .italian: return "🇮🇹"
        case .russian: return "🇷🇺"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        }
    }

    var shortName: String {
        switch self {
        case .english: return "ENG"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chinese: return "中文"
        case .spanish: return "ESP"
        case .french: return "FRA"
        case .german: return "DEU"
        case .portuguese: return "POR"
        case .italian: return "ITA"
        case .russian: return "РУС"
        case .arabic: return "عربي"
        case .hindi: return "हिंदी"
        }
    }

    /// WhisperKit language code
    var whisperLanguage: String? {
        return rawValue
    }

    /// Whether this language requires the multilingual kit (small model)
    var requiresMultilingualKit: Bool {
        switch self {
        case .english:
            return false
        default:
            return true
        }
    }

    /// Prompt hint for Whisper to improve accuracy
    var lecturePrompt: String {
        switch self {
        case .english:
            return " This is a university lecture. Academic terminology, proper nouns, and technical vocabulary may be used."
        case .japanese:
            return " これは大学の講義です。学術用語、専門用語、固有名詞が使われることがあります。"
        case .korean:
            return " 이것은 대학 강의입니다. 학술 용어, 고유명사, 전문 용어가 사용될 수 있습니다."
        case .chinese:
            return " 这是一场大学讲座。可能会使用学术术语、专有名词和技术词汇。"
        case .spanish:
            return " Esta es una clase universitaria. Se pueden usar términos académicos, nombres propios y vocabulario técnico."
        case .french:
            return " Ceci est un cours universitaire. Des termes académiques, des noms propres et du vocabulaire technique peuvent être utilisés."
        case .german:
            return " Dies ist eine Universitätsvorlesung. Fachbegriffe, Eigennamen und technisches Vokabular können verwendet werden."
        case .portuguese:
            return " Esta é uma aula universitária. Termos acadêmicos, nomes próprios e vocabulário técnico podem ser usados."
        case .italian:
            return " Questa è una lezione universitaria. Possono essere utilizzati termini accademici, nomi propri e vocabolario tecnico."
        case .russian:
            return " Это университетская лекция. Могут использоваться академические термины, имена собственные и техническая лексика."
        case .arabic:
            return " هذه محاضرة جامعية. قد تُستخدم مصطلحات أكاديمية وأسماء علم ومفردات تقنية."
        case .hindi:
            return " यह एक विश्वविद्यालय व्याख्यान है। शैक्षणिक शब्दावली, व्यक्तिवाचक संज्ञा और तकनीकी शब्दावली का उपयोग किया जा सकता है।"
        }
    }

    /// Base languages available without the multilingual kit
    static var baseLanguages: [TranscriptionLanguage] {
        [.english]
    }

    /// Languages that require the multilingual kit
    static var extendedLanguages: [TranscriptionLanguage] {
        [.japanese, .korean, .chinese, .spanish, .french, .german, .portuguese, .italian, .russian, .arabic, .hindi]
    }
}
