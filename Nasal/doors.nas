# =====
# Doors
# =====

Doors = {};

Doors.new = func {
   obj = { parents : [Doors],
           passenger : aircraft.door.new("instrumentation/doors/passenger", 2.0),
           rearL : aircraft.door.new("instrumentation/doors/rearL", 2.0),
           frontR : aircraft.door.new("instrumentation/doors/frontR", 2.0),
           frontL : aircraft.door.new("instrumentation/doors/frontL", 2.0),
         };
   return obj;
};

Doors.passengerexport = func {
   me.passenger.toggle();
}
Doors.rearLexport = func {
   me.rearL.toggle();
}
Doors.frontRexport = func {
   me.frontR.toggle();
}
Doors.frontLexport = func {
   me.frontL.toggle();
}

# ==============
# Initialization
# ==============

# objects must be here, otherwise local to init()
doorsystem = Doors.new();

