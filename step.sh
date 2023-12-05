#!/usr/bin/env bash

set -e

red=$'\e[31m'
green=$'\e[32m'
blue=$'\e[34m'
magenta=$'\e[35m'
cyan=$'\e[36m'
reset=$'\e[0m'

MERGES=$(git log --pretty='format:%s' $(git merge-base  --octopus $(git log --pretty='format:%P' -1 --merges ))..$(git log --pretty='format:%H' -1 --merges))

SAVEDIFS=$IFS
IFS=$'\n'

MERGES=($MERGES)

IFS=$SAVEDIFS

LAST_COMMIT=$(git log --pretty='format:%b' -1 )

TASKS=()

echo "${blue}⚡ ️Last commit:${cyan}"
echo $'\t'"📜 "$LAST_COMMIT
echo "${reset}"

if (( ${#MERGES[*]} > 0 ))
then
    echo "${blue}⚡ Last merge commits:${cyan}"

    for (( i=0 ; i<${#MERGES[*]} ; ++i ))
    do
        echo $'\t'"📜 "${MERGES[$i]}
    done

    echo "${reset}"

    if [ "$LAST_COMMIT" = "${MERGES[0]}" ];
    then
        echo "${green}✅ Merge commit detected. Searching for tasks in merge commits messages...${cyan}"
        for (( i=0 ; i<${#MERGES[*]} ; ++i ))
        do
            echo $'\t'"📜 "${MERGES[$i]}
        done

        for task in $(echo $MERGES | grep "$project_prefix[0-9]{1,5}" -E -o || true | sort -u -r --version-sort)
        do
            if [[ ! " ${TASKS[@]} " =~ " ${task} " ]]; then
                TASKS+=($task)
            fi
        done
    else
        echo "${magenta}☑️  Not a merge commit. Searching for tasks in current commit message...${cyan}"
        echo
        echo $'\t'"📜 "$LAST_COMMIT "${reset}"
        
        for task in $(echo $LAST_COMMIT | grep "$project_prefix[0-9]{1,5}" -E -o || true | sort -u -r --version-sort)
        do
            if [[ ! " ${TASKS[@]} " =~ " ${task} " ]]; then
                TASKS+=($task)
            fi
        done
    fi
fi

SAVEDIFS=$IFS
IFS=$'|'

DIVIDED_VALUES=($jira_issue_field_value)

IFS=$SAVEDIFS

create_add_array_data()
{
        VALUES_STRING=""

        for (( i=0 ; i<${#DIVIDED_VALUES[*]} ; ++i ))
        do
                if (( i > 0 ))
                then
                        VALUES_STRING="${VALUES_STRING},"
                fi

                VALUES_STRING=${VALUES_STRING}'{ "add": "'${DIVIDED_VALUES[$i]}'" }'
        done

cat<<EOF
{
"update": {
        "${jira_issue_field_name}": [
                        ${VALUES_STRING}
                ]
        }
}
EOF
}

create_set_array_data()
{
        VALUES_STRING=""

        for (( i=0 ; i<${#DIVIDED_VALUES[*]} ; ++i ))
        do
                if (( i > 0 ))
                then
                        VALUES_STRING="${VALUES_STRING},"
                fi

                VALUES_STRING=${VALUES_STRING}'"'${DIVIDED_VALUES[$i]}'"'
        done

cat<<EOF
{
"update": {
        "${jira_issue_field_name}": [
                        {
                                "set": [
                                        ${VALUES_STRING}
                                ]
                        }
                ]
        }
}
EOF
}

create_set_data()
{
cat<<EOF
{
"update": {
        "${jira_issue_field_name}": [
                        {
                                "set": "${jira_issue_field_value}"
                        }
                ]
        }
}
EOF
}

body=""

echo "${magenta}"
if [ "$jira_issue_field_type" = "array" ];
then
        if [ "$jira_should_array_add_or_set" = "add" ];
        then
                echo "Add to array..."
                body="$(create_add_array_data)"
        elif [ "$jira_should_array_add_or_set" = "set" ];
        then
                echo "Setting array..."
                body="$(create_set_array_data)"
        fi
elif [ "$jira_issue_field_type" = "single" ];
then
        echo "Setting value..."
        body="$(create_set_data)"
fi

echo "${blue}"
echo "${body}"
echo "${reset}"

for (( i=0 ; i<${#TASKS[*]} ; ++i ))
do
        echo $'\t'"${magenta}⚙️  "${TASKS[$i]}

        res="$(curl -u $jira_user:$jira_token -X PUT -H 'Content-Type: application/json' --data-binary "${body}" https://${backlog_default_url}/rest/api/2/issue/${TASKS[$i]})"

        if test "$res" == ""
        then
                echo $'\t'$'\t'"${green}✅ Success!${reset}"
        else
                echo $'\t'$'\t'"${red}❗️ Failed${reset}"
                echo "response: "$res
        echo ""
        fi
done
