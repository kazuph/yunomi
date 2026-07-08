# Task Card 3.3 Vim Keys

元の依頼: v3 PLAN の Phase 3 Collaboration として、Vim キーバインドでキーボード完結レビューを実装する。

## 未達・未確認

- 未達なし。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- `j` / `k` で次/前のレビュー対象へ移動できる。
- `c` で現在選択中の対象にコメントカードを開ける。
- `n` / `N` で保存済みコメントへジャンプできる。
- `r` で review-loop の未解決コメントを Resolve できる。
- `Cmd+Enter` / `Ctrl+Enter` でレビュー画面から Submit dialog を開ける。
- `?` でキーバインド一覧を表示し、localStorage で on/off を切り替えられる。
- `--no-vim` でページ単位に Vim keybindings を無効化できる。
- textarea/input/select の通常入力中は `j/k/c` を奪わない。`n/N/r` は Vim navigation として扱う。

## 検証

- `herdr run --label vim-keys-build-e2e15 --cwd .../feature/vim-keys/v2 --close-on-success -- bash -lc 'moon build --target js --release >/tmp/yunomi-vim-build.log && node --experimental-strip-types e2e/vim_keys.ts'`
- 結果:
  - `moon build --target js --release`: PASS
  - `Vim keys E2E: 12 passed, 0 failed`
- `herdr run --label vim-keys-verify3 --cwd .../feature/vim-keys/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/vim_keys.ts && node --experimental-strip-types e2e/comment_shortcuts_regression.ts && node --experimental-strip-types e2e/preview_interaction_regression.ts && node --experimental-strip-types e2e/smoke.ts'`
- 結果:
  - `moon test --target js`: 181 passed, 0 failed
  - `moon build --target js --release`: PASS
  - `Vim keys E2E`: 12 passed, 0 failed
  - `comment_shortcuts_regression`: PASS。通常の `hjkl` メディア移動も維持。
  - `preview_interaction_regression`: 12 passed, 0 failed
  - `smoke`: 134 passed, 0 failed

## サンプル

- `サンプル.md` に 3.3 vim-keys の確認項目を追加した。
- `herdr run --label sample-vim-keys-live --cwd .../feature/vim-keys -- bash -lc 'cd v2 && moon build --target js --release >/tmp/yunomi-sample-vim-keys-build.log && cd .. && node v2/_build/js/release/build/server/server.js サンプル.md --host 127.0.0.1 --port 5899 --no-open'`
- `http://127.0.0.1:5899/` を Chrome で開いた。
