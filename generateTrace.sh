n=$1
ef="${@:2}"

for tc in oneClientThreeServersReliable oneClientThreeServersUnreliable twoClientsThreeServersReliable twoClientsThreeServersUnreliable
do
    if ((${#ef} == 0))
    then
        echo "Run $tc with $n schedules for all events"
        dotnet /Users/mikehe/Documents/Princeton/osdi24/P/Bld/Drops/Release/Binaries/net8.0/p.dll check -tc $tc -s $n --pinfer
    else
        echo "Run $tc with $n schedules with events $ef"
        dotnet /Users/mikehe/Documents/Princeton/osdi24/P/Bld/Drops/Release/Binaries/net8.0/p.dll check -tc $tc -s $n -ef $ef --pinfer
    fi
done
echo "Finished"