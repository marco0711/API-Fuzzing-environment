#!/bin/bash
source $HOME/scripts/utils.sh

reset_all(){
    setup_environment
}

reset_targets(){
    source /tmp/env_cache_file.env
    rebuild_targets
}

init(){
    setup_environment
}

test_single(){
    source /tmp/env_cache_file.env
    interactive_test
}

test_full(){
    source /tmp/env_cache_file.env
    test_all
}

print_info(){
    source /tmp/env_cache_file.env	
    print_all
}

archive(){
    source /tmp/env_cache_file.env
    output_archival
}

print_help(){
    source /tmp/env_cache_file.env 
    print_help
}
