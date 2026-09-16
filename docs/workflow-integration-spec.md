# pstack・ponytail の核を yunomi の作業手順へ統合する

## 目的と承認済みの範囲

ユーザーは、pstack・ponytail の有効な核を既存の yunomi スキル群に取り込みたい。要求を落とす簡易版・劣化版は禁止。第三者スクリプトの取得・実行も禁止し、有用な処理は SPEC を先に定めて自前で実装する。

原本を yunomi に戻す。`/do` は要求確認から `/done` による検証・人間の承認まで進める。`/done` は既存作業の完了工程への入口にもなる。`/bucho` は同じ成果と完了基準を委譲する入口として残す。tiny 系は統合する。

## 忘れてはいけない統合内容

| 由来 | 取り込む判断と行動 | 担当 | 確認する結果 |
|---|---|---|---|
| pstack | 実際の処理を理解して設計を決め、検証可能な単位で進め、主担当が実物で完遂を確認する | do・bucho | 要求と実装と実行結果がつながる。子の完了報告だけを証拠にしない |
| ponytail | 実装前に既存コード、標準・プラットフォーム機能、導入済み依存で要求を満たせるか調べる | do | 全要求を保持し、追加する独自の仕組みには今回の依頼に即した理由がある |
| deslop | 今回の差分に入った不要な複雑さを、動作を変えずに整理する | done | 必要な検証・防御処理を残し、整理後に影響範囲を再検証する。無関係な修正を始めない |
| yunomi | 意図・成果・証拠・残る制約を示し、人間の指摘を修正と再検証につなげる | yunomi を done から利用 | 人間の承認まで同じ作業として続け、AIが自分で承認しない |

原本移動・コマンド削減・文章短縮だけでは、この依頼の達成にならない。unslop は文章編集、deslop はコード整理であり、混同しない。

## 既存機能を保持して追加する（ユーザー追加指示）

新要件が旧要件の再掲を含まなくても、既存機能・必須レビュー・完了条件を削除する許可にはならない。新しい do は変更前の動作・義務と追加要件を分けて記録し、done は両方を検証する。bucho はこの保持条件も実装責任者へ渡し、実物で確認する。

| 保持する既存機能 | 統合版の保持先 | 確認方法 |
|---|---|---|
| 要求確認・設計助言・実装と検証の計画・必要なTDD | do の Preserve existing functionality / Prepare and implement | 旧手順の具体的義務が計画と検証へ対応することを照合 |
| ビルド・実行環境・実動作と永続状態の確認 | done の Verify the real result and review | 対象の実行経路と結果を確認 |
| Code & Security、E2E、該当するUI/UXの専門レビュー | done の Verify the real result and review | 既存 review-code-security / review-e2e / review-ui-ux の観点と結果を確認 |
| Critical/Highの修正・再ビルド・再検証・再レビュー | done の同節 | 未解決の重大指摘を残して承認工程へ進まない |
| 報告の作成・検証・証拠・指摘履歴 | done の Serve the result with yunomi | 同じ報告パスを渡し、作成後に既存 report-builder / report-validator の適用項目と報告を照合 |
| 人間の承認と指摘対応ループ | done の Serve the result with yunomi | AIが承認せず、指摘後に修正・再検証する |

この表は照合対象を明示するもので、実運用検証済みの宣言ではない。起動方法は現行環境のHerdr規則に合わせるが、専門レビューの責任は消さない。

## 制約と配布

### 説明図の必須条件（ユーザー追加要求）

yunomiに提出する報告には説明図を必須とし、コード例・比較表・スクリーンショットでは代替しない。既存と新フローの比較は、両方を並べ、維持・追加・明確化・明示的に廃止した箇所を色と文字で区別する。既存のセキュリティ/E2E/該当するUIUXレビュー、動画を含む証拠、人間の承認を図から落とさない。

/doが図の内容・根拠・検証を計画し、/doneが報告書の表への埋め込みと実際のyunomiページでの画像読み込みを確認する。/buchoは同じ条件を委譲先へ渡し、主担当が証拠を確認する。artifact-proof、validate-report、report-builder、report-validatorも同じ条件を扱い、従来の点数による免除を認めない。現在のCodex画像生成規則とユーザーだけが再生成を指示できる規則を守る。

保存先を主checkoutの `.artifacts/<ブランチ名>/` へ集約する案は検討中。`REPORT.md`を読む入口とし、図・動画とレビュー履歴を同じ場所へ保持する構成を提案するが、保存先変更はまだ実施しない。

