protocol ScreenTitleProvider {
  func title() -> String
}

protocol TableViewDataSource {
  func numberOfRows() -> Int
  func titleForRow(row: Int) -> String
}

protocol TableViewDelegate {
  func didSelect(row: Int) -> Bool
}

struct SettingsTitle {
  let debug: Bool
}

extension SettingsTitle: ScreenTitleProvider {
  func title() -> String {
    if self.debug { "Settings Debug" } else { "Settings" }
  }
}

struct SettingsDataSource {
  let rows: Int
}

extension SettingsDataSource: TableViewDataSource {
  func numberOfRows() -> Int { self.rows }
  func titleForRow(row: Int) -> String {
    if row < 1 { "Account" } else { "Notifications" }
  }
}

struct SettingsDelegate {
  let enabled: Bool
}

extension SettingsDelegate: TableViewDelegate {
  func didSelect(row: Int) -> Bool {
    if self.enabled { row < 2 } else { false }
  }
}

struct ReuseIdentity {
  let keep: <T>(T) -> T
}

struct SettingsViewController {
  let titleProvider: any ScreenTitleProvider
  let dataSource: any TableViewDataSource
  let delegate: any TableViewDelegate
  let reuse: ReuseIdentity

  func screenTitle() -> String {
    self.titleProvider.title()
  }

  func firstCellTitle() -> String {
    self.dataSource.titleForRow(row: 0)
  }

  func canOpenFirstCell() -> Bool {
    self.delegate.didSelect(row: 0)
  }

  func stableIndex() -> Int {
    self.reuse.keep<Int>(0)
  }
}

func displayTitle<T: ScreenTitleProvider>(item: T) -> String {
  item.title()
}

let titleModel: SettingsTitle = SettingsTitle(debug: false)
let titleProvider: any ScreenTitleProvider = titleModel as any ScreenTitleProvider
let dataModel: SettingsDataSource = SettingsDataSource(rows: 2)
let dataSource: any TableViewDataSource = dataModel as any TableViewDataSource
let navigationModel: SettingsDelegate = SettingsDelegate(enabled: true)
let delegate: any TableViewDelegate = navigationModel as any TableViewDelegate
let reuse: ReuseIdentity = ReuseIdentity(keep: func <T>(_ value: T) -> T {
  value
})

let viewController: SettingsViewController = SettingsViewController(
  titleProvider: titleProvider,
  dataSource: dataSource,
  delegate: delegate,
  reuse: reuse
)

let title: String = displayTitle<SettingsTitle>(item: titleModel)
let firstCell: String = viewController.firstCellTitle()
let canOpen: Bool = viewController.canOpenFirstCell()
viewController.screenTitle()
