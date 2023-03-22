import Foundation

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

enum APIError: Error {
    case networkFailed
}

public class APIClient {
    private init() {}
    public static let shared = APIClient()
    
    public func fetch(request: String, completion: @escaping(Result<String, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion(.success(request))
        }
    }
    
    public func fetch(completion: @escaping(Result<String, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.failure(APIError.networkFailed))
        }
    }
    
    public func fetch(request: String) async throws -> String {
        try await Task.sleep(seconds: 1)
        return request
    }
    
    public func fetch() async throws -> String {
        try await Task.sleep(seconds: 1)
        throw APIError.networkFailed
    }
}


