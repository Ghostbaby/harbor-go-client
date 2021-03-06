#!/bin/bash

set -e

HARBOR_ADDR=localhost
PRJ_NAME=tmp

SUCCESS="\033[42;30;1m Success \033[0m"
ERROR="\033[41;30;1m Error \033[0m"

separator() {
    printf "%s\n\n" "-----------------"
}

prepare() {

    echo "----- prepare harbor-go-client and conf/ for tesing -----"
    go build -v ../
    cp -r ../conf .
    separator

    echo "----- docker login -----"
    docker login --username admin --password Harbor12345 $HARBOR_ADDR
    echo

    echo "----- prepare docker image and tags -----"
    docker pull hello-world
    for i in $(seq 1 5)
    do
        docker tag hello-world:latest $HARBOR_ADDR/$PRJ_NAME/hello-world:v"$i"
    done
    separator

    echo "----- harbor-go-client login -----"
    ./harbor-go-client login -u admin -p Harbor12345 && echo -e "${SUCCESS} username: admin\n${SUCCESS} Save .cookie.yaml" || echo "${ERROR}"
    separator

    echo "----- whoami -----"
    ./harbor-go-client whoami && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- prj_create (--public=1) -----"
    ./harbor-go-client prj_create --project_name=$PRJ_NAME --public=1 && echo -e "${SUCCESS} project_name: $PRJ_NAME\n${SUCCESS} public" || echo "${ERROR}"
    separator

    echo "----- push repo and tags under $PRJ_NAME project -----"
    for i in $(seq 1 5)
    do
        docker push $HARBOR_ADDR/$PRJ_NAME/hello-world:v"$i"
    done
    separator
}

cleanup() {

    echo "----- harbor-go-client logout -----"
    ./harbor-go-client logout && echo -e "${SUCCESS} Delete .cookie.yaml" || echo "${ERROR}"
    separator

    echo "----- delete docker image and tags created for test -----"
	docker rmi -f "$(docker images hello-world -q)"
    separator

    echo "----- docker logout -----"
    docker logout $HARBOR_ADDR
    separator

    echo "----- remove harbor-go-client and conf/ -----"
    rm harbor-go-client
    rm -r conf/
    separator
}

