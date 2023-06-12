#!/bin/bash

for i in $(seq 1 $2);
do
let "C = $i + $1"
docker run --cpus="0.5" --memory="2g" --memory-swap="4g" -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Testing1122" -p 49$C:1433 --name SqlWatch-$C -h SqlWatch-$C -d mcr.microsoft.com/mssql/server:2019-CU11-ubuntu-20.04;
done
