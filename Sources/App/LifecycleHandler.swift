import Vapor
import Foundation

struct BarcodeDropLifecycleHandler: LifecycleHandler {

    // Called before application boots.
    func willBoot(_ app: Application) throws {
        app.logger.notice("\(Self.self): APP WILL BOOT")
    }

    // Called after application boots.
    func didBoot(_ app: Application) throws {
        app.logger.notice("\(Self.self): APP DID BOOT")
    }

    // Called before application shutdown.
    func shutdown(_ app: Application) {
        app.logger.notice("\(Self.self): APP WILL SHUTDOWN")
    }

}
