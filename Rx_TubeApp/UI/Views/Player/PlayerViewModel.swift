//
//  PlayerViewModel.swift
//  Rx_TubeApp
//
//  Created by 細田　大志 on 2017/07/14.
//  Copyright © 2017 HIroshi Hosoda. All rights reserved.
//

import RxSwift
import RxCocoa

protocol PlayerViewModelType {
    
    /// Input
    
    /// video in Other than Player
    var videoDidTap: PublishRelay<SearchItemDetails.Video> { get }
    /// related video in player
    var relatedVideoDidTapIndexPath: PublishSubject<IndexPath> { get }
    var channelDidTap: PublishSubject<Void> { get }
    var likeDidTap: PublishSubject<Void> { get }
    var dislikeDidTap: PublishSubject<Void> { get }
    var nextDidTap: PublishSubject<Void> { get }
    var previousDidTap: PublishSubject<Void> { get }
    
    /// Output
    
    var play: Signal<String> { get }
    var showChannelDetail: Signal<SearchItemDetails.Channel> { get }
    var overview: Driver<VideoOverviewViewModelType> { get }
    var relatedVideoCellModels: Driver<[RelatedVideoCellModel]> { get }
}

final class PlayerViewModel: PlayerViewModelType {
    
    /// Input
    
    let videoDidTap = PublishRelay<SearchItemDetails.Video>()
    let relatedVideoDidTapIndexPath = PublishSubject<IndexPath>()
    let channelDidTap = PublishSubject<Void>()
    let likeDidTap = PublishSubject<Void>()
    let dislikeDidTap = PublishSubject<Void>()
    let nextDidTap = PublishSubject<Void>()
    let previousDidTap = PublishSubject<Void>()
    
    /// Output
    
    let play: Signal<String>
    let showChannelDetail: Signal<SearchItemDetails.Channel>
    var overview: Driver<VideoOverviewViewModelType>
    var relatedVideoCellModels: Driver<[RelatedVideoCellModel]>
    
    private let disposeBag = DisposeBag()
    
    init(relatedVideoRepository: YoutubeRelatedVideosRepositoryType) {
        
        let relatedVideoDidTap = PublishRelay<SearchItemDetails.Video>()
        let playVideo: Observable<SearchItemDetails.Video> = Observable
            .of(videoDidTap, relatedVideoDidTap)
            .merge()
            .share(replay: 1)
        
        play = playVideo
            .map { $0.player.embedHtml }
            .asSignal(onErrorSignalWith: Signal.empty())
        
        overview = playVideo.map(VideoOverviewViewModel.init)
            .asDriver(onErrorDriveWith: Driver.empty())
        
        showChannelDetail = channelDidTap
            .withLatestFrom(playVideo)
            .map { $0.toChannel() }
            .asSignal(onErrorSignalWith: Signal.empty())
        
        let relatedVideos: Observable<[SearchItemDetails.Video]> = playVideo
            .flatMap { video in relatedVideoRepository.fetch(videoId: video.id) }
        
        relatedVideoCellModels = relatedVideos
            .map { videos in videos.map(RelatedVideoCellModel.init) }
            .asDriver(onErrorJustReturn: [])
        
        relatedVideoDidTapIndexPath
            .withLatestFrom(relatedVideos) {(indexPath, videos)->SearchItemDetails.Video in videos[indexPath.row] }
            .bind(to: relatedVideoDidTap)
            .disposed(by: disposeBag)
    }
}
