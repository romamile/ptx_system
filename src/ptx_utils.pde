
class toggle {

  //    ci::Timer myTimer;
  float span; // DO WITH ASYNCHRONIOUS spans ... hu ?... ohh
  float ref;
  boolean state;
  boolean active;

  float phase; // betweeen 0 and 1, as a multiple of ref

  toggle() { 
    span = 1; 
    ref = 0.001*millis(); 
    state = false; 
    phase = 0;  
    active = true;
  }

  void tog() { 
    state = !state;
  }
  void set(boolean _state) { 
    state = _state;
  }

  void setSpanMs(int _timeMs) {
    span = 0.001*_timeMs;
  }
  void setSpanS(float _timeS) {
    span = _timeS;
  }
  float getTickTime() { 
    if (!active) return -1; 
    update(); 
    return 0.001*millis() - (ref + span*phase);
  }

  float getTickVal() { 
    if (!active) return -1; 
    update(); 
    return (0.001*millis() - ref + span*phase) / span;
  }

  void update() {
    while ( 0.001*millis() - (ref + span*phase) > span ) { 
      ref += span;
      state = !state;
    }
  }   

  boolean getState() { 
    if (!active) return state; 
    update(); 
    return state;
  }

  float getSaw() { 
    update(); 
    return getTickVal();
  }
  float getSquare() { 
    update(); 
    return getTickVal() < 0.5  ? 1 : 0;
  }
  
  float getSquare(float _val) { 
    update(); 
    return getTickVal(_val) < 0.5  ? 1 : 0;
  }

  float getTickVal(float _val) { 
    if (!active) return -1; 
    update(); 
    float rezTmp = (0.001*millis()*_val - ref + span*phase) / span;
    return rezTmp - floor(rezTmp);
  }

  float getOscil() { 
    update(); 
    return ( cos( getTickVal() *2*3.141592) + 1 ) / 2;
  }  
  boolean getDirac() {
    if(getState()) {
      tog();
      return true;
    } else {
      return false; 
    }
  }

  void stop  (boolean _state) { 
    active = false; 
    state = _state;
  }
  void start (boolean _state) { 
    active = true; 
    state = _state;
  }
  void reset (boolean _state) { 
    active = true; 
    state = _state;  
    ref = 0.001*millis();
  }
}
