//
//  FindFriendsViewController.swift
//  Ello
//
//  Created by Sean on 2/26/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import UIKit

class FindFriendsViewController: BaseElloViewController {

    @IBOutlet weak var tableView: UITableView!
    var dataSource: AddFriendsDataSource!
    let inviteService = InviteService()

    required override init() {
        super.init(nibName: "FindFriendsViewController", bundle: NSBundle(forClass: FindFriendsViewController.self))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    // MARK: - Private

    private func setupTableView() {
        registerCells()
        dataSource = AddFriendsDataSource()

        tableView.dataSource = dataSource
        tableView.delegate = self
    }

    private func registerCells() {
        let findCellNib = UINib(nibName: AddFriendsCellItem.CellType.Find.identifier, bundle: NSBundle(forClass: FindFriendsCell.self))
        tableView.registerNib(findCellNib, forCellReuseIdentifier: AddFriendsCellItem.CellType.Find.identifier)

        let inviteCellNib = UINib(nibName: AddFriendsCellItem.CellType.Invite.identifier, bundle: NSBundle(forClass: InviteFriendsCell.self))
        tableView.registerNib(inviteCellNib, forCellReuseIdentifier: AddFriendsCellItem.CellType.Invite.identifier)
    }
}

// MARK: FindFriendsViewController : UITableViewDelegate
extension FindFriendsViewController : UITableViewDelegate {

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50.0
    }
}