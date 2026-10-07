with Interfaces;

package Clicker_Core with SPARK_Mode => On is

   subtype Cps_Value is Integer range 1 .. 60;
   subtype Delay_Ms is Float range 1.0 .. 5_000.0;

   type Clicker_Cfg is record
      Enabled   : Boolean;
      Randomize : Boolean;
      Min_Cps   : Cps_Value;
      Max_Cps   : Cps_Value;
   end record with Dynamic_Predicate => Min_Cps <= Max_Cps;

   --  base delay from cps, no rng here so its provable
   function Clamp_Cps (Raw_Min, Raw_Max : Integer) return Clicker_Cfg with
     Post => Clamp_Cps'Result.Min_Cps <= Clamp_Cps'Result.Max_Cps;

   --  next delay with uniform jitter in [-3.0, 3.0]ms + gaussianish sigma
   --  Jitter_01 in [0.0, 1.0], caller supplies rng output so core stays pure
   function Next_Delay
     (Cfg       : Clicker_Cfg;
      Cps_Pick  : Cps_Value;
      Jitter_01 : Float;
      Spike_Roll : Float) return Delay_Ms with
     Pre  => Jitter_01 in 0.0 .. 1.0 and Spike_Roll in 0.0 .. 1.0,
     Post => Next_Delay'Result in 1.0 .. 5_000.0;

   --  press scheduling, pure: no clock, no rng, no syscalls.
   --  Now is monotonic ms from the caller. hold auto-shrinks
   --  with the interval so 60 cps stays reachable.
   type Decision is (None, Press, Release);

   type Button_State is record
      Down      : Boolean;
      Next_Fire : Integer;
      Up_At     : Integer;
   end record;

   type Step_Out is record
      Act  : Decision;
      Next : Button_State;
   end record;

   function Hold_For (Gap : Float) return Float with
     Pre  => Gap in 1.0 .. 5_000.0,
     Post => Hold_For'Result in 0.0 .. 25.0;

   --  uniform cps pick from raw rng bits. mod, never round,
   --  so the result cant escape Min .. Max by construction
   function Pick_Cps
     (Cfg : Clicker_Cfg;
      Raw : Interfaces.Unsigned_32) return Cps_Value with
     Post => Pick_Cps'Result in Cfg.Min_Cps .. Cfg.Max_Cps;

   function Step
     (Gate  : Boolean;
      Now   : Integer;
      St    : Button_State;
      Gap   : Float) return Step_Out with
     Pre  => Now in 0 .. Integer'Last - 10_000 and
             St.Next_Fire in 0 .. Integer'Last - 10_000 and
             St.Up_At in 0 .. Integer'Last - 10_000 and
             Gap in 1.0 .. 5_000.0,
     Post =>
       (if St.Down then Step'Result.Act /= Press) and
       (if not Gate then Step'Result.Act /= Press) and
       (if not Gate and St.Down then Step'Result.Act = Release) and
       (if not Gate then not Step'Result.Next.Down) and
       (if Gate and not St.Down and Now >= St.Next_Fire then
          Step'Result.Act = Press);

end Clicker_Core;