### 配布条件

- 原本は `plugin/skills/{do,done,bucho}/`。dotfiles は配布先となり、別の本文を保守しない。
- 既存の yunomi 承認スキルがブラウザと通知経路の手順を所有する。各ワークフローへ複製しない。
- 一律の質問回数・ファイル数による tiny 判定・品質水準の選択を廃止する。適用される検証・レビュー要件は弱めない。
- 委譲時はその環境の承認済み runtime・model・権限・通知経路を守る。外部モデルの既定値を輸入しない。
- 外部依存の自動取得、グローバル hook、外部指示の注入、自動環境初期化を追加しない。
- ユーザーの確定指示により、追加スクリプト・ライブラリは導入しない。提案した配布一致検査も新規導入しない。既存ツールで配布内容を確認する。

## 一次資料

- [pstack の中心スキル](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/SKILL.md)・[機能開発](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/feature.md)
- [ponytail の中心スキル](https://github.com/DietrichGebert/ponytail/blob/main/skills/ponytail/SKILL.md)
- [deslop](https://github.com/cursor/plugins/blob/main/cursor-team-kit/skills/deslop/SKILL.md)

## 旧手順からの保持・変更の対応

基準はdotfilesの統合直前 `0a3c57c` と、要求保持修正前 `f4c90f2` のスキル。ユーザー指示で変更した項目と、残す義務を分ける。

| 旧手順の義務 | 統合版の保持先・責任 |
|---|---|
| 利用者・user story・scope・機能/非機能・境界条件の確認 | do / Preserve existing functionality：回答と重要判断を記録。未確認の利用者像や閾値は作らない。 |
| 既存機能・実装・テスト・呼び出し元の調査 | do / Understand before choosing：全callerとデータ・失敗時の流れを読み、共通原因を特定。 |
| 設計選択とCode/Security、該当E2E/UIUX設計助言 | do / Preserve existing functionality と Model the domain：実際の既存レビュー指示を読み、独立助言と重大指摘への対応を残す。 |
| 方針のユーザー確認 | do / Preserve existing functionality：未解決の選択は確認、既に承認済みの方針は再確認しない。 |
| 実装と検証が対になるTODO、フィードバック原文 | do / Sequence dependencies、Resume：各単位の目的・前提・担当・検証と原文を保持。 |
| 既存実装担当から継承する設計指針 | do / Preserve project-specific verification：webapp/backend/mobile-implのチェックリストを読む。Web UIはfrontend-designとreduced-motionを計画・検証へ引き継ぐ。 |
| RED→GREEN→Refactor | do / Preserve existing functionality：t-wada TDDを明記。委譲にも渡す。 |
| ビルド・起動・実際の操作 | do / Preserve project-specific verification、done / Verify the real result：対象surfaceを実行。 |
| Backend実テスト・実DB/許可済みローカルエミュレーター・coverage | doのsurface表とdoneの同節。手動curlだけで置換しない。 |
| Mobile Maestroのassertions・各ステップ画像・対象画面サイズ | doのsurface表、doneの撮影前検証。 |
| UIログイン・初回以外のUI遷移・レコードと画面のassertions・状態待ち | doのE2E契約とdoneの撮影前検証。API/localStorageなどで操作を迂回しない。 |
| 全種別Code/SecurityとE2E、該当UIUXの最終レビュー | done / Verify the real result and review：観点・適用範囲・指示ファイル・独立レビューの結果収集を明記。 |
| Critical/High修正・再ビルド・再検証・再レビュー | doneの同節。指摘の空/未読レスポンスは合格でない。 |
| スクリーンショットと動画、包括的報告 | done / Serve the result：両方を保持。説明図も必須。 |
| report-builder・report-validator・artifact-proof・validate-report | done / Serve：実際の指示を読み、同一の報告パスを渡す。旧起動例より現行権限を優先。 |
| 言語・画像動画の表埋め込み・近接する判断材料・原文指摘履歴 | done / Serve：具体的な報告条件を保持。 |
| 人間の承認、request_changes後の修正・再検証 | done / Serve と Deliver：同じループを継続。AIが人間のコメントを解決済みにしない。 |
| 部長の同じHerdr workspace/tab、runtime/model/権限確認 | bucho / Establish ownership：現行herdr-pane-commanderを実際に読み、起動結果を検証。 |
| 部長の永続ルールと圧縮後の復帰 | bucho / Persistent rule anchor：実ファイル・双方TODO・子の受領確認を必須化。 |
| 部長の完全な成果委譲、実物確認、同じ責任者への修正差戻し | bucho / Delegate、Supervise、Accept：既存義務と今回の判断・検証をすべて引き継ぐ。 |

### ユーザー指示で置換した旧手順

- tinyの規模・品質選択を廃止し、旧ファイルは無効ディレクトリへ退避。機能と完了基準はdo/doneへ統合。
- 固定の質問回数は、未解決の意図と選択だけを聞く方式へ。要求探索の項目は維持。
- 固定人数・旧Task起動・退役モデル指定は現行の承認済み実行経路へ。レビューの責任は維持。
- 無断のglobal hookやdotenvx初期化、証跡の強制追加/LFS、worktreeの自動削除は現行ユーザー規則に従う方式へ。
- 保存先は合意済みパスを使う。主checkoutへの集約案は未承認で未実施。

## 一次資料から新しい行動への対応

| 一次資料 | 採用した行動 | 実施先 |
|---|---|---|
| [P-Stack how](https://github.com/cursor/plugins/blob/main/pstack/skills/how/SKILL.md) | 実装前に実際の層・責任・経路を読む | do / Understand before choosing |
| [P-Stack domain model](https://github.com/cursor/plugins/blob/main/pstack/skills/principle-model-the-domain/SKILL.md) | 状態・データ・所有者・不変条件を実装前に決める | do / Model the domain |
| [P-Stack feature playbook](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/feature.md) | 前提・共有状態・依存順・担当範囲を決める | do / Sequence dependencies、bucho / Establish ownership |
| [P-Stack verifiable units](https://github.com/cursor/plugins/blob/main/pstack/skills/principle-sequence-verifiable-units/SKILL.md) | 基準を確認→1単位を実装→検証→依存する次工程へ | do / Sequence dependencies、done / Check the requested outcome |
| [P-Stack decision trail](https://github.com/cursor/plugins/blob/main/pstack/skills/show-me-your-work/SKILL.md) | 判断理由・実証拠・訂正を残して再開できる | do / Resume、bucho / Persistent rule anchor。既存記録を利用しlogging scriptは導入しない。 |
| [Ponytail](https://github.com/DietrichGebert/ponytail/blob/main/skills/ponytail/SKILL.md) | 要求を理解してから既存手段を順に調べ、全callerから共通原因を直す | do / Understand、Choose what must be built |
| [deslop](https://github.com/cursor/plugins/blob/main/cursor-team-kit/skills/deslop/SKILL.md) | 今回の差分にある不要な複雑さを動作保持で整理、変更後に再検証 | done / Deslop the task diff |

## 作業と検証

- [x] ユーザー依頼：原本の3スキルを統合し、旧手順の具体的な保持先を照合した。
- [x] ユーザー依頼：配布用dotfilesブランチへ同一本文を配置し、tinyを無効ディレクトリへ退避した。
- [x] ユーザー依頼：同梱・呼び出し元の文書と既存チェックリストを整合。既存テストのスキル非同梱条件を3スキル同梱へ更新した。
- [x] 検証：ビルド成功、既存ブラウザ/同梱回帰テスト21件成功。本文一致・frontmatter・差分空白検査成功。
- [x] 検証：GPT-6-Astra highとCursor Grok 4.6 Highが最終配布版b22ff3eで未解決指摘なし。通常環境4か所×3本文の一致とtiny退避を確認した。
- [ ] 人間の承認：Yunomi原本のcommit/push前承認。実装と検証を終えてから同じレビューへ提出する。

## 現在地

元checkoutはYunomi main、dotfiles masterを維持。Yunomiの原本は `.worktree/feature/unified-workflow-skills`、配布用dotfilesは `.worktree/chore/yunomi-workflow-origin`。配布用の3本文は原本と完全一致する。dotfilesの保存済み配布改訂は `b22ff3e`。通常環境への反映と独立レビューは完了。dotfiles masterとremote masterはb22ff3eで一致しclean。Yunomi側の原本・補助指示・案内のmain反映は人間承認待ちであり、公開済みとは扱わない。追加スクリプト・ライブラリは導入していない。変更した実行ファイルは既存hookの案内文と、既存回帰テストの同梱契約のみ。呼び出す既存Markdown補助指示は、明示パス・読み取り専用・秘密値を出力しない検査・現行の報告見出しと通知手順へ整合した。実アプリ開発全種別での継続運用効果は未検証。
