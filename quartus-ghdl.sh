#!/bin/bash

GHDL="/usr/local/bin/ghdl"
VHDL_FILES="(*.vhd$)|(*.vhdl$)|(*.vht$)"

simulation_clean() {
    MSG_ERROR="\e[0;240;101m"
    MSG_SUCCESS="\e[0;240;92m"
    MSG_INFO="\e[0;46;97m"
    MSG_RED="\e[0;31m"
    MSG_GREEN="\e[0;32m"
    MSG_BLUE="\e[0;36m"
    MSG_RESET="\e[0m"
    echo -e "${MSG_INFO}====================="
    echo -e "=${MSG_GREEN} Start cleaning... ${MSG_INFO}="
    echo -e "=====================${MSG_RESET}"
    if [[ ! $(ls *.qpf) ]]; then
        echo -e "${MSG_RED}-> ${MSG_RESET}run from a quartus project."
        return
    fi
    PROJECT_DIR="${PWD}"
    if [[ ! -d "simulation/ghdl" ]]; then
        echo -e "${MSG_BLUE}no simulation created, no cleaning todo.${MSG_RESET}\n"
        return
    fi
    for file in ${PROJECT_DIR}/simulation/ghdl/* ; do
        if [ -f "${file}" ]; then
            if [[ ! $file == *.vht ]]; then
                if [[ ! $file == *.gtkw ]]; then
                    rm $file
                    echo -e "${MSG_RED}removed: ${MSG_RESET}$file"
                fi
            fi
        fi
    done
    echo -e "${MSG_BLUE}simulation folder cleaned.${MSG_RESET}\n"
    cd $PROJECT_DIR
    return
}

simulation_compile() {
    MSG_ERROR="\e[0;43;31m"
    MSG_SUCCESS="\e[40;47;5;92m"
    MSG_INFO="\e[0;46;97m"
    MSG_RED="\e[0;31m"
    MSG_GREEN="\e[0;32m"
    MSG_BLUE="\e[0;36m"
    MSG_RESET="\e[0m"
    if [[ ! $(ls *.qpf) ]]; then
        echo -e "${MSG_RED}-> ${MSG_RESET}run from a quartus project."
        return
    fi
    PROJECT_DIR="${PWD}"
    simulation_clean

    if [[ ! -d "simulation" ]]; then
        mkdir simulation
        echo -e "${MSG_GREEN}created: ${MSG_RESET}directory ./simulation"
    fi
    if [[ ! -d "simulation/ghdl" ]]; then
        mkdir simulation/ghdl
        echo -e "${MSG_GREEN}created: ${MSG_RESET}directory ./simulation/ghdl"
    fi
    SIMULATION_DIR="${PROJECT_DIR}/simulation/ghdl"
    cd $SIMULATION_DIR

    echo -e "${MSG_INFO}======================="
    echo -e "=${MSG_GREEN} Check project files ${MSG_INFO}="
    echo -e "=======================${MSG_RESET}"

    for file in $(ls ${PROJECT_DIR} |/bin/grep -E "${VHDL_FILES}"); do
        echo -e "${MSG_BLUE}checking project file:${MSG_RESET} ${file}"
        syntax_check=$(${GHDL} -s --std=08 ${PROJECT_DIR}/${file})
        if [[ $? != 0 ]]; then
            echo -e "${MSG_RED}error syntax :(${MSG_RESET}"
            cd $PROJECT_DIR
            return
        else
            echo -e "\t${MSG_GREEN}no syntax errors found.${MSG_RESET}"
        fi
        analyze_check=$(${GHDL} -a --std=08 "${PROJECT_DIR}/${file}")
        if [[ $? != 0 ]]; then
            echo -e "${MSG_RED}error in analyze :(${MSG_RESET}"
        else
            echo -e "\t${MSG_GREEN}analyze ok :D${MSG_RESET}\n"
        fi
    done

    echo -e "${MSG_INFO}==================================="
    echo -e "=${MSG_GREEN} Check testbench/simulator files ${MSG_INFO}="
    echo -e "===================================${MSG_RESET}" 
    declare -i tbamnt=0
    declare -a testbenches=()

    for file in $(ls ${SIMULATION_DIR} |/bin/grep -E "${VHDL_FILES}"); do
        tbamnt=$(($tbamnt+1))
        testbenches+=("${file}")
        echo -e "${MSG_BLUE}checking testbench file:${MSG_RESET} ${file}"
        if [[ $(${GHDL} -s --std=08 ${SIMULATION_DIR}/${file}) ]]; then
            echo -e "\t${MSG_RED}error syntax :(${MSG_RESET}"
        else
            echo -e "\t${MSG_GREEN}no syntax errors found.${MSG_RESET}"
        fi
        if [[ $(${GHDL} -a --std=08 "${SIMULATION_DIR}/${file}") ]]; then
            echo -e "\t${MSG_RED}error in analyze :(${MSG_RESET}"
        else
            echo -e "\t${MSG_GREEN}analyze ok :D${MSG_RESET}"
        fi
    done

    echo -e "\n${MSG_INFO}========================"
    echo -e "=${MSG_GREEN} Creating simultation ${MSG_INFO}="
    echo -e "========================${MSG_RESET}"
    if [ $tbamnt -eq 1 ]; then
        tb="${testbenches[0]%.*}"
        echo -e "${MSG_BLUE}found one testbench:${MSG_RESET} ${tb}"
        if [[ ! $($GHDL -e --std=08 "${tb}") ]]; then
            echo -e "\t${MSG_GREEN}compiled testbench${MSG_RESET}"
        else
            echo -e "\t${MSG_RED}could not make compile testbench ${MSG_RESET}"
            return
        fi
        $GHDL -r $tb --vcd="${tb}.vcd" | awk -F'/' '{print $NF}' > ${tb}.log
        echo -e "${MSG_BLUE}created simulation log: ${MSG_RESET}./simulation/ghdl/$tb.log"
        echo -e "${MSG_BLUE}created vcd file      : ${MSG_RESET}./simulation/ghdl/$tb.vcd"
    elif [ $tbamnt -eq 0 ]; then
        echo -e "${MSG_RED}no testbenches found..${MSG_RESET}"
        return
    else 
        tb="${testbenches[0]%.*}"
        echo -e "${MSG_BLUE}found several testbenches${MSG_RESET}"
        for test in $testbenches; do
            if [[ ! $($GHDL -e --std=08 "${test}") ]]; then
                echo -e "\t${MSG_GREEN}compiled testbench${MSG_RESET} ${test}"
            else
                echo -e "\t${MSG_RED}could not make compile testbench ${MSG_RESET}${test}"
                continue
            fi
            $GHDL -r $test --vcd="${test}.vcd" | awk -F'/' '{print $NF}' > ${test}.log
            echo -e "${MSG_BLUE}created simulation log: ${MSG_RESET}./simulation/ghdl/$test.log"
            echo -e "${MSG_BLUE}created vcd file      : ${MSG_RESET}./simulation/ghdl/$test.vcd"
        done
        echo -e "${MSG_BLUE}autoselected the first one found.${MSG_RESET}"
    fi

    cd ${PROJECT_DIR}
    return
}

simulation_just_run() {
    MSG_ERROR="\e[0;43;31m"
    MSG_SUCCESS="\e[40;47;5;92m"
    MSG_INFO="\e[0;46;97m"
    MSG_RED="\e[0;31m"
    MSG_GREEN="\e[0;32m"
    MSG_BLUE="\e[0;36m"
    MSG_RESET="\e[0m"
    PROJECT_DIR=$PWD
    tb=$1
    if [ ! -f "simulation/ghdl/$tb.vcd" ]; then
        echo -e "${MSG_RED}Simulation not found${MSG_RESET}"
        return
    fi
    cd simulation/ghdl
    echo -e "\n${MSG_INFO}======================="
    echo -e "=${MSG_GREEN} Starting simulation ${MSG_INFO}="
    echo -e "=======================${MSG_RESET}"
    if [ -f "$tb.log" ]; then
        echo -e "${MSG_BLUE} Simulation log: ${MSG_RESET}"
        cat $tb.log
        echo -e "${MSG_BLUE}= [ END LOG ] =${MSG_RESET}"
    fi

    ( nohup gtkwave ${tb}.vcd -a ${tb}.gtkw & ) > /dev/null 2>&1
    echo -e "${MSG_GREEN}gtkwave started.${MSG_RESET}"
    cd $PROJECT_DIR
}

simulation_run() {
    tb=$1
    simulation_compile
    simulation_just_run $tb
}
