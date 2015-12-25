###############################################################################
##
##   Dornier DO J II - f - Bos (Wal)
##   by Marc Kraus :: Lake of Constance Hangar
##
##   Copyright (C) 2012 - 2014  Marc Kraus  (info(at)marc-kraus.de)
##
###############################################################################
var debug_ca   = 0;  # the heaving crane action
var debug_cc   = 0;  # is_cam_carrier
var debug_sc   = 0;  # show_crane_state
var debug_hp   = 0;
var debug_he   = 0;
var debug_hm   = 0;
var debug_mooring = 0;
var debug_func = 0;

# =============================================================================
#                          Heaving and cargo action           
# =============================================================================
# all variables for the hold-pos.nas are initialized here, too

############################# ALL CAM-CARRIERS  ###############################
var schwabenland_index = -1;    # the index of the /ai/models/carrier [is_cam_carrier]
var westfalen_index    = -1;

var max_dis_to_carrier = 150000; # Meter  - In this range, we got the crane and loading informations

var found_cargo = 0;
var doj_crashed = 0;
var step_by_step = 0;
var craneIsFree = 1;
var crane_multi_stand = 0;

var is_engaged = -1;  # the index of the /ai/models/multiplayer/ - aircraft on that position [is_other]
var is_heaving = -1;  # the index of th  /ai/models/multiplayer/ - aircraft on that position [is_other]

# in step_by_step 2 of the crane_action
var internal_step = 0;

var powerTowel = 0;   # for func setMyHeading

################################ SCHWABENLAND #################################
var schw_craneLon = -16.570024;
var schw_craneLat = 13.46004;

# the center of the crane is a geo.Class
var schw_crane_pos = geo.Coord.new();
schw_crane_pos.set_latlon( schw_craneLat, schw_craneLon);

var schw_catapult_alt   = 11.2;
var catAltSchwabenland  = 37.58;
var catLonSchwabenland  = -16.5697346; # stop position on pushback action on the cat after heaving
var catLatSchwabenland  = 13.45989826; # stop position on pushback action on the cat after heaving

var betweenCatAndWaitLon = -16.5696;
var waitLatSchwabenland = 13.4597586;
var waitLonSchwabenland = -16.56953082;
var waitAltSchwabenland = 41.94;

# the point above the rails before unmount
var schw_unmountLONAxis = -16.569934; 
var schw_unmountLATAxis =  13.460035;

################################## WESTFALEN ##################################
var west_craneLon = -32.42001855;
var west_craneLat = -3.820006783;

# the center of the crane is a geo.Class
var west_crane_pos = geo.Coord.new();
west_crane_pos.set_latlon( west_craneLat, west_craneLon);# the point above the rails before unmount

var west_heave_alt   = 11.5;
var catAltWestfalen   = 37.75;
var west_railsCat_Lon = -32.41932094;
var west_railsCat_Lat = - 3.819819684;

var west_rails1_Lat   = - 3.8200235;  # near the crane
var west_rails1_Lon   = -32.41991;
#var west_rails2_Lat   = - 3.819947;  # on the first bend
#var west_rails2_Lon   = -32.41967;
var west_rails2_Lat   = - 3.819965937;  # on the first bend
var west_rails2_Lon   = -32.41972252;
#var west_rails3_Lat   = - 3.819905;  # in the middle of funnel and mast
#var west_rails3_Lon   = -32.41955;
var west_rails3_Lat   = - 3.81991;  # in the middle of funnel and mast
var west_rails3_Lon   = -32.41957;
var west_rails4_Lat   = - 3.819854;  # on the elevator to catapult
var west_rails4_Lon   = -32.419415;

var waitLatWest1 = -3.819881759;
var waitLonWest1 = -32.41976112;
var waitLatWest2 = -3.819929369;
var waitLonWest2 = -32.41989144;
var waitLatWest3 = -3.819940443;
var waitLonWest3 = -32.41992181;
var waitAltWestfalen = 23.64;

# the point above the rails before unmount
var west_unmountLONAxis = west_rails1_Lon; 
var west_unmountLATAxis = west_rails1_Lat;
var allowed_to_descent_over_waiting = 0;

var west1 = geo.Coord.new();
west1.set_latlon( west_rails1_Lat, west_rails1_Lon);

var west2 = geo.Coord.new();
west2.set_latlon( west_rails2_Lat, west_rails2_Lon);

var west3 = geo.Coord.new();
west3.set_latlon( west_rails3_Lat, west_rails3_Lon);

var west4 = geo.Coord.new();
west4.set_latlon( west_rails4_Lat, west_rails4_Lon);

var westCat = geo.Coord.new();
westCat.set_latlon( west_railsCat_Lat, west_railsCat_Lon);

#################  The mens pushback and pull action on the rail #####################
var fwctw_step = 0;


################################################################################

setlistener("/sim/signals/fdm-initialized", func {
    if(debug_func) print("setlistener fdm-initialized is runing");
    # be sure, if aircraft is restarted on session, that all variables are reseted, too
    found_cargo = 0;
    doj_crashed = 0;
    step_by_step = 0;
    craneIsFree = 1;
    schwabenland_index = -1;    # the index of the /ai/models/carrier [is_cam_carrier]
    westfalen_index    = -1;
    is_engaged = -1;  # the index of the /ai/models/multiplayer/ - aircraft on that position [is_other]
    is_heaving = -1;

    # init the cargo on board
    is_cam_carrier();
    settimer(func{ init_cargo(); }, 1); # if nobody is on crane or heaving an we start flightgear, look for cargo 
    settimer(func{ whereIsOlli(); }, 2); 
    settimer(func{ show_crane_state(); }, 4);
});

################################## control crane at cat action ################################################

setlistener("/gear/launchbar/state", func(catEngaged) {
    if(debug_func) print("setlistener lauchbar state is runing");
    var catEngaged = catEngaged.getValue() or "";
    setprop("/sim/multiplay/generic/string[1]", catEngaged);

    if (catEngaged == "Engaged"){
        setprop("/controls/special/shadow", 0);
        #  for multiplayer views #####################
        if(schwabenland_index != nil and schwabenland_index >= 0) interpolate("/controls/special/catapult-carrier-crane/multi-stand", 1, 2);
        if(!getprop("/engines/engine[0]/running") or !getprop("/engines/engine[1]/running")){
          screen.log.write("START ENGINES!", 1.0, 0.0, 0.0);
        }
        setprop("/controls/special/pos-stan", 2);
        setprop("/controls/special/pos-olli", 0);

        # if there is a carrier index
        if(westfalen_index != nil and westfalen_index >= 0){
          interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/cat-heave", 0, 4);
          interpolate("/controls/special/catapult-carrier-crane/cat-elevator-westfalen", 0, 4); # only for the sound
        }

    }elsif(catEngaged == "Launching"){
        setprop("/controls/special/shadow", 0);
        #  for multiplayer views #####################
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.0, 8);
        setprop("/controls/special/pos-stan", 3);
    }else{
        setprop("/controls/special/shadow", 1);
        #  for multiplayer views #####################
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.0, 8);
        setprop("/controls/special/pos-stan", 1);
        setprop("/controls/special/pos-olli", 1);
        setprop("/controls/gear/launchbar", 0);
    }
}, 1, 0);

