###############################################################################
##
##   Dornier DO J II - f - Bos (Wal)
##   by Marc Kraus :: Lake of Constance Hangar
##
##   Copyright (C) 2012 - 2014  Marc Kraus  (info(at)marc-kraus.de)
##
###############################################################################
# =============================================================================
#                          MOORING AND WAIT-PUSHBACK           
# =============================================================================
# all variables are initialized in the crane-action.nas !!! never walk alone :-)

######### Help to stay on a fix place on ship #########################
setlistener("/controls/special/hold-pos", func(hp) {
    var as = getprop("/instrumentation/airspeed-indicator/true-speed-kt");
    if (as < 25 and hp.getBoolValue()){
        setprop("/controls/special/hold-lon", getprop("/position/longitude-deg"));
        setprop("/controls/special/hold-lat", getprop("/position/latitude-deg"));
        setprop("/controls/special/hold-hdg", getprop("/orientation/heading-deg"));
        holdPos(); # call the function
    }else{
        if (hp.getBoolValue()){
          screen.log.write("Can't hold position.", 1.0, 0.0, 0.0);
          setprop("/controls/special/hold-pos", 0);
        }
    }
});

###################### hold position with heading ############################
var holdPos = func{

  if(debug_hp) print("Schwabenland Index" , schwabenland_index);
  if(debug_hp) print("Westfalen Index" , westfalen_index);

  #setprop("/controls/special/pos-olli", 0);  # only for the sound

  var targetHdg = getprop("/controls/special/hold-hdg") or 0;
  var targetLat = getprop("/controls/special/hold-lat") or 0;
  var targetLon = getprop("/controls/special/hold-lon") or 0;
  var isHdg = getprop("/orientation/heading-deg") or 0;
  var isLat = getprop("/position/latitude-deg") or 0;
  var isLon = getprop("/position/longitude-deg") or 0;
    
  var acthdg = getprop("/controls/special/hold-hdg") or 0;
  setMyHeading(acthdg);

  ## hold the longitude
  setprop("/position/longitude-deg", targetLon);

  ## hold the latitude
  setprop("/position/latitude-deg", targetLat);

  ## continue or break
  if(getprop("/controls/special/hold-pos")){
    setprop("/sim/crashed", 0);
    settimer(holdPos, 0);
  }else{
    setprop("/controls/special/catapult-carrier-crane/towel",0);
    setprop("/controls/special/catapult-carrier-crane/turn",0);
    setprop("/controls/special/catapult-carrier-crane/pull",0);
  }
}

######################## set the buoy for mooring ###############
setlistener("/controls/special/mooring", func(mo) {
    var as = getprop("/instrumentation/airspeed-indicator/true-speed-kt");
    if(getprop("/engines/engine[0]/running") or getprop("/engines/engine[1]/running")){
        screen.log.write("Captain, please stop engines before mooring!", 1.0, 0.0, 0.0);
        setprop("/controls/special/mooring", 0);       
    }
    if (as < 40 and mo.getBoolValue()){
        setprop("/controls/special/hold-lon", getprop("/position/longitude-deg"));
        setprop("/controls/special/hold-lat", getprop("/position/latitude-deg"));
        screen.log.write("Buoy is out.", 1.0, 0.7, 0.0);
        setMooringPos(); # call the function
    }else{
        if (mo.getBoolValue()){
          screen.log.write("Its too windy for mooring, or you are to fast :-))", 1.0, 0.0, 0.0);
          setprop("/controls/special/mooring", 0);
        }
    }
});

var setMooringPos = func{
  setprop("/controls/special/catapult-carrier-crane/pull", -0.3);
  var targetLat = getprop("/controls/special/hold-lat"); # set the buoy in center of the DO-J
  var targetLon = getprop("/controls/special/hold-lon");
  settimer ( func { holdMooringPos(targetLat, targetLon);} , 0);
}

