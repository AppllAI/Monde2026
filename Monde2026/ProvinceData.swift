import Foundation

// =============================================================
//  ProvinceData.swift
//  Le découpage du monde en ~600 régions (centre approximatif
//  de chaque région). Un pays absent de cette liste forme une
//  seule région. Les poids servent quand les régions d'un pays
//  ont des tailles très différentes.
// =============================================================

enum ProvinceData {

    typealias Entry = (String, Double, Double)   // nom, latitude, longitude

    static let lists: [CountryID: [Entry]] = build()

    /// Poids relatifs (sinon 1). Clé : "PAYS/Nom".
    static let weights: [String: Double] = [
        "UKR/Kyiv": 28, "UKR/Ouest": 120, "UKR/Odessa": 33, "UKR/Kharkiv": 31, "UKR/Dnipro": 32,
        "UKR/Zaporijia": 27, "UKR/Donetsk": 27, "UKR/Louhansk": 27, "UKR/Kherson": 28, "UKR/Crimée": 27,
        "UKR/Tchernihiv-Soumy": 56, "UKR/Centre": 167,
        "GEO/Tbilissi": 50, "GEO/Abkhazie": 12.5, "GEO/Ossétie du Sud": 5.5, "GEO/Adjarie et Ouest": 32,
        "MDA/Chișinău": 88, "MDA/Transnistrie": 12,
        "CYP/Nicosie": 64, "CYP/Nord de Chypre": 36,
        "SYR/Damas": 10, "SYR/Alep": 15, "SYR/Nord-Est": 40, "SYR/Homs": 35, "SYR/Golan": 1,
        "YEM/Aden et Hadramaout": 65, "YEM/Sanaa": 35,
        "LBY/Tripolitaine": 30, "LBY/Cyrénaïque": 40, "LBY/Fezzan": 30,
        "SDN/Khartoum": 20, "SDN/Est": 20, "SDN/Kordofan": 25, "SDN/Darfour": 35,
        "MLI/Bamako": 25, "MLI/Centre": 30, "MLI/Nord": 45,
        "BFA/Ouagadougou": 60, "BFA/Sahel": 40,
        "MMR/Naypyidaw": 30, "MMR/Rangoun": 15, "MMR/État Shan": 25, "MMR/Kachin et Chin": 20, "MMR/Rakhine": 10,
        "FRA/Guyane": 15, "FRA/Corse": 3
    ]

    /// Ordre dans lequel un occupant prend les régions (sinon : les plus proches de lui d'abord).
    static let occupationOrder: [String: [String]] = [
        "UKR|RUS": ["Crimée", "Louhansk", "Donetsk", "Zaporijia", "Kherson"],
        "GEO|RUS": ["Ossétie du Sud", "Abkhazie"],
        "MDA|RUS": ["Transnistrie"],
        "CYP|TUR": ["Nord de Chypre"],
        "SYR|ISR": ["Golan"]
    ]

    static func weight(_ country: CountryID, _ name: String) -> Double {
        weights[country + "/" + name] ?? 1
    }