######################### Click the worker on middledeck to heave you up ##################################

setlistener("/controls/special/catapult-carrier-crane/search-carrier", func(work) {
    if(debug_func) print("setlistener search-carrier is runing");
    if(getprop("/sim/signals/fdm-initialized")) {
      is_other();
      control_the_crane_traffic();
    }

    if (work.getBoolValue()){


      if( westfalen_index != nil and 
          westfalen_index >= 0 and 
          getprop("/position/altitude-ft") > 23.2 and 
          getprop("/position/altitude-ft") < 23.6 and
          getprop("/position/latitude-deg") > waitLatWest3){
            # we are on waiting position
            setprop("/controls/special/catapult-carrier-crane/search-carrier",0);
            setprop("/controls/special/hold-pos", 0);
            doj.fromWestWaitToCrane();
      }elsif(westfalen_index != nil and westfalen_index >= 0 and getprop("/position/altitude-ft") > 29.0 and getprop("/position/altitude-ft") < 31.0) {
        # an here we are on the rails position
        setprop("/controls/special/catapult-carrier-crane/search-carrier",0);
        setprop("/controls/special/hold-pos", 0);
        doj.fromWestCraneToCat();
      }else{
        # if airplane is on the canvas from Schwabenland or Westfalen
        var cs = getprop("sim/multiplay/callsign");
        screen.log.write("Hello "~cs~", clear for heaving procedure!", 1.0, 0.7, 0.0);
        if(getprop("/engines/engine[0]/running") or getprop("/engines/engine[1]/running")) screen.log.write("WARNING: Stop engines for heaving procedure!", 1.0, 0.0, 0.0);
        setprop("/consumables/fuel/tank[0]/level-lbs", 3200);
        setprop("/consumables/fuel/tank[1]/level-lbs", 1150);
        setprop("/consumables/fuel/tank[2]/level-lbs", 3200);
        unload_cargo();
        step_by_step = 0;
        fwctw_step = 0;
        setprop("/controls/special/hold-pos", 0);
        doj_crashed = 0;
        setprop("/sim/crashed",0);
      }
    }else{
      if(getprop("/sim/signals/fdm-initialized")) {
        if(getprop("/controls/special/catapult-carrier-crane/multi-turn") > 180){
          interpolate("/controls/special/catapult-carrier-crane/multi-turn", 359.9, 2);
        }else{
          interpolate("/controls/special/catapult-carrier-crane/multi-turn", 0, 2);
        }
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0, 1);
        setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
        setprop("/controls/special/catapult-carrier-crane/turn", 0.0);
        setprop("/controls/special/catapult-carrier-crane/pull", 0.0);
        if(schwabenland_index >= 0){
          interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", 0, 6);
        }
        if(westfalen_index >= 0){
          interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", 0, 6);
        }
        step_by_step = 0;
        fwctw_step = 0;
        craneIsFree = 1;
      }
    }
}, 1, 0);

# control if the crane or cat is free
var control_the_crane_traffic = func() {
    if(debug_func) print("func control_the_crane_traffic is runing");
    is_other();
    var nameOfOther = "";
    if (is_heaving >= 0) {
      craneIsFree = 0;
      nameOfOther = getprop("/ai/models/multiplayer["~is_heaving~"]/callsign") or "";
      if(getprop("/controls/special/catapult-carrier-crane/search-carrier")){
        setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
        screen.log.write("Please wait, crane is engaged with "~ nameOfOther ~".", 0.9, 0.8, 0.0);
      }
    }elsif (is_engaged >= 0 and schwabenland_index >= 0) {
      craneIsFree = 0;
      nameOfOther = getprop("/ai/models/multiplayer["~is_engaged~"]/callsign") or "";
      if(getprop("/controls/special/catapult-carrier-crane/search-carrier")){
        setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
        screen.log.write("Please wait, crane is engaged with "~ nameOfOther ~".", 0.9, 0.8, 0.0);
      }
    }else{
      if (!craneIsFree) screen.log.write("Crane is free!", 0.9, 0.8, 0.0);
      craneIsFree = 1;
      settimer(crane_action, 1);
    }
}

