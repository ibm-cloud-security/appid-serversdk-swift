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

public enum AppIDError: String, Error {
    case unauthorized = "Unauthorized"
    case failedParsingAuthContext = "Failed to parse authorization context"
    case jsonUtilsError = "json is malformed"
}

internal enum AppIDErrorInternal: String, Error {
    case authorizationHeaderNotFound = "Authorization header not found"
    case invalidAuthHeaderFormat = "Invalid authorization header format. Expected format 'Bearer accessToken idToken'"
    case invalidAccessToken = "Invalid access token"
    case invalidAccessTokenFormat = "Invalid access token format"
    case invalidAccessTokenSignature = "Invalid access token signature"
    case couldNotValidateAccessTokenSignature = "Could not validate access token signature"
    case publicKeyNotFound = "Public key not found"
}

internal enum OauthError: String {
    case invalidRequest = "invalid_request"
    case invalidToken = "invalid_token"
    case insufficientScope = "insufficient_scope"
    case missingAuth = "missing_authorization"
    case internalServerError = "internal_server_error"
}
