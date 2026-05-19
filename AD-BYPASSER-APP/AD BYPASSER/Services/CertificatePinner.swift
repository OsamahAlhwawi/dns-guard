import Foundation
import CryptoKit

/// URLSessionDelegate that pins SPKI SHA-256 fingerprints declared in `Constants.pinnedSPKIHashes`.
/// If no pins are configured for a host, the default system trust path is used.
final class CertificatePinner: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        let pins = Constants.pinnedSPKIHashes[host] ?? []
        if pins.isEmpty {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        for cert in chain {
            guard let publicKey = SecCertificateCopyKey(cert),
                  let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
            else { continue }
            let hash = SHA256.hash(data: data)
            let b64 = Data(hash).base64EncodedString()
            if pins.contains(b64) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
