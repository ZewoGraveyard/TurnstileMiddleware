let router = BasicRouter { route in
    route.post("/login") { request in
        let credentials = UsernamePassword(username: username, password: password)

        do {
            try request.user.login(credentials: credentials, persist: true)
            // If this call succeeds without throwing an error, the user is now logged in.
        } catch let error as TurnstileError {
            // TurnstileErrors have error.description string which is safe to display to the user.
        }
        Response(body: "hello")
    }
}