############################## Show the crane position and cargo on board  ####################################
# find always an active mp DO-J or yourself for the crane anmimation on board
var show_crane_state = func() {
    if(debug_func) print("func show_crane_state is runing");

    is_other();

    # if I'm crashed, stop my crane-search-action  
    if(!doj_crashed){
      if(getprop("/sim/crashed")){
        setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
        if(getprop("/controls/special/catapult-carrier-crane/multi-turn") > 180){
          interpolate("/controls/special/catapult-carrier-crane/multi-turn", 359.9, 2);
        }else{
          interpolate("/controls/special/catapult-carrier-crane/multi-turn", 0, 2);
        }
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0, 1);
        setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
        setprop("/controls/special/catapult-carrier-crane/pull", 0.0);
        setprop("/controls/special/catapult-carrier-crane/turn", 0.0);
        setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
        #screen.log.write("DO-J CRASHED!", 1.0, 0.7, 0.0);
        doj_crashed = 1;
      }
    }

    if(debug_sc){
      print ("schwabenland_index is: "~schwabenland_index);
      print ("westfalen_index is: "~westfalen_index);
      print ("is_engaged is: "~is_engaged);
      print ("is_heaving is: "~is_heaving);
    }

    if (schwabenland_index >= 0) {

      # if there is no other aircraft
      if (is_heaving < 0 and is_engaged < 0){
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-turn",
                  getprop("/controls/special/catapult-carrier-crane/multi-turn") or 0);
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-stand",
                  getprop("/controls/special/catapult-carrier-crane/multi-stand") or 0);
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-hook-locked",
                  getprop("/controls/special/catapult-carrier-crane/hook-locked") or 0);
		
		  if(getprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave") == nil or
		     getprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave") == ""){
			 setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", 0);}
		
          # cargo
          setprop("/ai/models/carrier["~schwabenland_index~"]/controls/cargo",
                  getprop("/controls/special/catapult-carrier-crane/cargo-schwabenland") or 0);
          # nobody can hook the cat, if somebody is on the crane
          setprop("/controls/special/catapult-carrier-crane/crane-is-free", 1);
          # if nobody (we also) is on the hook or catapult the crane stand up.
          var gls = getprop("/gear/launchbar/state") or "";
          var scn = getprop("/controls/special/catapult-carrier-crane/search-carrier") or 0;
          var mst = getprop("/controls/special/catapult-carrier-crane/multi-stand") or 0;
          if ( mst < 1.0 and !scn and gls == "Disengaged"){
             interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.0, 3);
             interpolate("/controls/special/catapult-carrier-crane/multi-turn", 0.0, 2);
             setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
          }

      }else{
          var mp_index = -1;
          if (is_heaving >= 0 ) mp_index = is_heaving;
          if (is_engaged >= 0 ) mp_index = is_engaged;
          # set on the carrier
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-turn",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[12]") or 0);
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-stand",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[13]") or 0);
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-hook-locked",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/int[19]") or 0);
          # cargo
          setprop("/ai/models/carrier["~schwabenland_index~"]/controls/cargo",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[15]") or 0);
          # and the same on your local aircraft
          setprop("/controls/special/catapult-carrier-crane/multi-turn",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[12]") or 0);
          setprop("/controls/special/catapult-carrier-crane/multi-stand",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[13]") or 0);

          setprop("/controls/special/catapult-carrier-crane/cargo-schwabenland",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[15]") or 0);
          # nobody can hook the cat, if somebody is on the crane
          setprop("/controls/special/catapult-carrier-crane/crane-is-free", 0);
      }


    } # end schwabenland_index

    if (westfalen_index >= 0) {

      # if there is no other aircraft
      if (is_heaving < 0){
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-turn",
                  getprop("/controls/special/catapult-carrier-crane/multi-turn") or 0);
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-stand",
                  getprop("/controls/special/catapult-carrier-crane/multi-stand") or 0);
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-hook-locked",
                  getprop("/controls/special/catapult-carrier-crane/hook-locked") or 0);

		  if(getprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave") == nil or
		     getprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave") == ""){
			 setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", 0);}
			 
		  if(getprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/cat-heave") == nil or
		     getprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/cat-heave") == ""){
			 setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/cat-heave", 0);}
			 
          # nobody can hook the cat, if somebody is on the crane
          setprop("/controls/special/catapult-carrier-crane/crane-is-free", 1);
          # if nobody (we also) is on the hook or catapult the crane stand up.
          var gls = getprop("/gear/launchbar/state") or "";
          var scn = getprop("/controls/special/catapult-carrier-crane/search-carrier") or 0;
          var mst = getprop("/controls/special/catapult-carrier-crane/multi-stand") or 0;
          if ( mst < 1.0 and !scn and gls == "Disengaged"){
             interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.0, 3);        
              if(getprop("/controls/special/catapult-carrier-crane/multi-turn") > 180){
                interpolate("/controls/special/catapult-carrier-crane/multi-turn", 359.9, 2);
              }else{
                interpolate("/controls/special/catapult-carrier-crane/multi-turn", 0, 2);
              }
             setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
          }

      }else{
          var mp_index = -1;
          if (is_heaving >= 0 ) mp_index = is_heaving;
          # set on the carrier
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-turn",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[12]") or 0);
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-stand",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[13]") or 0);
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-hook-locked",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/int[19]") or 0);
          # and the same on your local aircraft
          setprop("/controls/special/catapult-carrier-crane/multi-turn",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[12]") or 0);
          setprop("/controls/special/catapult-carrier-crane/multi-stand",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[13]") or 0);
    
          # nobody can hook the cat, if somebody is on the crane
          setprop("/controls/special/catapult-carrier-crane/crane-is-free", 0);
      }
      
      if (is_engaged >= 0){
          var mp_index = is_engaged;
          # cargo
          setprop("/ai/models/carrier["~westfalen_index~"]/controls/cargo",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[18]") or 0);
          setprop("/controls/special/catapult-carrier-crane/cargo-westfalen",
                  getprop("/ai/models/multiplayer["~mp_index~"]/sim/multiplay/generic/float[18]") or 0);              
      }else{
          # cargo
          setprop("/ai/models/carrier["~westfalen_index~"]/controls/cargo",
                  getprop("/controls/special/catapult-carrier-crane/cargo-westfalen") or 0);       
      }


    } # end westfalen_index

    settimer(show_crane_state, 0);
}