var holdMooringPos = func (targetLat = 0, targetLon = 0){

  var isLat = getprop("/position/latitude-deg");
  var isLon = getprop("/position/longitude-deg");

  # What is our position to the buoy?
  var our_pos  = geo.aircraft_position();
  var buoy_pos = geo.Coord.new();
			buoy_pos.set_latlon( targetLat, targetLon);
	var hdg_to_buoy = our_pos.course_to(buoy_pos);
  var distance = our_pos.distance_to(buoy_pos);
  var my_hdg = getprop("/orientation/heading-deg");
  var angle_to_buoy = geo.normdeg(my_hdg - hdg_to_buoy);
  
  #var hdg_to_buoy = our_pos.course_to(my_buoy);
  if(debug_mooring){
    print("Kurs zur Boje ist: " ~ hdg_to_buoy);
    print("Winkel ist: " ~ angle_to_buoy);
    print("Abstand ist: " ~ distance);
  }

  # set the seaplane nose up to buoy
  if(angle_to_buoy > 0.2 and angle_to_buoy < 180){
     if(angle_to_buoy > 10){
       setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
     }else{
       setprop("/controls/special/catapult-carrier-crane/towel",-0.1);
     }
  }elsif(angle_to_buoy >= 180 and angle_to_buoy < 359.8){
     if(angle_to_buoy < 350){
       setprop("/controls/special/catapult-carrier-crane/towel",0.3);
     }else{
       setprop("/controls/special/catapult-carrier-crane/towel", 0.1);
     }
  }else{
     # we have the nose in crane direction
     setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
  }

  # good distance to the crane
  if(distance <= 8  and getprop("/position/altitude-ft")){
    setprop("/controls/special/catapult-carrier-crane/pull",-0.2);
  }elsif(distance >= 10){
    setprop("/controls/special/catapult-carrier-crane/pull", 0.2);
  }elsif(distance > 13){
    setprop("/controls/special/catapult-carrier-crane/pull", 0.4);
  }else{
    setprop("/controls/special/catapult-carrier-crane/pull", 0);
  } 

  ## continue or break
  var controllSpeed = getprop("/instrumentation/airspeed-indicator/true-speed-kt");
  if(controllSpeed > 30) setprop("/controls/special/mooring", 0);

  if(getprop("/controls/special/mooring")){
    # sometimes the DO-J crashed on its own buoy ... so give them a better change
    if (getprop("/sim/crashed")){
        setprop("/sim/crashed", 0);
    }  
    settimer( func { holdMooringPos(targetLat, targetLon)}, 0);
  }else{
    setprop("/controls/special/catapult-carrier-crane/towel",0);
    setprop("/controls/special/catapult-carrier-crane/pull",0);
  }
}

########### slide from waiting position to startup position at catapult ##########
# Oliver Hardy do his job
# 0 = no Olli is in view
# 1 = Oliver stand near the catapult launch
# 2 = Oliver stand near the catapult launch and show the way back
# 3 = Oliver stand at the waiting position
# 4 = Oliver stand at the waiting position and show the way to the cat
var olliOnWork = func {
  var lo = getprop("/position/longitude-deg");
  if(lo > betweenCatAndWaitLon){
    fromWaitToCat();
  }else{
    fromCatToWait();
  }
}

var fromWaitToCat = func{

  setMyHeading(305);
  var time = 12;
  setprop("/sim/crashed", 0);
  setprop("/controls/special/shadow", 0);
  setprop("/controls/special/hold-pos", 0);
  setprop("/controls/special/pos-olli", 4);

  setprop("/position/latitude-deg", waitLatSchwabenland);
  setprop("/position/longitude-deg", waitLonSchwabenland);

  interpolate ("/position/latitude-deg", catLatSchwabenland, time);
  interpolate ("/position/longitude-deg", catLonSchwabenland, time);

  setprop("/controls/gear/brake-right", 1);
  setprop("/controls/gear/brake-left", 1);

  settimer( func{ setMyHeading(305); }, time - 10);
  settimer( func{ setMyHeading(305); }, time - 8);
  settimer( func{ setMyHeading(305); }, time - 6);
  settimer( func{ setMyHeading(305); }, time - 2);
  settimer( func{ setprop("/controls/special/catapult-carrier-crane/towel", 0); }, time);   
  settimer( func{ setprop("/controls/special/hold-pos", 1); }, time + 0.1);
  settimer( func{ setprop("/controls/special/pos-olli", 1); }, time + 0.6);
  settimer( func{ setprop("/controls/gear/brake-right", 0); }, time + 1);
  settimer( func{ setprop("/controls/gear/brake-right", 0); }, time + 1);
  setprop("/sim/crashed", 0);
}

