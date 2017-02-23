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


var options = [
    "tenantId": "768b5d51-37b0-44f7-a351-54fe59a67d18",
    "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/768b5d51-37b0-44f7-a351-54fe59a67d18"
    ]
import Credentials
private var router = Router()

let api = APIStrategy(options:options)


let credentials = Credentials()



credentials.register(plugin: api)


router.all("/api", middleware: [BodyParser(), credentials])

router.get("/api/protected", handler: { (request, response, next) in
    if let profile = request.userProfile {
        response.send("Hello from a protected resource " + profile.displayName)
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

