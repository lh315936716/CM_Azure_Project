namespace eval HPC::Example {

set start_script_path [ file dirname [ info script ] ]

# Demonstrates how to use files relative to this script. Also works "inside"
# mod file. This should be your preferred way to do this.
# source [file join $start_script_path test.tcl]

#
# CarMaker 8.0.1 - HPC_Example.tcl
#
# This file is a basic example how to integrate an own HPC execution mode in
# CarMaker's TestManager. Several hook points are provided in this file where
# customized actions can be performed. 
# When running a TestSeries in any HPC mode TestManager automatically creates
# a so called Startup file for each TestRun or variation. This Startup file
# contains all necessary information for the actual simulation. 
#
# In the available example an additional tasks file is created whose content is
# a list of command line calls to the CarMaker application (simulation program).
# Each simulation run is represented by one line in this file.
#
# In a real HPC environment this file may be parsed by subsequent scripts to
# create individual tasks for a scheduler. This scheduler would then distribute
# those tasks to multiple compute nodes where the actual simulations would be
# performed. To succeed all compute nodes need access to the same common project
# directory. If direct access cannot be guaranteed the project directory must
# be made available in a different way for example by copying its content to all
# compute nodes before simulation start and transferring the necessary result
# files back after simulation end.
#
# In the avilable example the individual tasks are just executed on the local
# host to present an easy example which is ready-to-run. Hence all tasks are 
# executed on one host sharing the project directory is not needed here.
#
# After the tasks have been submitted TestManager regularly checks for available
# SimEnd files which are written by the application after simulation end. As
# soon as an EndFile is encountered it is processed and the simulation result
# state in TestManager gets updated.
# 


## Variables ###################################################################


variable ExampleData
array set ExampleData {
    MaxTasks	100
    FastMode    1
	KeepTmpFiles 1
}


variable TasksFile
array set TasksFile {
    Name	""
    Descriptor	""
}


## Hook functions ##############################################################


## ::HPC::Example::Init
## --------------------
## HOOK
## @brief This hook gets called when the HPC mode is selected in TestManager.
## Can be used to initialize variables and settings.
##
proc Init {} {
	Log "Init..."
    # Insert your code here...
    
    # Example code: Initialize some parameters...
    variable ExampleData
    set ExampleData(MaxTasks) 20
    set ExampleData(FastMode) 1
	set ExampleData(KeepTmpFiles) 0
	

    return
}


## ::HPC::Example::ReadParamFile
## -----------------------------
## HOOK
## @brief This hook gets called after "Init", specifically to read from the
## HPCParameters file in Data/Config. This can be used to set Information like
## secrets, passwords or IDs specific to your platform.
##
proc ReadParamFile {IFile} {

    # Insert your code here...

    # Example code: Just read in some parameters...
    variable ExampleData
    $IFile getstr "Example.MaxTasks" ExampleData(MaxTasks) 100
    $IFile getstr "Example.FastMode" ExampleData(FastMode) 1
	$IFile getstr "Example.KeepTmpFiles" ExampleData(KeepTmpFiles) 1
	

    return
}


## ::HPC::Example::InitSim
## -----------------------
## HOOK
## @brief This Hook gets called when the user clicks the "Start" button in the 
## TestManager GUI. Can be used for platform-specific initialization steps
## before simulation start such as moving data to compute nodes, creating the
## job infrastructure or initializing the scheduler.
## Returning a non-empty result aborts the TestSeries start.
##
proc InitSim {} {

    # Insert your code here...

    # Example code: Create a tasks file which will hold all tasks
    OpenTasksFile 0

    # Copy some values to CarMaker's internal settings
    variable ExampleData
    set ::HPC::HPC(MaxTasks) $ExampleData(MaxTasks)
    set ::HIL(HPC.Fast) $ExampleData(FastMode)
	set ::HPC::HPC(KeepTmpFiles) $ExampleData(KeepTmpFiles)

    return
}


## ::HPC::Example::StartSim
## ------------------------
## HOOK
## @brief This hook gets called once for every TestRun or variation of the 
## TestSeries. Can be used to process every task individually if necessary.
## Additionally the tasks need to be set to "Started" here so the TestManager
## will continue.
## 
proc StartSim {args} {
    
    # Insert your code here...
    
    # Example code: Write the current task to the tasks file. The internal
    # variable ::HPC::Tasks is a dictionary which holds data for each task:
    # Exe = executable path with options, Startup = startup filename, SimEnd =
    # simend filename, Started = Flag whether the task has been started or not
    set taskNo [HPC::GetTaskNo]
    WriteToTasksFile $taskNo [dict getstr $::HPC::Tasks $taskNo Exe]
	
    dict set ::HPC::Tasks $taskNo Started 1

    return
}


## ::HPC::Azure::CollectResults
## ----------------------------
## HOOK
## @brief This hook gets called  when reaching a barrier or the end of the
## TestSeries. It gets also called when the maximum number of schedulable
## tasks is succeeded. Can be used to forward the tasks to the platform you
## are using and copy the startup files the TestManager created in Data/Config
## to your shared file system. The Startup files need to be available on
## the executing compute nodes. Once they are, CarMaker can be started
## from the command line with the Startup Files as a parameter, f.e.:
## 	CarMaker.linux64 Data/Config/Startup_0
##.
proc CollectResults {} {
    
    # Insert your code here...
    
    # Example: Close the current task file and execute the tasks listed in it
    variable TasksFile

    CloseTasksFile
    ExecuteTasks $TasksFile(Name)
    
    # The internal function ::HPC::CheckForResults starts a loop and polls
    # for incoming results
    after cancel ::HPC::CheckForResults
    after idle ::HPC::CheckForResults

    return
}


## ::HPC::Example::CheckForResults
## -------------------------------
## HOOK
## @brief This hook gets called periodically for as long as the TestSeries is
## active to check for the result of the TestRuns in the form of "SimEnd"-Files
## in the "SimOutput folder of your local project directory. These need to be
## collected from the compute nodes that executed the TestRuns.
##
proc CheckForResults {} {
	variable ExampleData
    # Insert your code here...
	
    return
}


## ::HPC::Example::ShowSettings
## ----------------------------
## HOOK
## @brief This hook gets called when pressing the "Settings" button in
## TestManager while this Example HPC mode is selected.
##



# Helper functions #############################################################


## ::HPC::Example::OpenTasksFile
## -----------------------------
## @brief Open a file for writing and return its name.
##
proc OpenTasksFile {taskNo} {
    variable TasksFile

    # Tasks file already open?
    if {$TasksFile(Descriptor) ne ""} return

    set TasksFile(Name) [DataDir Config tasks_$taskNo.txt]
    set TasksFile(Descriptor) [open $TasksFile(Name) "w"]

    return $TasksFile(Name)
}


## ::HPC::Example::CloseTasksFile
## ------------------------------
## @brief Close the current file.
##
proc CloseTasksFile {} {
    variable TasksFile

    # Tasks file already closed?
    if {$TasksFile(Descriptor) eq ""} return
    
    close $TasksFile(Descriptor)
    set TasksFile(Descriptor) ""

    return $TasksFile(Name)
}


## ::HPC::Example::WriteToTasksFile
## --------------------------------
## @brief Add the given line to the current file.
##
proc WriteToTasksFile {taskNo line} {
    variable TasksFile

    # Tasks file not open?
    if {$TasksFile(Descriptor) eq ""} {
	OpenTasksFile $taskNo
    }
    puts $TasksFile(Descriptor) $line

    return
}


## ::HPC::Example::ExecuteTasks
## ----------------------------
## @brief Example function to execute tasks on the local host. In a real HPC
## environment the tasks would be executed on the compute nodes.
##
proc ExecuteTasks {taskFile} {
    # Read the tasks file
	cd Data/Script
	Log [pwd]
    # Execute all tasks on the local host
    
	if {[catch {exec bash Azure_Batch.sh & } res]} {
	    Log "Executing command failed:  $res"
	}
    cd ../..
	
}


} ;# end of namespace


# Add execution mode to TestManager's execution mode list

TestMgr::AddExecMode "Azure_HPC" HPC_Example
