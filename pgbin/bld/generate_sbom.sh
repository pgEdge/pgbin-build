#!/bin/bash

# generate_sbom <component_name> <build_location>
function generate_sbom {
    local component_name="$1"
    local build_location="$2"
    local sbom_file="$build_location/${component_name}-sbom.json"
    
    # Check if syft is installed
    if ! command -v syft &> /dev/null; then
        echo "Warning: syft is not installed. Installing syft..."
        sudo curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required for SBOM generation. Please install jq first."
        return 1
    fi

    # Generate initial SBOM using syft
    echo "Generating SBOM for $component_name..."
    local temp_sbom=$(mktemp)

    # Print the syft command for debugging
    echo "Syft command: syft '$build_location' --output json='$temp_sbom'"
    syft "$build_location" --output json="$temp_sbom"

    # Create the simplified SBOM structure
    cat > "$sbom_file" << EOF
{
    "component": {
        "name": "$component_name",
        "version": "$componentFullVersion",
        "type": "postgresql-extension",
        "license": "PostgreSQL",
        "hash": "$(sha256sum "$build_location"/*.so 2>/dev/null | awk '{print $1}' || echo "N/A")"
    },
    "dependencies": {
        "libraries": [],
        "binaries": [],
        "extensions": []
    }
}
EOF

    # Extract dependencies as a JSON array
    deps_json=$(jq '[.artifacts[] | select(type == "object" and .type != "directory") | {
        name: (.name // "Unknown"),
        version: (.version // "N/A"),
        license: (
            if (.licenses? | type == "array" and (.licenses?|length) > 0)
            then .licenses[0].value // .licenses[0] // "Unknown"
            else "Unknown"
            end
        ),
        hash: (
            if (.metadata.checksums? | type == "array" and (.metadata.checksums?|length) > 0)
            then .metadata.checksums[0].value // .metadata.checksums[0] // "N/A"
            else "N/A"
            end
        )
    }]' "$temp_sbom")

    # Split dependencies into libraries, binaries, and extensions
    libs=$(echo "$deps_json" | jq '[.[] | select(.name|test("\\.so$"))]')
    bins=$(echo "$deps_json" | jq '[.[] | select(.name|test("bin"))]')
    exts=$(echo "$deps_json" | jq '[.[] | select((.name|test("\\.so$")|not) and (.name|test("bin")|not))]')

    # Update the SBOM file with syft-detected dependencies
    jq --argjson libs "$libs" --argjson bins "$bins" --argjson exts "$exts" \
       '.dependencies.libraries = $libs | .dependencies.binaries = $bins | .dependencies.extensions = $exts' \
       "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"

    # Post-process: Add all .so files in lib/ as libraries if not already present, and try to get version/license/hash from system
    if [ -d "$build_location/lib" ]; then
        find "$build_location/lib" -type f -name '*.so*' | while read sofile; do
            so_name=$(basename "$sofile")
            version="N/A"
            license="Unknown"
            hash="N/A"

            # Try RPM-based lookup
            found_pkg=false
            if command -v rpm &>/dev/null; then
                set +e
                pkg=$(rpm -qf "$sofile" 2>&1)
                rpm_status=$?
                set -e
                if [[ $rpm_status -ne 0 ]] || echo "$pkg" | grep -q "is not owned by any package"; then
                    # Try /lib64/ fallback
                    so_basename=$(basename "$sofile")
                    sysfile="/lib64/$so_basename"
                    set +e
                    pkg=$(rpm -qf "$sysfile" 2>&1)
                    rpm_status=$?
                    set -e
                fi
                if [[ $rpm_status -eq 0 ]] && ! echo "$pkg" | grep -q "is not owned by any package"; then
                    version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
                    license=$(rpm -q --qf '%{LICENSE}' "$pkg" 2>/dev/null)
                    found_pkg=true
                fi
            fi

            # Try DPKG-based lookup if not found by RPM
            if [ "$found_pkg" = false ] && command -v dpkg-query &>/dev/null; then
                pkg=$(dpkg -S "$sofile" 2>/dev/null | head -1 | cut -d: -f1)
                if [ -n "$pkg" ]; then
                    version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
                    license=$(apt-cache show "$pkg" 2>/dev/null | grep -i '^License:' | head -1 | cut -d' ' -f2-)
                    [ -z "$license" ] && license="Unknown"
                    found_pkg=true
                fi
            fi

            # Calculate SHA256 hash
            hash=$(sha256sum "$sofile" 2>/dev/null | awk '{print $1}')
            [ -z "$hash" ] && hash="N/A"

            # Only add to SBOM if a package was found
            if [ "$found_pkg" = true ]; then
                if jq -e --arg name "$so_name" '.dependencies.libraries[] | select(.name == $name)' "$sbom_file" > /dev/null; then
                    # Update version/license/hash if possible
                    jq --arg name "$so_name" --arg version "$version" --arg license "$license" --arg hash "$hash" '
                      .dependencies.libraries |= map(if .name == $name then .version = $version | .license = $license | .hash = $hash else . end)
                    ' "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"
                else
                    jq --arg name "$so_name" --arg version "$version" --arg license "$license" --arg hash "$hash" '.dependencies.libraries += [{"name": $name, "version": $version, "license": $license, "hash": $hash}]' "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"
                fi
            fi
        done
    fi

    # Add PostgreSQL as a dependency if not already present
    if ! jq -e '.dependencies.libraries[] | select(.name == "postgresql")' "$sbom_file" > /dev/null; then
        jq '.dependencies.libraries += [{
            "name": "postgresql",
            "version": "'"$pgFullVersion"'",
            "license": "PostgreSQL",
            "hash": "N/A"
        }]' "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"
    fi

    # Clean up temporary file
    rm -f "$temp_sbom"

    echo "SBOM generated successfully at $sbom_file"

    # Check for empty or invalid SBOM files
    if [ ! -s "$sbom_file" ]; then
        echo "Warning: SBOM file is empty or not valid JSON. Check above for details."
    fi

    # Check for errors after the Syft command
    jq_status=$?
    # echo "jq exit code: $jq_status"
    if [ $jq_status -ne 0 ]; then
        echo "jq failed. Check above for details."
        return 1
    fi

} 