#################################  Main function for the heaving process  ########################################
var crane_action = func() {

    if(debug_func) print("func crane_action is runing");

    var mp_cat_carrier = props.globals.getNode("/ai/models").getChildren("carrier");


    if(getprop("/controls/special/catapult-carrier-crane/search-carrier")){
      settimer(func { crane_action(); }, 0);
    }else{
      if(schwabenland_index >= 0) interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", 0, 0);
      if(westfalen_index >= 0){ 
        interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", 0, 5); 
        setprop("/sim/crashed",0);
      }    

      interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0, 0);
      if(getprop("/controls/special/catapult-carrier-crane/multi-turn") > 180){
        interpolate("/controls/special/catapult-carrier-crane/multi-turn", 359.9, 2);
      }else{
        interpolate("/controls/special/catapult-carrier-crane/multi-turn", 0, 2);
      }
      interpolate("/controls/special/catapult-carrier-crane/towel", 0, 0);
      interpolate("/controls/special/catapult-carrier-crane/pull", 0, 0); 
      interpolate("/controls/special/catapult-carrier-crane/turn", 0, 0); 
      setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
      setprop("/controls/gear/brake-parking",0);
      setprop("/controls/gear/brake-right", 0);
      setprop("/controls/gear/brake-left", 0);
      step_by_step = 0;
    }



    ##### Action for Schwabenland ####

    if (schwabenland_index >= 0) {
      # Oliver Hardy always makes shit on heaving action, banned from deck ...
      setprop("/controls/special/pos-olli", 0);

      # The heaving altitude position
      var real_heave_pos = mp_cat_carrier[schwabenland_index].getNode("surface-positions/crane-heave").getValue() or 0;

      # What is our position?
      var our_pos  = geo.aircraft_position();
      var hdg_to_crane = our_pos.course_to(schw_crane_pos);
      var distance = our_pos.distance_to(schw_crane_pos);
      var my_hdg = getprop("/orientation/heading-deg");
      var angle_to_crane = geo.normdeg(my_hdg - hdg_to_crane);
      var turn = getprop("/controls/flight/aileron");
      var pull = getprop("/controls/flight/elevator");
      var towel = getprop("/controls/flight/rudder");
      #var heave = getprop("/controls/engines/engine[0]/throttle") * schw_catapult_alt;

      var hdg_to_plane = schw_crane_pos.course_to(our_pos);
      var crane_to_plane = geo.normdeg(hdg_to_plane - 125);  # 125 degree is the true course of Schwabenland;

      # if we are to fare away
      if(distance > 20 and getprop("/position/altitude-ft") < 30){
        setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
        screen.log.write("You are fare away from crane, come closer please!", 1.0, 0.7, 0.0);
        return;
      }

      #### make a good position on the canvas before heaving start ###
      if(step_by_step == 0){
        setprop("/controls/gear/brake-parking", 1);
        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.2 and angle_to_crane < 180){
           if(angle_to_crane > 10){
             setprop("/controls/special/catapult-carrier-crane/towel",-1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.8){
           if(angle_to_crane < 350){
             setprop("/controls/special/catapult-carrier-crane/towel",1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel", 0.3);
           }
        }else{
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
        }

        # good distance to the crane
        if(distance <= 9  and getprop("/position/altitude-ft") < 4){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull",-0.7);
        }elsif(distance >= 12  and getprop("/position/altitude-ft") < 4){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }elsif(distance > 13  and getprop("/position/altitude-ft") < 4){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }else{
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        } 

        if((angle_to_crane < 0.2 or angle_to_crane > 359.08) and distance > 9 and distance < 12){
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
          settimer( func { screen.log.write("Heaving procedure is starting soon!", 1.0, 0.7, 0.0); }, 6);
          step_by_step = 1;
        }
      }

      # turn and descent the crane
      if(step_by_step == 1){
        interpolate("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane, 2);
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 1, 1.5);
        settimer( func { setprop("/controls/special/catapult-carrier-crane/hook-locked", 1); }, 11);
        settimer( func { step_by_step = 2; }, 11);
      }

      # heave onto catapult altitude
      if(step_by_step == 2){ 
   
        if(getprop("/sim/crashed")) {
          setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
          interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", 0, 6);
          setprop("/sim/crashed", 0);
        }

        # altitude is distance factor
        var alt_factor = 2.8 / schw_catapult_alt * real_heave_pos;
        if(debug_ca) print("alt_factor : ", alt_factor);
        if(distance <= 10){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull",-0.6);
        }elsif(distance > 14 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }elsif(distance >= 13 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }else{
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        }  

        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.2 and angle_to_crane < 180){
           if(angle_to_crane > 10){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.6);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.5){
           if(angle_to_crane < 350){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",0.6);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel", 0.3);
           }
        }else{
           internal_step = 1;
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
           interpolate("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane, 0);
        }

        if(internal_step == 1){

            setprop("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane);

            if(getprop("/controls/special/catapult-carrier-crane/hook-locked")){
              if(real_heave_pos < 1.5){
                setprop("/controls/special/shadow", 0);
                # push the transparent heaving-object from the Schwabenland
                interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", schw_catapult_alt, 10);
              }

              # 1.2/schw_catapult_alt cause crane stand is going form 1 to -0.2
              var crane_stand_factor = 1.1/schw_catapult_alt;
              var crane_stand = 1 - real_heave_pos * crane_stand_factor; 
              setprop("/controls/special/catapult-carrier-crane/multi-stand", crane_stand);
              if(debug_ca) print("crane_stand ",crane_stand);

              if(real_heave_pos >= schw_catapult_alt - 0.4){ 
                  interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", schw_catapult_alt - 0.4, 0);
                  interpolate("/controls/special/catapult-carrier-crane/multi-stand", -0.07, 0);
                  step_by_step = 3;
                  internal_step = 0;
              }

            }

        } 
        if(debug_ca) print("internal_step ",internal_step);
     }

     # only correction on hightest heaving point, before turning the crane
     if(step_by_step == 3){
  
        setprop("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane);

        # altitude is distance factor
        var alt_factor = 2.8 / real_heave_pos;
        if(debug_ca) print("alt_factor : ", alt_factor);
        if(distance <= 12){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull",-0.6);
        }elsif(distance > 14 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }elsif(distance > 13.5 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.7);
        }elsif(distance >= 12.8 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }else{
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        }  

        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.2 and angle_to_crane < 180){
           if(angle_to_crane > 10){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.5);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.2);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.5){
           if(angle_to_crane < 350){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",0.5);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel", 0.2);
           }
        }else{
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/pull", 0);
           setprop("/controls/special/catapult-carrier-crane/towel", 0);
        }

        if (real_heave_pos >= schw_catapult_alt - 0.5) {
          step_by_step = 4;
          interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", schw_catapult_alt, 0);
          interpolate("/controls/special/catapult-carrier-crane/multi-stand", -0.07, 0);
          screen.log.write("Turn the crane with your yoke now!", 1.0, 0.7, 0.0);
        }
     } 

     # turning the crane
     if(step_by_step == 4){

        # only if aircraft was heave over the towel sacks on board
        if ( crane_to_plane < 60 ) {
          setprop("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", schw_catapult_alt - 0.3);
          setprop("/controls/special/catapult-carrier-crane/multi-stand", -0.2);
        }

        setprop("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane);
        setprop("/controls/gear/brake-right", 0);
        setprop("/controls/gear/brake-left", 0);
        setprop("/controls/gear/brake-parking", 0);

        if(distance > 10.5){
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }elsif(distance >= 10.3){
          setprop("/controls/special/catapult-carrier-crane/pull", 0.8);
        }elsif(distance >= 10.2){
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }elsif(distance <= 9){
          setprop("/controls/special/catapult-carrier-crane/pull", -1);
        }elsif(distance < 9.4){
          setprop("/controls/special/catapult-carrier-crane/pull", -0.8);
        }elsif(distance < 9.7){
          setprop("/controls/special/catapult-carrier-crane/pull", -0.3);
        }else{
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        } 


        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.4 and angle_to_crane < 180 and distance > 9.7 and distance < 11){
           setprop("/controls/gear/brake-parking", 1);
           if(angle_to_crane > 2){
             setprop("/controls/special/catapult-carrier-crane/towel",-1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel",-0.6);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.4){
           if(angle_to_crane < 358){
             setprop("/controls/special/catapult-carrier-crane/towel", 1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel", 0.6);
           }
        }else{
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
        }


        # push the thruster in the DO-J
        if(distance > 9 and distance < 11){
           setprop("/controls/special/catapult-carrier-crane/turn", -turn);
        }else{
           setprop("/controls/special/catapult-carrier-crane/turn", 0);
           setprop("/controls/gear/brake-right", 1);
           setprop("/controls/gear/brake-left", 1);
           setprop("/controls/gear/brake-parking", 1);
        }

        if(crane_to_plane > 328 and crane_to_plane < 330){
          interpolate("/controls/special/catapult-carrier-crane/multi-stand", -0.3, 0.6);
          step_by_step = 5;
        }
        setprop("/sim/crashed", 0);
     }

     # over the rails turn the towel
     if(step_by_step == 5){

        if (distance > 9.6 and distance < 11){
          setprop("/controls/gear/brake-right", 1);
          setprop("/controls/gear/brake-left", 1);
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/turn", 0);

          setprop("/position/latitude-deg", schw_unmountLATAxis);
          setprop("/position/longitude-deg", schw_unmountLONAxis);

          setprop("/controls/special/catapult-carrier-crane/multi-turn", 328);
          
          if(my_hdg <= 304.8){
              if(my_hdg < 290){
                setprop("/controls/special/catapult-carrier-crane/towel",0.8);
              }else{
                setprop("/controls/special/catapult-carrier-crane/towel",0.5);
              }
          }elsif(my_hdg > 305.2){
              if(my_hdg > 315){
                setprop("/controls/special/catapult-carrier-crane/towel",-0.8);
              }else{
                setprop("/controls/special/catapult-carrier-crane/towel",-0.5);
              }
          }else{
            setprop("/controls/special/catapult-carrier-crane/pull", 0);
            setprop("/controls/special/catapult-carrier-crane/towel",0);
            setprop("/controls/special/catapult-carrier-crane/turn", 0);
            interpolate("/controls/special/catapult-carrier-crane/multi-stand", -0.2, 0.6);
            settimer( func{ step_by_step = 6;}, 1);
          }
        }else{
          step_by_step = 4;
        }
      }

      if(step_by_step == 6){
        setprop("/position/latitude-deg", schw_unmountLATAxis);
        setprop("/position/longitude-deg", schw_unmountLONAxis);
        step_by_step = 7;
      }

     # over the rails correction once more
     if(step_by_step == 7){

        setprop("/position/latitude-deg", schw_unmountLATAxis);
        setprop("/position/longitude-deg", schw_unmountLONAxis);

        setprop("/controls/gear/brake-right", 1);
        setprop("/controls/gear/brake-left", 1);
        setprop("/controls/gear/brake-parking", 1);
        setprop("/controls/special/catapult-carrier-crane/pull", 0);
        setprop("/controls/special/catapult-carrier-crane/towel",0);
        setprop("/controls/special/catapult-carrier-crane/turn", 0);

        if(my_hdg <= 304.8){
            if(my_hdg < 290){
              setprop("/controls/special/catapult-carrier-crane/towel",0.5);
            }else{
              setprop("/controls/special/catapult-carrier-crane/towel",0.3);
            }
        }elsif(my_hdg > 305.2){
            if(my_hdg > 315){
              setprop("/controls/special/catapult-carrier-crane/towel",-0.5);
            }else{
              setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
            }
        }else{
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/turn", 0);
          interpolate("/controls/special/catapult-carrier-crane/multi-stand", -0.2, 0.6);
        }

        if(my_hdg >= 304.8 and my_hdg <= 305.2){
          step_by_step = 8;
        }else{
          step_by_step = 7;
        }
      }


      # Elevator
      if(step_by_step == 8){

        setprop("/controls/special/catapult-carrier-crane/pull", pull);
        setprop("/controls/special/catapult-carrier-crane/towel", towel);
        setprop("/controls/special/catapult-carrier-crane/turn", 0);

        if (real_heave_pos >= schw_catapult_alt - 1) {
          interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", 0, 10);
          interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0, 0.6);
          interpolate("/controls/special/catapult-carrier-crane/multi-turn", 332, 0.6);
          if(debug_ca) print("Plattform absenken");
        }
        if (real_heave_pos <= schw_catapult_alt - 4) {

          #  for multiplayer views #####################
          interpolate("/controls/special/catapult-carrier-crane/multi-turn", 0, 3);

          setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
          setprop("/controls/gear/brake-parking",1);
          setprop("/controls/gear/brake-left",1);
          setprop("/controls/gear/brake-right", 1);

          setprop("/controls/special/pos-olli", 1);

          if(debug_ca) print("Aushaengen");
        }
        
        if (!getprop("/controls/special/catapult-carrier-crane/hook-locked") and (getprop("/position/longitude-deg") > (schw_unmountLONAxis - 0.00009) )){
          interpolate ("/position/latitude-deg", catLatSchwabenland, 5);
          interpolate ("/position/longitude-deg", catLonSchwabenland, 5);
        }

        if (getprop("/position/longitude-deg") >= catLonSchwabenland - 0.000005){
           interpolate ("/position/latitude-deg", catLatSchwabenland, 0);
           interpolate ("/position/longitude-deg", catLonSchwabenland, 0);
           setprop("/controls/gear/brake-parking",1);
           setprop("/controls/gear/brake-left",1);
           setprop("/controls/gear/brake-right", 1);
           setprop("/controls/special/hold-pos", 1);
           setprop("/controls/special/catapult-carrier-crane/pull", 0);
           setprop("/controls/special/catapult-carrier-crane/towel", 0);
           setprop("/controls/special/catapult-carrier-crane/turn",0);
           screen.log.write("Please mount the hook yourself, you are cleared for take-off!", 1.0, 0.7, 0.0);
           setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
           if(debug_ca) print("on Cat position.");
        }
      }

      if(!getprop("/controls/special/catapult-carrier-crane/search-carrier")){

        # for multiplayer views #####################
        interpolate("/controls/special/catapult-carrier-crane/multi-turn",0, 3);

        interpolate("/ai/models/carrier["~schwabenland_index~"]/surface-positions/crane-heave", 0, 6);
        setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
        setprop("/controls/special/catapult-carrier-crane/towel",0);
        setprop("/controls/special/catapult-carrier-crane/pull", 0);
        setprop("/controls/special/catapult-carrier-crane/turn",0);
        setprop("/controls/gear/brake-parking",0);
        setprop("/controls/gear/brake-right", 0);
        setprop("/controls/gear/brake-left", 0);
        setprop("/controls/special/pos-olli", 1);
        step_by_step = 0;
      }

      # debug helper
      if(debug_ca){
        print("############################################");
        print("angle_to_crane: ", angle_to_crane);
        print("crane_to_plane: ", crane_to_plane);
        print("distance: ", distance);
        print("turn:  ",-turn);
        print("pull:  ", pull);
        print("towel: ", towel);
        print("step_by_step: ", step_by_step);
        print("my_hdg: ", my_hdg);
      }

    } # end schwabenland_index


    ######################### Action for WESTFALEN ################################################

    if (westfalen_index >= 0) {
      # Oliver Hardy always makes shit on heaving action, banned from deck ...
      setprop("/controls/special/pos-olli", 0);

      # The heaving altitude position
      var real_heave_pos = mp_cat_carrier[westfalen_index].getNode("surface-positions/crane-heave").getValue() or 0;

      # What is our position?
      var our_pos  = geo.aircraft_position();
      var hdg_to_crane = our_pos.course_to(west_crane_pos);
      var distance = our_pos.distance_to(west_crane_pos);
      var my_hdg = getprop("/orientation/heading-deg");
      var angle_to_crane = geo.normdeg(my_hdg - hdg_to_crane);
      var turn = getprop("/controls/flight/aileron") or 0;
      var pull = getprop("/controls/flight/elevator") or 0;
      var towel = getprop("/controls/flight/rudder") or 0;
      #var heave = getprop("/controls/engines/engine[0]/throttle") * schw_catapult_alt;

      var hdg_to_plane = west_crane_pos.course_to(our_pos);
      var crane_to_plane = geo.normdeg(hdg_to_plane - 70);  # 70 degree is the true course of westfalen;

      # if we are to fare away
      if(distance > 24 and getprop("/position/altitude-ft") < 30){
        setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
        screen.log.write("You are fare away from crane, come closer please!", 1.0, 0.7, 0.0);
        return;
      }
      ################################################################################################################
      ######### if we are on WAITING position and NOT on canvas ###
      if(step_by_step == 0 and getprop("/position/altitude-ft") > 23.0 and getprop("/position/altitude-ft") < 24.2){
        if(step_by_step == 0) setprop("/controls/special/catapult-carrier-crane/multi-turn", 359.9);
        interpolate("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane, 2);
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.3, 1);
        settimer( func { setprop("/controls/special/catapult-carrier-crane/hook-locked", 1); }, 1);
        setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt - 3);
        step_by_step = 99;
      }

      if(step_by_step == 99){

        setprop("/controls/special/catapult-carrier-crane/multi-turn", 346);

        if(getprop("/controls/special/catapult-carrier-crane/hook-locked")){
          if(real_heave_pos < 24.2){
            setprop("/controls/special/shadow", 0);
            # push the transparent heaving-object from the westfalen
            interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt, 4);
          }

          # 1/west_heave_alt cause crane stand is going form 1 to 0
          var crane_stand_factor = 1/west_heave_alt;
          crane_multi_stand = 1 - real_heave_pos * crane_stand_factor; 
          setprop("/controls/special/catapult-carrier-crane/multi-stand", crane_multi_stand);
          if(debug_ca) print("crane_stand ",crane_multi_stand);

          if(real_heave_pos >= west_heave_alt - 0.4){ 
              interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt - 0.4, 0);
              interpolate("/controls/special/catapult-carrier-crane/multi-stand", crane_multi_stand, 0);
              step_by_step = 3;
              internal_step = 0;
          }
        }
      }
      ########## END waiting pos heaving ###
      #################################################################################################################
      #### make a good position on the CANVAS before heaving start ###
      if(step_by_step == 0){
        setprop("/controls/gear/brake-parking", 1);
        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.2 and angle_to_crane < 180){
           if(angle_to_crane > 10){
             setprop("/controls/special/catapult-carrier-crane/towel",-1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.8){
           if(angle_to_crane < 350){
             setprop("/controls/special/catapult-carrier-crane/towel",1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel", 0.3);
           }
        }else{
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
        }

        # good distance to the crane
        if(distance <= 13  and getprop("/position/altitude-ft") < 5){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull",-0.7);
        }elsif(distance >= 15  and getprop("/position/altitude-ft") < 5){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }elsif(distance > 16  and getprop("/position/altitude-ft") < 5){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }else{
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        } 

        if((angle_to_crane < 0.2 or angle_to_crane > 359.08) and distance > 10 and distance < 16){
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
          settimer( func { screen.log.write("Heaving procedure is starting soon!", 1.0, 0.7, 0.0); }, 6);
          step_by_step = 1;
        }
      }

      # turn and descent the crane
      if(step_by_step == 1){
        interpolate("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane, 2);
        interpolate("/controls/special/catapult-carrier-crane/multi-stand", 1, 1.5);
        settimer( func { setprop("/controls/special/catapult-carrier-crane/hook-locked", 1); }, 11);
        settimer( func { step_by_step = 2; }, 11);
      }

      # heave onto catapult altitude
      if(step_by_step == 2){ 
   
        if(getprop("/sim/crashed")) {
          setprop("/controls/special/catapult-carrier-crane/hook-locked", 0);
          interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", 0, 6);
          setprop("/sim/crashed", 0);
        }

        # altitude is distance factor
        var alt_factor = 2.8 / west_heave_alt * real_heave_pos;
        if(debug_ca) print("alt_factor : ", alt_factor);
        if(distance <= 13){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull",-0.6);
        }elsif(distance > 16 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }elsif(distance >= 15 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }else{
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        }  

        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.2 and angle_to_crane < 180){
           if(angle_to_crane > 10){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.6);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.5){
           if(angle_to_crane < 350){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",0.6);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel", 0.3);
           }
        }else{
           internal_step = 1;
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
           interpolate("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane, 0);
        }

        if(internal_step == 1){

            setprop("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane);

            if(getprop("/controls/special/catapult-carrier-crane/hook-locked")){
              if(real_heave_pos < 1.5){
                setprop("/controls/special/shadow", 0);
                # push the transparent heaving-object from the westfalen
                interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt, 10);
              }

              # 1/west_heave_alt cause crane stand is going form 1 to 0
              var crane_stand_factor = 1/west_heave_alt;
              crane_multi_stand = 1 - real_heave_pos * crane_stand_factor; 
              setprop("/controls/special/catapult-carrier-crane/multi-stand", crane_multi_stand);
              if(debug_ca) print("crane_multi_stand ",crane_multi_stand);

              if(real_heave_pos >= west_heave_alt - 0.4){ 
                  interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt - 0.4, 0);
                  interpolate("/controls/special/catapult-carrier-crane/multi-stand", crane_multi_stand, 0);
                  step_by_step = 3;
                  internal_step = 0;
              }

            }

        } 
        if(debug_ca) print("internal_step ",internal_step);
     }

     # only correction on hightest heaving point, before turning the crane
     if(step_by_step == 3){
  
        setprop("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane);

        # altitude is distance factor
        var alt_factor = 2.8 / real_heave_pos;
        if(debug_ca) print("alt_factor : ", alt_factor);
        if(distance <= 14){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull",-0.6);
        }elsif(distance > 17 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }elsif(distance > 16.5 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.7);
        }elsif(distance >= 14.8 - alt_factor){
          setprop("/controls/gear/brake-parking", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }else{
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        }  

        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.2 and angle_to_crane < 180){
           if(angle_to_crane > 10){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.5);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",-0.2);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.5){
           if(angle_to_crane < 350){
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel",0.5);
           }else{
             setprop("/controls/gear/brake-parking", 1);
             setprop("/controls/special/catapult-carrier-crane/pull", 0);
             setprop("/controls/special/catapult-carrier-crane/towel", 0.2);
           }
        }else{
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/pull", 0);
           setprop("/controls/special/catapult-carrier-crane/towel", 0);
        }

        if (real_heave_pos >= west_heave_alt - 0.5 and distance < 13.5) {
          step_by_step = 4;
          interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt, 0);
          interpolate("/controls/special/catapult-carrier-crane/multi-stand", crane_multi_stand, 0);
          screen.log.write("Turn the crane with your yoke now!", 1.0, 0.7, 0.0);
        }

        if (real_heave_pos >= west_heave_alt - 0.5) {
          if(distance > 12.5){
            setprop("/controls/special/catapult-carrier-crane/pull", 1);
          }elsif(distance >= 12.3){
            setprop("/controls/special/catapult-carrier-crane/pull", 0.8);
          }elsif(distance >= 12.2){
            setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
          }elsif(distance <= 11){
            setprop("/controls/special/catapult-carrier-crane/pull", -1);
          }elsif(distance < 11.4){
            setprop("/controls/special/catapult-carrier-crane/pull", -0.8);
          }elsif(distance < 11.7){
            setprop("/controls/special/catapult-carrier-crane/pull", -0.3);
          }else{
            setprop("/controls/gear/brake-parking", 1);
            setprop("/controls/special/catapult-carrier-crane/pull", 0);
          }
        }

     } 

     # turning the crane
     if(step_by_step == 4){
        if(crane_to_plane < 270) allowed_to_descent_over_waiting = 1;
        # only if aircraft was heave over the towel sacks on board
        if ( crane_to_plane < 60 ) {
          setprop("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", west_heave_alt- 0.1);
          interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.0, 1);
        }

        setprop("/controls/special/catapult-carrier-crane/multi-turn", crane_to_plane);
        setprop("/controls/gear/brake-right", 0);
        setprop("/controls/gear/brake-left", 0);
        setprop("/controls/gear/brake-parking", 0);

        if(distance > 12.5){
          setprop("/controls/special/catapult-carrier-crane/pull", 1);
        }elsif(distance >= 12.3){
          setprop("/controls/special/catapult-carrier-crane/pull", 0.8);
        }elsif(distance >= 12.2){
          setprop("/controls/special/catapult-carrier-crane/pull", 0.5);
        }elsif(distance <= 11){
          setprop("/controls/special/catapult-carrier-crane/pull", -1);
        }elsif(distance < 11.4){
          setprop("/controls/special/catapult-carrier-crane/pull", -0.8);
        }elsif(distance < 11.7){
          setprop("/controls/special/catapult-carrier-crane/pull", -0.3);
        }else{
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
        } 


        # set the seaplane nose up to the crane
        if(angle_to_crane > 0.4 and angle_to_crane < 180 and distance > 11.7 and distance < 13){
           setprop("/controls/gear/brake-parking", 1);
           if(angle_to_crane > 2){
             setprop("/controls/special/catapult-carrier-crane/towel",-1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel",-0.6);
           }
        }elsif(angle_to_crane >= 180 and angle_to_crane < 359.4){
           if(angle_to_crane < 358){
             setprop("/controls/special/catapult-carrier-crane/towel", 1);
           }else{
             setprop("/controls/special/catapult-carrier-crane/towel", 0.6);
           }
        }else{
           # we have the nose in crane direction
           setprop("/controls/special/catapult-carrier-crane/towel", 0.0);
        }


        # push the thruster in the DO-J
        if(distance > 10.5 and distance < 13){
           setprop("/controls/special/catapult-carrier-crane/turn", -turn);
        }else{
           setprop("/controls/special/catapult-carrier-crane/turn", 0);
           setprop("/controls/gear/brake-right", 1);
           setprop("/controls/gear/brake-left", 1);
           setprop("/controls/gear/brake-parking", 1);
        }

        if(crane_to_plane > 25 and crane_to_plane < 27){
          step_by_step = 5;
        }
        if(crane_to_plane < 270) allowed_to_descent_over_waiting = 1; # check property for waiting pos
        if(crane_to_plane > 342 and crane_to_plane < 344 and allowed_to_descent_over_waiting){
          step_by_step = 90;
          allowed_to_descent_over_waiting = 0;
        }
        setprop("/sim/crashed", 0);
     }

     ##################################################################################
     #### step 90 is the same as 5, only for the waiting position
     # over the rails turn the towel
     if(step_by_step == 90){
        if(crane_to_plane < 270) allowed_to_descent_over_waiting = 1;
        if (distance > 10 and distance < 14.5){
          setprop("/controls/gear/brake-right", 1);
          setprop("/controls/gear/brake-left", 1);
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/turn", 0);

          setprop("/position/latitude-deg", waitLatWest3);
          setprop("/position/longitude-deg", waitLonWest3);

          setprop("/controls/special/catapult-carrier-crane/multi-turn", 346);

          if(my_hdg <= 248.5){
              if(my_hdg < 240){
                setprop("/controls/special/catapult-carrier-crane/towel",0.7);
              }else{
                setprop("/controls/special/catapult-carrier-crane/towel",0.4);
              }
          }elsif(my_hdg > 251.5){
              if(my_hdg > 259){
                setprop("/controls/special/catapult-carrier-crane/towel",-0.7);
              }else{
                setprop("/controls/special/catapult-carrier-crane/towel",-0.4);
              }
          }else{
            setprop("/controls/special/catapult-carrier-crane/pull", 0);
            setprop("/controls/special/catapult-carrier-crane/towel",0);
            setprop("/controls/special/catapult-carrier-crane/turn", 0);
            interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.2, 0.6);

            if (real_heave_pos >= west_heave_alt- 1) {
              interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", 0, 4);
              if(debug_ca) print("Plattform absenken");
            }
            settimer( func{ step_by_step = 91;}, 1);
          }
        }else{
          step_by_step = 4;
        }
      }

      if(step_by_step == 91){
          setprop("/position/latitude-deg", waitLatWest3);
          setprop("/position/longitude-deg", waitLonWest3);
          settimer( func{ doj.fromWestCraneToWait();}, 5);
          step_by_step = 7;
      }

     ### end steps for waiting position
     ##################################################################################

     # over the rails turn the towel
     if(step_by_step == 5){

        if (distance > 10 and distance < 14.5){
          setprop("/controls/gear/brake-right", 1);
          setprop("/controls/gear/brake-left", 1);
          setprop("/controls/gear/brake-parking", 1);
          setprop("/controls/special/catapult-carrier-crane/pull", 0);
          setprop("/controls/special/catapult-carrier-crane/towel",0);
          setprop("/controls/special/catapult-carrier-crane/turn", 0);

          setprop("/position/latitude-deg", west_unmountLATAxis);
          setprop("/position/longitude-deg", west_unmountLONAxis);

          setprop("/controls/special/catapult-carrier-crane/multi-turn", 26);

          if(my_hdg <= 252.5){
              if(my_hdg < 242){
                setprop("/controls/special/catapult-carrier-crane/towel",0.5);
              }else{
                setprop("/controls/special/catapult-carrier-crane/towel",0.3);
              }
          }elsif(my_hdg > 253.5){
              if(my_hdg > 263){
                setprop("/controls/special/catapult-carrier-crane/towel",-0.5);
              }else{
                setprop("/controls/special/catapult-carrier-crane/towel",-0.3);
              }
          }else{
            setprop("/controls/special/catapult-carrier-crane/pull", 0);
            setprop("/controls/special/catapult-carrier-crane/towel",0);
            setprop("/controls/special/catapult-carrier-crane/turn", 0);
            interpolate("/controls/special/catapult-carrier-crane/multi-stand", 0.1, 0.6);

            if (real_heave_pos >= west_heave_alt- 1 and my_hdg > 252.5 and my_hdg < 253.5) {
              interpolate("/ai/models/carrier["~westfalen_index~"]/surface-positions/crane-heave", 0, 0);
              if(debug_ca) print("Plattform absenken");
              step_by_step = 6;
            }
          }
        }else{
          step_by_step = 4;
        }
      }

      if(step_by_step == 6){
        setprop("/position/latitude-deg", west_unmountLATAxis);
        setprop("/position/longitude-deg", west_unmountLONAxis);
        step_by_step = 7;
      }

      # Elevator
      if(step_by_step == 7){

        if (real_heave_pos <= west_heave_alt- 4) {
          setprop("/controls/special/catapult-carrier-crane/search-carrier", 0);
          setprop("/controls/special/hold-pos", 1);
          if(debug_ca) print("Aushaengen");
        }
      }


      # debug helper
      if(debug_ca){
        print("############################################");
        print("angle_to_crane: ", angle_to_crane);
        print("crane_to_plane: ", crane_to_plane);
        print("real_heave_pos: ", real_heave_pos);
        print("distance: ", distance);
        print("turn:  ", turn);
        print("pull:  ", pull);
        print("towel: ", towel);
        print("step_by_step: ", step_by_step);
        print("my_hdg: ", my_hdg);
      }

    } # end westfalen_index


}
############################### end of main function for heaving ###########################################

