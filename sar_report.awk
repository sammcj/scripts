BEGIN{
round=0
count=0
print "time", "Cpu%usr", "Cpu%sys", "Cpu%io", "Cpu%idl", "Mem%usd", "%Cache+Buff", "Swp%usd", "pswpin/s", "pswpout/s", "runq-sz", "ldavg-5", "IRQ/s", "proc/s", "cswch/s", "  tps", " rtps", " wtps"
}
{

if ( $1 == "===========" ) { round+=1 }
#time formating, change from AM/PM to 24hour format and remove seconds
if ( $1 != "===========" ) {
	if ( $2 != "AM" && $2 != "PM" ) {print "\n\nsecond column does not contain AM / PM time marker, quiting"; exit }
        #time formating, change from AM/PM to 24hour format and remove seconds
        if ( $2 == "AM" && substr($1,1,2) == 12 ) {fulltime="00:" substr($1,4,2)}
                else if ( $2 == "PM" && substr($1,1,2) == 12 ) {fulltime="12:" substr($1,4,2)}
                        else if ( $2 == "PM" ) {fulltime=substr($1,1,2)+12 ":" substr($1,4,2)}
                                else {fulltime=substr($1,1,5)}

#cpu usage; sar -u
if ( round == 0 ) {
        record[NR]=fulltime
        cpu_user[fulltime]=$4
        cpu_system[fulltime]=$6
        cpu_iowait[fulltime]=$7
        cpu_idle[fulltime]=$9
        count+=1
        }
#mem/swap usage; sar -r
if ( round == 1 ) {
        mem_used[fulltime]=$5
	mem_cache_and_buffers[fulltime]=($6+$7)*100/($3+$4)
#	print "buff + cache="($6+$7)" total mem="($3+$4) " "($6+$7)*100/($3+$4) " mem used=" $5
        swap_used[fulltime]=$10
        }
#load average for 1 minute; sar -q
if ( round == 2 ) {
        runq_sz[fulltime]=$3
        ldavg_5[fulltime]=$6
        }
#IRQ/s ; sar -I SUM
if ( round == 3 ) {
        intr_s[fulltime]=$4
        }
# proc/s - Total number of processes created per second; sar -c
if ( round == 4 ) {
        proc_s[fulltime]=$3
        }
# Total number of context switches per second ; sar -w
if ( round == 5 ) {
        cswch_s[fulltime]=$3
        }
#swap activity; sar -W
if ( round == 6 ) {
        pswpin_s[fulltime]=$3
        pswpout_s[fulltime]=$4
        }
#I/O transfers to disks; sar -b
if ( round == 7 ) {
        tps[fulltime]=$3
        rtps[fulltime]=$4
	wtps[fulltime]=$5
        }

} 
}
END{
for (i = 1; i <= count; i++) {
        time=record[i]
printf ("%s %6g  %6g %6g  %6g  %6g       %2.2f  %6g    %5d     %5d     %3g  %6g %5d %6d %7d %5d %5d %5d\n",time, cpu_user[time], cpu_system[time], cpu_iowait[time], cpu_idle[time], mem_used[time], mem_cache_and_buffers[time], swap_used[time], pswpin_s[time], pswpout_s[time], runq_sz[time], ldavg_5[time], intr_s[time], proc_s[time], cswch_s[time], tps[time], rtps[time], wtps[time])

        }

}
