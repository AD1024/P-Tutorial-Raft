event eAppendEntriesRecv: (mylog: seq[tServerLog]);
event eAppendEntriesSent: (mylog: seq[tServerLog]);

spec SafetyLogMatching observes eAppendEntriesRecv, eAppendEntriesSent{
    start state Init {
        entry {
            
        }
        on eAppendEntriesRecv do (arg: (mylog:seq[tServerLog])) {
            print "append entries recieved";
        }

        on eAppendEntriesSent do (arg: (mylog:seq[tServerLog])) {
            print "append entries sent";
        }
    }
}