var fromCatToWait = func{

  setMyHeading(305);
  var time = 12;
  setprop("/sim/crashed", 0);
  setprop("/controls/special/shadow", 0);
  setprop("/controls/special/hold-pos", 0);
  setprop("/controls/special/pos-olli", 2);
  setprop("/controls/special/catapult-carrier-crane/pull", -0.3);

  setprop("/position/latitude-deg", catLatSchwabenland);
  setprop("/position/longitude-deg", catLonSchwabenland);

  interpolate ("/position/latitude-deg", waitLatSchwabenland, time);
  interpolate ("/position/longitude-deg", waitLonSchwabenland, time);

  setprop("/controls/gear/brake-right", 1);
  setprop("/controls/gear/brake-left", 1);

  settimer( func{ setMyHeading(305); }, time - 10);
  settimer( func{ setMyHeading(305); }, time - 8);
  settimer( func{ setMyHeading(305); }, time - 6);
  settimer( func{ setMyHeading(305); }, time - 2); 
  settimer( func{ setprop("/controls/special/catapult-carrier-crane/towel", 0); }, time); 
  settimer( func{ setprop("/controls/special/hold-pos", 1); }, time + 0.1);
  settimer( func{ setprop("/controls/special/pos-olli", 3); }, time + 0.6); 
  settimer( func{ setprop("/controls/gear/brake-right", 0); }, time + 1);
  settimer( func{ setprop("/controls/gear/brake-right", 0); }, time + 1);

  setprop("/sim/crashed", 0);
}

########################  helper for catapult action  #############################
## hold position with Shift + l
setlistener("/controls/gear/launchbar", func(laba) {
    var alti = props.globals.getNode("/position/altitude-ft").getValue() or 0;
    if (laba.getBoolValue() and schwabenland_index >= 0 
        and alti > (catAltSchwabenland - 1) and alti < (catAltSchwabenland +1)){

          setprop("/controls/special/hold-pos", 1);

    }elsif (laba.getBoolValue() and westfalen_index >= 0 
            and alti > (catAltWestfalen - 1) and alti < (catAltWestfalen +1)){

          setprop("/controls/special/hold-pos", 1);

    }else{
        setprop("/controls/gear/launchbar", 0); # mouse up stop launchbar
    }
},1,0);
## leave position with Shift + c
setlistener("/controls/gear/catapult-launch-cmd", func(calaba) {
    if (calaba.getBoolValue()){
        setprop("/controls/special/hold-pos", 0);
        # stan laurel shake his head
        settimer( func{ setprop("/controls/special/pos-stan", 2); }, 0.1); 
        settimer( func{ setprop("/controls/special/pos-stan", 3); }, 0.3);
        settimer( func{ setprop("/controls/special/pos-stan", 2); }, 0.5); 
        settimer( func{ setprop("/controls/special/pos-stan", 3); }, 0.8);    
    }
});

var dojmod = func(x,y){
  var res = x/y;
  var resInt = int(res);
  var resSmall = y * resInt;
  return x - resSmall;
}


var findSheerDeg = func(a,b){
  var diff = b-a;
  var newAngle = 0.0;
  if(diff > 180)
  {
      newAngle = dojmod((diff + 180),360) - 180;
  }
  elsif(diff < -180)
  {
      newAngle = dojmod((diff - 180),360) + 180;
  }
  else
  {
      newAngle = dojmod(diff, 360);
  }

  if(debug_he) print("Zielwinkel: "~newAngle);

  return ( newAngle);
}


############################  ONLY WESTFALEN #######################################

#################  The mens pushback and pull action on the rail #####################

