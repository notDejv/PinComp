import Foundation

/// In-memory Set 18 sample used by previews and tests (subset of the published catalog).
public enum SampleCatalog {
    public static let userCode = "0242043A4004123E942A43C430401000TFTSet18"

    public static let set18 = SetCatalog(
        set: "TFTSet18",
        generatedAt: "2026-11-06T19:52:18Z",
        champions: [
            Champion(id: "DA_18_Rakan", name: "Rakan", cost: 1, plannerCode: 1056,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_rakan/skins/base/images/tft18_rakan_splash_tile_9.png")!),
            Champion(id: "DA_18_Yorick", name: "Yorick", cost: 1, plannerCode: 1082,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_yorick/skins/base/images/tft18_yorick_splash_tile_30.png")!),
            Champion(id: "DA_Fiddlesticks18", name: "Fiddlesticks", cost: 3, plannerCode: 1024,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_fiddlesticks/skins/base/images/tft18_fiddlesticks_splash_tile_46.png")!),
            Champion(id: "DA_18_Lillia", name: "Lillia", cost: 4, plannerCode: 1042,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_lillia/skins/base/images/tft18_lillia_splash_tile_28.png")!),
            Champion(id: "DA_18_Ahri", name: "Ahri", cost: 4, plannerCode: 1001,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_ahri/skins/base/images/tft18_ahri_splash_tile_27.png")!),
            Champion(id: "DA_18_Sett", name: "Sett", cost: 4, plannerCode: 1066,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_sett/skins/base/images/tft18_sett_splash_tile_38.png")!),
            Champion(id: "DA_18_Zyra", name: "Zyra", cost: 4, plannerCode: 1084,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_zyra/skins/base/images/tft18_zyra_splash_tile_0.png")!),
            Champion(id: "DA_Taric18", name: "Taric", cost: 5, plannerCode: 1072,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_taric/skins/base/images/tft18_taric_splash_tile_1.png")!),
            Champion(id: "DA_18_GnarSmall", name: "Gnar", cost: 5, plannerCode: 1025,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_gnar/skins/base/images/tft18_gnar_splash_tile_0.png")!),
            Champion(id: "DA_18_Akali_AD", name: "Akali", cost: 1, plannerCode: 1002,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_akali/skins/base/images/tft18_akali_splash_tile_2.png")!),
            Champion(id: "DA_18_Alistar", name: "Alistar", cost: 2, plannerCode: 1003,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_alistar/skins/base/images/tft18_alistar_splash_tile_40.png")!),
            Champion(id: "DA_18_Azir", name: "Azir", cost: 3, plannerCode: 1009,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_azir/skins/base/images/tft18_azir_splash_tile_5.png")!),
            Champion(id: "DA_18_Alune", name: "Alune", cost: 5, plannerCode: 1004,
                     iconURL: URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_alune/skins/base/images/tft18_alune_splash_tile_15.png")!),
        ]
    )

    public static let index = CatalogIndex(sets: ["TFTSet17", "TFTSet18"], latest: "TFTSet18")
}
