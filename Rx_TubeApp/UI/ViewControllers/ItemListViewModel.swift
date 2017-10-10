//
//  ItemListViewModel.swift
//  Rx_TubeApp
//
//  Created by 細田　大志 on 2017/07/11.
//  Copyright © 2017 HIroshi Hosoda. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxMoya
import Moya

fileprivate typealias SearchFilter = YoutubeAPI.FilterParameter.Search
fileprivate typealias SearchRequire = YoutubeAPI.RequireParameter.Search
fileprivate typealias ChannelsFilter = YoutubeAPI.FilterParameter.Channels
fileprivate typealias ChannelsRequire = YoutubeAPI.RequireParameter.Channels
fileprivate typealias VideosFilter = YoutubeAPI.FilterParameter.Videos
fileprivate typealias VideosRequire = YoutubeAPI.RequireParameter.Videos


// MARK: Types

enum ItemListViewType {
    case short
    case long
    case event
    case latest
    case viewCount
    case rating
    case period
    case region
    case caption
    case HD
    
    fileprivate var requireParameters: SearchRequire {
        return SearchRequire(properties: [SearchRequire.Property.id, SearchRequire.Property.snippet])
    }
    
    fileprivate var filterParameters:Set<SearchFilter> {
        switch self {
        case .short:
            return [SearchFilter.videoDuration(duration: SearchFilter.Duration.short)]
        case .long:
            return [SearchFilter.videoDuration(duration: SearchFilter.Duration.long)]
        case .event:
            return [SearchFilter.eventType(event: SearchFilter.Event.live)]
        case .latest:
            return [SearchFilter.order(order: SearchFilter.Order.date)]
        case .viewCount:
            return [SearchFilter.order(order: SearchFilter.Order.viewCount)]
        case .rating:
            return [SearchFilter.order(order: SearchFilter.Order.rating)]
        case .period:
            //TODO change date
            return [SearchFilter.publishedBefore(time: Date()), SearchFilter.publishedAfter(time: Date())]
        case .region:
            // Default US
            return [SearchFilter.regionCode(code: YoutubeAPI.FilterParameter.RegionCode.US)]
        case .caption:
            return [SearchFilter.videoCaption(caption: SearchFilter.Caption.closedCaption)]
        case .HD:
            return [SearchFilter.videoDefinition(definition: SearchFilter.Definition.high)]
        }
    }
}

protocol ItemListViewModelType: class {
    
    // Input
    var viewDidLoad: PublishSubject<Void> { get }
    var searchText: Variable<String> { get }
    var searchKeyDidTap: PublishSubject<Void> { get }
    var videoCategory: Variable<String> { get }
    var selectedTab: PublishSubject<Void> { get }
    var refresh: PublishSubject<Void> { get }
    var horizontalSwipe: PublishSubject<Void> { get }
    var selectedItem: PublishSubject<IndexPath> { get }
    
    // Output
    var presentPlayer: Observable<String> { get }
    var presentPlaylist: Observable<String> { get }
    var pushChannelDetail: Observable<String> { get }
    var itemDataSource: Driver<[SearchItemCellModel]> { get }
}

final class ItemListViewModel: ItemListViewModelType {
    
    // MARK: Input
    var viewDidLoad = PublishSubject<Void>()
    var searchText = Variable("")
    var searchKeyDidTap = PublishSubject<Void>()
    var videoCategory = Variable("")
    var selectedTab = PublishSubject<Void> ()
    var refresh = PublishSubject<Void>()
    var horizontalSwipe = PublishSubject<Void>()
    var selectedItem = PublishSubject<IndexPath>()
    
    // MARK: Output
    var presentPlayer: Observable<String> { return selectedPlayer }
    var presentPlaylist: Observable<String> { return selectedPlaylist }
    var pushChannelDetail: Observable<String> { return selectedChannel }
    let itemDataSource: Driver<[SearchItemCellModel]>
    
    private let selectedPlayer = PublishSubject<String>()
    private let selectedPlaylist = PublishSubject<String>()
    private let selectedChannel = PublishSubject<String>()
    private let disposeBag = DisposeBag()
    
    // MARK: Initializing
    
    init(provider: RxMoyaProvider<YoutubeAPI>, type: ItemListViewType) {
        
        let searchItems: Observable<SearchItems> = Observable
            .of(viewDidLoad, searchKeyDidTap, selectedTab, refresh, horizontalSwipe)
            .merge()
            .withLatestFrom(searchText.asObservable())
            .withLatestFrom(videoCategory.asObservable()) { ($0, $1) }
            .flatMapLatest { text, category -> Observable<Response> in
                var parameters = type.filterParameters
                if !text.isEmpty { parameters.insert(SearchFilter.q(keyword: text)) }
                if !category.isEmpty { parameters.insert(SearchFilter.videoCategoryId(id: category)) }
                return provider.request(YoutubeAPI.search(require: type.requireParameters, filter: parameters))
                    .retry(3)}
            .map(SearchItems.self)
        
        let models: Observable<(videos: Videos, channels: Channels, searchItems: SearchItems)> = searchItems
            .flatMapLatest { (searchItems)->Observable<(videos: Videos, channels: Channels, searchItems: SearchItems)> in
            let videoIds = searchItems.items.flatMap { $0.id.videoId }
            let channelIds = searchItems.items.map { $0.snippet.channelId }
            let videos = provider.request(YoutubeAPI.videos(require: VideosRequire(properties: [ VideosRequire.Property.snippet, VideosRequire.Property.statistics]), filter: VideosFilter.id(ids: videoIds)))
                .map(Videos.self)
            let channels = provider.request(YoutubeAPI.channels(require: ChannelsRequire(properties: [ChannelsRequire.Property.snippet, ChannelsRequire.Property.contentDetails, ChannelsRequire.Property.statistics]), filter: ChannelsFilter.id(ids: channelIds)))
                .map(Channels.self)
            
            return Observable
                .combineLatest(videos, channels) { (videos: $0, channels: $1, searchItems: searchItems)}
        }
        
        let cellModels: Observable<[SearchItemCellModel]> = models
            .map { model in
                let vCellModels = model.videos.items
                    .flatMap { SearchItemCellModel.Video(video: $0)}
                    .map { SearchItemCellModel.video($0) }
                let cCellModel = model.searchItems.items
                    .flatMap { $0.id.channelId }
                    .flatMap { id in model.channels.items.first(where: { $0.id == id }) }
                    .flatMap { SearchItemCellModel.Channel(channel: $0) }
                    .map { SearchItemCellModel.channel($0) }
                let pCellModel = model.searchItems.items
                    .filter { $0.id.playlistId != nil }
                    .flatMap { SearchItemCellModel.Playlist(searchItem: $0) }
                    .map { SearchItemCellModel.playlist($0)}
                
                return vCellModels + cCellModel + pCellModel
        }
        
    
        itemDataSource = cellModels.asDriver(onErrorJustReturn: [])
        
        selectedItem
            .withLatestFrom(cellModels) { ($0, $1) }
            .map { index, models in models[index.row] }
            .subscribe(onNext: { [weak self] model in
                switch model {
                case .video(let video): self?.selectedPlayer.onNext(video.id)
                case .playlist(let playlist): self?.selectedPlaylist.onNext(playlist.id)
                case .channel(let channel): self?.selectedChannel.onNext(channel.id)
                }
            }).disposed(by: disposeBag)
    }
}











