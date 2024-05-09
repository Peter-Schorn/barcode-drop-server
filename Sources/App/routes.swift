import Vapor

func routes(_ app: Application) throws {

    app.get { req async in
        return "success (version 0.1.0)"
    }


    app.post("scan") { req async throws -> String in
        let scan = try req.content.decode(Scan.self)
        req.logger.info("scanned \(scan.barcode)")
        return "scanned \(scan.barcode)"
    }

}
