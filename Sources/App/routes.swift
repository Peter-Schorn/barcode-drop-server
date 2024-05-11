import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow

func routes(_ app: Application) async throws {

    // MARK: Initialize Database

    guard let password = ProcessInfo.processInfo
            .environment["BARCODE_DROP_DATABASE_PASSWORD"] else {
        fatalError(
            """
            could not retrieve password from BARCODE_DROP_DATABASE_PASSWORD \
            environment variable
            """
        )
    }
    let connectionURI = "mongodb+srv://peter:\(password)@barcode-drop.5wwntye.mongodb.net/Barcodes"

    let database = try await MongoDatabase.connect(to: connectionURI)
    let barcodesCollection = database["barcodes"]


    app.get { req async in
        let message = "success (version 0.1.1)"
        req.logger.info("\(message)")
        return message
    }

    // POST /scan
    //
    // Saves scanned barcode to the database.
    //
    // Request: { "barcode": "1234567890" }
    // Response: "scanned '1234567890'"
    app.post("scan") { req async throws -> String in
        let scan = try req.content.decode(Scan.self)
        req.logger.info("scanned '\(scan.barcode)'")
        let scannedBarcode = ScannedBarcode(
            _id: ObjectId(),
            barcode: scan.barcode,
            date: Date()  // save date barcode was scanned to the database
        )

        // insert the scanned barcode into the database
        try await barcodesCollection.insertEncoded(scannedBarcode)

        return "scanned '\(scan.barcode)'"
    }

    // GET /scans
    app.get("scans") { req async throws -> [ScannedBarcodeResponse] in

        req.logger.info("retrieving scanned barcodes")

        let scans: [ScannedBarcode] = try await barcodesCollection
            .find()  // find all documents in the collection
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
        
        let response = ScannedBarcodeResponse.array(scans)
        req.logger.info(
            "retrieved \(response.count) scanned barcodes: \(response)"
        )

        return response
    }


}