# cam (catapult aircraft merchantman) in range all 11.125 sec. only
var is_cam_carrier = func {
    if (debug_cc) print("Suchfunktion is_cam_carrier aufgerufen."); 
    var mp_cat = props.globals.getNode("/ai/models").getChildren("carrier");
    var tt = size(mp_cat);
    var do_pos  = geo.aircraft_position();

    var shipsName = "";
    schwabenland_index = -1;
    westfalen_index = -1;

    settimer(func{ is_cam_carrier(); }, 11.125);

    for(var i = 0; i < tt; i += 1) {
        schwabenland_index = -1;
        westfalen_index = -1;

        if (mp_cat[i].getNode("name") != nil) var shipsName = mp_cat[i].getNode("name").getValue();
        if (shipsName == "Schwabenland" and do_pos.distance_to(schw_crane_pos) < max_dis_to_carrier ){
          if (debug_cc) print(shipsName~" gefunden");
          schwabenland_index = i;
          return;
        }

        if (shipsName == "Westfalen" and do_pos.distance_to(west_crane_pos) < max_dis_to_carrier){
          if (debug_cc) print(shipsName~" gefunden");
          westfalen_index = i;
          return;
        }
    }
}

# main function to look always, who is the master of cargo and crane :-)
var is_other = func {

    var mpOther = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var otherNr = size(mpOther);

    is_engaged = -1;
    is_heaving = -1;
    
    if (debug_sc) print("otherNr:" ~otherNr);

    # find other DO-J which are on cat or crane
    for(var v = 0; v < otherNr; v += 1) {

       if (mpOther[v].getNode("sim/model/path").getValue() == "Aircraft/DO-J-II/Models/DO-J-II.xml" and
           mpOther[v].getNode("id").getValue() >= 0 ) {

           var searchCrane = mpOther[v].getNode("sim/multiplay/generic/int[18]").getValue() or 0;

           if (( mpOther[v].getNode("sim/multiplay/generic/string[1]").getValue() == "Engaged" or 
                 mpOther[v].getNode("sim/multiplay/generic/string[1]").getValue() == "Launching")){
               if(is_engaged >= 0){ 
                  is_engaged = is_engaged;
               }else{
                  is_engaged = v;
               }
           }

           if (searchCrane){
               if(is_heaving >= 0){ 
                  is_heaving = is_heaving;
               }else{
                  is_heaving = v;
               }
           }
       }
    }
}