var fromWestCraneToCat = func{

  if(debug_func) print("func fromWestCraneToCat is runing");

  var our_pos  = geo.aircraft_position();

  var myLat = props.globals.getNode("/position/latitude-deg");
  var myLon = props.globals.getNode("/position/longitude-deg");
  var myHdg = props.globals.getNode("/orientation/heading-deg").getValue();

  var br = getprop("/controls/gear/brake-right") or 0;
  var bl = getprop("/controls/gear/brake-left") or 0;
  var bp = getprop("/controls/gear/brake-parking") or 0;

  var fwctw_towel = getprop("/controls/flight/rudder") or 0;
  var s5towel = fwctw_towel/3;

  setprop("/controls/special/shadow", 0);

  # fwctw is init in the crane-action.nas
  if(fwctw_step == 0){
    setprop("/controls/special/hold-pos", 0);
    setprop("/controls/gear/brake-right", 0);
    setprop("/controls/gear/brake-left", 0);
    setprop("/controls/gear/brake-parking", 0);
    setprop("/controls/special/pos-olli", 2);  # only for the sound
    br = 0;
    bl = 0;
    bp = 0;
    screen.log.write("Now its your turn. Turn with rudder and stop with brakes.", 1.0, 0.7, 0.0);
    fwctw_step = 1;
  }

  # heading and pos correction before start pushback
  if(fwctw_step == 1){
    setprop("/position/latitude-deg", west_rails1_Lat);
    setprop("/position/longitude-deg", west_rails1_Lon);

    if(myHdg > 252.5 or myHdg < 253.5){
      if ((abs(myLon.getValue() - west_rails1_Lon) <= 0.000005) and
          (abs(myLat.getValue() - west_rails1_Lat) <= 0.0000005) ){
        fwctw_step = 2;
      }
    }else{
      setMyHeading(253);
      fwctw_step = 1;
    }

  }

  # pull to first bend
  if(fwctw_step == 2){

    setprop("/controls/special/catapult-carrier-crane/towel", s5towel);
    setprop("/controls/special/catapult-carrier-crane/pull", getprop("/controls/flight/elevator")/4);

    if(debug_hm) print("Drehdruck: ", s5towel);

    if(!br and !bl and !bp){
      setprop("/controls/special/hold-pos", 0);
      # 12 sec
      var fwctw_time = 12 * our_pos.distance_to(west2)/west1.distance_to(west2);
      interpolate ("/position/latitude-deg", west_rails2_Lat, fwctw_time);
      interpolate ("/position/longitude-deg", west_rails2_Lon, fwctw_time);
      if(debug_hm) print("fwctw_time: ", fwctw_time);
    }else{
      interpolate ("/position/latitude-deg", myLat.getValue(), 0);
      interpolate ("/position/longitude-deg", myLon.getValue(), 0);
      setprop("/controls/special/hold-pos", 1);  
    }

    if((abs(myLon.getValue() - west_rails2_Lon) <= 0.000005) and
       (abs(myLat.getValue() - west_rails2_Lat) <= 0.0000005) ){ 
      interpolate ("/position/latitude-deg", west_rails2_Lat, 0);
      interpolate ("/position/longitude-deg", west_rails2_Lon, 0);
      fwctw_step = 3; 
    }
  }

  # pos correction before second step
  if(fwctw_step == 3){
    setprop("/controls/special/catapult-carrier-crane/towel", s5towel);
    setprop("/position/latitude-deg", west_rails2_Lat);
    setprop ("/position/longitude-deg", west_rails2_Lon);
    fwctw_step = 4;
  }

  # now its the complicate turn 
  if(fwctw_step == 4){

    # if DO-J elevator touch the mast
    if(myLat.getValue() >= -3.819953956 and myLat.getValue() < -3.819946032 and myHdg < 220){
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Stop at 1");
    }

    if(myLat.getValue() >= -3.819946032 and myLat.getValue() < -3.819940894 and myHdg < 196){
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Stop at 2");
    }

    if(myLat.getValue() >= -3.819940894 and myLat.getValue() < -3.819925471 and myHdg < 160){
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Stop at 3");
    }

    if(myLat.getValue() >= -3.819925471 and myLat.getValue() < -3.819885624 and (myHdg < 130 or myHdg > 222)){
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Stop at 4");
    }

    # fuselage at the funnel
    if(myLat.getValue() < -3.819875531 and myLat.getValue() > -3.8198750 and myHdg > 171){
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Stop at 5");
    }

    # fuselage at the funnel
    if(myLat.getValue() < -3.819886388 and myLat.getValue() > -3.8198860 and myHdg < 163){
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Stop at 6");
    }

    # if DO-J touch the the funnel
    if(myLat.getValue() > -3.819930551 and myLat.getValue() < -3.819953786 and myHdg > 224) {
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Kaputt bei: 7");
    }
    if(myLat.getValue() < -3.819912548 and myLat.getValue() > -3.819905649 and myHdg > 190) {
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Kaputt bei: 8");
    }
    if((myLat.getValue() > -3.819905649 and myLat.getValue() < -3.819896582 and (myHdg < 135 or myHdg > 185))) {
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Kaputt bei: 9");
    }
    if(myLat.getValue() > -3.819649580 and myHdg > 129) {
      setprop("/sim/crashed", 1);
      if(debug_hm) print("Kaputt bei: 10");
    }

    if(debug_hm) print("# lat", myLat.getValue());
    if(debug_hm) print("# hdg", myHdg);

    setprop("/controls/special/catapult-carrier-crane/towel", s5towel);
    setprop("/controls/special/catapult-carrier-crane/pull", getprop("/controls/flight/elevator")/4);

    if(debug_hm) print("Drehdruck: ", s5towel);

    if(!br and !bl and !bp){
      setprop("/controls/special/hold-pos", 0);
      interpolate ("/position/latitude-deg", myLat.getValue(), 0);
      interpolate ("/position/longitude-deg", myLon.getValue(), 0);

      if ( myLon.getValue() < west_rails3_Lon or myLat.getValue() < west_rails3_Lat){
          # 13 sec from west2 to west3
          var fwctw_time = 13 * our_pos.distance_to(west3)/west2.distance_to(west3);
          interpolate ("/position/latitude-deg", west_rails3_Lat + 0.00001, fwctw_time);
          interpolate ("/position/longitude-deg", west_rails3_Lon + 0.000001, fwctw_time);
          if(debug_hm) print("rails 3");
      }else{
          # 10 sec from west3 to west4
          var fwctw_time = 10 * our_pos.distance_to(west4)/west3.distance_to(west4);
          interpolate ("/position/latitude-deg", west_rails4_Lat, fwctw_time);
          interpolate ("/position/longitude-deg", west_rails4_Lon, fwctw_time);
          if(debug_hm) print("rails 4");
      }

    }else{
      interpolate ("/position/latitude-deg", myLat.getValue(), 0);
      interpolate ("/position/longitude-deg", myLon.getValue(), 0);
      setprop("/controls/special/hold-pos", 1);  
    }

    if ((abs(myLon.getValue() - west_rails4_Lon) <= 0.000009) and
       (abs(myLat.getValue() - west_rails4_Lat) <= 0.0000009) ){ 
      fwctw_step = 5; 
    }
  } 

  # pos correction before last step
  if(fwctw_step == 5){
    setprop("/controls/special/catapult-carrier-crane/towel", s5towel);
    interpolate ("/position/latitude-deg", west_rails4_Lat, 0);
    interpolate ("/position/longitude-deg", west_rails4_Lon, 0);
    fwctw_step = 6;
  }

  # heaving to the cat altitude
  if(fwctw_step == 6){
    setprop("/controls/special/catapult-carrier-crane/towel", 0);
    setprop("/controls/special/catapult-carrier-crane/pull", 0);
    setprop("/position/latitude-deg", west_rails4_Lat);
    setprop("/position/longitude-deg", west_rails4_Lon);
    setMyHeading(69.9);
    interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/cat-heave", 1.70, 4);
    interpolate("/controls/special/catapult-carrier-crane/cat-elevator-westfalen", 1.70, 4); # only for the sound
    if(getprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/cat-heave") > 1.65){
      fwctw_step = 7;
    }
    #fwctw_step = 7;
  }

  # the last few meters to the catapult 
  if(fwctw_step == 7){

    setprop("/controls/special/catapult-carrier-crane/towel", s5towel);
    #setprop("/controls/special/catapult-carrier-crane/pull", getprop("/controls/flight/elevator")/4);

    if(debug_hm) print("Drehdruck: ", s5towel);

    if(!br and !bl and !bp){
      setprop("/controls/special/hold-pos", 0);
      # 4 sec      
      var fwctw_time = 4 * our_pos.distance_to(westCat)/west4.distance_to(westCat);
      interpolate ("/position/latitude-deg", west_railsCat_Lat, fwctw_time);
      interpolate ("/position/longitude-deg", west_railsCat_Lon, fwctw_time);
    }else{
      setprop("/controls/special/hold-pos", 1);  
    }

    if(abs(myLon.getValue() - west_railsCat_Lon) < 0.000005 ){ 
      interpolate ("/position/latitude-deg", west_railsCat_Lat, 0);
      interpolate ("/position/longitude-deg", west_railsCat_Lon, 0);
      setprop("/position/latitude-deg", west_railsCat_Lat);
      setprop("/position/longitude-deg", west_railsCat_Lon);
      fwctw_step = 8; 
    }
  }

  # last hdg correction
  if(fwctw_step == 8){
    setMyHeading(68.25);
    if( myHdg > 68 and myHdg < 68.5 ){
      fwctw_step = 0; 
      setprop("/controls/gear/launchbar", 1);
    }
  }   

  if(debug_hm) print("Step: ", fwctw_step);
  if(fwctw_step and !getprop("/sim/crashed")) {

    settimer( func { fromWestCraneToCat(); }, 0);

  }else{
    if(getprop("/sim/crashed")){
      setprop("/orientation/roll-deg", 6);
      interpolate ("/position/latitude-deg", myLat.getValue(), 0);
      interpolate ("/position/longitude-deg", myLon.getValue(),0);
    }
  }
}

