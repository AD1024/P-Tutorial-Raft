type tStartTimer = int;

event eStartTimer: tStartTimer;
event eTimerTimeout;
event eCancelTimer;
event eTick: int;

machine Timer {
    var holder: machine;
    var ticksRemain: int;

    start state Init {
        entry (user: machine) {
            holder = user;
            goto TimerIdle;
        }
        ignore eCancelTimer, eTick, eStartTimer;
    }

    state TimerIdle {
        on eStartTimer do (ticks: int) {
            // goto TimerRunning;
            ticksRemain = ticks;
            goto TimerTick;
        }
        ignore eCancelTimer, eTick;
    }

    state TimerTick {
        entry {
            checkTick();
        }
        on eTick do (tick: int) {
            ticksRemain = ticksRemain - 1;
            checkTick();
        }
        on eCancelTimer goto TimerIdle;
        ignore eStartTimer;
    }

    fun checkTick() {
        if (ticksRemain == 0) {
            send holder, eTimerTimeout;
            goto TimerIdle;
        } else {
            send this, eTick, ticksRemain;
        }
    }
}