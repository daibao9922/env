#!/bin/bash

readonly g_version='1.5'
readonly g_cur_shell_path=$0

copy_file()
{
    local target_path=$1
    local version=$2
    local change_file=$3
    local file_sha=''
    local file_type=''
    local segment_list=$(echo $change_file | tr '/' ' ')
    local change_file_dir=''
    
    file_sha=$(git cat-file -p $version | awk 'NR == 1 {printf("%s", $2)}')
    
    for segment in $segment_list
    do
        if [[ '' == $file_sha ]]; then
            return 0
        fi
        file_type=$(git cat-file -p $file_sha | awk -v file_name=${segment} '$4 == file_name {printf("%s", $2)}')
        file_sha=$(git cat-file -p $file_sha | awk -v file_name=${segment} '$4 == file_name {printf("%s", $3)}')
        if [[ $file_type != 'tree' && $file_type != 'blob' && $file_type != '' ]]; then
            echo "Error !!!!! file_type:$file_type"
            exit 1
        fi
    done
    
    if [[ $file_type == 'tree']]; then
        mkdir -p ${target_path}/${change_file}
    elif [[ $file_type == 'blob' ]]; then
        if [[ $file_sha == '' ]]; then
            echo "Error !!!!! file_sha is null"
            exit 1
        fi
        
        change_file_dir="${target_path}/${change_file}"
        change_file_dir=${change_file_dir%/*}
        if [[ ! -d $change_file_dir ]]; then
            mkdir -p $change_file_dir
        fi
        git cat-file -p $file_sha >${target_path}/${change_file}
    fi
}

copy_change_list()
{
    local target_path=$1
    local version=$2
    
    shift
    
    local change_file=$2
    while [[ "${change_file}" != "" ]]
    do
        copy_file $target_path $version $change_file
        shift
        change_file=$2
    done
}

usage()
{
    cat <<\
EOF
version ${g_version}

USAGE:
    mygitdiff.sh revision
    mygitdiff.sh revision_old revision_new

OPTION:
    --help
    --version
EOF
}

get_base_path()
{
    local tmp_base_path=$(pwd)
    while [[ "${tmp_base_path}" != "" ]]
    do
        if [[ -d ${tmp_base_path}/.git ]]; then
            echo ${tmp_base_path}
            return
        fi
        tmp_base_path=${tmp_base_path%/*}
    done
}

check_arg()
{
    if [[ 0 == $# || "$1" == '--help' ]]; then
        usage
        exit 0
    fi
    
    if [[ "$1" == "--version" ]]; then
        echo "version ${g_version}"
        exit 0
    fi
    
    local base_path=''
    base_path=$(get_base_path)
    if [[ "${base_path}" == "" ]]; then
        echo "Path is error!"
        exit 0
    fi
    
    if [[ $# > 2 ]]; then
        echo "Args are too many!"
        exit 0
    fi
}

get_parent_revision_list()
{
    local parent_list=$(git log $1 -1 | awk '/^Merge/ {printf("%s %s\n", $2, $3)}')
    if [[ $parent_list == "" ]]; then
        parent_list="${1}~1"
    fi
    echo $parent_list
}

get_change_list()
{
    local start_version=$1
    local end_version=$2
    local change_list1=$(git diff ${start_version} ${end_version} --name-only)
    local change_list2=$(git diff ${end_version} ${start_version} --name-only)
    
    echo $change_list1 $change_list2 | tr ' ' '\n' | sort | uniq
}

build_diff_by_revision_range()
{
    local target_path=$1
    local start_version=$2
    local end_version=$3
    local change_list=$(get_change_list ${start_version} ${end_version})
    
    copy_change_list "${target_path}/old" ${start_version} $change_list
    copy_change_list "${target_path}/new" ${end_version} $change_file
}

build_diff_by_revision()
{
    local target_path_arg=$1
    local target_path=''
    local revision=$2
    local parent_list=$(get_parent_revision_list $revision)
    
    for parent in $parent_list
    do
        if [[ "${parent}" == "${revision}~1" ]]; then
            target_path="${target_path_arg}/${revision}"
        else
            target_path="${target_path_arg}/${parent}-${revision}"
        fi
        
        if [[ -d "${target_path}" ]]; then
            \rm -rf "${target_path}"
        fi
        
        build_diff_by_revision_range $target_path $parent $revision
    done
}

main()
{
    check_arg $@
    
    local base_path=$(get_base_path)
    local target_base_path="/home/git_diff_list"
    
    cd $base_path
    
    if [[ $# == 1 ]]; then
        build_diff_by_revision ${target_base_path} $1
    else
        build_diff_by_revision_range "${target_base_path}/${1}-${2}" $1 $2
    fi
}

main $@

