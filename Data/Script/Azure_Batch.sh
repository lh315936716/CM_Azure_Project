#!/bin/bash
############################################################
##  CarMaker - Version 10.0								  ##
##  Test Automation Toolkit								  ##
##	Author: Hao Li									      ##
##  Copyright (C)   IPG Automotive(Shanghai) Co.,Ltd      ##
##                  China        www.ipg-automotive.com   ##
############################################################

if [[ $1 = "--help" ]] || [[ $1 = "-h" ]]
#||[ ! -n "$1" ]
then
    echo "usage: hahaha]"
	echo "ipg)"
    exit 0
fi
CWD=$(pwd)
project_dir="$(dirname $(dirname $CWD))"
dir="$project_dir/Data/Config"

echo $dir

dateTime="`date "+%Y-%m-%d %H:%M:%S"`"
prefix="`date "+%H%M%S"`"
ts=.ts

startup=Startup_
jobname="job_$prefix"
echo $jobname
echo "uploading project folder"
az storage blob upload-batch  -d input -s /home/cm/CM_Projects/CM_Azure_Project --account-name csg100320016c67a921 --account-key 4RulN9BGhovHRjhysdGojuEMBS/CFFMROjgxAAHt9Kbwui0W27wkew5X+9dZomTKgoz+wk3/VNy2dxyf/tDaHA== > /dev/null 2>&1
echo "Project folder uploaded"
az batch job create --id $jobname --pool-id test
echo "Job $jobname created"
for file in $(ls $dir)
do
	if [[ $file =~ $ts ]];then
		echo "Found TestSeries file $file, ignored"
	elif [[ $file == Startup_* ]];then
		az batch task create --task-id "$file$prefix" --job-id $jobname --command-line "/bin/bash -c '/tmp/run.sh $file'"  &
		echo “task "$file$prefix" for "$file" has been submitted”
	fi
done
echo -e "submitted all tasks."