full_api_tests() {

    echo
    echo "####################################"
    echo "##        Full API Tests          ##"
    echo "####################################"
    echo

    prepare

    echo "----- prjs_list (filter by --name=$PRJ_NAME) -----"
    ./harbor-go-client prjs_list --name=$PRJ_NAME && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    PRJ_ID=$(./harbor-go-client prjs_list --name=$PRJ_NAME | grep "project_id" | awk '{print $2}' | sed -r 's/,//g')

    echo "----- prj_get (--project_id=$PRJ_ID) -----"
    ./harbor-go-client prj_get --project_id="$PRJ_ID" && echo -e "${SUCCESS} project_id: $PRJ_ID" || echo "${ERROR}"
    separator

    echo "----- repos_list (under project $PRJ_ID, filter by $PRJ_NAME) -----"
    ./harbor-go-client repos_list --project_id="$PRJ_ID" --repo_name=$PRJ_NAME && echo -e "${SUCCESS} project_id: $PRJ_ID\n${SUCCESS} repo_name (filter): $PRJ_NAME" || echo "${ERROR}"
    separator

    echo "----- tags_list -----"
    ./harbor-go-client tags_list --repo_name=$PRJ_NAME/hello-world && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    echo "----- tag_get -----"
    for i in $(seq 1 5)
    do
        ./harbor-go-client tag_get --repo_name="$PRJ_NAME"/hello-world --tag=v"$i" && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world\n${SUCCESS} tag: v$i" || echo "${ERROR}"
    done
    separator

    echo "----- search -----"
	./harbor-go-client search --query=$PRJ_NAME && echo -e "${SUCCESS} query: $PRJ_NAME" || echo "${ERROR}"
    separator

    echo "----- tag_del -----"
    for i in $(seq 1 5)
    do
        ./harbor-go-client tag_del --repo_name=$PRJ_NAME/hello-world --tag=v"$i" && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world\n${SUCCESS} tag: v$i" || echo "${ERROR}"
    done
    separator

    echo "----- repo_del -----"
    echo "----- (NOTE: if all tags with a repo are deleted, the repo will be deleted altogether. You will get 404 NOT FOUND here) -----"
    ./harbor-go-client repo_del --repo_name=$PRJ_NAME/hello-world && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    echo "----- prj_del -----"
    ./harbor-go-client prj_del --project_id="$PRJ_ID" && echo -e "${SUCCESS} project_id: $PRJ_ID" || echo "${ERROR}"
    separator

    # special one
    echo "----- repos_top -----"
    ./harbor-go-client repos_top --count=3 && echo -e "${SUCCESS} count: 3" || echo "${ERROR}"
    separator

    # ----

    echo "----- targets_create -----"
    ./harbor-go-client targets_create --endpoint=11.11.11.100 --name=e100 -u admin -p Harbor12345 --insecure && echo -e "${SUCCESS} endpoint: 11.11.11.100\n${SUCCESS} name: e100" || echo "${ERROR}"
    separator

    echo "----- targets_list -----"
    ./harbor-go-client targets_list --name=100 && echo -e "${SUCCESS} name (filter): 100" || echo -e "${ERROR}"
    separator

    TARGET_ID=$(./harbor-go-client targets_list --name=100 | grep "id" | awk '{print $2}' | sed 's/,//g')

    echo "----- targets_update_by_tid -----"
    ./harbor-go-client targets_update_by_tid --id="$TARGET_ID" --endpoint=11.11.11.100 --name="from e100 to E100" -u admin -p Harbor12345 --insecure && echo -e "${SUCCESS} id: $TARGET_ID\n${SUCCESS} name: from e100 to E100" || echo "${ERROR}"
    separator

    echo "----- targets_get_by_tid -----"
    ./harbor-go-client targets_get_by_tid --id="$TARGET_ID" && echo -e "${SUCCESS} id: $TARGET_ID" || echo -e "${ERROR}"
    separator

    echo "----- targets_policies_by_tid -----"
    ./harbor-go-client targets_policies_by_tid --id="$TARGET_ID" && echo -e "${SUCCESS} id: $TARGET_ID" || echo -e "${ERROR}"
    separator

    echo "----- targets_ping (Not working here, just show how to use) -----"
    ./harbor-go-client targets_ping --endpoint=11.11.11.100 -u admin -p Harbor12345 --insecure && echo -e "${SUCCESS} endpoint: 11.11.11.100" || echo "${ERROR}"
    separator

    echo "----- targets_ping_by_tid (Not working here, just show how to use) -----"
    ./harbor-go-client targets_ping_by_tid --id="$TARGET_ID" && echo -e "${SUCCESS} id: $TARGET_ID" || echo "${ERROR}"
    separator

    echo "----- targets_delete_by_tid -----"
    ./harbor-go-client targets_delete_by_tid --id="$TARGET_ID" && echo -e "${SUCCESS} id: $TARGET_ID" || echo "${ERROR}"
    separator

    # ----

    echo "----- configurations_create (read system configuration from conf/config.yaml) -----"
    ./harbor-go-client configurations_create && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- configurations_get -----"
    ./harbor-go-client configurations_get && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- configurations_reset (reset to default setting) -----"
    ./harbor-go-client configurations_reset && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    # ----

    echo "----- sysinfo_general -----"
    ./harbor-go-client sysinfo_general && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- sysinfo_volumes -----"
    ./harbor-go-client sysinfo_volumes && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- sysinfo_rootcert (You will get 404 NOT FOUND here) -----"
    ./harbor-go-client sysinfo_rootcert && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    # ----

    echo "----- logs -----"
	./harbor-go-client logs && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- statistics -----"
	./harbor-go-client statistics && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    cleanup
}


repositories_test() {

    echo
    echo "===================================="
    echo "##     Repository API Tests       ##"
    echo "===================================="
    echo

    prepare

    echo "----- repo_del -----"
    ./harbor-go-client repo_del --repo_name=$PRJ_NAME/hello-world && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    echo "----- repo_del (one more time, you will get 404 NOT FOUND) -----"
    ./harbor-go-client repo_del --repo_name=$PRJ_NAME/hello-world && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    echo "----- repos_top -----"
    ./harbor-go-client repos_top --count=3 && echo -e "${SUCCESS} count: 3" || echo "${ERROR}"
    separator

    cleanup
}

