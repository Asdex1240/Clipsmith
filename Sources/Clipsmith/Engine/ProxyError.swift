import AVFoundation

enum ProxyError: Error, Equatable {
    case cannotCreateSession
    case exportFailed(String)
}
