//
//  SearchItemCellModel.swift
//  Rx_TubeApp
//
//  Created by 細田　大志 on 2017/07/26.
//  Copyright © 2017 HIroshi Hosoda. All rights reserved.
//

import Foundation

enum SearchItemCellModel {
    case video(Video)
    case channel(Channel)
    case playlist(Playlist)
        
    class SearchItem {
        let publishedAt: String
        let title: String
        let thumbnailUrl: String
        
        init(snippet: ContentsSnippetType) {
            publishedAt = snippet.publishedAt
            title = snippet.title
            thumbnailUrl = snippet.thumbnails.default.url
        }
    }
    
    class Video: SearchItem {
        let id: String
        let duration: String
        let channelTitle: String
        let definition: String
        
        
        init?(video: Videos.Item) {
            guard let snippet = video.snippet,
                let statistics = video.statistics,
                let contentsDetail = video.contentDetails else { return nil }
            
            id = video.id
            duration = contentsDetail.duration
            channelTitle = snippet.channelTitle
            definition = contentsDetail.definition
            
            
            super.init(snippet: snippet)
        }
    }
    
    class Channel: SearchItem {
        let id: String
        
        init?(channel: Channels.Item) {
            guard let snippet = channel.snippet,
                let statistics = channel.statistics,
                let contentsDetail = channel.contentDetails else { return nil }
            id = channel.id
            super.init(snippet: snippet)
        }
    }
    
    class Playlist: SearchItem {
        let id: String
        
        init?(searchItem: SearchItems.Item) {
            guard let playlistId = searchItem.id.playlistId else { return nil }
            id = playlistId
            super.init(snippet: searchItem.snippet)
        }
    }
    
}