tags_test() {

    echo
    echo "=================================="
    echo "##       Tags API Tests         ##"
    echo "=================================="
    echo

    prepare

    echo "----- tags_list -----"
    ./harbor-go-client tags_list --repo_name=$PRJ_NAME/hello-world && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    # get
    echo "----- tag_get -----"
    for i in $(seq 1 5)
    do
        ./harbor-go-client tag_get --repo_name=$PRJ_NAME/hello-world --tag=v"$i" && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world\n${SUCCESS} tag: v$i" || echo "${ERROR}"
    done
    separator

    # del
    echo "----- tag_del -----"
    for i in $(seq 1 5)
    do
        ./harbor-go-client tag_del --repo_name=$PRJ_NAME/hello-world --tag=v"$i" && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world\n${SUCCESS} tag: v$i" || echo "${ERROR}"
    done
    separator

    # get again
    echo "----- tag_get (You will get 404 NOT FOUND here) -----"
    for i in $(seq 1 5)
    do
        ./harbor-go-client tag_get --repo_name=$PRJ_NAME/hello-world --tag=v"$i" && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world\n${SUCCESS} tag: v$i" || echo "${ERROR}"
    done
    separator

    cleanup
}

projects_test() {

    echo
    echo "=================================="
    echo "##      Projects API Tests      ##"
    echo "=================================="
    echo

	prepare

    echo "----- prj_create (--public=1) -----"
    ./harbor-go-client prj_create --project_name=${PRJ_NAME}-public --public=1 && echo -e "${SUCCESS} project_name: ${PRJ_NAME}-public\n${SUCCESS} public" || echo "${ERROR}"
    separator

    echo "----- prj_create (--public=0) -----"
    ./harbor-go-client prj_create --project_name=${PRJ_NAME}-private --public=0 && echo -e "${SUCCESS} project_name: ${PRJ_NAME}-private\n${SUCCESS} private" || echo "${ERROR}"
    separator

    echo "----- prjs_list (--public=1) -----"
    ./harbor-go-client prjs_list --name=${PRJ_NAME}-public --public=1 && echo -e "${SUCCESS} name (filter): ${PRJ_NAME}-public\n${SUCCESS} public" || echo "${ERROR}"
    separator

    echo "----- prjs_list (--public=0) -----"
    ./harbor-go-client prjs_list --name=${PRJ_NAME}-private --public=0 && echo -e "${SUCCESS} name (filter): ${PRJ_NAME}-private\n${SUCCESS} private" || echo "${ERROR}"
    separator

    echo "----- prjs_list (--public=) -----"
    ./harbor-go-client prjs_list --name=${PRJ_NAME} && echo -e "${SUCCESS} name (filter): ${PRJ_NAME}\n${SUCCESS} public + private" || echo "${ERROR}"
    separator

    PUB_ID=$(./harbor-go-client prjs_list --name=${PRJ_NAME}-public --public=1 | grep "project_id" | awk '{print $2}' | sed 's/,//g')
    PRI_ID=$(./harbor-go-client prjs_list --name=${PRJ_NAME}-private --public=0 | grep "project_id" | awk '{print $2}' | sed 's/,//g')

    echo "----- prj_get (--project_id=$PUB_ID, before delete) -----"
    ./harbor-go-client prj_get --project_id="$PUB_ID" && echo -e "${SUCCESS} project_id: $PUB_ID" || echo "${ERROR}"
    separator

    echo "----- prj_get (--project_id=$PRI_ID, before delete) -----"
    ./harbor-go-client prj_get --project_id="$PRI_ID" && echo -e "${SUCCESS} project_id: $PRI_ID" || echo "${ERROR}"
    separator

    echo "----- prj_del (--project_id=$PUB_ID, public) -----"
    ./harbor-go-client prj_del --project_id="$PUB_ID" && echo -e "${SUCCESS} project_id: $PUB_ID\n${SUCCESS} public" || echo "${ERROR}"
    separator

    echo "----- prj_del (--project_id=$PRI_ID, private) -----"
    ./harbor-go-client prj_del --project_id="$PRI_ID" && echo -e "${SUCCESS} project_id: $PRI_ID\n${SUCCESS} private" || echo "${ERROR}"
    separator

    echo "----- prj_get (--project_id=$PUB_ID, after delete) -----"
    ./harbor-go-client prj_get --project_id="$PUB_ID" && echo -e "${SUCCESS} project_id: $PUB_ID" || echo "${ERROR}"
    separator

    echo "----- prj_get (--project_id=$PRI_ID, after delete) -----"
    ./harbor-go-client prj_get --project_id="$PRI_ID" && echo -e "${SUCCESS} project_id: $PRI_ID" || echo "${ERROR}"
    separator

    PRJ_ID=$(./harbor-go-client prjs_list --name=$PRJ_NAME | grep "project_id" | awk '{print $2}' | sed -r 's/,//g')

    echo "----- prj_del (project contains repositories, cann't be deleled, will get 412 Precondition Failed) -----"
    ./harbor-go-client prj_del --project_id="$PRJ_ID" && echo -e "${SUCCESS} project_id: $PRJ_ID" || echo "${ERROR}"
    separator

    #echo "----- prj_del (project contains targets, cann't be deleled, will get 412 Precondition Failed) -----"

    echo "----- repo_del (delete the repo under project $PRJ_NAME)-----"
    ./harbor-go-client repo_del --repo_name=$PRJ_NAME/hello-world && echo -e "${SUCCESS} repo_name: $PRJ_NAME/hello-world" || echo "${ERROR}"
    separator

    echo "----- prj_del (project contains no repositories, can be deleled this time) -----"
    ./harbor-go-client prj_del --project_id="$PRJ_ID" && echo -e "${SUCCESS} project_id: $PRJ_ID" || echo "${ERROR}"
    separator

    cleanup
}

