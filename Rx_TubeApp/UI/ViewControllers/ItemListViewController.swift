//
//  ItemListViewController.swift
//  Rx_TubeApp
//
//  Created by 細田　大志 on 2017/07/11.
//  Copyright © 2017 HIroshi Hosoda. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class ItemListViewController: UIViewController {
    
//    enum Destination {
//        case Player(PlayerViewModel)
//        case Search(SearchViewModel)
//        case Playlist(PlaylistViewModel)
//        case Channel(ChannelViewModel)
//
//        func go(from vc: UIViewController) {
//            switch self {
//            case .Player(let vm):
//                let view = PlayerView(viewModel: vm)
//                // TODO: transition
//            case .Search(let vm):
//                let view = SearchView(viewModel: vm)
//                // TODO: transition
//            case .Playlist(let vm):
//                let view = PlaylistView(viewModel: vm)
//                // TODO: transition
//            case .Channel(let vm):
//                let view = ChannelView(viewModel: vm)
//                // TODO: transition
//            }
//        }
//    }

    private let searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: nil)
    private lazy var videoListView: UITableView = {
        let tableView = UITableView()
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.register(VideoItemCell.self, forCellReuseIdentifier: VideoItemCell.identifier)
        tableView.register(ChannelItemCell.self, forCellReuseIdentifier: ChannelItemCell.identifier)
        tableView.register(PlaylistItemCell.self, forCellReuseIdentifier: PlaylistItemCell.identifier)
        return tableView
    }()
    
    private let dataSource = DataSource()
    let disposeBag = DisposeBag()

    // MARK: Initializing
    
    init(viewModel: ItemListViewModelType) {
        super.init(nibName: nil, bundle: nil)
        self.configure(viewModel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = searchButton
        self.view.addSubview(videoListView)
        setupConstraint()
    }
    
    // MARK: Setup Constraint
    
    private func setupConstraint() {
        self.videoListView.snp.makeConstraints { make in
            make.edges.equalTo(0)
        }
    }
    
    // MARK: Configuring
    
    private func configure(_ viewModel: ItemListViewModelType) {
        self.rx.viewDidLoad
            .bind(to: viewModel.viewDidLoad)
            .addDisposableTo(self.disposeBag)
                
        viewModel.itemDataSource
            .drive(videoListView.rx.items(dataSource: dataSource))
            .addDisposableTo(disposeBag)
        
        videoListView.delegate = dataSource
        
        dataSource.selectedIndexPath
            .bind(to: viewModel.selectedItem)
            .addDisposableTo(disposeBag)
    }
    
    class DataSource: NSObject, RxTableViewDataSourceType, UITableViewDataSource, UITableViewDelegate {
        
        typealias Element = [SearchItemCellModel]
        var items: Element = []
        
        fileprivate let selectedIndexPath = PublishSubject<IndexPath>()
        
        func tableView(_ tableView: UITableView, observedEvent: Event<[SearchItemCellModel]>) {
            if case .next(let items) = observedEvent {
                self.items = items
                tableView.reloadData()
            }
        }
        
        // MARK: UITableViewDataSource
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return items.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let item = items[indexPath.row]
            switch item {
            case .video(let video):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: VideoItemCell.identifier, for: indexPath) as? VideoItemCell else { fatalError("Could not create Cell") }
                cell.config(item: video)
                return cell
            case .playlist(let playlist):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: PlaylistItemCell.identifier, for: indexPath) as? PlaylistItemCell else { fatalError("Could not create Cell") }
                cell.config(item: playlist)
                return cell
            case .channel(let channel):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: ChannelItemCell.identifier, for: indexPath) as? ChannelItemCell else { fatalError("Could not create Cell") }
                cell.config(item: channel)
                return cell
            }
        }
        
        // MARK: UITableViewDelegate
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            selectedIndexPath.onNext(indexPath)
        }
        
    }

}
