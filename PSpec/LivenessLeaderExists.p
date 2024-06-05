spec LivenessLeaderExists observes eBecomeLeader {
    start state Init {
        entry {
            goto NoLeader;
        }
    }

    hot state NoLeader {
        on eBecomeLeader do {
            goto HasLeader;
        }
    }

    cold state HasLeader {
        ignore eBecomeLeader;
    }
}