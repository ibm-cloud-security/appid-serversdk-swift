/*
 Copyright 2018 IBM Corp.
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

struct Constants {

    struct APIPlugin {
        static let name = "APIKituraCredentialsPlugin"
    }

    struct WebAppPlugin {
        static let name = "WebAppKituraCredentialsPlugin"
    }

    struct Utils {
        static let publicKey = "PublicKeyUtil"
        static let configuration = "AppIDPluginConfig"
        static let appId = "BluemixAppIDUtils"
    }

    struct VCAP {
        static let services = "VCAP_SERVICES"
        static let application = "VCAP_APPLICATION"
        static let credentials = "credentials"
        static let serviceName = "AppID"
        static let serviceNameV1 = "AdvancedMobileAccess"
    }

    struct Credentials {
        static let tenantId = "tenantId"
        static let clientId = "clientId"
        static let secret = "secret"
        static let redirectUri = "redirectUri"
        static let oauthServerUrl = "oauthServerUrl"
        static let userProfileServerUrl = "profilesUrl"
    }

    struct AppID {
        static let allowAnonymousLogin = "allowAnonymousLogin"
        static let allowCreateNewAnonymousUser = "allowCreateNewAnonymousUser"
        static let forceLogin = "forceLogin"

        static let defaultScope = "appid_default"
    }

    struct AuthContext {
        static let name = "APPID_AUTH_CONTEXT"
        static let identityToken = "identityToken"
        static let identityTokenPayload = "identityTokenPayload"
        static let accessToken = "accessToken"
        static let accessTokenPayload = "accessTokenPayload"
    }

    struct Endpoints {
        static let token = "/token"
        static let authorization = "/authorization"
        static let publicKeys = "/publickeys"
        static let attributes = "/api/v1/attributes"
        static let userInfo = "/userinfo"
    }

    static let context = "Context"
    static let isAnonymous = "isAnonymous"
    static let state = "state"
    static let bearer = "Bearer"
    static let authHeader = "Authorization"
}
