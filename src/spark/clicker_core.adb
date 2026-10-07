package body Clicker_Core with SPARK_Mode => On is

   function Clamp_Cps (Raw_Min, Raw_Max : Integer) return Clicker_Cfg is
      Lo : Integer := Raw_Min;
      Hi : Integer := Raw_Max;
   begin
      if Lo < 1 then
         Lo := 1;
      elsif Lo > 60 then
         Lo := 60;
      end if;
      if Hi < 1 then
         Hi := 1;
      elsif Hi > 60 then
         Hi := 60;
      end if;
      if Hi < Lo then
         Hi := Lo;
      end if;
      return (Enabled   => True,
              Randomize => True,
              Min_Cps   => Lo,
              Max_Cps   => Hi);
   end Clamp_Cps;

   function Hold_For (Gap : Float) return Float is
   begin
      return Float'Min (25.0, Gap * 0.45);
   end Hold_For;

   function Next_Delay
     (Cfg        : Clicker_Cfg;
      Cps_Pick   : Cps_Value;
      Jitter_01  : Float;
      Spike_Roll : Float) return Delay_Ms
   is
      --  integer division first: provers crush linear int
      --  math but struggle bounding float division. sub-ms
      --  precision loss drowns in the jitter below anyway.
      Base : constant Float := Float (1000 / Cps_Pick);
      D    : Float := Base;
   begin
      if Cfg.Randomize then
         D := D + (Jitter_01 - 0.5) * 6.0;
         if Spike_Roll < 0.08 then
            D := D * 0.45;
         elsif Spike_Roll > 0.97 then
            D := D * 2.0;
         end if;
      end if;
      --  hard bounds by construction, not branches
      D := Float'Max (D, 1.0);
      D := Float'Min (D, 5_000.0);
      return D;
   end Next_Delay;

   function Pick_Cps
     (Cfg : Clicker_Cfg;
      Raw : Interfaces.Unsigned_32) return Cps_Value
   is
      N : constant Natural :=
        Natural (Cfg.Max_Cps - Cfg.Min_Cps) + 1;
      K : constant Natural :=
        Natural (Interfaces."mod" (Raw, Interfaces.Unsigned_32 (N)));
   begin
      return Cps_Value (Natural (Cfg.Min_Cps) + K);
   end Pick_Cps;

   function Step
     (Gate  : Boolean;
      Now   : Integer;
      St    : Button_State;
      Gap   : Float) return Step_Out
   is
      Hold : constant Float := Hold_For (Gap);
   begin
      if not Gate then
         if St.Down then
            return (Release, (Down => False, Next_Fire => Now, Up_At => Now));
         end if;
         return (None, (Down => False, Next_Fire => Now, Up_At => Now));
      end if;
      if not St.Down and then Now >= St.Next_Fire then
         return (Press,
           (Down      => True,
            Next_Fire => Now + Integer (Gap),
            Up_At     => Now + Integer (Hold)));
      end if;
      if St.Down and then Now >= St.Up_At then
         return (Release,
           (Down => False, Next_Fire => St.Next_Fire, Up_At => St.Up_At));
      end if;
      return (None, St);
   end Step;

end Clicker_Core;
