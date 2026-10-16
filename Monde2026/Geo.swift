import Foundation

// =============================================================
//  Geo.swift
//  Position de chaque pays sur la carte (centre approximatif)
//  et code ISO à 2 lettres (pour le drapeau emoji).
// =============================================================

struct GeoInfo {
    let iso2: String
    let lat: Double
    let lon: Double
}

enum Geo {

    static func info(_ id: CountryID) -> GeoInfo {
        table[id] ?? GeoInfo(iso2: "UN", lat: 0, lon: 0)
    }

    /// Drapeau emoji à partir du code ISO à 2 lettres.
    static func flag(_ id: CountryID) -> String {
        let base: UInt32 = 127397
        var result = ""
        for scalar in info(id).iso2.unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
        return result
    }

    /// Distance approximative entre deux pays (km), à vol d'oiseau.
    static func distance(_ a: CountryID, _ b: CountryID) -> Double {
        let p = info(a), q = info(b)
        let rad = Double.pi / 180
        let dLat = (q.lat - p.lat) * rad
        let dLon = (q.lon - p.lon) * rad
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(p.lat * rad) * cos(q.lat * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * 6371 * asin(min(1, h.squareRoot()))
    }

    private static func g(_ iso2: String, _ lat: Double, _ lon: Double) -> GeoInfo {
        GeoInfo(iso2: iso2, lat: lat, lon: lon)
    }

    static let table: [CountryID: GeoInfo] = [
        // Amériques
        "USA": g("US", 39.8, -98.6), "CAN": g("CA", 56.1, -106.3), "MEX": g("MX", 23.6, -102.5),
        "BRA": g("BR", -10.8, -52.9), "ARG": g("AR", -35.4, -65.2), "COL": g("CO", 4.1, -73.0),
        "VEN": g("VE", 7.1, -66.2), "CHL": g("CL", -33.5, -70.9), "PER": g("PE", -9.2, -75.0),
        "CUB": g("CU", 21.5, -79.5), "ECU": g("EC", -1.8, -78.2), "BOL": g("BO", -16.3, -63.6),
        "PRY": g("PY", -23.4, -58.4), "URY": g("UY", -32.5, -55.8), "GTM": g("GT", 15.8, -90.2),
        "HND": g("HN", 15.2, -86.2), "SLV": g("SV", 13.8, -88.9), "NIC": g("NI", 12.9, -85.2),
        "CRI": g("CR", 9.7, -83.8), "PAN": g("PA", 8.5, -80.8), "DOM": g("DO", 18.7, -70.2),
        "HTI": g("HT", 19.0, -72.7), "JAM": g("JM", 18.1, -77.3), "GUY": g("GY", 4.9, -58.9),
        "SUR": g("SR", 4.0, -56.0),
        // Europe de l'Ouest
        "GBR": g("GB", 54.0, -2.0), "FRA": g("FR", 46.6, 2.4), "DEU": g("DE", 51.2, 10.4),
        "ITA": g("IT", 42.8, 12.6), "ESP": g("ES", 40.2, -3.6), "NLD": g("NL", 52.2, 5.5),
        "BEL": g("BE", 50.6, 4.6), "CHE": g("CH", 46.8, 8.2), "AUT": g("AT", 47.6, 14.1),
        "PRT": g("PT", 39.6, -8.0), "GRC": g("GR", 39.1, 22.0), "SWE": g("SE", 62.0, 15.0),
        "NOR": g("NO", 61.0, 9.0), "FIN": g("FI", 63.5, 26.0), "DNK": g("DK", 56.0, 9.5),
        "IRL": g("IE", 53.2, -8.2), "ISL": g("IS", 64.9, -18.5), "LUX": g("LU", 49.8, 6.1),
        "CYP": g("CY", 35.0, 33.2),
        // Europe de l'Est, Balkans, Caucase
        "POL": g("PL", 52.1, 19.4), "ROU": g("RO", 45.9, 25.0), "CZE": g("CZ", 49.8, 15.5),
        "HUN": g("HU", 47.2, 19.5), "UKR": g("UA", 49.0, 31.4), "BLR": g("BY", 53.7, 28.0),
        "RUS": g("RU", 56.5, 50.0), "MDA": g("MD", 47.2, 28.5), "SRB": g("RS", 44.0, 20.9),
        "BGR": g("BG", 42.7, 25.5), "SVK": g("SK", 48.7, 19.7), "HRV": g("HR", 45.3, 16.0),
        "SVN": g("SI", 46.1, 14.8), "BIH": g("BA", 44.2, 17.8), "ALB": g("AL", 41.1, 20.0),
        "MKD": g("MK", 41.6, 21.7), "MNE": g("ME", 42.7, 19.4), "XKX": g("XK", 42.6, 20.9),
        "LTU": g("LT", 55.2, 23.9), "LVA": g("LV", 56.9, 24.6), "EST": g("EE", 58.6, 25.0),
        "ARM": g("AM", 40.1, 45.0), "AZE": g("AZ", 40.4, 47.7), "GEO": g("GE", 42.3, 43.4),
        // Moyen-Orient
        "TUR": g("TR", 39.0, 35.2), "ISR": g("IL", 31.4, 35.0), "IRN": g("IR", 32.4, 53.7),
        "IRQ": g("IQ", 33.2, 43.7), "SAU": g("SA", 24.0, 45.0), "ARE": g("AE", 23.9, 54.3),
        "QAT": g("QA", 25.3, 51.2), "KWT": g("KW", 29.3, 47.6), "SYR": g("SY", 35.0, 38.5),
        "JOR": g("JO", 31.2, 36.5), "LBN": g("LB", 33.9, 35.9), "YEM": g("YE", 15.6, 48.0),
        "OMN": g("OM", 21.5, 57.0), "BHR": g("BH", 26.0, 50.55), "AFG": g("AF", 33.9, 67.7),
        // Afrique
        "EGY": g("EG", 26.6, 30.8), "DZA": g("DZ", 28.2, 2.6), "LBY": g("LY", 27.0, 17.2),
        "MAR": g("MA", 31.8, -7.1), "TUN": g("TN", 34.0, 9.5), "MRT": g("MR", 20.3, -10.9),
        "NGA": g("NG", 9.1, 8.7), "ETH": g("ET", 9.1, 40.5), "ZAF": g("ZA", -29.0, 24.7),
        "AGO": g("AO", -12.3, 17.5), "KEN": g("KE", 0.2, 37.9), "COD": g("CD", -2.9, 23.6),
        "SDN": g("SD", 15.6, 30.2), "SSD": g("SS", 7.0, 30.0), "TCD": g("TD", 15.5, 18.7),
        "NER": g("NE", 17.6, 8.1), "MLI": g("ML", 17.6, -2.0), "BFA": g("BF", 12.2, -1.6),
        "SEN": g("SN", 14.5, -14.5), "GHA": g("GH", 7.9, -1.0), "CIV": g("CI", 7.5, -5.5),
        "CMR": g("CM", 5.7, 12.4), "SOM": g("SO", 5.2, 46.2), "ERI": g("ER", 15.2, 39.8),
        "UGA": g("UG", 1.4, 32.3), "TZA": g("TZ", -6.4, 34.9), "RWA": g("RW", -1.9, 29.9),
        "BDI": g("BI", -3.4, 29.9), "MOZ": g("MZ", -18.7, 35.5), "ZMB": g("ZM", -13.1, 27.8),
        "ZWE": g("ZW", -19.0, 29.2), "NAM": g("NA", -22.6, 17.1), "BWA": g("BW", -22.3, 24.7),
        "MDG": g("MG", -18.8, 46.9), "MWI": g("MW", -13.3, 34.3), "GIN": g("GN", 10.0, -10.9),
        "BEN": g("BJ", 9.3, 2.3), "TGO": g("TG", 8.6, 0.8), "CAF": g("CF", 6.6, 20.9),
        "COG": g("CG", -0.7, 15.2), "GAB": g("GA", -0.8, 11.6), "DJI": g("DJ", 11.8, 42.6),
        // Asie
        "IND": g("IN", 22.0, 79.0), "PAK": g("PK", 30.0, 69.4), "BGD": g("BD", 23.7, 90.3),
        "NPL": g("NP", 28.4, 84.1), "LKA": g("LK", 7.9, 80.8), "KAZ": g("KZ", 48.0, 67.0),
        "TKM": g("TM", 39.0, 59.5), "UZB": g("UZ", 41.4, 64.6), "KGZ": g("KG", 41.2, 74.8),
        "TJK": g("TJ", 38.9, 71.3), "MNG": g("MN", 46.9, 103.8), "CHN": g("CN", 35.0, 103.0),
        "JPN": g("JP", 36.5, 138.5), "KOR": g("KR", 36.4, 127.9), "PRK": g("KP", 40.2, 127.2),
        "TWN": g("TW", 23.7, 121.0), "VNM": g("VN", 16.0, 107.5), "THA": g("TH", 15.1, 101.0),
        "MYS": g("MY", 3.8, 102.0), "SGP": g("SG", 1.35, 103.8), "IDN": g("ID", -2.5, 118.0),
        "PHL": g("PH", 12.9, 122.0), "MMR": g("MM", 21.0, 96.0), "KHM": g("KH", 12.6, 105.0),
        "LAO": g("LA", 19.9, 102.5),
        // Océanie
        "AUS": g("AU", -25.3, 134.0), "NZL": g("NZ", -41.5, 172.5), "PNG": g("PG", -6.3, 145.0),
        "FJI": g("FJ", -17.7, 178.0),
        // Petits États
        "LBR": g("LR", 6.4, -9.4), "SLE": g("SL", 8.5, -11.8), "GMB": g("GM", 13.4, -15.3), "GNB": g("GW", 11.8, -15.2),
        "GNQ": g("GQ", 1.6, 10.3), "LSO": g("LS", -29.6, 28.2), "SWZ": g("SZ", -26.5, 31.5), "BTN": g("BT", 27.5, 90.4),
        "BRN": g("BN", 4.5, 114.7), "TLS": g("TL", -8.9, 125.7), "BLZ": g("BZ", 17.2, -88.5), "TTO": g("TT", 10.7, -61.2),
        "MLT": g("MT", 35.9, 14.4), "BHS": g("BS", 24.7, -78.0)
    ]
}
