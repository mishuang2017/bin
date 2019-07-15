#!/bin/bash


#========================================================================================
# fHeader
# -------
#========================================================================================
fHeader(){
    header=$1
    echo  "******************************************************************"
    echo -n "                      "
    echo -e ${header}
    echo  "******************************************************************"
}
#========================================================================================
# fLine
# -------
#========================================================================================
fLine(){
    echo "======================================================================"
}



#========================================================================================
# fExit
# -----
# Called when exiting the script, in order to go back to the original Dir
#========================================================================================
fExit(){
    exit 1
}

#========================================================================================
# fCheckIsOperationOK
# -------------------
# If the last command failed exit the script
#
# Input :
# $1 = the last operation that was performed (in use for user message)
#========================================================================================
fCheckIsOperationOK(){
    local RES=$?
    local OPER=$1
    local __NoExit=$2
    if [ $RES == 0 ]; then
        echo -e "${COLOR_BLUE}$(hostname):${NC} ${GREEN} ${OPER} done${NC}"
        res="OK"
    else
        echo -e "${COLOR_BLUE}$(hostname):${NC} ${RED} ${OPER} failed${NC}"
        res="FAIL"
        if [ "$__NoExit" != "do_not_exit" ]; then
            fExit
        fi
    fi
}

#========================================================================================
# fCheckIfVarIsEmpty
# ------------------
#========================================================================================
fCheckIfVarIsEmpty(){
    local var=$1
    local description=$2
    if [ -z "$var" ]; then
        echo -e "${RED}${description} has no value${NC}"
        fExit
    fi
}

#========================================================================================
# fDoCommand
# ------------------
#========================================================================================
fDoCommand(){
   local __command=$1
   echo "--------------------------------------------------------------------"
   ${__command}
   #fCheckIsOperationOK "[${__command}]" do_not_exit
   fCheckIsOperationOK "[${__command}]"
   echo "-----------------------------------------------------------------***"
}

#========================================================================================
# fDoCommandInVM
# ------------------
#========================================================================================
fDoCommandInVM(){
   local __vm=$1
   local __command=$2
   echo "--------------------------------------------------------------------"
   ssh -l root $__vm $__command
   fCheckIsOperationOK "[ssh -l root $__vm $__command]"
   echo "-----------------------------------------------------------------***"
}

#========================================================================================
# fDoFuncInRemote
# ------------------
#========================================================================================
fDoFuncInRemote(){
   local __user="root"
   local __host=$1
   local __funcName=$2
   local __CommandWithFunc=$3
   echo "--------------------------------------------------------------------"
  # echo "__host=$__host __funcName=$__funcName __CommandWithFunc=$__CommandWithFunc"
   ssh ${__user}@${__host} "$(typeset -f ${__funcName}); ${__CommandWithFunc}"
   fCheckIsOperationOK "[ssh ${__user}@${__host}  ${__CommandWithFunc}]" do_not_exit
   echo "-----------------------------------------------------------------***"
}

#========================================================================================
# fDoCommandInVMAdi
# ------------------
#========================================================================================
fDoCommandInVMAdi(){
   local __vm=$1
   local __command=$2
   echo "--------------------------------------------------------------------"
   ssh -l adin $__vm $__command
   fCheckIsOperationOK "[ssh -l adin $__vm $__command]"
   echo "-----------------------------------------------------------------***"
}

#========================================================================================
# fDoCommandIfNotEmpty
# ------------------
#========================================================================================
fDoCommandIfNotEmpty(){
   local __command=$1
   local __var=$2
   if [ ! -z "$__var" ]; then
        echo "--------------------------------------------------------------------"
        ${__command}
        fCheckIsOperationOK "[${__command}]"
        echo "-----------------------------------------------------------------***"
   fi
}

#========================================================================================
# fEchoIfNotEmpty
# ------------------
#========================================================================================
fEchoIfNotEmpty(){
    local __var=$2
    local __line=$1
    if [ ! -z "$__var" ]; then
        echo -e -n "${__line}"
    fi
}

#========================================================================================
# fShowMenu
# ---------
# pring the array values to user as menu
# exit the script if array is empty
# recieve user choice
# return value choosen by user
# Input : array
# Output: uChoice
#========================================================================================
fshowMenu(){
    local array=("$@")
    local i=0
    local flag=0
    local arraySize=${#array[@]}

    if [ $arraySize == 0 ]; then
        echo "There are no options"
        fExit
    fi

    if [ $arraySize == 1 ]; then
        echo "${bold}There is only 1 option: ${array[0]}${normal}"
        uIndex=0
        flag=1
    fi

    while [ $flag == 0 ]
    do
        i=0
        for val in ${array[@]}; do
            echo -e "$COLOR_LIGHT_CYAN$i) ${val}${normal}"
            let i+=1
        done
        echo -n "${bold}:${normal}"
        read uIndex

        #check if index is valid
        if [ "$uIndex" -ge  0 ]; then
            if [ "$uIndex" -lt  "$i" ]; then
                #uIndex is valid
                flag=1
            else
                echo "Not a valid option"
            fi
        else
            echo "Not a valid option"
        fi
    done
    uChoice=${array[$uIndex]}
}
