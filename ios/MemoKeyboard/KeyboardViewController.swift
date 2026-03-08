import UIKit
import SQLite3

class KeyboardViewController: UIInputViewController {

    private var snippets: [(String, String, String)] = [] // id, title, content
    private var tableView: UITableView!
    private let primaryColor = UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1.0)
    private let bgColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSnippets()
    }

    private func setupUI() {
        view.backgroundColor = bgColor

        // Header
        let headerView = UIView()
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

        // Table view
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = bgColor
        tableView.separatorStyle = .none
        tableView.register(SnippetCell.self, forCellReuseIdentifier: "SnippetCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            switchBtn.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            switchBtn.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            switchBtn.widthAnchor.constraint(equalToConstant: 32),
            switchBtn.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.heightAnchor.constraint(equalToConstant: 220),
        ])
    }

    @objc private func switchKeyboard() {
        advanceToNextInputMode()
    }

    private func loadSnippets() {
        snippets.removeAll()
        guard let dbPath = getDBPath() else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT id, title, content FROM snippets ORDER BY isPinned DESC, copyCount DESC LIMIT 50"

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let content = String(cString: sqlite3_column_text(stmt, 2))
                snippets.append((id, title, content))
            }
        }
        sqlite3_finalize(stmt)
        tableView?.reloadData()
    }

    private func getDBPath() -> String? {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
        ) {
            let path = groupURL.appendingPathComponent("memo_copypaste.db").path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // Fallback
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let path = paths[0].appendingPathComponent("memo_copypaste.db").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
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
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}

class SnippetCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let containerView = UIView()

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

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        contentLabel.font = UIFont.systemFont(ofSize: 12)
        contentLabel.textColor = .gray
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),

            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
        ])
    }

    func configure(title: String, content: String) {
        titleLabel.text = title
        contentLabel.text = content
    }
}
