# MoonBit toolchainを0.10.5へ更新し、7日ルール適合版へ固定

> 「ちなみにムーンビットのバージョンが更新されている場合、そちらの更新作業を今から行ってください。依存しているものもすべて更新してもらう方向で大丈夫です。もちろん7日間ルールがあるのでそこだけ注意をお願いします。」

## Why

ローカルとCIはMoonBit 0.10.0（2026-06-08系）を使い、CIは毎回`latest`を取得していました。このままでは開発環境が古い一方、公開時だけ7日未満のtoolchainへ予告なく変わる状態でした。

npm依存もcaret指定だったため、lockfileを作り直すタイミングによって7日未満のPlaywrightが選ばれます。

## How

2026-08-06時点から満7日を経過した公式releaseだけを候補にしました。

- MoonBit: `0.10.5+5e7afb0c0`。公式releaseは2026-07-28、toolchain内の`moon`と`moonrun`は2026-07-29です。
- Playwright: `1.61.1`をexact pin。`1.62.0`は日付条件を満たしますが、新しいChromiumの追加インストールが必要になり、既存のブラウザだけで全回帰できないため採用しませんでした。
- `1.62.1`は2026-07-30 16:38 UTC公開で、調査時点では満7日に約2時間足りないため除外しました。

ローカルtoolchainは旧版を削除せず、`~/.moon/toolchain-backups/0.10.0-20260806`へ退避してから更新しました。CIも同じMoonBit releaseへ固定しています。

## What

- `moon 0.1.20260729`、`moonc v0.10.5+5e7afb0c0`、`moonrun 0.1.20260729`へ更新。
- `moon.mod`の`source`を現行トップレベル構文へ移行。
- server/UI packageを`is-main`から`pkgtype(kind: "executable")`へ移行。
- 空Map初期値を曖昧な`{}`から`Map([])`へ移行。
- `moon fmt`と`moon info`を新版で実行し、自動生成`.mbti`は追跡対象外に設定。
- `@playwright/test`と`playwright`を`1.61.1`へexact pin。
- inline editor幅とVim選択outlineのE2Eを、実際に描画されるCSS契約へ合わせました。製品CSSは変更していません。

## Verification

- `moon tree`: 外部mooncakes依存なし。
- `moon fmt`: 成功。
- `moon info`: 成功。既存の未使用helper警告5件、エラー0件。
- `npm audit`: 脆弱性0件。
- `npm test`: 成功。
  - MoonBit unit tests: 190/190。
  - Complex markdown showcase: 28/28。
  - Inline comment mode layout: 14/14。
  - HTML preview: 39/39。
  - Structured comment schema: 33/33。
  - Vim keys: 20/20。
  - その他の全E2Eも失敗0件。
- `npm pack --dry-run`: 成功。`yunomi@2.4.5`、6ファイル、213.9 kB。

## Decision

- ✅ MoonBit 0.10.5更新と7日ルール対応を承認する
