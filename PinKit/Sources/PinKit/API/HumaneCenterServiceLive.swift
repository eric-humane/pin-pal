import Foundation
import Get
import Models

extension HumaneCenterService {
    public static func live() -> Self {
        let delegate = ClientDelegate()
        let client = APIClient(baseURL: API.rootUrl) {
            $0.delegate = delegate
            $0.decoder = {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSX"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                return decoder
            }()
            $0.encoder = {
                let decoder = JSONEncoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSX"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                decoder.dateEncodingStrategy = .formatted(dateFormatter)
                return decoder
            }()
        }
        return Self(
            captures: { 
                try await client.send(API.captures(page: $0, size: $1)).value
            },
            memory: {
                try await client.send(API.memory(uuid: $0)).value
            },
            deviceIdentifiers: {
                try await client.send(API.deviceIdentifiers()).value
            },
            download: {
                try await client.send(API.download(memoryUUID: $0, asset: $1)).data
            }
        )
    }
    
    enum Error: Swift.Error {
        case feedbackError
    }
}
