# dashboard-widget-extensions

dashboard.el用の自作ウィジェット集(Googleカレンダー同期・日替わり俳句 ほか)

![Emacs-30.2](https://minorugh.github.io/img/emacs30.2.png)

```
♡ 今日の一句  8月27日（木）
    高架下また轟音し地蔵盆    青畝

Agenda for the coming 30 days:
2026-09-02（水）10:00-11:00  西神戸医療センター
2026-09-13（日）10:30-11:30  献金祈祷（第二）
2026-09-18（金）10:00-10:30  山下診療所
```

## Requirements

- Emacs 27以降(`icalendar.el`、`calendar.el`、`org.el`はbuiltin)
- [dashboard.el](https://github.com/emacs-dashboard/emacs-dashboard) 1.8.0+

## Installation

```elisp
(add-to-list 'load-path "/path/to/dashboard-widget-extensions")
```

各ウィジェットは完全に独立しているので、使う方だけ`require`すれば十分です。

## Widgets

- [gcal-widget](#gcal-widget) — Google CalendarをorgファイルへSyncし、dashboardのAgendaに表示
- [haiku-widget](#haiku-widget) — 青畝俳句366日分を日替わりでdashboardに表示、他の日替わりコンテンツにも応用可

---

## gcal-widget

Google Calendarの予定を、dashboardのAgendaとして表示する単一ファイルのウィジェットです。ファイル名は`dashboard-gcal-widget.el`(`ls`したときに`dashboard-*`で並ぶように命名)、Lisp内の関数・変数プレフィックスは`gcal-widget-*`です。

### コンセプト

- **予定はスマホで登録する**ことを前提にしています。EmacsからGoogle Calendarへの書き込みは行いません(一方向同期)。
- **calendar-mode(月表示バッファ)は使いません**。日付計算のユーティリティとしてのみ`calendar.el`を利用しています。
- **org-modeへの深入りもしません**。`org-agenda`コマンドは使わず、dashboard標準の軽量なAgendaウィジェットに載せているだけです。TODO管理やスケジューリングなど、org-modeの本格的な機能を使う設計ではありません。
- **認証不要**です。OAuth等は使わず、Google Calendarの「非公開URL(iCal形式)」を読み取るだけなので、セットアップが簡単です。

### 仕組み

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

同期は`kill-emacs-hook`(Emacs終了時)、または`M-x gcal-widget-sync`で手動実行できます。途中でネットワークエラーやタイムアウトが起きても本番ファイル(`gcal.org`)には一切手を付けないまま終わるので、常に「直前の完全な状態」が保たれます。

表示側はdashboard.el標準の`agenda`ウィジェットをそのまま使います。独自のitem-generatorを新設しない理由は、dashboard.elが見出しアイコン(`dashboard-heading-icons`)やショートカットキー(`dashboard-item-shortcuts`)を`recents`/`bookmarks`/`projects`/`agenda`/`registers`の5種類にしか対応付けておらず、別シンボルを作ると標準ウィジェットの恩恵(アイコン表示など)を失うだけだからです。表示日数の拡張(`dashboard-due-date-for-agenda`)や曜日表示(`dashboard-agenda--formatted-time`)、見出し文言(`dashboard-item-names`)など、dashboard.el内部の関数振る舞いを変える必要がある箇所だけ`advice-add`/公式のカスタマイズ変数で差し替えており、`(advice-remove 'dashboard-due-date-for-agenda #'gcal-widget--due-date-for-agenda)`のように元の挙動へ戻すこともできます。

### Setup

`require`するだけでdashboard標準の`agenda`アイテムに連携されます。

```elisp
(use-package dashboard
  :ensure t
  :config
  (require 'dashboard-gcal-widget)
  (setq dashboard-items '((agenda . 10))))
```

1. Google Calendarの「設定」→ 対象カレンダーの「カレンダーの統合」→「非公開URL(iCal形式)」をコピーする
2. コピーしたURLを、1行だけのテキストファイルとして保存する。**このファイルは絶対に公開リポジトリにコミットしないでください。**
   ```
   ~/.config/gcal-widget/private-url
   ```
   ```
   https://calendar.google.com/calendar/ical/xxxxx%40gmail.com/private-yyyyy/basic.ics
   ```
3. `gcal-widget-calendars`に登録する
   ```elisp
   (setq gcal-widget-calendars
         '(("private" . "~/.config/gcal-widget/private-url")
           ("work"    . "~/.config/gcal-widget/work-url")))
   ```
   複数のカレンダーを登録すると、まとめて1つのAgendaに時刻順でマージされます。
4. 初回同期
   ```
   M-x gcal-widget-sync
   ```
   以降は`kill-emacs-hook`で自動的に同期されます。

### Customization

`M-x customize-group RET gcal-widget`でもまとめて確認・変更できます。

| 変数 | デフォルト | 説明 |
|---|---|---|
| `gcal-widget-calendars` | (なし、要設定) | 同期対象カレンダーの一覧。`(名前 . URLファイルパス)`のalist |
| `gcal-widget-org-file` | `~/.emacs.d/tmp/gcal.org` | 同期結果の出力先(自動生成、手編集不可) |
| `gcal-widget-months-back` | `12` | 何ヶ月前より新しい予定を残すか |
| `gcal-widget-block-end-date-correction` | `1` | 複数日イベントの終了日補正(日数) |
| `gcal-widget-agenda-days` | `30` | Agendaに何日先までの予定を表示するか |
| `gcal-widget-weekday-kanji` | `["日" "月" ... "土"]` | 曜日表示に使う漢字(ロケール非依存) |

`dashboard-agenda-sort-strategy`や`dashboard-agenda-prefix-format`など、dashboard標準の変数もこのパッケージ側で上書き設定しているので、変更したい場合は`(require 'dashboard-gcal-widget)`の**後**に`setq`してください。ただし`gcal-widget-agenda-days`だけは例外で、dashboardバッファを更新するたびに値を読み直す作りにしているため、`require`の前後を気にせず単純な`setq`で変更できます。

### 制約・既知の癖

- **複数日の予定は日ごとに1行ずつ表示されます**(「稲刈帰省 10/2」「稲刈帰省 10/3」...のように)。org-agendaなら範囲タイムスタンプ`<開始>--<終了>`を正しく扱えますが、dashboardのAgendaウィジェットが使う簡易実装(`"TIMESTAMP"`プロパティ)は単一タイムスタンプしか見ないための制約です。org-agenda自体に完全に乗せれば解決しますが実装が複雑になるため、この制約を受け入れる設計にしています。
- **繰り返し予定(定期的な予定)** は、diary sexp形式(`<%%(diary-cyclic ...)>`など)としてそのまま出力されます。org側で評価できる形式である必要があります。
- **gcal.orgは洗い替え方式**です。org標準のTODO/DONE切り替えなど、同期後にファイルへ手を加えても、次回の同期で消えます。

---

## haiku-widget

青畝の俳句366日分データを、dashboard起動時に日替わりで1句表示するウィジェットです。ファイル名は`dashboard-haiku-widget.el`、Lisp内のプレフィックスは`seiho-haiku-*`(俳句データの出典・青畝に由来)です。

### コンセプト

- **完全にオフライン・静的データ**です。ネットワークアクセスも外部依存もなく、`seiho-haiku-data`という366日分(月×日)の俳句リストをファイル内に丸ごと持っています。
- **その日の日付に対応する句を1件だけ表示**します。閏年や月末日数のズレは考慮せず、単純に「今日の月・日」をインデックスとして引くだけの割り切った設計です。
- **表示はdashboardのitem-generatorとして提供**しますが、gcal-widgetと違いdashboard標準アイテムに相乗りできないため、利用側で`dashboard-item-generators`への登録が必要です(下記Setup参照)。
- **「今日の一句」という枠組み自体が汎用的**です。データを`seiho-haiku-data`と同じ`(俳句 . 作者)`ペアの366要素alistに差し替えるだけで、「今日の聖書の言葉」「今日の格言」「今日の名言」など、日替わりで何か1件を表示する別ウィジェットに転用できます。中身(データ)と表示ロジック(`seiho-haiku-today`/`seiho-haiku-insert-today`)が分離されているので、複製してデータとプレフィックスを差し替えるのが一番手軽な拡張方法です。

### Setup

自前のitem-generatorを定義してdashboardに登録する必要があります。

```elisp
(require 'dashboard-haiku-widget)

(defun dashboard-insert-haiku (_list-size)
  "今日の一句をdashboardに挿入する。"
  (seiho-haiku-insert-today #'dashboard-insert-heading))

(add-to-list 'dashboard-item-generators
             '(haiku . dashboard-insert-haiku))

(setq dashboard-items '((haiku . 1) (agenda . 6)))
```

### Customization

| 変数 | デフォルト | 説明 |
|---|---|---|
| `seiho-haiku-ku-height` | `1.4` | 俳句のフォントサイズ倍率 |
| `seiho-haiku-ku-weight` | `bold` | フォントウェイト(`bold`/`normal`) |
| `seiho-haiku-box-color` | `"gray40"` | 俳句ボックスの枠線色 |
| `seiho-haiku-box-line-width` | `10` | ボックス上下padding(px) |

### 制約・既知の癖

- **句データはseihohaiku.cgiからの自動変換**です。データを差し替える場合は`seiho-haiku-data`の形式(月ごとのリスト、`(俳句 . 作者)`のペア、該当日なしは`nil`)に合わせる必要があります。
- **日付判定はシステムのローカルタイムのみ**です。タイムゾーンをまたぐ運用は想定していません。

---

## License

MIT
