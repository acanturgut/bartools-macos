import Foundation

// MARK: - Models

struct SonosDevice: Equatable {
    let name: String        // raw mDNS service name (RINCON_XXX@Room)
    let displayName: String // friendly room name extracted from service name
    let host: String
    let port: Int
    static func == (a: SonosDevice, b: SonosDevice) -> Bool { a.name == b.name }

    init(name: String, host: String, port: Int) {
        self.name = name
        self.host = host
        self.port = port
        // "RINCON_542A1B977FBC01400@Living Room" → "Living Room"
        if let atIdx = name.lastIndex(of: "@") {
            self.displayName = String(name[name.index(after: atIdx)...])
        } else {
            self.displayName = name
        }
    }
}

// MARK: - Manager

class SonosManager: NSObject {
    static let shared = SonosManager()

    private(set) var devices: [SonosDevice] = []
    var onDevicesChanged: (() -> Void)?

    private var browser: NetServiceBrowser?
    private var pending: [NetService] = []

    private override init() { super.init() }

    // MARK: - Discovery

    func startDiscovery() {
        devices = []; pending = []
        onDevicesChanged?()
        browser?.stop()
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: "_sonos._tcp.", inDomain: "local.")
    }

    func stopDiscovery() {
        browser?.stop(); browser = nil
    }

    // MARK: - UPnP SOAP

    private func soap(host: String, port: Int, path: String, ns: String,
                      action: String, innerBody: String,
                      completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "http://\(host):\(port)\(path)") else {
            completion(nil, err("Bad URL")); return
        }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.setValue("\"\(ns)#\(action)\"", forHTTPHeaderField: "SOAPAction")
        req.httpBody = """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>\(innerBody)</s:Body></s:Envelope>
        """.data(using: .utf8)
        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                completion(data.flatMap { String(data: $0, encoding: .utf8) }, error)
            }
        }.resume()
    }

    private func avt(_ device: SonosDevice, action: String, body: String,
                     completion: @escaping (String?, Error?) -> Void) {
        let ns = "urn:schemas-upnp-org:service:AVTransport:1"
        soap(host: device.host, port: device.port,
             path: "/MediaRenderer/AVTransport/Control",
             ns: ns, action: action, innerBody: body, completion: completion)
    }

    private func rc(_ device: SonosDevice, action: String, body: String,
                    completion: @escaping (String?, Error?) -> Void) {
        let ns = "urn:schemas-upnp-org:service:RenderingControl:1"
        soap(host: device.host, port: device.port,
             path: "/MediaRenderer/RenderingControl/Control",
             ns: ns, action: action, innerBody: body, completion: completion)
    }

    // MARK: - Transport Control

    func play(device: SonosDevice, completion: @escaping (Error?) -> Void) {
        avt(device, action: "Play",
            body: "<u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>")
        { _, e in completion(e) }
    }

    func pause(device: SonosDevice, completion: @escaping (Error?) -> Void) {
        avt(device, action: "Pause",
            body: "<u:Pause xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Pause>")
        { _, e in completion(e) }
    }

    func next(device: SonosDevice, completion: @escaping (Error?) -> Void) {
        avt(device, action: "Next",
            body: "<u:Next xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Next>")
        { _, e in completion(e) }
    }

    func previous(device: SonosDevice, completion: @escaping (Error?) -> Void) {
        avt(device, action: "Previous",
            body: "<u:Previous xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Previous>")
        { _, e in completion(e) }
    }

    // MARK: - State & Metadata

    func getTransportState(device: SonosDevice, completion: @escaping (String?) -> Void) {
        avt(device, action: "GetTransportInfo",
            body: "<u:GetTransportInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:GetTransportInfo>")
        { xml, _ in completion(xml.flatMap { self.xml($0, tag: "CurrentTransportState") }) }
    }

    func getPositionInfo(device: SonosDevice,
                         completion: @escaping (_ title: String?, _ artist: String?, _ album: String?) -> Void) {
        avt(device, action: "GetPositionInfo",
            body: "<u:GetPositionInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:GetPositionInfo>")
        { xml, _ in
            guard let xml = xml else { completion(nil, nil, nil); return }
            // TrackMetaData is HTML-entity-encoded DIDL-Lite XML
            let raw  = self.xml(xml, tag: "TrackMetaData") ?? ""
            let meta = raw
                .replacingOccurrences(of: "&lt;",  with: "<")
                .replacingOccurrences(of: "&gt;",  with: ">")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&apos;",with: "'")
                .replacingOccurrences(of: "&quot;",with: "\"")
            completion(self.xml(meta, tag: "dc:title"),
                       self.xml(meta, tag: "dc:creator"),
                       self.xml(meta, tag: "upnp:album"))
        }
    }

    // MARK: - Volume

    func getVolume(device: SonosDevice, completion: @escaping (Int?) -> Void) {
        rc(device, action: "GetVolume",
           body: "<u:GetVolume xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\"><InstanceID>0</InstanceID><Channel>Master</Channel></u:GetVolume>")
        { xml, _ in completion(xml.flatMap { self.xml($0, tag: "CurrentVolume") }.flatMap { Int($0) }) }
    }

    func setVolume(device: SonosDevice, volume: Int, completion: @escaping (Error?) -> Void) {
        rc(device, action: "SetVolume",
           body: "<u:SetVolume xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\"><InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>\(volume)</DesiredVolume></u:SetVolume>")
        { _, e in completion(e) }
    }

    // MARK: - Helpers

    func xml(_ s: String, tag: String) -> String? {
        guard let a = s.range(of: "<\(tag)>"),
              let b = s.range(of: "</\(tag)>") else { return nil }
        let v = String(s[a.upperBound..<b.lowerBound])
        return v.isEmpty ? nil : v
    }

    private func err(_ msg: String) -> Error {
        NSError(domain: "Sonos", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - NetServiceBrowser Delegate

extension SonosManager: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5)
        pending.append(service)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        devices.removeAll { $0.name == service.name }
        pending.removeAll { $0 === service }
        if !moreComing { onDevicesChanged?() }
    }
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {}
}

extension SonosManager: NetServiceDelegate {
    func netServiceDidResolveAddress(_ service: NetService) {
        // Parse the IP from the TXT record's "location=" key (most reliable)
        // e.g. location=http://192.168.1.5:1400/xml/device_description.xml
        var host: String?
        if let txtData = service.txtRecordData() {
            let txt = NetService.dictionary(fromTXTRecord: txtData)
            if let locData = txt["location"],
               let locStr = String(data: locData, encoding: .utf8),
               let url = URL(string: locStr) {
                host = url.host
            }
        }
        // Fallback to resolved hostname
        if host == nil {
            var h = service.hostName ?? "\(service.name).local"
            if h.hasSuffix(".") { h = String(h.dropLast()) }
            host = h
        }
        // Always connect over plain HTTP on port 1400 (not the mDNS-advertised SSL port)
        let device = SonosDevice(name: service.name, host: host!, port: 1400)
        if !devices.contains(device) { devices.append(device) }
        onDevicesChanged?()
    }
    func netService(_ service: NetService, didNotResolve errorDict: [String: NSNumber]) {}
}
