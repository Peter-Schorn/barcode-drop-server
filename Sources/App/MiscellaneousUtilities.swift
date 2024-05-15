import Foundation

extension Result {

    func flatMapErrorThrowing(
        _ transform: (Failure) throws -> Success
    ) -> Result<Success, Error> {

        return self.flatMapError { error in
            return Result<Success, Error> {
                try transform(error)
            }
        }

    }

}
