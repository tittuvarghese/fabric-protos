function  build() {
  branch="${1:-master}"

  # Lint the protocol buffers
  prototool lint

  [ -d build/fabric-protos-go/.git ] || git clone https://github.com/tittuvarghese/fabric-protos.git build/fabric-protos-go

  # Checkout the appropriate branch and remove generated files
  (
    cd build/fabric-protos-go
    git show-branch "${branch}" > /dev/null 2>&1 || git branch "${branch}"
    git checkout "${branch}"
    if git ls-remote --heads --exit-code origin "${branch}"; then
      git pull origin "${branch}"
    fi
    git ls-files | grep -vFx -f <(grep -v '^#' < .whitelist) | tr '\n' '\0' | xargs -0 rm -f
    find ./* -type d -empty -delete
  )

  ci/compile_go_protos.sh
  cd build/fabric-protos-go
  go mod tidy
  go build ./...

  git add -A .
  git diff --color --cached

}

function compile() {
  repo="build/fabric-protos-go"

  if [ ! -d "$repo" ]; then
    echo "$repo does not exist"
    exit 1
  fi

  for protos in $(find . -name '*.proto' -exec dirname {} \; | sort -u); do
    protoc "--go_out=plugins=grpc,paths=source_relative:$repo" "$protos"/*.proto
  done
}

build master
compile
