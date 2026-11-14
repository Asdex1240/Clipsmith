import Foundation

extension TitleTemplate {
    var titleKey: String {
        switch self {
        case .centerTitle: return "title.centerTitle"
        case .lowerThird: return "title.lowerThird"
        case .locationTag: return "title.locationTag"
        case .chapter: return "title.chapter"
        case .caption: return "title.caption"
        }
    }

    var sampleKey: String {
        switch self {
        case .centerTitle: return "title.centerTitle.sample"
        case .lowerThird: return "title.lowerThird.sample"
        case .locationTag: return "title.locationTag.sample"
        case .chapter: return "title.chapter.sample"
        case .caption: return "title.caption.sample"
        }
    }
}
