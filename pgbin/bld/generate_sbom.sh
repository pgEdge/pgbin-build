#!/bin/bash

# generate_sbom <component_name> <build_location>
function generate_sbom {
    local component_name="$1"
    local build_location="$2"
    local sbom_file="$build_location/${component_name}-sbom.spdx.json"
    
    # Check if syft is installed
    if ! command -v syft &> /dev/null; then
        echo "Warning: syft is not installed. Installing syft..."
        sudo curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
    fi

    # Generate SPDX SBOM using syft
    echo "Generating SPDX SBOM for $component_name..."
    local temp_sbom=$(mktemp)
    echo "Syft command: syft '$build_location' --output spdx-json='$temp_sbom'"
    syft "$build_location" --output spdx-json="$temp_sbom"
    syft_exit_code=$?
    echo "Syft exit code: $syft_exit_code"
    if [ $syft_exit_code -ne 0 ]; then
        echo "Error: Failed to generate SPDX SBOM. Syft exited with code $syft_exit_code."
        cat "$temp_sbom"
        exit 1
    fi
    if [ ! -s "$temp_sbom" ]; then
        echo "Error: Syft did not produce a valid SBOM file ($temp_sbom is empty)."
        exit 1
    fi
    echo "Syft SBOM generated at $temp_sbom"

    mv "$temp_sbom" "$sbom_file"

    # Ensure .packages array exists in SPDX file
    jq 'if has("packages") then . else . + {packages: []} end' "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"

    # Enrich SPDX SBOM with third-party RPM/DEB info for .so files in lib/
    if [ -d "$build_location/lib" ]; then
        for sofile in "$build_location"/lib/*.so*; do
            [ -e "$sofile" ] || continue
            so_name=$(basename "$sofile")
            # Check if already present in SPDX
            if jq -e --arg name "$so_name" '.packages[]? | select(.name == $name)' "$sbom_file" > /dev/null; then
                continue
            fi

            version="N/A"
            license="NOASSERTION"
            pkg="Unknown"
            found_pkg=false
            supplier="NOASSERTION"
            downloadLocation="NOASSERTION"
            purl="$pkg"
            if command -v rpm &>/dev/null; then
                if rpm -qf "$sofile" &>/dev/null; then
                    pkg=$(rpm -qf "$sofile" 2>/dev/null)
                    version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
                    license=$(rpm -q --qf '%{LICENSE}' "$pkg" 2>/dev/null)
                    [ -z "$license" ] && license=$(rpm -q --qf '%{LICENSES}' "$pkg" 2>/dev/null)
                    [ -z "$license" ] && license="NOASSERTION"
                    supplier=$(rpm -q --qf '%{VENDOR}' "$pkg" 2>/dev/null)
                    [ -z "$supplier" ] && supplier=$(rpm -q --qf '%{PACKAGER}' "$pkg" 2>/dev/null)
                    [ -z "$supplier" ] && supplier="NOASSERTION"
                    downloadLocation=$(rpm -q --qf '%{URL}' "$pkg" 2>/dev/null)
                    [ -z "$downloadLocation" ] && downloadLocation="NOASSERTION"
                    # Prefix supplier if not already
                    if [ -n "$supplier" ] && [ "$supplier" != "NOASSERTION" ]; then
                      case "$supplier" in
                        Organization:*|Person:*) ;;
                        *) supplier="Organization: $supplier" ;;
                      esac
                    fi
                    # Set purl for RPMs (assuming redhat, adjust if needed)
                    purl="pkg:rpm/redhat/$pkg@$version"
                    found_pkg=true
                else
                    # Try to find the same library in /lib64
                    sysfile="/lib64/$(basename "$sofile")"
                    if [ -f "$sysfile" ] && rpm -qf "$sysfile" &>/dev/null; then
                        pkg=$(rpm -qf "$sysfile" 2>/dev/null)
                        version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
                        license=$(rpm -q --qf '%{LICENSE}' "$pkg" 2>/dev/null)
                        [ -z "$license" ] && license=$(rpm -q --qf '%{LICENSES}' "$pkg" 2>/dev/null)
                        [ -z "$license" ] && license="NOASSERTION"
                        supplier=$(rpm -q --qf '%{VENDOR}' "$pkg" 2>/dev/null)
                        [ -z "$supplier" ] && supplier=$(rpm -q --qf '%{PACKAGER}' "$pkg" 2>/dev/null)
                        [ -z "$supplier" ] && supplier="NOASSERTION"
                        downloadLocation=$(rpm -q --qf '%{URL}' "$pkg" 2>/dev/null)
                        [ -z "$downloadLocation" ] && downloadLocation="NOASSERTION"
                        if [ -n "$supplier" ] && [ "$supplier" != "NOASSERTION" ]; then
                          case "$supplier" in
                            Organization:*|Person:*) ;;
                            *) supplier="Organization: $supplier" ;;
                          esac
                        fi
                        purl="pkg:rpm/redhat/$pkg@$version"
                        found_pkg=true
                    fi
                fi
            fi
            if [ "$found_pkg" = false ] && command -v dpkg-query &>/dev/null; then
                pkg=$(dpkg-query -S "$sofile" 2>/dev/null | head -1 | cut -d: -f1)
                if [ -n "$pkg" ]; then
                    version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
                    # Try apt-cache first
                    license=$(apt-cache show "$pkg" 2>/dev/null | grep -i '^License:' | head -1 | cut -d' ' -f2-)
                    # If not found, try /usr/share/doc
                    if [ -z "$license" ] && [ -f "/usr/share/doc/$pkg/copyright" ]; then
                        license=$(grep -m1 -i '^License:' "/usr/share/doc/$pkg/copyright" | awk '{print $2}')
                        if [ -z "$license" ]; then
                            license=$(awk '/^License:/{getline; while($0 ~ /^ / || $0 == ""){print; getline}}' "/usr/share/doc/$pkg/copyright" | head -1 | tr -d '\n')
                        fi
                    fi
                    [ -z "$license" ] && license="NOASSERTION"
                    supplier=$(apt-cache show "$pkg" 2>/dev/null | grep -i '^Maintainer:' | head -1 | cut -d' ' -f2-)
                    [ -z "$supplier" ] && supplier="NOASSERTION"
                    if [ -n "$supplier" ] && [ "$supplier" != "NOASSERTION" ]; then
                      case "$supplier" in
                        Organization:*|Person:*) ;;
                        *) supplier="Person: $supplier" ;;
                      esac
                    fi
                    downloadLocation=$(apt-cache show "$pkg" 2>/dev/null | grep -i '^Homepage:' | head -1 | cut -d' ' -f2-)
                    [ -z "$downloadLocation" ] && downloadLocation="NOASSERTION"
                    purl="pkg:deb/debian/$pkg@$version"
                    found_pkg=true
                fi
            fi
            if [ "$found_pkg" = true ]; then
                jq --arg name "$so_name" \
                   --arg version "$version" \
                   --arg license "$license" \
                   --arg pkg "$pkg" \
                   --arg supplier "$supplier" \
                   --arg downloadLocation "$downloadLocation" \
                   --arg purl "$purl" \
                   '.packages += [{
                      name: $name,
                      SPDXID: ("SPDXRef-Package-" + $name),
                      versionInfo: $version,
                      downloadLocation: $downloadLocation,
                      licenseConcluded: $license,
                      licenseDeclared: $license,
                      supplier: $supplier,
                      externalRefs: [{
                        referenceCategory: "PACKAGE-MANAGER",
                        referenceType: "purl",
                        referenceLocator: $purl
                      }]
                    }]' "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"
            fi
        done
    fi

    echo "SPDX SBOM (enriched) generated successfully at $sbom_file"

    # Generate a human-readable JSON file (pretty-printed, without 'spdx' in the name)
    #readable_file="${sbom_file/-sbom.spdx.json/-sbom.json}"
    #jq . "$sbom_file" > "$readable_file"
    #echo "Human-readable SBOM written to $readable_file"

    if [ ! -s "$sbom_file" ]; then
        echo "Error: Final SBOM file $sbom_file is missing or empty."
        exit 1
    fi
    echo "Final SBOM file $sbom_file exists and is not empty."

    # Ensure all PostgreSQL-related packages have PostgreSQL license
    jq '(.packages[] | select(.name | test("postgresql"))) |= (.licenseConcluded = "PostgreSQL" | .licenseDeclared = "PostgreSQL")' \
       "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"

    # Ensure the main component (if it is PostgreSQL) has PostgreSQL license
    jq --arg component "$component_name" \
       '(.packages[] | select(.name == $component)) |= (.licenseConcluded = "PostgreSQL" | .licenseDeclared = "PostgreSQL")' \
       "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"

    # Always set supplier to Organization: pgEdge for our own components (postgresql, spock, lolor, snowflake, and the main component)
    jq --arg component "$component_name" \
       '(.packages[] | select((.name | test("postgresql|spock|lolor|snowflake")) or (.name == $component))) |= (.supplier = "Organization: pgEdge")' \
       "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"

    # Add checksums to files
    for file in $(jq -r '.files[].fileName' "$sbom_file"); do
        sha1=$(sha1sum "$file" 2>/dev/null | awk '{print $1}')
        [ -z "$sha1" ] && continue
        jq --arg file "$file" --arg sha1 "$sha1" \
            '(.files[] | select(.fileName == $file).checksums[] | select(.algorithm == "SHA1")).checksumValue = $sha1' \
            "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"
    done

    # Set documentDescribes to the SPDXID of the first package (simple fallback)
    root_spdxid=$(jq -r '.packages[0].SPDXID' "$sbom_file")
    jq --arg root "$root_spdxid" \
       --arg comment "SBOM for $component_name built by pgEdge" \
       '.documentDescribes = [$root] | .documentComment = $comment' \
       "$sbom_file" > "${sbom_file}.tmp" && mv "${sbom_file}.tmp" "$sbom_file"
} 
