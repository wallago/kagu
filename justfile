# List all commands
default:
    @just --list


# Regenerate CHANGELOG.md from git history
[group('release')]
changelog:
    git-cliff -o CHANGELOG.md




# Verify commit messages follow Conventional Commits
[group('release')]
commits base=`git rev-parse --abbrev-ref origin/HEAD`:
    committed -vv {{ `git merge-base HEAD ` + base }}..HEAD


# Check files conform to .editorconfig
[group('quality')]
editorconfig:
    editorconfig-checker

# Lint Nix (statix) and report dead Nix code (deadnix)
[group('quality')]
nix-lint:
    statix check .
    deadnix --fail .

# Build & check every flake output on all systems
[group('dev')]
flake-check:
    nix flake check --print-build-logs --all-systems

# Update all flake inputs to their latest revisions
[group('dev')]
flake-update:
    nix flake update


# Format TOML files with taplo
[group('quality')]
fmt-toml:
    taplo fmt

# Spell-check the codebase
[group('quality')]
typos:
    typos

# Cut & publish a release: bump version, changelog, commit, tag, push. Usage: just publish 0.2.0
[confirm("This will tag and push a release to origin. Continue?")]
[group('release')]
jj-publish VERSION:
    @test -z "$(jj diff --name-only)" || (echo "✗ working copy has uncommitted changes — commit or abandon them first" && exit 1)
    @echo "▶ bump version → {{ VERSION }}"
    cargo set-version {{ VERSION }}
    @echo "▶ regenerate changelog"
    @if command -v git-cliff >/dev/null 2>&1; then \
        git-cliff --tag v{{ VERSION }} -o CHANGELOG.md; \
    else \
        echo "⊘ git-cliff not installed — skipping changelog"; \
    fi
    @echo "▶ record release commit"
    jj commit -m "chore(release): v{{ VERSION }}"
    @echo "▶ advance main bookmark"
    jj bookmark set main -r @-
    @echo "▶ tag release commit"
    git tag -a v{{ VERSION }} -m "v{{ VERSION }}" "$(jj log -r @- --no-graph -T commit_id)"
    @echo "▶ push bookmark + tag"
    jj git push --bookmark main
    git push origin v{{ VERSION }}
    @echo "✅ published v{{ VERSION }}"
