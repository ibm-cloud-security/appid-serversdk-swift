import XCTest
import Kitura
import SimpleLogger
import Credentials
import KituraSession
import SwiftyJSON

@testable import BluemixAppID

class WebAppPluginTest: XCTestCase {
	
	let options = [
		"clientId": "86148468-1d73-48ac-9b5c-aaa86a34597a",
		"secret": "ODczMjUxZDAtNGJhMy00MzFkLTkzOGUtYmY4YzU0N2U3MTY4",
		"tenantId": "50d0beed-add7-48dd-8b0a-c818cb456bb4",
		"oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/50d0beed-add7-48dd-8b0a-c818cb456bb4",
		"redirectUri": "http://localhost:1234/ibm/bluemix/appid/callback"
	]
	
	var LOGIN_URL = "/ibm/bluemix/appid/login"
	var LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"
	var CALLBACK_URL = "/ibm/bluemix/appid/callback"
	var LOGOUT_URL = "/ibm/bluemix/appid/logout"
	var LANDING_PAGE_URL = "/index.html"

	let logger = Logger(forName:"WebAppPluginTest")
	
	// Remove off_ for running
	func off_testRunWebAppServer(){
		logger.debug("Starting")
		
		let router = Router()
		let session = Session(secret: "Some secret")
		router.all(middleware: session)
		router.all("/", middleware: StaticFileServer(path: "./Tests/BluemixAppIDTests/public"))

		let webappKituraCredentialsPlugin = WebAppKituraCredentialsPlugin(options: options)
		let kituraCredentials = Credentials()
		let kituraCredentialsAnonymous = Credentials(options: [
			WebAppKituraCredentialsPlugin.AllowAnonymousLogin: true,
			WebAppKituraCredentialsPlugin.AllowCreateNewAnonymousUser: true
		])
		
		kituraCredentials.register(plugin: webappKituraCredentialsPlugin)
		kituraCredentialsAnonymous.register(plugin: webappKituraCredentialsPlugin)

		router.get(LOGIN_URL,
		           handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
		                                                   successRedirect: LANDING_PAGE_URL,
		                                                   failureRedirect: LANDING_PAGE_URL
		))

		router.get(LOGIN_ANON_URL,
		           handler: kituraCredentialsAnonymous.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
		                                                            successRedirect: LANDING_PAGE_URL,
		                                                            failureRedirect: LANDING_PAGE_URL
		))

		router.get(CALLBACK_URL,
		           handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
		                                                   successRedirect: LANDING_PAGE_URL,
		                                                   failureRedirect: LANDING_PAGE_URL
		))
		
		router.get(LOGOUT_URL, handler:  { (request, response, next) in
			kituraCredentials.logOut(request: request)
			kituraCredentialsAnonymous.logOut(request: request)
			webappKituraCredentialsPlugin.logout(request: request)
			_ = try? response.redirect(self.LANDING_PAGE_URL)
		})
		
		router.get("/protected", handler: { (request, response, next) in
			let appIdAuthContext:JSON? = request.session?[WebAppKituraCredentialsPlugin.AuthContext]
			let identityTokenPayload:JSON? = appIdAuthContext?["identityTokenPayload"]
			
			guard appIdAuthContext?.dictionary != nil, identityTokenPayload?.dictionary != nil else {
				response.status(.unauthorized)
				return next()
			}

			print("accessToken:: \(appIdAuthContext!["accessToken"])")
			print("identityToken:: \(appIdAuthContext!["identityToken"])")
			response.send(json: identityTokenPayload!)
			next()
		})
		
		Kitura.addHTTPServer(onPort: 1234, with: router)
		Kitura.run()
	}
}
