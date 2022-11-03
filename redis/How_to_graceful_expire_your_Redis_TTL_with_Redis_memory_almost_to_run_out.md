# How to graceful expire your Redis TTL with Redis memory almost to run out

## Use this script
```
#!/bin/bash

while [ 1 ]
do
        getkey=$(redis-cli -n 1 RANDOMKEY)
        ttl=$(redis-cli -n 1 ttl $getkey)

        if [[ $ttl -ne -1 ]]
        then
                sleep 0.05
                continue # If there is a set TTL, bypass
        fi

        if [[ $getkey =~ ^${$Filter_Key_Name} ]]
        then
                redis-cli -n 1 EXPIRE $getkey ${Reduced_TTL_time} # Specify the TTL time, the shorter the better
                sleep 0.1
        fi
        sleep 0.1
done
```
