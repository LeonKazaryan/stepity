import Foundation

/// The routes the prototype knows. The real planner (any home, any dream, a graph of towns
/// over land) is on the roadmap; until then a home in Almaty walks the Silk Road west.
///
/// Landmark coordinates in Almaty are approximate (prototype): check them before release.
enum Routes {
    /// Almaty → Paris along the Silk Road, with the Caspian crossed by ferry.
    static let almatyToParis: [Waypoint] = homeAlmaty + silkRoadWest + [paris]

    /// The prologue keeps going past Paris to Lisbon and over the Atlantic to San Francisco:
    /// a lifetime of steps can be very long.
    static let prologueFromAlmaty: [Waypoint] = homeAlmaty + silkRoadWest + [paris] + beyondParis

    static let homeAlmaty: [Waypoint] = [
        Waypoint("Republic Square", "Площадь Республики", "KZ", 43.2381, 76.9452),
        Waypoint("Central Stadium", "Центральный стадион", "KZ", 43.2346, 76.9179, kind: .landmark),
        Waypoint("Sairan Lake", "Озеро Сайран", "KZ", 43.2359, 76.8701, kind: .landmark),
        Waypoint("Kaskelen", "Каскелен", "KZ", 43.2000, 76.6200, kind: .town),
    ]

    static let silkRoadWest: [Waypoint] = [
        Waypoint("Uzynagash", "Узынагаш", "KZ", 43.2260, 76.3000, kind: .town),
        Waypoint("Kordai", "Кордай", "KZ", 43.0450, 74.7100, kind: .town),
        Waypoint("Merke", "Мерке", "KZ", 42.8700, 73.1800, kind: .town),
        Waypoint("Taraz", "Тараз", "KZ", 42.9000, 71.3700),
        Waypoint("Shymkent", "Шымкент", "KZ", 42.3200, 69.5900),
        Waypoint("Tashkent", "Ташкент", "UZ", 41.3110, 69.2790),
        Waypoint("Samarkand", "Самарканд", "UZ", 39.6540, 66.9750),
        Waypoint("Bukhara", "Бухара", "UZ", 39.7680, 64.4210),
        Waypoint("Türkmenabat", "Туркменабат", "TM", 39.0730, 63.5790),
        Waypoint("Mary", "Мары", "TM", 37.6000, 61.8300),
        Waypoint("Ashgabat", "Ашхабад", "TM", 37.9600, 58.3260),
        Waypoint("Balkanabat", "Балканабат", "TM", 39.5100, 54.3700),
        Waypoint("Türkmenbaşy", "Туркменбаши", "TM", 40.0220, 52.9550, watersAfter: true),
        Waypoint("Baku", "Баку", "AZ", 40.4090, 49.8670),
        Waypoint("Ganja", "Гянджа", "AZ", 40.6830, 46.3600),
        Waypoint("Tbilisi", "Тбилиси", "GE", 41.7150, 44.8270),
        Waypoint("Batumi", "Батуми", "GE", 41.6420, 41.6360),
        Waypoint("Trabzon", "Трабзон", "TR", 41.0050, 39.7270),
        Waypoint("Samsun", "Самсун", "TR", 41.2930, 36.3310),
        Waypoint("Ankara", "Анкара", "TR", 39.9330, 32.8600),
        Waypoint("Istanbul", "Стамбул", "TR", 41.0080, 28.9780),
        Waypoint("Edirne", "Эдирне", "TR", 41.6770, 26.5560),
        Waypoint("Plovdiv", "Пловдив", "BG", 42.1350, 24.7450),
        Waypoint("Sofia", "София", "BG", 42.6980, 23.3220),
        Waypoint("Niš", "Ниш", "RS", 43.3210, 21.8950),
        Waypoint("Belgrade", "Белград", "RS", 44.7870, 20.4490),
        Waypoint("Novi Sad", "Нови-Сад", "RS", 45.2670, 19.8330),
        Waypoint("Budapest", "Будапешт", "HU", 47.4980, 19.0400),
        Waypoint("Vienna", "Вена", "AT", 48.2080, 16.3740),
        Waypoint("Linz", "Линц", "AT", 48.3060, 14.2860),
        Waypoint("Salzburg", "Зальцбург", "AT", 47.8100, 13.0550),
        Waypoint("Munich", "Мюнхен", "DE", 48.1370, 11.5760),
        Waypoint("Stuttgart", "Штутгарт", "DE", 48.7760, 9.1830),
        Waypoint("Strasbourg", "Страсбург", "FR", 48.5730, 7.7520),
        Waypoint("Reims", "Реймс", "FR", 49.2580, 4.0320),
    ]

    static let paris = Waypoint("Paris", "Париж", "FR", 48.8566, 2.3522)

    static let beyondParis: [Waypoint] = [
        Waypoint("Orléans", "Орлеан", "FR", 47.9030, 1.9090),
        Waypoint("Tours", "Тур", "FR", 47.3940, 0.6850),
        Waypoint("Bordeaux", "Бордо", "FR", 44.8380, -0.5790),
        Waypoint("San Sebastián", "Сан-Себастьян", "ES", 43.3180, -1.9810),
        Waypoint("Burgos", "Бургос", "ES", 42.3440, -3.6970),
        Waypoint("Madrid", "Мадрид", "ES", 40.4170, -3.7040),
        Waypoint("Salamanca", "Саламанка", "ES", 40.9700, -5.6640),
        Waypoint("Lisbon", "Лиссабон", "PT", 38.7220, -9.1390, watersAfter: true),
        Waypoint("Ponta Delgada", "Понта-Делгада", "PT", 37.7410, -25.6750, watersAfter: true),
        Waypoint("New York", "Нью-Йорк", "US", 40.7130, -74.0060),
        Waypoint("Philadelphia", "Филадельфия", "US", 39.9530, -75.1650),
        Waypoint("Pittsburgh", "Питтсбург", "US", 40.4410, -79.9960),
        Waypoint("Chicago", "Чикаго", "US", 41.8780, -87.6300),
        Waypoint("Omaha", "Омаха", "US", 41.2570, -95.9350),
        Waypoint("Denver", "Денвер", "US", 39.7390, -104.9900),
        Waypoint("Salt Lake City", "Солт-Лейк-Сити", "US", 40.7610, -111.8910),
        Waypoint("Reno", "Рино", "US", 39.5300, -119.8140),
        Waypoint("San Francisco", "Сан-Франциско", "US", 37.7750, -122.4190),
    ]
}
