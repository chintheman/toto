import Foundation
import Security

/// An anonymous, Keychain-persisted device identifier. No user accounts
/// exist anywhere in this app — this UUID is what Phase 2 (push tokens) and
/// Phase 3 (purchase records, keyed primarily on Apple's originalTransactionId
/// but usable here for local correlation) hang off instead of a login.
enum DeviceIdentity {
    private static let service = "com.chintheman.toto.deviceIdentity"
    private static let account = "anonymousDeviceUUID"

    static var current: UUID = {
        if let existing = readFromKeychain() {
            return existing
        }
        let generated = UUID()
        writeToKeychain(generated)
        return generated
    }()

    private static func readFromKeychain() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: string)
        else { return nil }
        return uuid
    }

    private static func writeToKeychain(_ uuid: UUID) {
        let data = Data(uuid.uuidString.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
