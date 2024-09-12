n=$1
ef="${@:2}"

for tc in oneClientFiveServersReliable oneClientFiveServersUnreliable twoClientsThreeServersReliable twoClientsThreeServersUnreliable
do
    if ((${#ef} == 0))
    then
        echo "Run $tc with $n schedules for all events"
        /scratch/network/dh7120/osdi24/deps/dotnet-sdk-8.0.401-linux-x64/dotnet /scratch/network/dh7120/osdi24/P/Bld/Drops/Release/Binaries/net8.0/p.dll check -tc $tc -s $n --pinfer
    else
        echo "Run $tc with $n schedules with events $ef"
        /scratch/network/dh7120/osdi24/deps/dotnet-sdk-8.0.401-linux-x64/dotnet /scratch/network/dh7120/osdi24/P/Bld/Drops/Release/Binaries/net8.0/p.dll check -tc $tc -s $n -ef $ef --pinfer
    fi
done
echo "Finished"