#!/bin/bash
# Public Test Profile - Predictable patterns for debugging
bandwidth=50000  # 50 Mbps baseline
delay=50         # 50ms baseline RTT
pl=0.1          # 0.1% baseline loss

# Initial setup - Apply traffic shaping to loopback interface (lo) for localhost traffic
tc qdisc add dev lo root handle 1: htb default 1
tc class add dev lo parent 1: classid 1:1 htb rate ${bandwidth}kbit ceil ${bandwidth}kbit
tc qdisc add dev lo parent 1:1 handle 10: netem delay ${delay}ms loss ${pl}%

phase=1
counter=0

while true; do
    counter=$((counter + 1))
    
    case $phase in
        1)
            bandwidth=50000
            delay=50
            pl=0.1
            if [ $counter -ge 15 ]; then
                phase=2
                counter=0
            fi
            ;;

        2)
            bandwidth=10000
            delay=50
            pl=1.0
            if [ $counter -ge 10 ]; then
                phase=3
                counter=0
            fi
            ;;

        3)
            bandwidth=30000
            delay=$((50 + RANDOM % 100))
            pl=0.5
            if [ $counter -ge 12 ]; then
                phase=4
                counter=0
            fi
            ;;

        4)
            bandwidth=40000
            delay=75
            if [ $((counter % 10)) -eq 0 ]; then
                pl=15
            else
                pl=0
            fi
            if [ $counter -ge 15 ]; then
                phase=1
                counter=0
            fi
            ;;
    esac
    tc class change dev lo parent 1: classid 1:1 htb rate ${bandwidth}kbit ceil ${bandwidth}kbit
    tc qdisc change dev lo parent 1:1 handle 10: netem delay ${delay}ms loss ${pl}%
    
    echo "Phase: $phase, Time: $counter, BW: ${bandwidth}kbit, Delay: ${delay}ms, Loss: ${pl}%"
    sleep 1
done