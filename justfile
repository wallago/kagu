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


# Regenerate case geometry from the KiCad PCBs
[group('case')]
case-geometry:
    python3 case/extract_geometry.py

# Render all case STLs into case/build/
[group('case')]
case: case-geometry
    mkdir -p case/build
    for side in left right; do \
        for part in bottom plate; do \
            echo "▶ $side $part"; \
            openscad -D "part=\"$part\"" \
                -o case/build/kagu_${side}_${part}.stl case/${side}.scad; \
        done; \
    done

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

# Render the Choc v2 keycap tilters into case/build/
# Square and diagonal leans are separate parts: an MX cross only seats every
# 90 degrees, so a 45 degree lean cannot be had by turning a square one.
[group('case')]
tilters:
    mkdir -p case/build
    openscad -D "tilt=0" -o case/build/choc_v2_tilter_0deg.stl case/choc_v2_tilter.scad
    for a in 10 15 25 35; do \
        echo "▶ tilter ${a}deg square"; \
        openscad -D "tilt=$a" -D "azimuth=0" \
            -o case/build/choc_v2_tilter_${a}deg.stl case/choc_v2_tilter.scad; \
        echo "▶ tilter ${a}deg diagonal"; \
        openscad -D "tilt=$a" -D "azimuth=45" \
            -o case/build/choc_v2_tilter_${a}deg_diag.stl case/choc_v2_tilter.scad; \
    done

# Render the Choc v2 keycap risers into case/build/
# Round posts, Choc v2 socket below and an MX cross on top, straight or leaned.
# Printed socket down, no supports.
[group('case')]
risers:
    mkdir -p case/build
    for h in 0.5 1 3 5; do \
        echo "▶ riser ${h}mm"; \
        openscad -D "height=$h" -o case/build/choc_v2_riser_${h}mm.stl case/choc_v2_riser.scad; \
    done
    echo "▶ riser 0.5mm no collar"
    openscad -D "height=0.5" -D "collar=false" \
        -o case/build/choc_v2_riser_0.5mm_nocollar.stl case/choc_v2_riser.scad
    echo "▶ riser 1.5mm 15deg square"
    openscad -D "height=1.5" -D "tilt=15" -D "azimuth=0" \
        -o case/build/choc_v2_riser_1.5mm_15deg.stl case/choc_v2_riser.scad
    echo "▶ riser 1.5mm 15deg diagonal"
    openscad -D "height=1.5" -D "tilt=15" -D "azimuth=45" \
        -o case/build/choc_v2_riser_1.5mm_15deg_diag.stl case/choc_v2_riser.scad
