# TurnstileMiddleware 

`TurnstileMiddleware` is a Zewo middleware which provides authentication through [Turnstile](https://github.com/stormpath/Turnstile).

[![Swift][swift-badge]][swift-url]
[![License][mit-badge]][mit-url]
[![Slack][slack-badge]][slack-url]
[![Travis][travis-badge]][travis-url]
[![Codecov][codecov-badge]][codecov-url]
[![Codebeat][codebeat-badge]][codebeat-url]

## Installation

Add TurnstileMiddleware to your `Package.swift`

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/Zewo/TurnstileMiddleware.git", majorVersion: 0, minor: 14),
    ]
)
```

## Usage

```swift
import HTTPServer
import TurnstileMiddleware

let router = BasicRouter { route in
    route.get("/hello") { _ in
    	Response(body: "hello")
    }
}

let turnstile = TurnstileMiddleware()
let server = try Server(port: 8080, middleware: [turnstile], responder: router)
try server.start()

```

By default, TurnstileMiddleware uses Turnstile's MemorySessionManager and MemoryWebRealm to store user accounts and sessions in memory. This is great for development purposes, but your accounts will disappear when the server is shut off. To persist your user accounts to a database, you'll need to build your own Realm by [reading the Turnstile documentation](https://github.com/stormpath/Turnstile#realm).

The `WebMemoryRealm` supports Username/Password, Facebook, and Google authentication.

## Authenticating a User

Turnstile adds a `user` property to every `Request`. This is a Turnstile `Subject`, which represents the current operating user, and what we know about them. For a username/password combination, we'll need to login a user. We can collect the user info from the request, put them in a `UsernamePassword` value, and give it to Turnstile to authenticate.

```swift
let router = BasicRouter { route in

    struct Credentials : MapInitializable {
        let username: String
        let password: String
    }

    route.post("/login") { (request, credentials: Credentials)  in
        let credentials = UsernamePassword(
            username: credentials.username,
            password: credentials.password
        )

        // If this call succeeds without throwing an error, the user is now logged in.
        try request.user.login(credentials: credentials, persist: true)
        return Response(body: "Success! 😎")
    }
}
```

When the user is authenticated, you can query for things like:

```swift
// True if the user is authenticated
request.user.authenticated 

// The unique ID of the account in the database
request.user.authDetails?.account.uniqueID 

// A string with the session ID, if persist is true
request.user.authDetails?.sessionID 

// This would be UsernamePassword.self on the first request, and
// Session.self on subsequent requests. 
request.user.authDetails?.credentialType 
```

## Registering a User

As a convenience, you can register users using Turnstile and the MemoryWebRealm. This looks the same as logging in, except for:

```swift
try request.user.register(credentials: credentials)
```

Registering a user does not automatically log them in, so you'll need to call `login` afterwards as well.

## Authenticating with Facebook or Google

The Facebook and Google Login flows look like the following:

Your web application redirects the user to the Facebook / Google login page, and saves a "state" to prevent a malicious attacker from hijacking the login session.
The user logs in.
Facebook / Google redirects the user back to your application.
The application validates the Facebook / Google token as well as the state, and logs the user in.

### Create a Facebook Application

To get started, you first need to [register an application](https://developers.facebook.com/?advanced_app_create=true) with Facebook. After registering your app, go into your app dashboard's settings page. Add the Facebook Login product, and save the changes.

In the **Valid OAuth redirect URIs box**, type in a URL you'll use for step 3 in the OAuth process. (eg, `http://localhost:8080/login/facebook/consumer`)

### Create a Google Application

To get started, you first need to [register an application](https://console.developers.google.com/project) with Google. Click "Enable and Manage APIs", and then the [credentials tab](https://console.developers.google.com/apis/credentials). Create an OAuth Client ID for "Web".

Add a URL you'll use for step 3 in the OAuth process to the **Authorized redirect URIs** list. (eg, `http://localhost:8080/login/google/consumer`)

### Initiating the Login Redirect

To use Facebook/Google login, import `TurnstileWeb`. TurnstileWeb has `Facebook` and `Google` objects, which will allow a you to set up your configured application and log users in. To initialize them, use the client ID and secret (sometimes called App ID) from your Facebook or Google developer console:

```swift
let facebook = Facebook(
    clientID: "clientID",
    clientSecret: "clientSecret"
)

let google = Google(
    clientID: "clientID",
    clientSecret: "clientSecret"
)
```

Then, we'll generate a "state", save it with a cookie, and redirect the user:

```swift
route.get("/login/facebook") { request in
    // This is using the TurnstileCrypto random token generator.
    let state = URandom().secureToken

    let redirectURL = facebook.getLoginLink(
        redirectURL: "http://localhost:8181/login/facebook/consumer",
        state: state
    )

    var response = Response(status: .found)
    response.headers["Location"] = redirectURL.absoluteString

    let cookie = AttributedCookie(
        name: "OAuthState",
        value: state,
        expiration: .maxAge(3600),
        path: "/",
        httpOnly: true
    )

    response.cookies.insert(cookie)
    return response
}
```

### Consuming the Login Response

Once the user is redirected back to your application, you can now verify that they've properly authenticated using the `state` from the earlier step, and the full URL that the user has been redirected to. If successful, it will return a `FacebookAccount` or `GoogleAccount`. These implement the `Credentials` protocol, so then can be passed back into your application's Realm for further validation.

```swift
route.get("/login/facebook/consumer") { request in
    // Check that the state matches the cookie.
    guard let state = request.cookies.filter({ $0.name == "OAuthState"} ).first?.value else {
        // Throw some custom error
        throw LoginError.cookiesDontMatch
    }

    var response = Response(status: .found)
    response.headers["Location"] = "/"

    // Expire the "state" token.
    let cookie = AttributedCookie(
        name: "OAuthState",
        value: state,
        expiration: .maxAge(0),
        path: "/",
        httpOnly: true
    )

    response.cookies.insert(cookie)

    var url = "http://localhost:8181" + request.path!

    let credentials = try facebook.authenticate(
        authorizationCodeCallbackURL: url,
        state: state
    ) as! FacebookAccount

    // Use the credentials to login.
    try request.user.login(
        credentials: credentials,
        persist: true
    )

    return response
}
```

Congrats! You've gotten your first application working with Turnstile! To do more advanced things, we recommend digging into the code, or reading the [Turnstile](https://github.com/stormpath/Turnstile) documentation for more information.

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-badge]: https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat
[swift-url]: https://swift.org
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
[slack-image]: http://s13.postimg.org/ybwy92ktf/Slack.png
[slack-badge]: https://zewo-slackin.herokuapp.com/badge.svg
[slack-url]: http://slack.zewo.io
[travis-badge]: https://travis-ci.org/Zewo/TurnstileMiddleware.svg?branch=master
[travis-url]: https://travis-ci.org/Zewo/TurnstileMiddleware
[codecov-badge]: https://codecov.io/gh/Zewo/TurnstileMiddleware/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/Zewo/TurnstileMiddleware
[codebeat-badge]: https://codebeat.co/badges/95be315c-e5ff-4c5a-bf9d-959fc305cc0c
[codebeat-url]: https://codebeat.co/projects/github-com-zewo-turnstilemiddleware
