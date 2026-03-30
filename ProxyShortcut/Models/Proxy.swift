struct Proxy {
    let name: String
    let getCommand: String
    let setCommand: String

    static let all: [Proxy] = [
        Proxy(
            name: "Automatic proxy configuration",
            getCommand: "getautoproxyurl",
            setCommand: "setautoproxystate"
        ),
        Proxy(
            name: "Web proxy (HTTP)",
            getCommand: "getwebproxy",
            setCommand: "setwebproxystate"
        ),
        Proxy(
            name: "Secure web proxy (HTTPS)",
            getCommand: "getsecurewebproxy",
            setCommand: "setsecurewebproxystate"
        )
    ]
}