    private static func build() -> [CountryID: [Entry]] {
        var d: [CountryID: [Entry]] = [:]

        // Amérique du Nord
        d["USA"] = [("Nouvelle-Angleterre", 43.0, -71.5), ("New York", 42.5, -75.5), ("Pennsylvanie", 40.9, -77.8),
                    ("Virginie et Washington", 37.8, -78.2), ("Carolines", 35.3, -80.0), ("Floride", 28.1, -81.6),
                    ("Géorgie et Alabama", 32.7, -85.0), ("Michigan et Ohio", 41.8, -83.5), ("Illinois et Indiana", 40.5, -88.5),
                    ("Minnesota et Wisconsin", 45.5, -91.5), ("Missouri et Kansas", 38.5, -95.5), ("Texas", 31.0, -99.0),
                    ("Louisiane et Mississippi", 31.5, -91.0), ("Tennessee et Kentucky", 36.5, -86.5),
                    ("Grandes Plaines", 44.0, -100.0), ("Colorado et Utah", 39.5, -108.0), ("Montana et Wyoming", 45.5, -108.5),
                    ("Arizona et Nouveau-Mexique", 34.0, -110.0), ("Californie", 36.8, -119.5), ("Nord-Ouest Pacifique", 45.5, -121.0),
                    ("Nevada et Idaho", 41.5, -116.5), ("Alaska", 64.0, -150.0)]
        d["CAN"] = [("Colombie-Britannique", 53.7, -125.0), ("Alberta", 54.5, -114.5), ("Saskatchewan", 54.0, -106.0),
                    ("Manitoba", 55.0, -97.5), ("Nord de l'Ontario", 49.5, -85.0), ("Sud de l'Ontario", 43.9, -79.8),
                    ("Québec", 47.0, -72.0), ("Nord du Québec", 53.5, -73.0), ("Maritimes", 46.5, -64.5),
                    ("Terre-Neuve", 49.0, -56.0), ("Territoires du Nord-Ouest", 63.5, -118.0), ("Nunavut", 66.0, -95.0),
                    ("Yukon", 63.5, -135.5)]
        d["MEX"] = [("Basse-Californie", 30.0, -115.0), ("Sonora", 29.5, -110.5), ("Chihuahua", 28.5, -106.0),
                    ("Nuevo León", 25.6, -100.0), ("Jalisco", 20.6, -103.3), ("Mexico", 19.4, -99.1),
                    ("Veracruz", 19.2, -96.6), ("Oaxaca", 17.0, -96.7), ("Yucatán", 20.0, -89.0)]
        d["CUB"] = [("La Havane", 22.8, -82.4), ("Orient", 20.6, -76.5)]

        // Amérique du Sud
        d["COL"] = [("Bogotá", 4.7, -74.1), ("Antioquia", 6.5, -75.5), ("Caraïbes", 10.0, -75.0),
                    ("Valle del Cauca", 3.4, -76.5), ("Llanos et Amazonie", 2.0, -71.5)]
        d["VEN"] = [("Caracas", 10.2, -66.9), ("Zulia", 9.8, -72.0), ("Llanos", 8.0, -67.5), ("Bolívar", 6.5, -63.0)]
        d["ECU"] = [("Quito", -0.2, -78.5), ("Guayaquil", -2.0, -79.9), ("Amazonie équatorienne", -1.5, -77.0)]
        d["PER"] = [("Lima", -12.0, -76.8), ("Nord", -6.5, -79.0), ("Arequipa", -16.0, -72.0), ("Cuzco", -13.5, -72.0),
                    ("Amazonie péruvienne", -6.0, -74.5)]
        d["BOL"] = [("La Paz", -16.8, -68.2), ("Santa Cruz", -17.5, -61.5), ("Beni", -13.5, -65.5)]
        d["BRA"] = [("São Paulo", -22.8, -48.0), ("Rio de Janeiro", -22.3, -43.0), ("Minas Gerais", -18.5, -44.5),
                    ("Bahia", -12.5, -41.5), ("Pernambouc", -8.3, -36.5), ("Ceará", -5.0, -39.5), ("Pará", -4.5, -52.5),
                    ("Amazonas", -4.0, -63.0), ("Mato Grosso", -13.0, -56.0), ("Goiás et Brasília", -15.8, -48.5),
                    ("Paraná et Santa Catarina", -25.8, -51.0), ("Rio Grande do Sul", -29.8, -53.5),
                    ("Rondônia et Acre", -10.0, -65.0), ("Maranhão et Piauí", -5.0, -45.0)]
        d["PRY"] = [("Asunción", -25.6, -56.5), ("Chaco", -22.0, -60.5)]
        d["CHL"] = [("Santiago", -33.6, -70.7), ("Atacama", -24.0, -69.5), ("Araucanie", -39.0, -72.5),
                    ("Patagonie chilienne", -47.0, -73.0)]
        d["ARG"] = [("Buenos Aires", -35.5, -59.5), ("Córdoba", -31.5, -64.0), ("Mendoza", -34.5, -68.5),
                    ("Nord-Ouest", -25.5, -65.5), ("Nord-Est", -27.5, -59.0), ("Patagonie", -42.0, -68.0),
                    ("Santa Cruz et Terre de Feu", -50.0, -70.0)]

        // Europe de l'Ouest
        d["GBR"] = [("Londres", 51.6, -0.3), ("Sud-Ouest", 50.9, -3.4), ("Midlands", 52.6, -1.8),
                    ("Nord de l'Angleterre", 54.2, -2.0), ("Écosse", 56.8, -4.2), ("Pays de Galles", 52.3, -3.7),
                    ("Irlande du Nord", 54.6, -6.7)]
        d["IRL"] = [("Dublin", 53.3, -6.6), ("Ouest", 53.0, -9.0)]
        d["FRA"] = [("Île-de-France", 48.8, 2.4), ("Hauts-de-France", 50.2, 2.8), ("Normandie", 49.1, 0.2),
                    ("Bretagne", 48.1, -2.9), ("Pays de la Loire", 47.4, -0.8), ("Grand Est", 48.7, 6.0),
                    ("Bourgogne-Franche-Comté", 47.2, 5.0), ("Nouvelle-Aquitaine", 45.0, 0.0), ("Occitanie", 43.6, 2.2),
                    ("Auvergne-Rhône-Alpes", 45.5, 4.7), ("Provence-Alpes-Côte d'Azur", 43.8, 6.2), ("Centre-Val de Loire", 47.5, 1.7),
                    ("Corse", 42.1, 9.1), ("Guyane", 4.0, -53.0)]
        d["BEL"] = [("Flandre", 51.0, 4.0), ("Wallonie", 50.3, 4.9)]
        d["NLD"] = [("Hollande", 52.3, 4.8), ("Est des Pays-Bas", 52.3, 6.3)]
        d["DEU"] = [("Berlin-Brandebourg", 52.5, 13.4), ("Basse-Saxe", 52.7, 9.5), ("Schleswig-Holstein", 54.2, 9.8),
                    ("Mecklembourg", 53.7, 12.5), ("Rhénanie-du-Nord", 51.4, 7.2), ("Hesse", 50.6, 9.0), ("Saxe", 51.0, 13.5),
                    ("Bavière", 48.8, 11.5), ("Bade-Wurtemberg", 48.5, 9.0), ("Rhénanie-Palatinat", 49.8, 7.3),
                    ("Thuringe et Saxe-Anhalt", 51.3, 11.5)]
        d["CHE"] = [("Zurich", 47.4, 8.6), ("Berne et Genève", 46.6, 7.0)]
        d["AUT"] = [("Vienne", 48.1, 16.0), ("Tyrol et Salzbourg", 47.3, 12.0)]
        d["ITA"] = [("Lombardie", 45.6, 9.7), ("Piémont", 45.0, 7.7), ("Vénétie", 45.7, 12.0), ("Émilie et Toscane", 44.0, 11.0),
                    ("Latium", 42.0, 12.7), ("Campanie et Pouilles", 41.0, 15.5), ("Calabre", 39.0, 16.5),
                    ("Sicile", 37.5, 14.2), ("Sardaigne", 40.1, 9.0)]
        d["ESP"] = [("Madrid", 40.4, -3.7), ("Catalogne", 41.8, 1.6), ("Andalousie", 37.5, -4.5), ("Valence", 39.3, -0.7),
                    ("Galice", 42.7, -8.0), ("Castille-et-León", 41.8, -4.5), ("Pays basque et Navarre", 42.8, -2.0),
                    ("Aragon", 41.5, -0.8), ("Estrémadure", 39.2, -6.2)]
        d["PRT"] = [("Lisbonne", 38.9, -8.8), ("Porto", 41.3, -8.0)]
        d["DNK"] = [("Jutland", 56.2, 9.2), ("Seeland", 55.5, 11.8)]
        d["NOR"] = [("Oslo", 60.2, 10.5), ("Bergen", 61.0, 6.5), ("Trondheim", 63.5, 10.5), ("Nord de la Norvège", 68.5, 17.0)]
        d["SWE"] = [("Stockholm", 59.5, 17.5), ("Göteborg", 58.0, 13.0), ("Scanie", 56.0, 13.6), ("Norrland", 65.0, 18.5)]
        d["FIN"] = [("Helsinki", 60.6, 24.8), ("Finlande centrale", 62.5, 25.0), ("Laponie", 67.5, 26.0)]
        d["GRC"] = [("Athènes", 38.1, 23.2), ("Macédoine grecque", 40.6, 22.9), ("Crète", 35.2, 24.9)]
        d["CYP"] = [("Nicosie", 34.8, 33.0), ("Nord de Chypre", 35.3, 33.6)]

        // Europe de l'Est
        d["POL"] = [("Varsovie", 52.2, 21.0), ("Petite-Pologne", 50.0, 20.0), ("Silésie", 50.6, 18.0), ("Grande-Pologne", 52.4, 17.0),
                    ("Poméranie", 54.0, 17.5), ("Lublin", 51.2, 23.0)]
        d["CZE"] = [("Bohême", 50.0, 14.5), ("Moravie", 49.4, 17.0)]
        d["SVK"] = [("Bratislava", 48.4, 17.8), ("Košice", 48.7, 21.0)]
        d["HUN"] = [("Budapest", 47.4, 18.8), ("Grande Plaine", 47.2, 21.3)]
        d["ROU"] = [("Bucarest", 44.5, 26.2), ("Transylvanie", 46.5, 24.0), ("Moldavie roumaine", 47.0, 27.0), ("Banat", 45.6, 21.8)]
        d["BGR"] = [("Sofia", 42.6, 23.6), ("Est de la Bulgarie", 42.9, 26.8)]
        d["SRB"] = [("Belgrade", 44.8, 20.5), ("Serbie du Sud", 43.3, 21.9)]
        d["HRV"] = [("Zagreb", 45.8, 16.2), ("Dalmatie", 43.6, 16.4)]
        d["MDA"] = [("Chișinău", 47.0, 28.6), ("Transnistrie", 47.2, 29.5)]
        d["BLR"] = [("Minsk", 53.9, 27.6), ("Brest", 52.3, 25.0), ("Biélorussie orientale", 53.6, 30.5)]
        d["UKR"] = [("Kyiv", 50.4, 30.5), ("Ouest", 49.4, 25.0), ("Odessa", 46.8, 30.3), ("Kharkiv", 49.8, 36.2),
                    ("Dnipro", 48.4, 35.0), ("Zaporijia", 47.3, 35.6), ("Donetsk", 48.0, 37.8), ("Louhansk", 48.8, 39.3),
                    ("Kherson", 46.7, 33.2), ("Crimée", 45.1, 34.2), ("Tchernihiv-Soumy", 51.3, 33.0), ("Centre", 49.0, 31.0)]
        d["RUS"] = [("Moscou", 55.8, 37.6), ("Saint-Pétersbourg", 59.8, 30.5), ("Arkhangelsk", 64.0, 42.0),
                    ("Carélie et Mourmansk", 66.0, 33.5), ("Volga", 55.8, 47.0), ("Samara et Saratov", 52.5, 47.5),
                    ("Rostov et Krasnodar", 46.5, 40.0), ("Caucase du Nord", 43.5, 45.0), ("Belgorod et Voronej", 51.5, 38.5),
                    ("Smolensk et Briansk", 53.8, 33.5), ("Kaliningrad", 54.7, 21.0), ("Oural", 57.0, 60.5),
                    ("Perm et Komi", 61.5, 55.0), ("Bachkirie et Orenbourg", 53.0, 56.0), ("Tioumen", 61.0, 72.0),
                    ("Omsk et Novossibirsk", 55.0, 78.0), ("Altaï et Kouzbass", 52.5, 86.0), ("Krasnoïarsk", 58.0, 93.0),
                    ("Taïmyr", 70.0, 95.0), ("Irkoutsk", 56.0, 105.0), ("Bouriatie et Tchita", 52.0, 113.0),
                    ("Iakoutie", 63.0, 125.0), ("Amour et Khabarovsk", 50.5, 133.0), ("Primorié", 44.5, 134.0),
                    ("Magadan et Tchoukotka", 64.5, 160.0), ("Kamtchatka", 56.0, 159.0), ("Sakhaline", 50.0, 142.8)]

        // Caucase, Asie centrale
        d["GEO"] = [("Tbilissi", 41.7, 44.8), ("Abkhazie", 43.0, 41.0), ("Ossétie du Sud", 42.3, 44.0), ("Adjarie et Ouest", 41.9, 42.4)]
        d["AZE"] = [("Bakou", 40.4, 49.5), ("Gandja et Karabakh", 40.2, 46.8), ("Nakhitchevan", 39.2, 45.4)]
        d["KAZ"] = [("Astana", 51.2, 71.4), ("Almaty", 43.8, 77.0), ("Kazakhstan occidental", 47.5, 53.0),
                    ("Kazakhstan du Nord", 53.5, 69.0), ("Karaganda", 48.0, 73.5), ("Kyzylorda", 44.5, 64.5)]
        d["UZB"] = [("Tachkent", 41.0, 69.5), ("Karakalpakstan", 43.0, 59.0)]
        d["TKM"] = [("Achgabat", 38.5, 58.0), ("Turkménistan oriental", 39.0, 62.5)]
        d["AFG"] = [("Kaboul", 34.5, 69.2), ("Hérat", 34.3, 62.5), ("Kandahar", 31.6, 65.7), ("Mazar-e Charif", 36.5, 67.5)]
        d["MNG"] = [("Oulan-Bator", 47.9, 106.9), ("Mongolie occidentale", 47.5, 95.0), ("Gobi", 44.0, 105.0)]

        // Moyen-Orient
        d["TUR"] = [("Istanbul", 41.0, 28.9), ("Ankara", 39.6, 32.8), ("Égée", 38.4, 28.0), ("Antalya", 37.2, 30.7),
                    ("Adana", 37.2, 35.5), ("Sud-Est anatolien", 37.9, 40.2), ("Anatolie orientale", 39.5, 41.5),
                    ("Mer Noire", 40.9, 37.5)]
        d["IRN"] = [("Téhéran", 35.7, 51.4), ("Azerbaïdjan iranien", 38.0, 46.5), ("Khorassan", 36.0, 59.0),
                    ("Ispahan", 32.7, 51.7), ("Fars", 29.6, 52.5), ("Khouzistan", 31.3, 48.7), ("Kerman et Baloutchistan", 28.5, 59.0),
                    ("Kurdistan iranien", 34.5, 46.8)]
        d["IRQ"] = [("Bagdad", 33.3, 44.4), ("Kurdistan irakien", 36.3, 44.0), ("Bassora", 30.8, 47.0), ("Anbar", 33.4, 41.5)]
        d["SYR"] = [("Damas", 33.5, 36.5), ("Alep", 36.2, 37.2), ("Nord-Est", 35.8, 40.0), ("Homs", 34.7, 37.8), ("Golan", 33.0, 35.75)]
        d["ISR"] = [("Tel-Aviv et Jérusalem", 31.9, 34.9), ("Néguev", 30.7, 34.8)]
        d["SAU"] = [("Riyad", 24.7, 46.7), ("Hedjaz", 21.5, 40.0), ("Médine", 24.8, 39.0), ("Province orientale", 25.5, 49.5),
                    ("Nord saoudien", 29.5, 41.0), ("Asir", 18.5, 43.0), ("Rub al-Khali", 20.5, 50.0)]
        d["YEM"] = [("Aden et Hadramaout", 15.0, 48.5), ("Sanaa", 15.4, 44.2)]
        d["OMN"] = [("Mascate", 22.8, 58.0), ("Dhofar", 18.0, 54.5)]

        // Afrique du Nord
        d["EGY"] = [("Le Caire", 30.0, 31.2), ("Delta et Alexandrie", 30.9, 30.2), ("Haute-Égypte", 25.5, 32.5),
                    ("Désert occidental", 27.0, 27.5), ("Sinaï", 29.5, 33.8)]
        d["LBY"] = [("Tripolitaine", 32.0, 13.5), ("Cyrénaïque", 30.5, 21.0), ("Fezzan", 26.0, 14.0)]
        d["TUN"] = [("Tunis", 36.5, 10.0), ("Sud tunisien", 33.0, 9.5)]
        d["DZA"] = [("Alger", 36.5, 3.0), ("Oran", 35.3, -0.6), ("Constantine", 36.0, 6.6), ("Sahara algérien", 28.0, 3.0),
                    ("Hoggar", 23.0, 6.0)]
        d["MAR"] = [("Rabat et Casablanca", 33.6, -7.0), ("Fès et Oriental", 34.0, -3.5), ("Marrakech et Souss", 30.5, -8.5)]
        d["MRT"] = [("Nouakchott", 18.5, -15.5), ("Mauritanie orientale", 19.5, -9.0)]

        // Afrique subsaharienne
        d["SDN"] = [("Khartoum", 15.6, 32.5), ("Est", 18.5, 36.0), ("Kordofan", 12.5, 30.0), ("Darfour", 13.5, 24.5)]
        d["SSD"] = [("Djouba", 5.5, 31.5), ("Haut-Nil", 9.0, 32.0)]
        d["ETH"] = [("Addis-Abeba", 9.0, 38.7), ("Tigré", 13.8, 39.3), ("Amhara", 11.5, 37.5), ("Région Somali", 7.0, 44.0),
                    ("Oromia du Sud", 6.0, 38.5)]
        d["SOM"] = [("Mogadiscio", 2.5, 45.0), ("Puntland et Somaliland", 9.5, 47.0), ("Jubaland", 0.5, 42.5)]
        d["KEN"] = [("Nairobi", -1.3, 36.8), ("Nord du Kenya", 2.5, 38.5)]
        d["TZA"] = [("Dar es Salaam", -6.8, 38.8), ("Dodoma", -6.2, 35.7), ("Ouest tanzanien", -4.0, 31.5)]
        d["COD"] = [("Kinshasa", -4.5, 15.5), ("Kasaï", -5.5, 22.0), ("Katanga", -10.0, 26.5), ("Kivu", -1.5, 28.5),
                    ("Équateur et Nord", 2.0, 22.0)]
        d["AGO"] = [("Luanda", -9.0, 13.8), ("Angola central", -12.5, 16.5), ("Angola du Sud-Est", -15.0, 20.0)]
        d["MOZ"] = [("Maputo", -24.5, 32.8), ("Beira", -19.0, 34.5), ("Cabo Delgado", -13.0, 39.0)]
        d["ZAF"] = [("Gauteng", -26.2, 28.0), ("Le Cap", -33.3, 19.8), ("KwaZulu-Natal", -29.0, 30.5), ("Cap-Oriental", -32.0, 26.5),
                    ("Cap-Nord", -28.5, 22.0)]
        d["NAM"] = [("Windhoek", -22.6, 17.1), ("Nord namibien", -18.5, 16.5)]
        d["ZMB"] = [("Lusaka", -15.0, 28.3), ("Copperbelt", -12.5, 27.5)]
        d["MDG"] = [("Antananarivo", -19.0, 47.0), ("Sud malgache", -23.0, 45.0)]
        d["NGA"] = [("Lagos", 6.8, 3.6), ("Abuja", 9.1, 7.4), ("Kano", 12.0, 8.5), ("Borno", 11.8, 13.2), ("Delta du Niger", 5.2, 6.3),
                    ("Nigeria oriental", 6.5, 7.8)]
        d["GHA"] = [("Accra", 6.0, -0.5), ("Nord du Ghana", 9.5, -1.0)]
        d["CIV"] = [("Abidjan", 5.8, -4.8), ("Nord ivoirien", 9.0, -5.5)]
        d["MLI"] = [("Bamako", 12.6, -8.0), ("Centre", 14.5, -4.0), ("Nord", 18.5, -1.0)]
        d["BFA"] = [("Ouagadougou", 12.2, -1.8), ("Sahel", 13.8, 0.5)]
        d["NER"] = [("Niamey", 13.8, 3.0), ("Agadez et Diffa", 17.0, 10.0)]
        d["TCD"] = [("N'Djaména", 11.5, 16.0), ("Tibesti", 19.5, 18.0)]
        d["CMR"] = [("Yaoundé", 4.0, 11.5), ("Nord du Cameroun", 9.3, 13.4)]
        d["CAF"] = [("Bangui", 5.0, 18.6), ("Est centrafricain", 7.0, 23.0)]

        // Asie du Sud
        d["IND"] = [("Delhi", 28.6, 77.2), ("Maharashtra", 19.0, 75.0), ("Bengale-Occidental", 23.0, 88.0), ("Tamil Nadu", 11.0, 78.5),
                    ("Karnataka", 14.5, 76.0), ("Gujarat", 22.5, 71.5), ("Rajasthan", 26.5, 73.5), ("Uttar Pradesh", 26.8, 80.9),
                    ("Madhya Pradesh", 23.5, 78.0), ("Bihar et Jharkhand", 24.5, 85.5), ("Odisha", 20.5, 84.5),
                    ("Andhra et Telangana", 16.5, 79.5), ("Kerala", 10.0, 76.5), ("Pendjab et Haryana", 30.5, 75.5),
                    ("Cachemire indien", 33.8, 75.5), ("Nord-Est indien", 26.2, 92.5)]
        d["PAK"] = [("Pendjab", 31.5, 73.0), ("Sind", 25.8, 68.5), ("Khyber Pakhtunkhwa", 34.0, 71.8), ("Baloutchistan", 28.5, 65.0),
                    ("Cachemire pakistanais", 35.5, 74.5)]
        d["BGD"] = [("Dacca", 23.8, 90.4), ("Chittagong", 22.5, 91.8)]

        // Asie de l'Est
        d["CHN"] = [("Pékin", 39.9, 116.4), ("Shanghai", 31.2, 121.3), ("Guangdong", 23.3, 113.5), ("Sichuan", 30.6, 104.0),
                    ("Hubei et Chongqing", 30.5, 110.5), ("Henan", 34.5, 113.5), ("Shandong", 36.3, 118.0), ("Jiangsu et Zhejiang", 30.5, 120.0),
                    ("Fujian", 26.0, 118.0), ("Hunan et Jiangxi", 27.5, 113.5), ("Guangxi", 23.5, 108.5), ("Yunnan", 25.0, 101.5),
                    ("Guizhou", 26.6, 106.7), ("Shaanxi et Shanxi", 36.5, 110.5), ("Mongolie-Intérieure", 42.5, 113.0),
                    ("Liaoning et Jilin", 42.5, 125.0), ("Heilongjiang", 47.0, 128.5), ("Gansu et Ningxia", 37.5, 103.5),
                    ("Qinghai", 35.5, 96.5), ("Tibet", 31.5, 88.0), ("Xinjiang du Nord", 44.0, 85.5), ("Xinjiang du Sud", 38.5, 79.5),
                    ("Hainan", 19.2, 109.8)]
        d["TWN"] = [("Taipei", 24.9, 121.4), ("Sud de Taïwan", 23.0, 120.5)]
        d["PRK"] = [("Pyongyang", 39.0, 125.7), ("Nord-Est coréen", 41.0, 129.5)]
        d["KOR"] = [("Séoul", 37.5, 127.0), ("Busan", 35.3, 128.8)]
        d["JPN"] = [("Kantō", 35.9, 139.7), ("Kansai", 34.7, 135.5), ("Kyūshū", 32.8, 130.8), ("Tōhoku", 39.5, 140.8),
                    ("Hokkaidō", 43.4, 142.8), ("Chūbu", 36.2, 137.5)]

        // Asie du Sud-Est, Océanie
        d["VNM"] = [("Hanoï", 21.0, 105.8), ("Da Nang", 15.5, 108.0), ("Hô Chi Minh-Ville", 10.8, 106.6)]
        d["THA"] = [("Bangkok", 13.8, 100.5), ("Nord thaïlandais", 18.8, 99.0), ("Isan", 15.5, 103.5), ("Sud thaïlandais", 8.0, 99.0)]
        d["MMR"] = [("Naypyidaw", 20.0, 96.0), ("Rangoun", 17.0, 96.0), ("État Shan", 21.5, 98.0), ("Kachin et Chin", 25.5, 96.0),
                    ("Rakhine", 19.5, 94.0)]
        d["MYS"] = [("Malaisie péninsulaire", 3.5, 102.0), ("Bornéo malaisien", 3.5, 114.0)]
        d["IDN"] = [("Jakarta", -6.3, 106.8), ("Java", -7.3, 110.5), ("Sumatra du Nord", 2.5, 98.5), ("Sumatra du Sud", -3.0, 103.5),
                    ("Kalimantan", -1.0, 114.0), ("Sulawesi", -2.0, 121.0), ("Papouasie indonésienne", -4.0, 137.0),
                    ("Petites îles de la Sonde", -8.6, 120.5)]
        d["PHL"] = [("Luçon", 15.5, 121.0), ("Visayas", 10.5, 123.5), ("Mindanao", 7.5, 125.0)]
        d["AUS"] = [("Nouvelle-Galles du Sud", -32.5, 147.0), ("Victoria", -37.0, 144.5), ("Queensland", -22.5, 145.0),
                    ("Australie-Occidentale", -26.0, 121.0), ("Kimberley", -18.0, 126.0), ("Australie-Méridionale", -30.0, 135.5),
                    ("Territoire du Nord", -19.5, 133.5), ("Tasmanie", -42.0, 146.6)]
        d["NZL"] = [("Île du Nord", -38.5, 175.5), ("Île du Sud", -43.5, 170.5)]
        return d
    }
}
