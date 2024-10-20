#!/usr/bin/env bash

usage() {
  echo "Save github contributors json data to local machine" >&2
  echo "$0 [-r REPO] [-o ORG] [-t TOKEN]" >&2
}

tmp_file="tmp.json"
token=
org=
repo=

while getopts "t:o:r:" opt; do
  case $opt in
  t)
    token="$OPTARG"
    ;;
  o)
    org="$OPTARG"
    ;;
  r)
    repo="$OPTARG"
    ;;
  \?)
    usage
    exit 1
    ;;
  esac
done

shift $((OPTIND - 1))

if [[ -z "$token" ]]; then
  echo "You must specify the github token by $0 -t TOKEN." >&2
  usage
  exit 1
fi

if [[ -z "$org" ]] && [[ -z "$repo" ]]; then
  echo "You must specify the organization by -o ORG or the repository by -r REPO" >&2
  usage
  exit 1
fi

save_repo_contributors() {
  local repo="$1"
  mkdir -p "$repo"
  seq=1
  contributors_file="$repo/contributors.$seq.json"
  # It seems that we already download the contributors to a file, skipping redownload
  if [[ -f "$contributors_file" ]]; then
    return
  fi
  while true; do
    contributors_file="$repo/contributors.$seq.json"
    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $token" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/$repo/contributors?per_page=100&page=$seq" >"$contributors_file"
    if [[ "$(jq length "$contributors_file")" == 0 ]] || ! [[ -s "$contributors_file" ]]; then
      break
    fi
    seq=$((seq + 1))
  done
  jq -c '.[]' "$repo"/contributors.*.json >"$repo"/contributors.json
}

save_org_repos() {
  local org="$1"
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
}

if [[ -n "$org" ]]; then
  save_org_repos "$org"

  jq -r '.[].full_name' "$org"/repos.*.json | while read -r r; do
    save_repo_contributors "$r"
  done

  rm -f "$tmp_file"
  for f in "$org"/*/contributors.*.json; do
    jq -c '.[]' "$f" >>"$tmp_file"
  done
  mv "$tmp_file" "$org"/contributors.json
fi

if [[ -n "$repo" ]]; then
  save_repo_contributors "$repo"

  rm -f "$tmp_file"
  for f in "$repo"/contributors.*.json; do
    jq -c '.[]' "$f" >>"$tmp_file"
  done
  mv "$tmp_file" "$repo"/contributors.json
fi