# only for start-up, if other multiplayer are not on cat or crane action but in range
var init_cargo = func {
    var mpDos = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var otherdos = size(mpDos);

    for(var d = 0; d < otherdos; d += 1) {

        if (mpDos[d].getNode("sim/model/path").getValue() == "Aircraft/DO-J-II/Models/DO-J-II.xml" and
            mpDos[d].getNode("id").getValue() >= 0 and
            found_cargo != 1) {

          setprop("/controls/special/catapult-carrier-crane/cargo-schwabenland",
                  getprop("/ai/models/multiplayer["~d~"]/sim/multiplay/generic/float[15]") or 0);

          setprop("/controls/special/catapult-carrier-crane/cargo-westfalen",
                  getprop("/ai/models/multiplayer["~d~"]/sim/multiplay/generic/float[18]") or 0);

          var nameOf = getprop("/ai/models/multiplayer["~d~"]/callsign");
          screen.log.write("You recept loading informations from "~ nameOf ~".", 0.9, 0.8, 0.0); 
          found_cargo = 1;
      }
    }

}

################################ Take cargo on both the Westfalen or Schwabenland ##################################
# if we click on the cargo also work for westfalen
setlistener("/controls/special/catapult-carrier-crane/cargo-schwabenland-toggle", func {
   doj.take_cargo();
}, 0, 1);

