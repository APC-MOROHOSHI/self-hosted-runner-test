#!/usr/bin/env bash

set -u

# 環境変数の設定
export APP_ID=704560
export GITHUB_API_URL="https://api.github.com"

# Base64URLエンコード関数
# 入力値をBase64URLに変換する
base64url() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

# 署名関数
# GitHub Appsで事前生成した秘密鍵を使用して署名する
sign() {
  openssl dgst -binary -sha256 -sign <(printf '%s' "${PRIVATE_KEY}")
}

# 固定値のヘッダーのJSONをBase64URLエンコードする
header="$(printf '{"alg":"RS256","typ":"JWT"}' | base64url)"

# ペイロードのJSONをBase64URLエンコードする
now="$(date '+%s')"
iat="$((now - 60))"
exp="$((now + (3 * 60)))"
template='{"iss":"%s","iat":%s,"exp":%s}'
payload="$(printf "${template}" "${APP_ID}" "${iat}" "${exp}" | base64url)"

# ヘッダーとペイロードをピリオドで連結しその値に対して署名する
signature="$(printf '%s' "${header}.${payload}" | sign | base64url)"

# 各要素をピリオドで連結してJWTにする
jwt="${header}.${payload}.${signature}"

# GitHubのREST APIを使ってGitHub AppsのInstallation IDを取得する
# トークンを生成するAPIではInstallation IDが必要
installation_id="$(curl --location --silent --request GET \
  --url "${GITHUB_API_URL}/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/installation" \
  --header "Accept: application/vnd.github+json" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer ${jwt}" \
  | jq -r '.id'
)"

# Installation IDを指定してトークンを生成する
token="$(curl --location --silent --request POST \
  --url "${GITHUB_API_URL}/app/installations/${installation_id}/access_tokens" \
  --header "Accept: application/vnd.github+json" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer ${jwt}" \
  | jq -r '.token'
)"
echo "${token}"