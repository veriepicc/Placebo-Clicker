with Clicker_Core;
pragma Elaborate_All (Clicker_Core);

package Click_Engine with SPARK_Mode => Off is

   type Snapshot is record
      Left       : Clicker_Core.Clicker_Cfg;
      Right      : Clicker_Core.Clicker_Cfg;
      Priming    : Boolean;
      Armed      : Boolean;
      Bind       : Integer;
      Mc_Found   : Boolean;
      Mc_Focused : Boolean;
      Sent       : Natural;
      Failed     : Natural;
      Dead       : Boolean;
   end record;

   protected State is
      procedure Set_Left (E : Boolean);
      procedure Set_Right (E : Boolean);
      procedure Set_Priming (P : Boolean);
      procedure Set_Bind (B : Integer);
      procedure Set_Cps (Left : Boolean; Mn, Mx : Integer);
      procedure Set_Mc (Found, Focused : Boolean);
      procedure Note_Dead;
      procedure Note_Failed;
      procedure Note_Sent;
      procedure Toggle_Armed;
      function Get return Snapshot;
   private
      L : Clicker_Core.Clicker_Cfg :=
        (Enabled => False, Randomize => False, Min_Cps => 12, Max_Cps => 14);
      R : Clicker_Core.Clicker_Cfg :=
        (Enabled => False, Randomize => False, Min_Cps => 15, Max_Cps => 17);
      P : Boolean := False;
      A : Boolean := True;
      B : Integer := 0;
      M_Found : Boolean := False;
      M_Focus : Boolean := False;
      N_Sent : Natural := 0;
      N_Failed : Natural := 0;
      Dead_F : Boolean := False;
   end State;

   task Engine;

   type Phys_Snap is record
      L       : Boolean;
      R       : Boolean;
      Presses : Natural;
   end record;

   protected Phys is
      procedure Bump;
      function Get return Phys_Snap;
      procedure Set_L (B : Boolean);
      procedure Set_R (B : Boolean);
   private
      Pl : Boolean := False;
      Pr : Boolean := False;
      Pc : Natural := 0;
   end Phys;

   task Hook_Pump;

end Click_Engine;