####################### Crane to Wait ####################################
var fromWestCraneToWait = func{

  if(debug_func) print("func fromWestCraneToWait is runing");

  var our_pos  = geo.aircraft_position();

  var myLat = props.globals.getNode("/position/latitude-deg");
  var myLon = props.globals.getNode("/position/longitude-deg");
  var myHdg = props.globals.getNode("/orientation/heading-deg").getValue();

  var fwctw_towel = getprop("/controls/flight/rudder") or 0;
  var s5towel = fwctw_towel/3;

  setprop("/sim/crashed", 0);

  setprop("/controls/special/shadow", 0);

  setprop("/controls/special/catapult-carrier-crane/towel", s5towel);

  # fwctw is init in the crane-action.nas
  if(fwctw_step == 0){
    setprop("/controls/special/hold-pos", 0);
    setprop("/controls/gear/brake-right", 0);
    setprop("/controls/gear/brake-left", 0);
    setprop("/controls/gear/brake-parking", 0);
    setprop("/controls/special/pos-olli", 2);  # only for the sound
    br = 0;
    bl = 0;
    bp = 0;
    screen.log.write("We push you back to the waiting position.", 1.0, 0.7, 0.0);
    fwctw_step = 1;
  }

  # heading and pos correction before pushback
  if(fwctw_step == 1){
    setprop("/position/latitude-deg", waitLatWest3);
    setprop("/position/longitude-deg", waitLonWest3);

    if(myHdg > 249.5 and myHdg < 250.5 and 
      (abs(myLon.getValue() - waitLonWest3) <= 0.000001) and
      (abs(myLat.getValue() - waitLatWest3) <= 0.0000001) ){
      fwctw_step = 2;
    }else{
      setMyHeading(250);
      fwctw_step = 1;
    }

  }

  # start pushback
  if(fwctw_step == 2){
     interpolate ("/position/latitude-deg", waitLatWest1, 8);
     interpolate ("/position/longitude-deg", waitLonWest1, 8);
     fwctw_step = 3;
  }
  # control pushback
  if(fwctw_step == 3){
     if ((abs(myLon.getValue() - waitLonWest1) <= 0.000001) and
          (abs(myLat.getValue() - waitLatWest1) <= 0.0000001) ){
        fwctw_step = 4;
      }
  }

  # turn
  if(fwctw_step == 4){
    if(myHdg > 210.5 and myHdg < 211.5){
      setprop("/controls/gear/brake-right", 1);
      setprop("/controls/gear/brake-left", 1);
      setprop("/controls/gear/brake-parking", 1);
      fwctw_step = 5;
    }else{
      setprop("/controls/gear/brake-right", 1);
      setprop("/controls/gear/brake-left", 1);
      setprop("/controls/gear/brake-parking", 1);
      setMyHeading(211);
      fwctw_step = 4;
    }
  }

  # control pushback
  if(fwctw_step == 5){
     if(myHdg > 210.5 and myHdg < 211.5 and 
      (abs(myLon.getValue() - waitLonWest1) <= 0.000001) and
      (abs(myLat.getValue() - waitLatWest1) <= 0.0000001) ){
        fwctw_step = 6;
      }else{
        setprop("/position/latitude-deg", waitLatWest1);
        setprop("/position/longitude-deg", waitLonWest1);
        setMyHeading(211);
        fwctw_step = 4;
      }
  }

  # hold position
  if(fwctw_step == 6){
    setprop ("/position/latitude-deg", waitLatWest1);
    setprop ("/position/longitude-deg", waitLonWest1);
    setprop("/controls/special/hold-pos", 1);
    fwctw_step = 7;
  }

  if(!getprop("/controls/special/hold-pos") and fwctw_step > 0){
    settimer( fromWestCraneToWait, 0);
  }else{
     settimer( func{ fwctw_step = 0; }, 1);
  }
  #print("fwctw_step ", fwctw_step);
}

