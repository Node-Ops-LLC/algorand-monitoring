    scratchpad

    IFS=' ' read -r host port <<< "${relay}";
    url="http://${host}:${port}/v1/mainnet-v1.0/block/0";
    IFS=' ' read -r response_code total_time < <(curl --location --head --silent --output /dev/null --max-time 3 --write-out "%{response_code} %{time_total}" ${url});
    echo "{\"host\":\"${host}\",\"port\":\"${port}\",\"response_code\":\"${response_code}\", \"total_time\":${total_time}}" | jq -R '. as $line | try(fromjson) catch $line';


    {print $0,"USER"; next} 

    { backup_cmd = "cp " $2 " " toDir " >/dev/null 2>&1"
          st = system(backup_cmd)
          print $0, ( st==0? "Success" : "Failed" ) }

top -bn1 | (head -n2 | tail -1 && awk '{if($5>0||$6>0) print}') | awk 'NR==1{print $0,"USER"; next}{print}'

top -bn1 | awk '{if($5>0||$6>0) print; next}{u="id -un " $2
    print $0 (u)}'