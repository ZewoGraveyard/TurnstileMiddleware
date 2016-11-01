@_exported import Turnstile
import HTTP
import TurnstileWeb
import Foundation

public extension Request {
    internal(set) public var user: Subject {
        get {
            return storage["TurnstileSubject"] as! Subject
        }
        set {
            storage["TurnstileSubject"] = newValue
        }
    }
}

struct AuthorizationHeader {
    let headerValue: String

    init?(value: String?) {
        guard let value = value else {
            return nil
        }

        headerValue = value
    }

    var basic: APIKey? {
        guard let range = headerValue.range(of: "Basic ") else { return nil }
        let token = headerValue.substring(from: range.upperBound)

        guard let data = Data(base64Encoded: token) else {
            return nil
        }

        guard let decodedToken = String(data: data, encoding: .utf8),
            let separatorRange = decodedToken.range(of: ":") else {
                return nil
        }

        let apiKeyID = decodedToken.substring(to: separatorRange.lowerBound)
        let apiKeySecret = decodedToken.substring(from: separatorRange.upperBound)

        return APIKey(id: apiKeyID, secret: apiKeySecret)
    }

    var bearer: AccessToken? {
        guard let range = headerValue.range(of: "Bearer ") else { return nil }
        let token = headerValue.substring(from: range.upperBound)
        return AccessToken(string: token)
    }
}

extension Request {
    var auth: AuthorizationHeader? {
        return AuthorizationHeader(value: self.authorization)
    }
}

extension Request {
    func getCookie(name: String) -> String? {
        for cookie in cookies {
            if cookie.name == name {
                return cookie.value
            }
        }

        return nil
    }
}

public struct TurnstileMiddleware : Middleware {
    private let turnstile: Turnstile

    public init(
        sessionManager: SessionManager = MemorySessionManager(),
        realm: Realm = WebMemoryRealm()
    ) {
        self.turnstile = Turnstile(sessionManager: sessionManager, realm: realm)
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        request.user = Subject(
            turnstile: turnstile,
            sessionID: request.getCookie(name: "TurnstileSession")
        )

        if let apiKeys = request.auth?.basic {
            try? request.user.login(credentials: apiKeys)
        } else if let token = request.auth?.bearer {
            try? request.user.login(credentials: token)
        }

        var response = try next.respond(to: request)

        if let sessionID = request.user.authDetails?.sessionID {
            let cookie = AttributedCookie(
                name: "TurnstileSession",
                value: "\(sessionID)",
                expiration: .maxAge(60*60*24*365),
                path: "/",
                httpOnly: true
            )

            response.cookies.insert(cookie)
        }

        return response
    }
}
