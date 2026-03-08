import Foundation

protocol DateService {
    func now() -> Date
}

struct SystemDateService: DateService {
    func now() -> Date {
        Date()
    }
}
