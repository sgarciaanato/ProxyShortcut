struct Proxy {
    let id: String
    let name: String
    let getCommand: String
    let setCommand: String

    static let all: [Proxy] = [
        Proxy(
            id: "auto",
            name: "Automatic proxy configuration",
            getCommand: "getautoproxyurl",
            setCommand: "setautoproxystate"
        ),
        Proxy(
            id: "http",
            name: "Web proxy (HTTP)",
            getCommand: "getwebproxy",
            setCommand: "setwebproxystate"
        ),
        Proxy(
            id: "https",
            name: "Secure web proxy (HTTPS)",
            getCommand: "getsecurewebproxy",
            setCommand: "setsecurewebproxystate"
        )
    ]
}
