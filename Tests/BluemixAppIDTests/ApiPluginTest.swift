import XCTest
import Kitura
import SimpleLogger
import Credentials

@testable import BluemixAppID

class ApiPluginTest: XCTestCase {
	
	let options = [
		"oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/768b5d51-37b0-44f7-a351-54fe59a67d18"
	]
	
	let logger = Logger(forName:"ApiPluginTest")
	
	// Remove off_ for running
	func off_testRunApiServer(){
		logger.debug("Starting")
		
		let router = Router()
		let apiKituraCredentialsPlugin = APIKituraCredentialsPlugin(options: options)
		let kituraCredentials = Credentials()
		kituraCredentials.register(plugin: apiKituraCredentialsPlugin)
		router.all("/api/protected", middleware: [BodyParser(), kituraCredentials])
		router.get("/api/protected") { (req, res, next) in
			let name = req.userProfile?.displayName ?? "Anonymous"
			res.status(.OK)
			res.send("Hello from protected resource, \(name)")
			next()
		}
		
		Kitura.addHTTPServer(onPort: 1234, with: router)
		Kitura.run()
	}
}
