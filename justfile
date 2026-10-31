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


# Regenerate case geometry from the KiCad PCBs
[group('case')]
case-geometry:
    python3 case/extract_geometry.py

# Render the bottom trays into case/build/
# Floor, border flush with the PCB top face, five M3 bosses, and a cable gap
# on the chip side. The right PCB has its XIAO on the back layer, so the tray
# clears the board by enough to swallow the module either way up and the USB
# notch spans the whole border height; that is what makes the two halves plain
# mirrors of each other.
[group('case')]
trays: case-geometry
    mkdir -p case/build
    for side in left right; do \
        echo "▶ $side tray"; \
        openscad -o case/build/kagu_${side}_tray.stl case/${side}_tray.scad; \
    done

# Render the top plates into case/build/
# Switch plate plus a short skirt that lands on the tray border. The PCB screws
# go through it, so it is countersunk for M3 x 8 flat heads (DIN 965). Comes
# out plate face down, ready to slice.
[group('case')]
tops: case-geometry
    mkdir -p case/build
    for side in left right; do \
        echo "▶ $side top"; \
        openscad -o case/build/kagu_${side}_top.stl case/${side}_top.scad; \
    done

# Render the left tray with the screen pod, and the pod's back cover, into case/build/
# A wedge behind the index columns holding the 1.47" ST7789 module, face tilted 55 degrees.
[group('case')]
screen: case-geometry
    mkdir -p case/build
    openscad -o case/build/kagu_left_tray_screen.stl case/left_tray_screen.scad
    openscad -o case/build/kagu_left_screen_cover.stl case/left_screen_cover.scad

# Render the Choc v2 keycap risers into case/build/
# Round posts, Choc v2 socket below and an MX cross on top, straight or leaned.
# Straight ones print socket down, leaned ones on the stem tip; no supports.
[group('case')]
risers:
    mkdir -p case/build
    echo "▶ riser straight"
    openscad -o case/build/choc_v2_riser.stl case/choc_v2_riser.scad
    for a in 15 25 35; do \
        echo "▶ riser ${a}deg square"; \
        openscad -D "tilt=$a" -D "azimuth=0" \
            -o case/build/choc_v2_riser_${a}deg.stl case/choc_v2_riser.scad; \
        echo "▶ riser ${a}deg diagonal"; \
        openscad -D "tilt=$a" -D "azimuth=45" \
            -o case/build/choc_v2_riser_${a}deg_diag.stl case/choc_v2_riser.scad; \
    done
