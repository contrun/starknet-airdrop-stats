#!/usr/bin/env bash

org="$1"

token=
while getopts "t:" opt; do
  case $opt in
  t)
    token="$OPTARG"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    echo "$0 -t TOKEN"
    exit 1
    ;;
  esac
done

if [[ -z "$token" ]]; then
  if [[ -f ~/.config/gh/hosts.yml ]] && command -v yq >/dev/null; then
    token="$(yq '.[] | .oauth_token' ~/.config/gh/hosts.yml)"
  else
    echo "You must specify the github token by $0 -t TOKEN, or have a valid ~/.config/gh/hosts.yml file and yq."
    exit 1
  fi
fi

mkdir -p "$org"
seq=1
while true; do
  repos_file="$org/repos.$seq.json"
  # It seems that we already download the repos to a file, skipping redownload
  if [[ -f "$repos_file" ]]; then
    break
  fi
  curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $token" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/orgs/$org/repos?sort=full_name&per_page=100&page=$seq" >"$repos_file"
  if [[ "$(jq length "$repos_file")" == 0 ]]; then
    break
  fi
  seq=$((seq + 1))
done

jq -r '.[].full_name' "$org"/repos.*.json | while read -r repo; do
  mkdir -p "$repo"
  seq=1
  contributors_file="$repo/contributors.$seq.json"
  # It seems that we already download the contributors to a file, skipping redownload
  if [[ -f "$contributors_file" ]]; then
    continue
  fi
  while true; do
    contributors_file="$repo/contributors.$seq.json"
    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $token" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/$repo/contributors?per_page=100&page=$seq" >"$contributors_file"
    if [[ "$(jq length "$contributors_file")" == 0 ]] || ! [[ -s "$contributors_file" ]]; then
      break
    fi
    seq=$((seq + 1))
  done
done

for i in "$org"/*/contributors.1.json; do
  repo="$(dirname "$i")"
  jq -c '.[]' "$repo"/contributors.*.json >"$repo"/contributors.json
done

for i in "$org"/*/contributors.1.json; do
  org="$(dirname "$(dirname "$i")")"
  jq -c '.[]' "$org"/*/contributors.*.json >"$org"/contributors.json
done

jq -c '.[]' */*/contributors.*.json >contributors.json
