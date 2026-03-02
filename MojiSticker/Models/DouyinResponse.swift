import Foundation

struct DouyinResponse: Decodable {
    let statusCode: Int
    let emoticonData: EmoticonData?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
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
