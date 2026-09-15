# NCP static website

WordPressを使わない静的サイトです。NEWSとTOPICはPages CMSからブラウザで更新できます。

## Content import

```sh
ruby scripts/import_wordpress.rb ncp.WordPress.2026-09-01.xml
ruby scripts/download_media.rb
```

## Build

```sh
ruby scripts/build.rb
```

生成結果は `dist/` に出力されます。

## Browser editing

1. このフォルダをGitHubリポジトリへ登録する
2. `https://app.pagescms.org` にGitHubでログインする
3. 対象リポジトリへのアクセスを許可する
4. NEWSまたはTOPICを編集・追加する

CMSの設定は `.pages.yml` にあります。

## Fixed preview (Cloudflare Pages)

GitHubの`main`ブランチをCloudflare Pagesへ接続すると、Pages CMSやローカルから変更をpushするたびに固定プレビューURLが自動更新されます。

Cloudflare Pagesの設定値:

- Framework preset: `None`
- Production branch: `main`
- Build command: `ruby scripts/build.rb`
- Build output directory: `dist`
- Root directory: 未指定（リポジトリ直下）

初回公開後に発行される`https://<project-name>.pages.dev`を確認用URLとして共有します。これは`ncptokyo.net`の公開内容やDNSを変更しません。
