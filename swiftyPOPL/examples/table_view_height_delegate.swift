protocol RowHeightDelegate {
  func heightForRow(row: Int) -> Int
}

struct CompactRows {
  let base: Int
}

extension CompactRows: RowHeightDelegate {
  func heightForRow(row: Int) -> Int {
    if row < 1 { self.base } else { self.base + 8 }
  }
}

struct TableView {
  let delegate: any RowHeightDelegate
  func firstRowHeight() -> Int {
    self.delegate.heightForRow(row: 0)
  }
}

let compact: CompactRows = CompactRows(base: 44)
let delegate: any RowHeightDelegate = compact as any RowHeightDelegate
let tableView: TableView = TableView(delegate: delegate)
tableView.firstRowHeight()
