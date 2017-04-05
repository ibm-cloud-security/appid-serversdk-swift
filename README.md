# Bluemix App ID
Swift SDK for the Bluemix App ID service

[![Bluemix powered][img-bluemix-powered]][url-bluemix]
[![Travis][img-travis-master]][url-travis-master]
[![Coveralls][img-coveralls-master]][url-coveralls-master]
[![Codacy][img-codacy]][url-codacy]
[![Version][img-version]][url-repo]
[![DownloadsMonthly][img-downloads-monthly]][url-repo]
[![DownloadsTotal][img-downloads-total]][url-repo]
[![License][img-license]][url-repo]

[![GithubWatch][img-github-watchers]][url-github-watchers]
[![GithubStars][img-github-stars]][url-github-stars]
[![GithubForks][img-github-forks]][url-github-forks]

### Table of Contents
* [Summary](#summary)
* [Requirements](#requirements)
* [Installation](#installation)
* [Example Usage](#example-usage)
* [License](#license)

### Summary

This SDK provides Kitura Credentials plugins for protecting Web applications.


When using WebAppKituraCredentialsPlugin the unauthenticated client will get HTTP 302 redirect to the login page hosted by App ID service (or, depending on configuration, directly to identity provider login page).

Read the [official documentation](https://console.ng.bluemix.net/docs/services/appid/protecting-resources-swift.html#protecting-resources-swift) for information about getting started with Bluemix App ID Service.

### Requirements
* Swift 3.1
* Kitura 1.6

### Installation
```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/ibm-cloud-security/appid-serversdk-swift.git", majorVersion: 1)
    ]
)
```
* 0.0.x releases were tested on OSX and Linux with Swift 3.0.2

### Example Usage
Below is an example of using this SDK to protect Web applications.

#### Protecting web applications using WebAppKituraCredentialsPlugin
WebAppKituraCredentialsPlugin is based on the OAuth2 authorization_code grant flow and should be used for web applications that use browsers. The plugin provides tools to easily implement authentication and authorization flows. WebAppKituraCredentialsPlugin provides mechanisms to detect unauthenticated attempts to access protected resources. The WebAppKituraCredentialsPlugin will automatically redirect user's browser to the authentication page. After successful authentication user will be taken back to the web application's callback URL (redirectUri), which will once again use WebAppKituraCredentialsPlugin to obtain access and identity tokens from App ID service. After obtaining these tokens the WebAppKituraCredentialsPlugin will store them in HTTP session under WebAppKituraCredentialsPlugin.AuthContext key. In a scalable cloud environment it is recommended to persist HTTP sessions in a scalable storage like Redis to ensure they're available accross server app instances.

```swift
import Kitura
import KituraSession
import Credentials
import SwiftyJSON
import BluemixAppID

// Below URLs will be used for App ID OAuth flows
var LOGIN_URL = "/ibm/bluemix/appid/login"
var CALLBACK_URL = "/ibm/bluemix/appid/callback"
var LOGOUT_URL = "/ibm/bluemix/appid/logout"
var LANDING_PAGE_URL = "/index.html"

// Setup Kitura to use session middleware
// Must be configured with proper session storage for production
// environments. See https://github.com/IBM-Swift/Kitura-Session for
// additional documentation
let router = Router()
let session = Session(secret: "Some secret")
router.all(middleware: session)

// Use static resources if required directory
router.all("/", middleware: StaticFileServer(path: "./Tests/BluemixAppIDTests/public"))

// Below configuration can be obtained from Service Credentials
// tab in the App ID Dashboard. You're not required to manually provide below
// configuration if your Kitura application runs on Bluemix and is bound to the
// App ID service instance. In this case App ID configuration will be obtained
// automatically using VCAP_SERVICES environment variable.
//
// The redirectUri value can be supplied in three ways:
// 1. Manually in new WebAppKituraCredentialsPlugin options
// 2. As environment variable named `redirectUri`
// 3. If none of the above was supplied the App ID SDK will try to retrieve
//    application_uri of the application running on Bluemix and append a
//    default suffix "/ibm/bluemix/appid/callback"
let options = [
	"clientId": "{client-id}",
	"secret": "{secret}",
	"tenantId": "{tenant-id}",
	"oauthServerUrl": "{oauth-server-url}",
	"redirectUri": "{app-url}" + CALLBACK_URL
]
let webappKituraCredentialsPlugin = WebAppKituraCredentialsPlugin(options: options)
let kituraCredentials = Credentials()
kituraCredentials.register(plugin: webappKituraCredentialsPlugin)

// Explicit login endpoint
router.get(LOGIN_URL,
		   handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
												   successRedirect: LANDING_PAGE_URL,
												   failureRedirect: LANDING_PAGE_URL
))

// Callback to finish the authorization process. Will retrieve access and identity tokens from App ID
router.get(CALLBACK_URL,
		   handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
												   successRedirect: LANDING_PAGE_URL,
												   failureRedirect: LANDING_PAGE_URL
))

// Logout endpoint. Clears authentication information from session
router.get(LOGOUT_URL, handler:  { (request, response, next) in
	kituraCredentials.logOut(request: request)
	webappKituraCredentialsPlugin.logout(request: request)
	_ = try? response.redirect(LANDING_PAGE_URL)
})

// Protected area
router.get("/protected", handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name), { (request, response, next) in
    let appIdAuthContext:JSON? = request.session?[WebAppKituraCredentialsPlugin.AuthContext]
    let identityTokenPayload:JSON? = appIdAuthContext?["identityTokenPayload"]

    guard appIdAuthContext?.dictionary != nil, identityTokenPayload?.dictionary != nil else {
        response.status(.unauthorized)
        return next()
    }

    response.send(json: identityTokenPayload!)
    next()
})

// Start the server!
Kitura.addHTTPServer(onPort: 1234, with: router)
Kitura.run()
```

#### Anonymous login
WebAppKituraCredentialsPlugin allows users to login to your web application anonymously, meaning without requiring any credentials. After successful login the anonymous user access token will be persisted in HTTP session, making it available as long as HTTP session is kept alive. Once HTTP session is destroyed or expired the anonymous user access token will be destroyed as well.  

To allow anonymous login for a particular URL use two configuration properties as shown on a code snippet below:
* `WebAppKituraCredentialsPlugin.AllowAnonymousLogin` - set this value to true if you want to allow your users to login anonymously when accessing this endpoint. If this property is set to true no authentication will be required. The default value of this property is `false`, therefore you must set it explicitly to allow anonymous login.
* `WebAppKituraCredentialsPlugin.AllowCreateNewAnonymousUser` - By default a new anonymous user will be created every time this method is invoked unless there's an existing anonymous access_token stored in the current HTTP session. In some cases you want to explicitly control whether you want to automatically create new anonymous user or not. Set this property to `false` if you want to disable automatic creation of new anonymous users. The default value of this property is `true`.  

```swift
var LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"

let webappKituraCredentialsPlugin = WebAppKituraCredentialsPlugin(options: options)
let kituraCredentialsAnonymous = Credentials(options: [
	WebAppKituraCredentialsPlugin.AllowAnonymousLogin: true,
	WebAppKituraCredentialsPlugin.AllowCreateNewAnonymousUser: true
])
kituraCredentialsAnonymous.register(plugin: webappKituraCredentialsPlugin)

// Explicit anonymous login endpoint
router.get(LOGIN_ANON_URL,
		   handler: kituraCredentialsAnonymous.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
															successRedirect: LANDING_PAGE_URL,
															failureRedirect: LANDING_PAGE_URL
))


router.get(LOGOUT_URL, handler:  { (request, response, next) in
	kituraCredentialsAnonymous.logOut(request: request)
	webappKituraCredentialsPlugin.logout(request: request)
	_ = try? response.redirect(LANDING_PAGE_URL)
})

```

As mentioned previously the anonymous access_token and identity_token will be automatically persisted in HTTP session by App ID SDK. You can retrieve them from HTTP session via same mechanisms as regular tokens. Access and identity tokens will be kept in HTTP session and will be used until either them or HTTP session expires.

### License
This package contains code licensed under the Apache License, Version 2.0 (the "License"). You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and may also view the License in the LICENSE file within this package.

[img-bluemix-powered]: https://img.shields.io/badge/bluemix-powered-blue.svg
[url-bluemix]: http://bluemix.net
[url-repo]: https://github.com/ibm-cloud-security/appid-serversdk-swift
[img-license]: https://img.shields.io/github/license/ibm-cloud-security/appid-serversdk-swift.svg
[img-version]: https://img.shields.io/github/release/ibm-cloud-security/appid-serversdk-swift.svg
[img-downloads-monthly]: https://img.shields.io/github/downloads/ibm-cloud-security/appid-serversdk-swift/latest/total.svg
[img-downloads-total]: https://img.shields.io/github/downloads/ibm-cloud-security/appid-serversdk-swift/total.svg

[img-github-watchers]: https://img.shields.io/github/watchers/ibm-cloud-security/appid-serversdk-swift.svg?style=social&label=Watch
[url-github-watchers]: https://github.com/ibm-cloud-security/appid-serversdk-swift/watchers
[img-github-stars]: https://img.shields.io/github/stars/ibm-cloud-security/appid-serversdk-swift.svg?style=social&label=Star
[url-github-stars]: https://github.com/ibm-cloud-security/appid-serversdk-swift/stargazers
[img-github-forks]: https://img.shields.io/github/forks/ibm-cloud-security/appid-serversdk-swift.svg?style=social&label=Fork
[url-github-forks]: https://github.com/ibm-cloud-security/appid-serversdk-swift/network

[img-travis-master]: https://travis-ci.org/ibm-cloud-security/appid-serversdk-swift.svg
[url-travis-master]: https://travis-ci.org/ibm-cloud-security/appid-serversdk-swift

[img-coveralls-master]: https://coveralls.io/repos/github/ibm-cloud-security/appid-serversdk-swift/badge.svg
[url-coveralls-master]: https://coveralls.io/github/ibm-cloud-security/appid-serversdk-swift

[img-codacy]: https://api.codacy.com/project/badge/Grade/a6952171ff5c4adaa6cf41a8652516d4?branch=master
[url-codacy]: https://www.codacy.com/app/ibm-cloud-security/appid-serversdk-swift
