#!/bin/bash

# generate_sbom <component_name> <build_location>
function generate_sbom {
    local component_name="$1"
    local build_location="$2"
    local sbom_file="$build_location/${component_name}-sbom.spdx.json"
    local sbom_file_asc="$build_location/${component_name}-sbom.spdx.json.asc"

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

    KEY_ID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5}' | head -n 1); export KEY_ID
    gpg --armor --detach-sign --output ${sbom_file_asc} ${sbom_file} || exit 1
}

# generate_grype_sbom <component_name> <build_location>
function generate_grype_sbom {
    local component_name="$1"
    local build_location="$2"
    local sbom_file="$build_location/${component_name}-grype-sbom.cyclonedx.json"

    # Check if grype is installed
    if ! command -v grype &> /dev/null; then
        echo "grype is not installed. Installing grype..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
    fi

    echo "Generating CycloneDX SBOM with grype for $component_name..."
    grype "$build_location" -o cyclonedx-json > "$sbom_file"
    if [ $? -ne 0 ]; then
        echo "Error: grype failed to generate CycloneDX SBOM."
        return 1
    fi
    echo "Grype CycloneDX SBOM generated at $sbom_file"
    # Optionally, print a summary of the grype scan
    grype "$build_location"
    # Scan system libraries in the build's lib directory for vulnerabilities
    scan_libs_with_grype "$build_location"
}

# scan_libs_with_grype <build_location>
function scan_libs_with_grype {
    local build_location="$1"
    if ! command -v rpm &> /dev/null; then
        echo "rpm is not installed. Skipping system library vulnerability scan."
        return 1
    fi
    if ! command -v grype &> /dev/null; then
        echo "grype is not installed. Skipping system library vulnerability scan."
        return 1
    fi
    if ! command -v repoquery &> /dev/null; then
        echo "repoquery is not installed. Installing dnf-plugins-core..."
        sudo dnf install -y dnf-plugins-core
    fi
    local tmpdir=$(mktemp -d)
    echo "Scanning system libraries in $build_location/lib with grype..."
    for sofile in "$build_location/lib/"*.so*; do
        [ -e "$sofile" ] || continue
        so_name=$(basename "$sofile")
        sysfile="/lib64/$so_name"
        if [ -f "$sysfile" ]; then
            pkg=$(rpm -qf "$sysfile" 2>/dev/null)
            if [[ "$pkg" != *"is not owned by any package"* ]]; then
                echo "\n--- Scanning $pkg (for $so_name) ---" | tee -a "$build_location/system-libs-vuln-report.txt"
                rpmfile=$(repoquery --location "$pkg" 2>/dev/null | head -1)
                cd "$tmpdir"
                localfile=""
                if [ -n "$rpmfile" ]; then
                    if [[ "$rpmfile" =~ ^https?:// ]]; then
                        curl -O "$rpmfile"
                        localfile=$(basename "$rpmfile")
                    fi
                fi
                # Fallback to dnf download if curl did not succeed
                if [ ! -f "$localfile" ]; then
                    dnf download "$pkg" || true
                    localfile=$(ls -t *.rpm 2>/dev/null | head -1)
                fi
                if [ -f "$localfile" ]; then
                    grype "$localfile" -o table >> "$build_location/system-libs-vuln-report.txt"
                else
                    echo "Failed to download RPM for $pkg, skipping grype scan." | tee -a "$build_location/system-libs-vuln-report.txt"
                    echo "$pkg" >> "$build_location/missing-grype-rpms.txt"
                fi
                cd - > /dev/null
            else
                echo "$so_name is not owned by any RPM package." | tee -a "$build_location/system-libs-vuln-report.txt"
            fi
        else
            echo "$so_name not found in /lib64." | tee -a "$build_location/system-libs-vuln-report.txt"
        fi
    done
    # Scan pip packages if available
    # if command -v pip &> /dev/null; then
    #     echo -e "\n--- Scanning pip packages ---" >> "$build_location/system-libs-vuln-report.txt"
    #     pip freeze > "$tmpdir/requirements.txt"
    #     grype pip:$(realpath "$tmpdir/requirements.txt") -o table >> "$build_location/system-libs-vuln-report.txt"
    # fi
    rm -rf "$tmpdir"
}

# scan_tarball_with_grype <tarball_path>
function scan_tarball_with_grype {
    local tarball_path="$1"
    if [ ! -f "$tarball_path" ]; then
        echo "Error: Tarball $tarball_path does not exist."
        return 1
    fi
    if ! command -v grype &> /dev/null; then
        echo "grype is not installed. Installing grype..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
    fi
    local tmpdir
    tmpdir=$(mktemp -d)
    tar -xzf "$tarball_path" -C "$tmpdir"
    local report_file="${tarball_path%.tgz}.grype-report.txt"
    echo "Scanning extracted tarball contents in $tmpdir with grype..."
    grype "$tmpdir" -o table > "$report_file"
    local grype_status=$?
    rm -rf "$tmpdir"
    if [ $grype_status -ne 0 ]; then
        echo "Error: grype failed to scan extracted tarball."
        return 1
    fi
    echo "Grype scan report written to $report_file"
} 
