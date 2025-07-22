#!/bin/bash

function generateDebugSymbols {

        build_dir=$1
        cwd=$(pwd)

        cd $build_dir
        find . -type f \( -perm /111 -o -name "*.so" \) -exec dirname {} \; | sort -u | xargs -I{} mkdir -p debug_symbols/{}

        for stripfile in `find . -type f | xargs -I{} file {} | grep ELF | grep "not stripped" | cut -d : -f 1 `
        do
                objcopy --only-keep-debug "${stripfile}" "${build_dir}/debug_symbols/${stripfile}.symbols"
                strip --strip-debug --strip-unneeded "${stripfile}"
                objcopy --add-gnu-debuglink="${build_dir}/debug_symbols/${stripfile}.symbols" "${stripfile}"
        done

        cd $cwd
}
