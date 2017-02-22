import Foundation
import Kitura
import KituraNet
import SwiftyJSON
import HeliumLogger
import LoggerAPI
import AppIDServerSDKSwift
import KituraSession


var LOGIN_URL = "/ibm/bluemix/appid/login"
var LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"
var CALLBACK_URL = "/ibm/bluemix/appid/callback"
var LOGOUT_URL = "/ibm/bluemix/appid/logout"
var LANDING_PAGE_URL = "/web-app-sample.html"


import Credentials
private var router = Router()
let session = Session(secret: "Some secret", store: nil)
router.all(middleware: session)

// Handle HTTP GET requests to /
router.get("/") {
    request, response, next in
    response.send("Hello, World!")
    next()
}

let web = WebAppStrategy(options:["redirectUri": "http://localhost:3002" + CALLBACK_URL])
let webAnon = WebAppStrategy(options:["redirectUri": "http://localhost:3002" + CALLBACK_URL])

let credentials = Credentials()
let anonCredentials = Credentials(options: [
    "allowAnonymousLogin": true,
    "allowCreateNewAnonymousUser": true
    ])
credentials.register(plugin: web)
credentials.options["failureRedirect"] = LOGIN_URL
anonCredentials.register(plugin: webAnon)
anonCredentials.options["failureRedirect"] = LOGIN_URL
router.all("/protected", middleware: [BodyParser(), credentials])

router.get(LOGIN_URL, handler: credentials.authenticate(credentialsType: web.name, successRedirect: LANDING_PAGE_URL))
router.get(CALLBACK_URL, handler: credentials.authenticate(credentialsType: web.name, successRedirect: LANDING_PAGE_URL))
router.get(LOGIN_ANON_URL, handler: anonCredentials.authenticate(credentialsType: web.name, successRedirect: LANDING_PAGE_URL))
router.get(LOGOUT_URL, handler: { (request, response, next) in
    WebAppStrategy.logout(request: request)
    do {
        try response.redirect(LANDING_PAGE_URL)
    } catch let err {
        response.status(.internalServerError)
    }
})
router.get("/protected/protectedResource", handler: { (request, response, next) in
    if let profile = request.userProfile {
        response.send("Hi \(profile.displayName). Welcome to protected resource.")
        //TODO: add ensure registered
        response.status(.OK)
        next()
    } else {
        response.send("Hi anonymous user. Welcome to protected resource.")
        response.status(.OK)
        next()
    }})

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 3002, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()

