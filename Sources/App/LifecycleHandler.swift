import Vapor
import Foundation

struct BarcodeDropLifecycleHandler: LifecycleHandler {

    // Called before application boots.
    func willBoot(_ app: Application) throws {
        app.logger.notice("APP WILL BOOT")
    }

    // Called after application boots.
    func didBoot(_ app: Application) throws {
        app.logger.notice("APP DID BOOT")
    }

    // Called before application shutdown.
    func shutdown(_ app: Application) {
        app.logger.notice("APP WILL SHUTDOWN")
    }

}
