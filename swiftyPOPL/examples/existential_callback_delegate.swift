protocol SelectionDelegate {
  func didSelect(row: Int) -> Bool
}

struct EvenSelection {
  let enabled: Bool
}

extension EvenSelection: SelectionDelegate {
  func didSelect(row: Int) -> Bool {
    if self.enabled { row < 2 } else { false }
  }
}

struct MyTableView {
  let delegate: any SelectionDelegate
  func canSelect(row: Int) -> Bool {
    self.delegate.didSelect(row: row)
  }
}

let concrete: EvenSelection = EvenSelection(enabled: true)
let delegate: any SelectionDelegate = concrete as any SelectionDelegate
let tableView: MyTableView = MyTableView(delegate: delegate)
tableView.canSelect(row: 0)