################### Wait to Crane ##########################################
var fromWestWaitToCrane = func{
  if(debug_func) print("func fromWestWaitToCrane is runing");

  var our_pos  = geo.aircraft_position();

  var myLat = props.globals.getNode("/position/latitude-deg");
  var myLon = props.globals.getNode("/position/longitude-deg");
  var myHdg = props.globals.getNode("/orientation/heading-deg").getValue();

  var fwctw_towel = getprop("/controls/flight/rudder") or 0;
  var s5towel = fwctw_towel/3;

  setprop("/sim/crashed", 0);

  setprop("/controls/special/hold-pos", 0);

  setprop("/controls/special/shadow", 0);

  setprop("/controls/special/catapult-carrier-crane/towel", s5towel);

  # fwctw is init in the crane-action.nas
  if(fwctw_step == 0){
    setprop("/controls/gear/brake-right", 0);
    setprop("/controls/gear/brake-left", 0);
    setprop("/controls/gear/brake-parking", 0);
    setprop("/controls/special/pos-olli", 2);  # only for the sound
    screen.log.write("We push you to the heaving position.", 1.0, 0.7, 0.0);
    fwctw_step = 1;
  }

  # heading and pos correction before pushback
  if(fwctw_step == 1){
    setprop("/position/latitude-deg", waitLatWest1);
    setprop("/position/longitude-deg", waitLonWest1);

     if(myHdg > 249.5 and myHdg < 250.5 and 
      (abs(myLon.getValue() - waitLonWest1) <= 0.000001) and
      (abs(myLat.getValue() - waitLatWest1) <= 0.0000001) ){
        fwctw_step = 2;
    }else{
      setprop("/controls/gear/brake-right", 1);
      setprop("/controls/gear/brake-left", 1);
      setprop("/controls/gear/brake-parking", 1);
      setMyHeading(250);
      fwctw_step = 1;
    }

  }

  # start push
  if(fwctw_step == 2){
     interpolate ("/position/latitude-deg", waitLatWest3, 8);
     interpolate ("/position/longitude-deg", waitLonWest3, 8);
     fwctw_step = 3;
  }
  # control push
  if(fwctw_step == 3){
     setMyHeading(250);
     if ((abs(myLon.getValue() - waitLonWest3) <= 0.000002) and
          (abs(myLat.getValue() - waitLatWest3) <= 0.0000002) ){
        fwctw_step = 4;
      }
  }

  # heading and pos correction after pushback
  if(fwctw_step == 4){
    setprop("/position/latitude-deg", waitLatWest3);
    setprop("/position/longitude-deg", waitLonWest3);

    if(myHdg > 249.5 and myHdg < 250.5){
      if ((abs(myLon.getValue() - waitLonWest3) <= 0.000003) and
          (abs(myLat.getValue() - waitLatWest3) <= 0.0000003) ){
          fwctw_step = 5;
      }
    }else{
      setMyHeading(250);
      fwctw_step = 4;
    }

  }

  # hold position
  if(fwctw_step == 5){
    setprop("/position/latitude-deg", waitLatWest3);
    setprop("/position/longitude-deg", waitLonWest3);
    setprop("/controls/special/catapult-carrier-crane/search-carrier",1);
    fwctw_step = 0;
  }

  if(!getprop("/controls/special/catapult-carrier-crane/search-carrier")){
    settimer( func{ fromWestWaitToCrane();}, 0 );
  }
  #print("fwctw_step ", fwctw_step);
}



################################  Helper for Westfalen #####################################

var setMyHeading = func (targetHdg = 0){
  if(debug_func) print("func setMyHeading is runing");
  var actHdg = getprop("/orientation/heading-deg");
  var ct = findSheerDeg(targetHdg, actHdg);

   powerTowel = - (1/5*ct); 

   if (powerTowel > 0 and powerTowel < 0.1) powerTowel = 0.1;
   if (powerTowel > 1.0) powerTowel = 1.0;
   if (powerTowel < 0 and powerTowel > -0.1) powerTowel = -0.1;
   if (powerTowel < -1.0) powerTowel = -1.0;

  if(abs(ct) > 0.4){
    setprop("/controls/special/catapult-carrier-crane/towel", powerTowel);
    if(debug_hm) print("Abweichung: ", ct);
    if(debug_hm) print("Drehdruck: ", powerTowel);
  }else{
    setprop("/controls/special/catapult-carrier-crane/towel", 0);
  }
}


