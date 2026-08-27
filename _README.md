# gcal-dashboard-widget.el

![Emacs-30.2](https://minorugh.github.io/img/emacs30.2.png)


Google Calendarの予定を、Emacsの起動画面([emacs-dashboard](https://github.com/emacs-dashboard/emacs-dashboard))にAgendaとして表示するための、単一ファイルで完結するパッケージです。

```
Agenda for the coming 30 days:
2026-09-02（水）10:00-11:00  西神戸医療センター
2026-09-13（日）10:30-11:30  献金祈祷（第二）
2026-09-18（金）10:00-10:30  山下診療所
2026-09-20（日）10:30-11:30  敬老感謝礼拝
2026-10-02（金）  稲刈帰省(広島）
2026-10-03（土）  稲刈帰省(広島）
```

## コンセプト

- **予定はスマホで登録する**ことを前提にしています。EmacsからGoogle Calendarへの書き込みは行いません(一方向同期)。
- **calendar-mode(月表示バッファ)は使いません**。日付計算のユーティリティとしてのみ`calendar.el`を利用しています。
- **org-modeへの深入りもしません**。`org-agenda`コマンドは使わず、dashboard標準の軽量なAgendaウィジェットに載せているだけです。TODO管理やスケジューリングなど、org-modeの本格的な機能を使う設計ではありません。
- **認証不要**です。OAuth等は使わず、Google Calendarの「非公開URL(iCal形式)」を読み取るだけなので、セットアップが簡単です。

## 仕組み

```
Google Calendar (複数可)
      │  非公開URL(iCal形式)をダウンロード
      ▼
  icalendar-import-file (diary形式に変換)
      │  複数日イベントの終了日を補正
      │  直近N ヶ月より新しい予定だけに絞り込み
      ▼
  独自のorg変換 (見出し + タイムスタンプ)
      │  複数日イベントは日ごとに展開(下記「制約」参照)
      ▼
  gcal.org (洗い替え、手で編集しない)
      │  org-agenda-files に登録
      ▼
  dashboardのAgendaウィジェット
```

同期は`kill-emacs-hook`(Emacs終了時)、または`M-x gcal-dashboard-sync`で手動実行できます。途中でネットワークエラーやタイムアウトが起きても本番ファイル(`gcal.org`)には一切手を付けないまま終わるので、常に「直前の完全な状態」が保たれます。

表示側はdashboard.el標準の`agenda`ウィジェットをそのまま使います。独自のitem-generatorを新設しない理由は、dashboard.elが見出しアイコン(`dashboard-heading-icons`)やショートカットキー(`dashboard-item-shortcuts`)を`recents`/`bookmarks`/`projects`/`agenda`/`registers`の5種類にしか対応付けておらず、別シンボルを作ると標準ウィジェットの恩恵(アイコン表示など)を失うだけだからです。表示日数の拡張(`dashboard-due-date-for-agenda`)や曜日表示(`dashboard-agenda--formatted-time`)、見出し文言(`dashboard-item-names`)など、dashboard.el内部の関数振る舞いを変える必要がある箇所だけ`advice-add`/公式のカスタマイズ変数で差し替えており、`(advice-remove 'dashboard-due-date-for-agenda #'gcal-dashboard--due-date-for-agenda)`のように元の挙動へ戻すこともできます。

## 必要なもの

- Emacs 27以降(`icalendar.el`、`calendar.el`、`org.el`はbuiltin)
- [dashboard.el](https://github.com/emacs-dashboard/emacs-dashboard)(Agendaウィジェットの土台として利用)

## インストール

`gcal-dashboard.el`を`load-path`の通ったディレクトリに置き、dashboardの設定の中で`require`してください。`dashboard-items`には標準の`agenda`をそのまま指定します。

```elisp
(use-package dashboard
  :ensure t
  :config
  (require 'gcal-dashboard-widget)
  (setq dashboard-items '((agenda . 10))))
```

## 設定

### 1. Google CalendarのURLを取得する

Google Calendarの「設定」→ 対象カレンダーの「カレンダーの統合」→「非公開URL(iCal形式)」をコピーします。

### 2. URLをファイルに保存する

コピーしたURLを、1行だけのテキストファイルとして保存します。**このファイルは絶対に公開リポジトリにコミットしないでください。**

```
~/.config/gcal-dashboard/private-url
```
```
https://calendar.google.com/calendar/ical/xxxxx%40gmail.com/private-yyyyy/basic.ics
```

### 3. `gcal-dashboard-calendars` に登録する

```elisp
(setq gcal-dashboard-calendars
      '(("private" . "~/.config/gcal-dashboard/private-url")
        ("work"    . "~/.config/gcal-dashboard/work-url")))
```

複数のカレンダーを登録すると、まとめて1つのAgendaに時刻順でマージされます。

### 4. 初回同期

```
M-x gcal-dashboard-sync
```

以降は`kill-emacs-hook`で自動的に同期されます(詳細は上記「仕組み」参照)。

## 主な設定変数

`M-x customize-group RET gcal-dashboard`でもまとめて確認・変更できます。

| 変数 | デフォルト | 説明 |
|---|---|---|
| `gcal-dashboard-calendars` | (なし、要設定) | 同期対象カレンダーの一覧。`(名前 . URLファイルパス)`のalist |
| `gcal-dashboard-org-file` | `~/.emacs.d/tmp/gcal.org` | 同期結果の出力先(自動生成、手編集不可) |
| `gcal-dashboard-months-back` | `12` | 何ヶ月前より新しい予定を残すか |
| `gcal-dashboard-block-end-date-correction` | `1` | 複数日イベントの終了日補正(日数) |
| `gcal-dashboard-agenda-days` | `30` | Agendaに何日先までの予定を表示するか |
| `gcal-dashboard-weekday-kanji` | `["日" "月" ... "土"]` | 曜日表示に使う漢字(ロケール非依存) |

`dashboard-agenda-sort-strategy`や`dashboard-agenda-prefix-format`など、dashboard標準の変数もこのパッケージ側で上書き設定しているので、変更したい場合は`(require 'gcal-dashboard)`の**後**に`setq`してください。ただし`gcal-dashboard-agenda-days`だけは例外で、dashboardバッファを更新するたびに値を読み直す作りにしているため、`require`の前後を気にせず単純な`setq`で変更できます。

## 制約・既知の癖

- **複数日の予定は日ごとに1行ずつ表示されます**(「稲刈帰省 10/2」「稲刈帰省 10/3」...のように)。これはM-x org-agendaなら範囲タイムスタンプ`<開始>--<終了>`を正しく扱えるのですが、dashboardのAgendaウィジェットが使う簡易実装(`org-entry-get`の特殊プロパティ`"TIMESTAMP"`)は単一タイムスタンプしか見ないための制約です。org-agenda自体に完全に乗せれば解決しますが、その分実装が複雑になるため、今回はこの制約を受け入れる設計にしています。
- **繰り返し予定(定期的な予定)** は、diary sexp形式(`<%%(diary-cyclic ...)>`など)としてそのまま出力されます。org側で評価できる形式である必要があります。
- **gcal.orgは洗い替え方式**です。org標準のTODO/DONE切り替えなど、同期後にファイルへ手を加えても、次回の同期で消えます。

## ライセンス

MIT