var take_cargo = func () {
    var allowed = getprop("/gear/launchbar/state") or "";

    if(allowed == "Engaged"){
      var freight = props.globals.getNode("/sim/weight[1]/weight-lb");
      var cam_path = "";
      if(schwabenland_index >= 0) cam_path = "/controls/special/catapult-carrier-crane/cargo-schwabenland";
      if(westfalen_index >= 0) cam_path = "/controls/special/catapult-carrier-crane/cargo-westfalen";

      if(freight.getValue() < 7000 and cam_path != "") {
          if(schwabenland_index >= 0) setprop(cam_path, (getprop(cam_path) - 1));
          if(westfalen_index >= 0) setprop(cam_path, (getprop(cam_path) - 1));
          if (freight.getValue() >= 4999 and freight.getValue() < 7000 ) freight.setValue(7000.0);
          if (freight.getValue() >= 2499 and freight.getValue() < 5000) freight.setValue(4999.0);
          if (freight.getValue() < 2500) freight.setValue(2499.0);
      }else{
        var gw = getprop("/yasim/gross-weight-lbs") or 0;
        var kg = gw/2.20462262185;
        gw = int(gw); 
        kg = int(kg);  
        screen.log.write("Loading is finished. Your weight is "~gw~" lb / "~kg~" kg now!", 1.0, 0.7, 0.0);
      }
    }else{
      screen.log.write("Please mount the catapult. You can't load before!", 1.0, 0.7, 0.0);
    }
}
# will called, if somebody comes with loading on the canvas for heaving. So put the cargo on the deck :-)
var unload_cargo = func() {
    var freight = props.globals.getNode("/sim/weight[1]/weight-lb"); 
    var cam_path = "";
    if(schwabenland_index >= 0) cam_path = "/controls/special/catapult-carrier-crane/cargo-schwabenland";
    if(westfalen_index >= 0) cam_path = "/controls/special/catapult-carrier-crane/cargo-westfalen"; 

    if(cam_path != ""){
      if (freight.getValue() > 5000 and freight.getValue() <= 7000 ){
          setprop(cam_path, (getprop(cam_path) + 3 ));
      }
      if (freight.getValue() > 2500 and freight.getValue() <= 5000){
          setprop(cam_path, (getprop(cam_path) + 2 ));
      }
      if (freight.getValue() > 800 and freight.getValue() <= 2500){
          setprop(cam_path, (getprop(cam_path) + 1 ));
      }
    }

    freight.setValue(500); # is the standard weight for the heaving action
}

######################################## Where we find Oliver Hardy ########################################
# this function called on fdm init - looking if you are on cat or waiting position
var whereIsOlli = func {
     var alti = props.globals.getNode("/position/altitude-ft").getValue() or 0;
     if (alti > 36.5 and alti <= 38.5) {
         setprop("/controls/special/pos-olli", 1);
         setprop("/controls/special/hold-pos", 1);
     }elsif (alti > 39.5 and alti < 42) {
         setprop("/controls/special/pos-olli", 3);
         setprop("/controls/special/hold-pos", 1);
     }
}

##################### happens, if you click on Stan Laurel or Shift + l #####################################
var hookTheCatapult = func {
    if(getprop("/controls/special/catapult-carrier-crane/crane-is-free") and !getprop("/controls/special/catapult-carrier-crane/search-carrier")) {
      setprop("/controls/gear/launchbar", 1);
    }else{
      if(schwabenland_index >= 0){
        screen.log.write("Not possible for the moment, please go back to waiting position!", 1.0, 0.7, 0.0);
      }
      if(westfalen_index >= 0){
        setprop("/controls/gear/launchbar", 1);
      }
    
    }
}

