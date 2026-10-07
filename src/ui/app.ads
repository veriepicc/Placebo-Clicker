with Clicker_Core;

package App with SPARK_Mode => Off is

   type Settings is record
      Left   : Clicker_Core.Clicker_Cfg :=
        (Enabled => False, Randomize => False, Min_Cps => 12, Max_Cps => 14);
      Right  : Clicker_Core.Clicker_Cfg :=
        (Enabled => False, Randomize => False, Min_Cps => 15, Max_Cps => 17);
      Priming : Boolean := False;
      Bind    : Integer := 0;
      Armed   : Boolean := True;
      Mc_Found : Boolean := False;
      Mc_Focus : Boolean := False;
      Dead    : Boolean := False;
   end record;

   procedure Run (H : Integer := 0);

   function Current return Settings;

end App;
