protocol TableViewDelegate {
  func numberOfRows() -> Int
  func titleForRow(row: Int) -> String
}

struct InboxDelegate {
  let rows: Int
}

extension InboxDelegate: TableViewDelegate {
  func numberOfRows() -> Int { self.rows }
  func titleForRow(row: Int) -> String {
    if row < 1 { "Inbox" } else { "Archive" }
  }
}

struct TableView {
  let delegate: any TableViewDelegate
  func renderFirstTitle() -> String {
    self.delegate.titleForRow(row: 0)
  }
}

let concrete: InboxDelegate = InboxDelegate(rows: 2)
let delegate: any TableViewDelegate = concrete as any TableViewDelegate
let tableView: TableView = TableView(delegate: delegate)
tableView.renderFirstTitle()
