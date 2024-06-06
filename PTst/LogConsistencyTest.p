machine TestLogMatching {
  start state Init {
    entry { 
      setUpRaft(5);
    }
  }
}