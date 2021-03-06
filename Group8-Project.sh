
#--------------------------------------------------------
##        Web Search Engines - Homework 1 - Group 8
##
##      @desc: This script builds the crawls,mines,index,
##             starts server and outputs their evaluations
##             for all the queries in data/queries.tsv
##      @author: Sanchit Mehta<sanchit.mehta@cs.nyu.edu>
#--------------------------------------------------------


#!/bin/sh

red='\033[0;31m'
green='\033[1;32m'
yellow='\033[01;33m'
bold='\033[1m'
blue='\033[0;34m'
NC='\033[0m' # No Color


#Creates TestOutput dir if it doesn't exist
mkdir -p TestOutputs
rm -r TestOutputs/* &> /dev/null



compile_code () {
    printf "\nCompiling Java Code\n"
    {
        javac src/edu/nyu/cs/cs2580/*.java
    } &> /dev/null
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        printf "\n\n${green}Java Build Successful${NC}\n\n"
    else
        printf "\n\n${red}Java Build Failed${NC}\n\n"
        exit 1
    fi
}


run_indexer () {
    printf "\nCreating search Index\n"
    {
        java -cp src edu.nyu.cs.cs2580.SearchEngine --mode=index --options=conf/engine.conf
    } &> /dev/null
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        printf "\n\n${green}Search Index Created${NC}\n\n"
    else
        printf "\n\n${red}Index Creation Failed${NC}\n\n"
        exit 1
    fi
}


start_server () {
    printf "\nStarting Java Search Engine Server\n"
    {
        ps aux | grep  25808 | awk '{print $2}' |xargs kill -9
        java -cp src -Xmx512m edu.nyu.cs.cs2580.SearchEngine --mode=serve --port=25808 --options=conf/engine.conf &
        #storing PID of the server process,to shut it down later
        echo $! > java_pid
    } &> /dev/null
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        #waiting until the server has started
        url=http://localhost:25808/
        printf "Loading Index "
        until curl --output /dev/null --silent "$url"; do
            printf '.'
            sleep 2
        done
        printf "\n\n${green}Server Started${NC}\n\n"
    else
        printf "\n\n${red}Initialising Server Encountered an error${NC}\n\n"
        exit 1
    fi
}



test () {
    printf "\nStarting Test Case Execution\n"

    run_query () {
        q=$1
        r=$2
        q="${q// /+}"
        if [[ ! -z $r ]]
        then
            curl "http://localhost:25808/search?query=$q&ranker=$r&format=text&num=10"
        fi
    }

    evaluate () {
        q=$1
        r=$2
        printf "$q\t"
        q="${q// /+}"
        n=10
        for i in $(seq 0 6)
        do
            if [[ ! -z $r ]]
            then
                #1000 Results for Precision at Recall Points
                if [[ $i == 3 ]]
                then
                    n="all"
                fi
                curl "http://localhost:25808/search?query=$q&ranker=$r&format=text&num=$n" | java -cp src edu.nyu.cs.cs2580.Evaluator data/labels.tsv $i | awk -F "\t" '{print $2}' | tr '\n' '\t'
                n=10
            fi
        done
        printf "\n\n"
    }

    filename="data/queries.tsv"

    while read -r line
    do
        query="$line"
        printf "\n\nQuery : ${blue}$query${NC}"

        printf "\nRunning QL Ranker"
        {
            run_query "$query" "ql"
        } >> TestOutputs/hw1.1-ql.tsv  2>&0

        printf "\nRunning Cosine Ranker"
        {
            run_query "$query" "cosine"
        } >> TestOutputs/hw1.1-vsm.tsv 2>&0

        printf "\nRunning Phrase Ranker"
        {
            run_query "$query" "phrase"
        } >> TestOutputs/hw1.1-phrase.tsv 2>&0

        printf "\nRunning Linear Ranker"
        {
            run_query "$query" "linear"
        } >> TestOutputs/hw1.2-linear.tsv 2>&0

        printf "\nRunning Numviews Ranker"
        {
            run_query "$query" "numviews"
        } >> TestOutputs/hw1.1-numviews.tsv 2>&0

        printf "\nEvaluating vsm ranker"
        {
            evaluate "$query" "cosine"
        } >> TestOutputs/hw1.3-vsm.tsv  2>&0

        printf "\nEvaluating ql ranker"
        {
            evaluate "$query" "ql"
        } >> TestOutputs/hw1.3-ql.tsv  2>&0

        printf "\nEvaluating numviews ranker"
        {
            evaluate "$query" "ql"
        } >> TestOutputs/hw1.3-numviews.tsv  2>&0

        printf "\nEvaluating phrase ranker"
        {
            evaluate "$query" "phrase"
        } >> TestOutputs/hw1.3-phrase.tsv  2>&0
    done < "$filename"
}



shut_server () {
    printf "\n\nShuting down Java Server\n"
    {
        value=`cat java_pid`
        kill $value
    } &> /dev/null
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        printf "\n\n${green}Server Stopped${NC}\n\n"
    else
        printf "\n\n${red}Error in shutting down the server${NC}\n\n"
        exit 1
    fi
    rm java_pid
}


usage () {
    printf "\n\nUsage: `basename $0` \n-- This is a utility script for server commands and test execution\n\nCommands: [-r] [-t] [-s] [--run] [--stop] [--test]\n\nwhere:\n-r\tcompiles code, sets up index and runs the java server\n-t\tcompiles code, starts server, indexes and generates the output cases\n-s\tstops the java server\n\n"
}


if [ "$1" == "" ]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
        -r | --run )    shift
                        printf "\n\n${bold}${yellow}CSGA-2580 - Group 8 - Server Runner${NC}\n\n"
                        compile_code
                        run_indexer
                        start_server
                        ;;
        -s | --stop )
                        printf "\n\n${bold}${yellow}CSGA-2580 - Group 8 - Stop Processor${NC}\n\n"
                        shut_server
                        ;;
        -t | --test )
                        printf "\n\n${bold}${yellow}CSGA-2580 - Group 8 - Test Output Files Generator${NC}\n\n"
                        compile_code
                        run_indexer
                        start_server
                        test
                        shut_server
                        printf "\nTest case execution ${green}completed!${NC} Output files generated in ${bold}./TestOutputs${NC}\n"
                        ;;
        -h | --help )
                        usage
                        exit
                        ;;
        * )
                        usage
                        exit 1
                        ;;
    esac
    shift
done

exit 0

