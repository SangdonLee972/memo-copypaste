import UIKit
import SQLite3

class KeyboardViewController: UIInputViewController {

    private var snippets: [(String, String, String)] = [] // id, title, content
    private var categories: [(String, String)] = [] // id, name
    private var selectedCategoryId: String? = nil
    private let primaryColor = UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1.0)
    private let bgColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)

    private var headerView: UIView!
    private var categoryScrollView: UIScrollView!
    private var categoryStackView: UIStackView!
    private var tableView: UITableView!
    private var emptyLabel: UILabel!
    private var copiedLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCategories()
        loadSnippets()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCategories()
        loadSnippets()
    }

    private func setupUI() {
        view.backgroundColor = bgColor

        // Header
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .white
        view.addSubview(headerView)

        let titleLabel = UILabel()
        titleLabel.text = "메모복붙"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = primaryColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let switchBtn = UIButton(type: .system)
        switchBtn.setImage(UIImage(systemName: "globe"), for: .normal)
        switchBtn.tintColor = .gray
        switchBtn.addTarget(self, action: #selector(switchKeyboard), for: .touchUpInside)
        switchBtn.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(switchBtn)

        // Category tabs
        categoryScrollView = UIScrollView()
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = false
        categoryScrollView.showsHorizontalScrollIndicator = false
        categoryScrollView.backgroundColor = .white
        view.addSubview(categoryScrollView)

        categoryStackView = UIStackView()
        categoryStackView.translatesAutoresizingMaskIntoConstraints = false
        categoryStackView.axis = .horizontal
        categoryStackView.spacing = 6
        categoryStackView.alignment = .center
        categoryScrollView.addSubview(categoryStackView)

        // Copied feedback label
        copiedLabel = UILabel()
        copiedLabel.text = "✓ 복사됨"
        copiedLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(red: 0.31, green: 0.81, blue: 0.40, alpha: 1.0)
        copiedLabel.textAlignment = .center
        copiedLabel.layer.cornerRadius = 14
        copiedLabel.clipsToBounds = true
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        copiedLabel.alpha = 0
        view.addSubview(copiedLabel)

        // Table view
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = bgColor
        tableView.separatorStyle = .none
        tableView.register(SnippetCell.self, forCellReuseIdentifier: "SnippetCell")
        view.addSubview(tableView)

        // Empty state label
        emptyLabel = UILabel()
        emptyLabel.text = "스니펫이 없습니다\n메모복붙 앱에서 스니펫을 추가해주세요"
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.systemFont(ofSize: 14)
        emptyLabel.textColor = .gray
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            switchBtn.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            switchBtn.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            switchBtn.widthAnchor.constraint(equalToConstant: 32),
            switchBtn.heightAnchor.constraint(equalToConstant: 32),

            categoryScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            categoryScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 36),

            categoryStackView.topAnchor.constraint(equalTo: categoryScrollView.topAnchor, constant: 4),
            categoryStackView.bottomAnchor.constraint(equalTo: categoryScrollView.bottomAnchor, constant: -4),
            categoryStackView.leadingAnchor.constraint(equalTo: categoryScrollView.leadingAnchor, constant: 8),
            categoryStackView.trailingAnchor.constraint(equalTo: categoryScrollView.trailingAnchor, constant: -8),
            categoryStackView.heightAnchor.constraint(equalToConstant: 28),

            copiedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copiedLabel.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor, constant: 4),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 28),

            tableView.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.heightAnchor.constraint(equalToConstant: 190),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    @objc private func switchKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let tag = sender.tag
        if tag == -1 {
            selectedCategoryId = nil
        } else if tag < categories.count {
            let catId = categories[tag].0
            selectedCategoryId = (selectedCategoryId == catId) ? nil : catId
        }
        loadSnippets()
        updateCategoryButtons()
    }

    private func updateCategoryButtons() {
        for case let btn as UIButton in categoryStackView.arrangedSubviews {
            let isSelected: Bool
            if btn.tag == -1 {
                isSelected = (selectedCategoryId == nil)
            } else if btn.tag < categories.count {
                isSelected = (categories[btn.tag].0 == selectedCategoryId)
            } else {
                isSelected = false
            }

            if isSelected {
                btn.backgroundColor = primaryColor
                btn.setTitleColor(.white, for: .normal)
            } else {
                btn.backgroundColor = UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1.0)
                btn.setTitleColor(.darkGray, for: .normal)
            }
        }
    }

    private func buildCategoryTabs() {
        categoryStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // "전체" tab
        let allBtn = makeCategoryButton(title: "전체", tag: -1)
        categoryStackView.addArrangedSubview(allBtn)

        for (index, cat) in categories.enumerated() {
            let btn = makeCategoryButton(title: cat.1, tag: index)
            categoryStackView.addArrangedSubview(btn)
        }

        updateCategoryButtons()
    }

    private func makeCategoryButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        btn.tag = tag
        btn.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func showCopiedFeedback() {
        copiedLabel.alpha = 1
        UIView.animate(withDuration: 0.3, delay: 0.8, options: [], animations: {
            self.copiedLabel.alpha = 0
        })
    }

    private func loadCategories() {
        categories.removeAll()
        guard let dbPath = getDBPath() else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT id, name FROM categories ORDER BY sortOrder ASC"

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                categories.append((id, name))
            }
        }
        sqlite3_finalize(stmt)
        buildCategoryTabs()
    }

    private func loadSnippets() {
        snippets.removeAll()
        guard let dbPath = getDBPath() else {
            emptyLabel.isHidden = false
            emptyLabel.text = "DB를 찾을 수 없습니다\n메모복붙 앱을 먼저 실행해주세요"
            tableView?.reloadData()
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            emptyLabel.isHidden = false
            tableView?.reloadData()
            return
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        var query: String

        if let catId = selectedCategoryId {
            query = "SELECT id, title, content FROM snippets WHERE categoryId = '\(catId)' ORDER BY isPinned DESC, copyCount DESC LIMIT 50"
        } else {
            query = "SELECT id, title, content FROM snippets ORDER BY isPinned DESC, copyCount DESC LIMIT 50"
        }

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let titlePtr = sqlite3_column_text(stmt, 1)
                let title = titlePtr != nil ? String(cString: titlePtr!) : ""
                let contentPtr = sqlite3_column_text(stmt, 2)
                let content = contentPtr != nil ? String(cString: contentPtr!) : ""
                snippets.append((id, title, content))
            }
        }
        sqlite3_finalize(stmt)

        emptyLabel.isHidden = !snippets.isEmpty
        if snippets.isEmpty {
            emptyLabel.text = "스니펫이 없습니다\n메모복붙 앱에서 스니펫을 추가해주세요"
        }
        tableView?.reloadData()
    }

    private func getDBPath() -> String? {
        let dbName = "memo_copypaste.db"

        // App Group container (메인 앱과 공유)
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
        ) {
            let path = groupURL.appendingPathComponent(dbName).path
            NSLog("[메모복붙 키보드] App Group 경로: %@, 존재: %@",
                  path, FileManager.default.fileExists(atPath: path) ? "YES" : "NO")
            if FileManager.default.fileExists(atPath: path) { return path }
        } else {
            NSLog("[메모복붙 키보드] App Group 컨테이너를 찾을 수 없음 - entitlements 확인 필요")
        }

        NSLog("[메모복붙 키보드] DB를 찾을 수 없음")
        return nil
    }
}

extension KeyboardViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snippets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SnippetCell", for: indexPath) as! SnippetCell
        let (_, title, content) = snippets[indexPath.row]
        cell.configure(title: title.isEmpty ? String(content.prefix(30)) : title, content: content)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let (_, _, content) = snippets[indexPath.row]
        textDocumentProxy.insertText(content)
        showCopiedFeedback()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }
}

class SnippetCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let containerView = UIView()
    private let copyIcon = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        contentLabel.font = UIFont.systemFont(ofSize: 11)
        contentLabel.textColor = .gray
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentLabel)

        copyIcon.image = UIImage(systemName: "doc.on.doc")
        copyIcon.tintColor = UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 0.6)
        copyIcon.translatesAutoresizingMaskIntoConstraints = false
        copyIcon.contentMode = .scaleAspectFit
        containerView.addSubview(copyIcon)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            copyIcon.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            copyIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            copyIcon.widthAnchor.constraint(equalToConstant: 16),
            copyIcon.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: copyIcon.leadingAnchor, constant: -8),

            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: copyIcon.leadingAnchor, constant: -8),
        ])
    }

    func configure(title: String, content: String) {
        titleLabel.text = title
        contentLabel.text = content
    }
}
