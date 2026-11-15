#!/bin/bash
#
# apply-local-patches.sh
#
# Applies the patches in patches/ to a local checkout, the same way the GitHub
# browser build does (see .github/workflows/build_trio.yml). Without this, Xcode
# builds on a Mac compile the submodules without the patches, and code that
# depends on them fails with confusing errors.
#
# Each patch ends up in one of three states:
#   applied     already in the checkout: nothing to do
#   applicable  not in the checkout yet: apply it
#   conflict    neither, usually because an older version of the patch is still
#               applied: stop and print the commands that fix it. This script never
#               discards changes on its own.
#
# Usage: apply-local-patches.sh [apply|verify]
#   apply   (Trio scheme build pre-action) apply what is missing. Problems are
#           only reported by the verify phase; the pre-action itself ignores the
#           exit status, because a failing pre-action stops the whole archive.
#   verify  (Trio target build phase) apply what is missing, and fail the build
#           with a clear message if anything had to be applied or cannot be.
#           Patched submodules are compiled before this phase runs, so a patch
#           applied here only takes effect on the next build.

# No `set -u`: macOS runs this with bash 3.2, where expanding an empty array
# ("${list[@]}") under `set -u` is an "unbound variable" error. That failed the
# browser build whenever every patch was already applied.

mode="${1:-verify}"
root="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" || exit 1

shopt -s nullglob
patches=(patches/*.patch)
[ ${#patches[@]} -eq 0 ] && exit 0

if ! command -v git >/dev/null 2>&1; then
    echo "warning: git not found; cannot check the patches in patches/"
    exit 0
fi

# Prints the top-level folders a patch changes, e.g. CGMBLEKit.
patch_dirs() {
    sed -n 's|^diff --git a/\([^/]*\)/.*|\1|p' "$1" | sort -u
}

applied_now=()
conflicts=()

for patch in "${patches[@]}"; do
    if git apply --reverse --check "$patch" >/dev/null 2>&1; then
        echo "applied: $patch"
    elif git apply --check --whitespace=fix "$patch" >/dev/null 2>&1; then
        if git apply --whitespace=fix "$patch"; then
            echo "applied now: $patch"
            applied_now+=("$patch")
        else
            conflicts+=("$patch")
        fi
    else
        conflicts+=("$patch")
    fi
done

for patch in ${conflicts[@]+"${conflicts[@]}"}; do
    dirs=$(patch_dirs "$patch")
    echo "error: $patch does not apply to ${dirs//$'\n'/, }. An older version of the patch, or other changes, are probably still there."
    echo "error: To reset and re-apply, run from the repository root (this discards any changes inside ${dirs//$'\n'/, }):"
    for dir in $dirs; do
        echo "error:     git -C $dir checkout -- . && git -C $dir clean -fd"
    done
    echo "error:     git apply --whitespace=fix $patch"
done

[ "$mode" = "apply" ] && exit 0

if [ ${#conflicts[@]} -gt 0 ]; then
    exit 1
fi

if [ ${#applied_now[@]} -gt 0 ]; then
    echo "error: Applied ${applied_now[*]} just now, after the patched code was already compiled. Build again (if it still fails, Product > Clean Build Folder first)."
    exit 1
fi

exit 0