users_test() {

    echo "----- prepare harbor-go-client and conf/ for tesing -----"
    go build -v ../
    cp -r ../conf .
    separator

    echo "----- harbor-go-client login -----"
    ./harbor-go-client login -u admin -p Harbor12345 && echo -e "${SUCCESS} username: admin\n${SUCCESS} Save .cookie.yaml" || echo "${ERROR}"
    separator

    echo "----- whoami -----"
    ./harbor-go-client whoami && echo -e "${SUCCESS}" || echo "${ERROR}"
    separator

    echo "----- logout -----"
    ./harbor-go-client logout && echo -e "${SUCCESS} Delete .cookie.yaml" || echo "${ERROR}"
    separator

    echo "----- remove harbor-go-client and conf/ -----"
    rm harbor-go-client
    rm -r conf/
    separator
}

retention_policy_test() {

    echo
    echo "===================================="
    echo "##    Rentention Policy Tests     ##"
    echo "===================================="
    echo

    ./rp_repos_simulation.sh 10 10 10
    separator
}

scenario_simulation_tests() {

    echo
    echo "#############################################"
    echo "##        Scenario Simulation Tests        ##"
    echo "#############################################"
    echo

    case "$1" in
        1*) repositories_test;;
        2*) tags_test;;
        3*) projects_test;;
        4*) users_test;;
        5*) retention_policy_test;;
        9*)
			repositories_test
			tags_test
			projects_test
			users_test
			retention_policy_test
		;;
    esac

}

# ----------------

echo
echo " __ __   ____  ____   ____    ___   ____          ____   ___            __  _      ____    ___  ____   ______"
echo " |  |  | /    ||    \ |    \  /   \ |    \        /    | /   \          /  ]| |    |    |  /  _]|    \ |      |"
echo " |  |  ||  o  ||  D  )|  o  )|     ||  D  )_____ |   __||     | _____  /  / | |     |  |  /  [_ |  _  ||      |"
echo " |  _  ||     ||    / |     ||  O  ||    /|     ||  |  ||  O  ||     |/  /  | |___  |  | |    _]|  |  ||_|  |_|"
echo " |  |  ||  _  ||    \ |  O  ||     ||    \|_____||  |_ ||     ||_____/   \_ |     | |  | |   [_ |  |  |  |  |"
echo " |  |  ||  |  ||  .  \|     ||     ||  .  \      |     ||     |      \     ||     | |  | |     ||  |  |  |  |"
echo " |__|__||__|__||__|\_||_____| \___/ |__|\_|      |___,_| \___/        \____||_____||____||_____||__|__|  |__|"
echo

echo "You can do some tests by choosing the following options: "
echo "1. Run full API tests one by one (automatically)."
echo "2. Run Scenario Simulation tests on you choose."

echo
read -p "Please select which one do you prefer: [1] " OPTION
if [ -z "$OPTION" ] ; then
    echo "Selecting default: 1"
    OPTION=1
elif [ $OPTION -eq 1 ] ; then
	echo "You select: $OPTION"
elif [ $OPTION -eq 2 ] ; then
	echo "You select: $OPTION"
	echo
	echo "Current support Scenarios:"
	echo "1. repositories operation scenario"
	echo "2. tags operation scenario"
	echo "3. prjects operation scenario"
	echo "4. users operation scenario"
	echo "5. retention policy analysis scenario"
	echo "9. all scenarios"
	echo
	read -p "Please select which scenario do you prefer: [1] " SCENARIO
    if [ -z "$SCENARIO" ] ; then
        SCENARIO=1
    fi
	echo "You select: $SCENARIO"
else
    echo "Wrong number, Select default: 1"
    OPTION=1
fi

case "$OPTION" in
    1*) full_api_tests
	;;
    2*) scenario_simulation_tests $SCENARIO
	;;
esac

exit 0
