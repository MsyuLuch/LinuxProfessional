#!/bin/bash

    pid_array=$(ls /proc | grep -E '^[0-9]+$' | sort -n)
    clock_ticks=$(getconf CLK_TCK)
    total_memory=$(awk '/MemTotal/ {print $2}' /proc/meminfo)

    printf "%-10s %-6s %-9s %-9s %8s %-4s %-18s\n" USER PID CPU_USAGE MEMORY_USAGE RSS STATE COMMAND

    for pid in $pid_array
    do
        if [ -r /proc/"$pid"/stat ]
        then
            stat_array=( $(sed -E 's/(\([^\s)]+)\s([^)]+\))/\1_\2/g' /proc/"$pid"/stat) )
            uptime_array=( $(cat /proc/uptime) )
            statm_array=( $(cat /proc/"$pid"/statm) )
            comm=( $(grep -Po '^[^\s\/]+' /proc/"$pid"/comm) )
            user_id=$( grep -Po '(?<=Uid:\s)(\d+)' /proc/"$pid"/status )
            rss=$(cat /proc/"$pid"/status | awk '/VmRSS/{print $2}')
            if [ -z "$rss" ];
               then
               rss=0
            fi

            user=$( id -nu "$user_id" )
            uptime=${uptime_array[0]}

            state=${stat_array[2]}

            utime=${stat_array[13]}
            stime=${stat_array[14]}
            cutime=${stat_array[15]}
            cstime=${stat_array[16]}
            starttime=${stat_array[21]}

            total_time=$(( $utime + $stime))
            total_time=$(( $total_time + $cstime  + $cutime))
            seconds=$( awk 'BEGIN {print ( '"$uptime"' - ('"$starttime"' / '"$clock_ticks"') )}' )
            cpu_usage=$( awk 'BEGIN {print ( 100 * (('$total_time' / '"$clock_ticks"') / '"$seconds"') )}' )

            resident=${statm_array[2]}
            data_and_stack=${statm_array[6]}
            memory_usage=$( awk 'BEGIN {print( (('"$resident"' + '"$data_and_stack"' ) * 100) / '"$total_memory"'  )}' )

            printf "%-10s %-6d %-12.2f %-12.2f %-6s %-4s %-18s\n" "$user" "$pid" "$cpu_usage" "$memory_usage" "$rss" "$state" "$comm"

        fi
    done