#!/bin/sh

echo "$1 "'[-(-h)elp] [--root-dir <directory>] [--nested-in-android] [--task <task>] [--repos-file <repos.txt>] [-(-j)obs <n>]


ARGUMENTS:
    --root-dir - Specify directory which will be treated as root of your project

    --nested-in-android - If this flag is set then android folder in the root of your project will be used. Otherwise, treat root of the project as android folder

    --task - Runs specified task, availabe tasks are:
           * gen_proj_list
           * gen_deps_list
           * gen_deps_urls
           * gen_deps_json
             by default all of them are run from the top to bottom

    --repos-file - txt file that contains list of maven repos to use

    -(-j)obs - Number of parallel jobs (used when possible)

    -(-h)elp - Show this menu

NOTES:
This script loads additional dependencies (that arent automatically loaded) from `additional-deps.list` file that has the same structure as `deps.list`. It assumes that this file is avaible in PWD.'
