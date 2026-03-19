import Foundation

struct DouyinResponse: Decodable {
    let statusCode: Int
    let statusMessage: String?
    let emoticonData: EmoticonData?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMessage = "status_msg"
        case emoticonData = "emoticon_data"
    }
}

struct EmoticonData: Decodable {
    let hasMore: Bool
    let nextCursor: String
    let stickerList: [Sticker]?

    enum CodingKeys: String, CodingKey {
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
        case stickerList = "sticker_list"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
        stickerList = try container.decodeIfPresent([Sticker].self, forKey: .stickerList)
        // API returns next_cursor as Int or String depending on context
        if let intValue = try? container.decode(Int.self, forKey: .nextCursor) {
            nextCursor = String(intValue)
        } else {
            nextCursor = try container.decode(String.self, forKey: .nextCursor)
        }
    }
}

struct Sticker: Decodable {
    let origin: StickerImage?
    let thumbnail: StickerImage?
}

struct StickerImage: Decodable {
    let urlList: [String]

    enum CodingKeys: String, CodingKey {
        case urlList = "url_list"
    }
}
