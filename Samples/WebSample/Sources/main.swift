/*
 Copyright 2017 IBM Corp.
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import Kitura
import KituraNet
import SwiftyJSON
import LoggerAPI
import AppIDServerSDKSwift
import KituraSession


var LOGIN_URL = "/ibm/bluemix/appid/login"
var LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"
var CALLBACK_URL = "/ibm/bluemix/appid/callback"
var LOGOUT_URL = "/ibm/bluemix/appid/logout"
var LANDING_PAGE_URL = "/index.html"

var options = [
    "clientId": "85ed8be9-a820-4bbb-a78e-44eee50c57f2",
    "secret": "ZDQzMTU3YzQtN2RkMS00Yzk4LTg4MDYtYjZmYjlhNjI1OTFh",
    "tenantId": "768b5d51-37b0-44f7-a351-54fe59a67d18",
    "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/768b5d51-37b0-44f7-a351-54fe59a67d18",
    "redirectUri": "http://localhost:3002" + CALLBACK_URL
    ]
import Credentials
private var router = Router()
let session = Session(secret: "Some secret", store: nil)
router.all(middleware: session)
router.all("/", middleware: StaticFileServer(path: "./public"))

let web = WebAppStrategy(options:options)
let webAnon = WebAppStrategy(options:options)

let credentials = Credentials()
let anonCredentials = Credentials(options: [
    "allowAnonymousLogin": true,
    "allowCreateNewAnonymousUser": true
    ])


//TODO: two different credetilas needed for anon and not anon. add to logout anon call to anon credentials logout

credentials.register(plugin: web)
credentials.options["failureRedirect"] = LOGIN_URL

anonCredentials.register(plugin: webAnon)
anonCredentials.options["failureRedirect"] = LOGIN_URL

router.all("/protected", middleware: [BodyParser(), credentials])

router.get(LOGIN_URL, handler: credentials.authenticate(credentialsType: web.name, successRedirect: LANDING_PAGE_URL))
router.get(CALLBACK_URL, handler: credentials.authenticate(credentialsType: web.name, successRedirect: LANDING_PAGE_URL))
router.get(LOGIN_ANON_URL, handler: anonCredentials.authenticate(credentialsType: web.name, successRedirect: LANDING_PAGE_URL))
router.get(LOGOUT_URL, handler:  { (request, response, next) in
    credentials.logOut(request: request)
    WebAppStrategy.logout(request: request)
    do {
        try response.redirect(LANDING_PAGE_URL)
    } catch let err {
        response.status(.internalServerError)
    }
})
router.get("/protected", handler: { (request, response, next) in
    if let context:JSON = request.session?["APPID_AUTH_CONTEXT"] {
        var userId = AuthorizationContext(idTokenPayload: context["identityTokenPayload"]).userIdentity
        var provider =  userId.authBy.count > 0 ? userId.authBy[0]["provider"].stringValue : ""
        response.send(json: ["sub" : provider, "name": userId.displayName, "picture": userId.picture])
        response.status(.OK)
        next()
    } else {
        response.status(.OK)
        next()
    }
})

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 3002, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()

