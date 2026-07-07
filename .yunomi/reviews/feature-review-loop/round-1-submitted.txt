# REPORT.md 新機能検証

## 1. Toggle記法（折りたたみ）のテスト

<details>
<summary>クリックして展開：詳細な実装メモ</summary>

ここに折りたたまれた内容が入ります。

- 項目1
- 項目2
- 項目3

```javascript
// コードブロックも含められる
const test = () => {
  console.log("Hello");
};
```

</details>

<details>
<summary>E2E Health Review 詳細（折りたたみ例）</summary>

### goto制限チェック詳細
| ファイル | 行 | コード | 判定 |
|---------|-----|--------|------|
| login.e2e.ts | 15 | `page.goto('/')` | ✅ OK |
| dashboard.e2e.ts | 42 | `page.goto('/settings')` | ❌ 違反 |

</details>

---

## 2. 画面遷移全体像（Mermaid）

```mermaid
flowchart LR
    A[ログイン画面] --> B[ダッシュボード]
    B --> C[設定画面]
    B --> D[プロフィール]
    C --> E[通知設定]
    C --> F[セキュリティ]
```

## 3. Evidence (証拠)

### Screenshots（テーブル記法必須）

| Before | After |
|--------|-------|
| ![Before](./assets/screenshot-before.png) | ![After](./assets/screenshot-after.png) |

### 画面遷移フロー + 動画

**注意**: テーブル内にコードフェンス(```)を入れるとMarkdownパーサーが混乱するため、Mermaidはテーブル外に配置する必要があります。

| 動画 | 説明 |
|------|------|
| ![ログインフロー](./videos/video-landscape.mp4) | ログイン操作のデモ動画 |
| ![設定変更フロー](./videos/video-portrait.mp4) | 設定変更のデモ動画 |

#### ログインフロー図
```mermaid
flowchart TD
    A[メール入力] --> B[パスワード入力]
    B --> C[ログインボタン]
    C --> D[ダッシュボード表示]
```

#### 設定変更フロー図
```mermaid
flowchart TD
    A[設定画面] --> B[項目選択]
    B --> C[値変更]
    C --> D[保存]
```

### 動画プレビュー（画像記法でサムネイル表示）

| 動画プレビュー | 説明 |
|---------------|------|
| ![テスト動画](./videos/test-video.mp4) | 動画がサムネイル付きで表示される |

### 動画一覧（代替テーブル形式）

| 動画ファイル | 説明 | フロー |
|-------------|------|--------|
| video-landscape.mp4 | 横長動画デモ | 横画面表示 |
| video-portrait.mp4 | 縦長動画デモ | 縦画面表示 |

### 閾値調整テスト用動画

| 動画 | 説明 |
|------|------|
| ![16色テスト](./videos/video-16colors.mp4) | 16種類の異なる色（1秒ずつ切り替わり）- シーン検出テスト用 |
| ![グラデーション](./videos/video-gradient.mp4) | 虹色のグラデーション変化（10秒）- 閾値感度テスト用 |

---

## 4. E2E Health Review (自動追記)

### goto制限チェック
| ファイル | 行 | コード | 判定 |
|---------|-----|--------|------|
| auth.e2e.ts | 10 | `page.goto('/')` | ✅ OK |

### 総合判定
- スコア: 4/5

---

## Notes

- Toggle記法が正しく動作するか確認
- Mermaid図がレンダリングされるか確認
- テーブル内の画像が展開されるか確認
