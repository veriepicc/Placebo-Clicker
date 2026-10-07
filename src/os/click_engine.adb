with System; use type System.Address;
with System.Storage_Elements;
with Interfaces; use Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Exceptions;
with Ada.Unchecked_Conversion;
with Win32; use Win32;
with Win32.User32; use Win32.User32;

package body Click_Engine with SPARK_Mode => Off is

   use type Clicker_Core.Decision;

   Seed     : Unsigned_64 := 16#9E3779B97F4A7C15#;
   Prev_B   : Boolean := False;
   Handled  : Natural := 0;
   Latch    : Boolean := False;
   Tag_Addr : constant System.Address :=
     System.Storage_Elements.To_Address
       (System.Storage_Elements.Integer_Address (Injected_Tag));
   Mc_Found : Boolean := False;
   Mc_Focus : Boolean := False;
   Mc_Hwnd  : HANDLE := System.Null_Address;
   Mc_Check : Time := Time_First;
   Scans    : Natural := 0;

   L_St : Clicker_Core.Button_State := (False, 0, 0);
   R_St : Clicker_Core.Button_State := (False, 0, 0);
   L_Delay : Float := 80.0;
   R_Delay : Float := 80.0;
   Ms_Base : Time := Time_First;
   Ms_Set  : Boolean := False;

   protected body State is
      function Get return Snapshot is
        (Left => L, Right => R, Priming => P, Armed => A, Bind => B,
         Mc_Found => M_Found, Mc_Focused => M_Focus,
         Sent => N_Sent, Failed => N_Failed, Dead => Dead_F);

      procedure Note_Dead is
      begin
         Dead_F := True;
      end Note_Dead;

      procedure Note_Failed is
      begin
         N_Failed := N_Failed + 1;
      end Note_Failed;

      procedure Note_Sent is
      begin
         N_Sent := N_Sent + 1;
      end Note_Sent;

      procedure Set_Bind (B : Integer) is
      begin
         State.B := B;
      end Set_Bind;

      procedure Set_Cps (Left : Boolean; Mn, Mx : Integer) is
         Tmp : Clicker_Core.Clicker_Cfg :=
           Clicker_Core.Clamp_Cps (Mn, Mx);
      begin
         if Left then
            Tmp.Enabled := L.Enabled;
            Tmp.Randomize := L.Randomize;
            L := Tmp;
         else
            Tmp.Enabled := R.Enabled;
            Tmp.Randomize := R.Randomize;
            R := Tmp;
         end if;
      end Set_Cps;

      procedure Set_Left (E : Boolean) is
      begin
         L.Enabled := E;
      end Set_Left;

      procedure Set_Mc (Found, Focused : Boolean) is
      begin
         M_Found := Found;
         M_Focus := Focused;
      end Set_Mc;

      procedure Set_Priming (P : Boolean) is
      begin
         State.P := P;
      end Set_Priming;

      procedure Set_Right (E : Boolean) is
      begin
         R.Enabled := E;
      end Set_Right;

      procedure Toggle_Armed is
      begin
         A := not A;
      end Toggle_Armed;
   end State;

   function Find_Mc_Window return HANDLE;

   function Key_Down (Vk : Integer_32) return Boolean;

   procedure Log (Msg : String);

   procedure Mc_Refresh (Now : Time);

   protected body Phys is
      procedure Bump is
      begin
         Pc := Pc + 1;
      end Bump;

      function Get return Phys_Snap is
        (L => Pl, R => Pr, Presses => Pc);

      procedure Set_L (B : Boolean) is
      begin
         Pl := B;
      end Set_L;

      procedure Set_R (B : Boolean) is
      begin
         Pr := B;
      end Set_R;
   end Phys;

   procedure Rnd32 (V : out Unsigned_32);

   procedure Send_Click (Down : Boolean; Right : Boolean);

   procedure Tick (S : out Snapshot);

   task body Engine is
      S : Snapshot;
   begin
      Log ("engine up");
      Log ("input bytes:" & Integer'Image (INPUT'Object_Size / 8));
      loop
         Tick (S);
         delay until Clock + Milliseconds (1);
      end loop;
   exception
      when E : others =>
         State.Note_Dead;
         Log ("engine dead: " & Ada.Exceptions.Exception_Information (E));
   end Engine;

   task body Hook_Pump is
      type Hook_Ptr is access MSLLHOOKSTRUCT;
      function To_Data is new Ada.Unchecked_Conversion
        (LPARAM, Hook_Ptr);

      function Cb (Code : Integer_32; Msg : WPARAM; Param : LPARAM)
        return LRESULT;
      pragma Convention (Stdcall, Cb);

      function Cb (Code : Integer_32; Msg : WPARAM; Param : LPARAM)
        return LRESULT
      is
         D : constant Hook_Ptr := To_Data (Param);
      begin
         if Code = HC_ACTION then
            if Interfaces."and" (D.Flags, DWORD (LLMHF_INJECTED)) = 0 and
              D.Extra /= Tag_Addr
            then
               if Msg = WM_LBUTTONDOWN then
                  Phys.Set_L (True);
                  Phys.Bump;
               elsif Msg = WM_LBUTTONUP then
                  Phys.Set_L (False);
               elsif Msg = WM_RBUTTONDOWN then
                  Phys.Set_R (True);
               elsif Msg = WM_RBUTTONUP then
                  Phys.Set_R (False);
               end if;
            end if;
         end if;
         return Call_Next (System.Null_Address, Code, Msg, Param);
      exception
         when others =>
            return Call_Next (System.Null_Address, Code, Msg, Param);
      end Cb;

      Hk : HANDLE;
      M  : aliased MSG;
      R  : Integer_32;
   begin
      Hk := Set_Hook
        (WH_MOUSE_LL, Cb'Address,
         Get_Module_Handle (System.Null_Address), 0);
      if Hk = System.Null_Address then
         State.Note_Failed;
         Log ("hook failed");
      else
         Log ("hook up");
      end if;
      loop
         exit when Get_Message (M'Access, System.Null_Address, 0, 0) <= 0;
         R := Translate_Message (M'Access);
         if R < 0 then
            State.Note_Failed;
         end if;
         declare
            D : constant LRESULT := Dispatch_Message (M'Access);
         begin
            if D = LRESULT'Last then
               State.Note_Failed;
            end if;
         end;
      end loop;
      Log ("pump dead");
   end Hook_Pump;

   --  find mc by window title, exe names lie but the
   --  title bar says Minecraft. prefix match so suffixes pass
   function Find_Mc_Window return HANDLE is
      Want : constant char_array := To_C ("Minecraft");
      Got : HANDLE := System.Null_Address;

      function Cb (W : HWND; Lp : LPARAM) return BOOL;
      pragma Convention (Stdcall, Cb);

      function Cb (W : HWND; Lp : LPARAM) return BOOL is
         pragma Unreferenced (Lp);
         Buf : aliased char_array (0 .. 255) := [others => nul];
         N   : Integer_32;
      begin
         if Is_Visible (W) = 0 then
            return 1;
         end if;
         N := Get_Window_Text (W, Buf'Address, 256);
         if Scans = 1 and N > 0 then
            Log ("win: " & To_Ada (Buf));
         end if;
         if N >= 9 then
            for I in Interfaces.C.size_t range 0 .. 8 loop
               if Buf (I) /= Want (I) then
                  return 1;
               end if;
            end loop;
            Got := W;
            return 0;
         end if;
         return 1;
      end Cb;

      R : Integer_32;
   begin
      Scans := Scans + 1;
      Log ("enum start");
      R := Enum_Windows (Cb'Address, 0);
      if Got = System.Null_Address then
         Log ("enum done none");
      else
         Log ("enum done found");
      end if;
      if R = 0 and Got = System.Null_Address then
         State.Note_Failed;
      end if;
      return Got;
   end Find_Mc_Window;

   function Key_Down (Vk : Integer_32) return Boolean is
   begin
      return Get_Async_Key_State (Vk) < 0;
   end Key_Down;

   procedure Log (Msg : String) is
      pragma Unreferenced (Msg);
   begin
      null;
   end Log;

   procedure Mc_Refresh (Now : Time) is
      Found   : Boolean := Mc_Found;
      Focused : Boolean := False;
   begin
      --  or else matters: Now - Time_First overflows realtime
      --  window hunt stays slow, focus check runs every
      --  tick so tabbing in/out reacts instantly
      if Mc_Check = Time_First or else
        Now - Mc_Check > Milliseconds (2000)
      then
         Mc_Check := Now;
         Mc_Hwnd := Find_Mc_Window;
         Found := Mc_Hwnd /= System.Null_Address;
      end if;
      if Found then
         Focused := Get_Foreground = Mc_Hwnd;
      end if;
      if Found /= Mc_Found or Focused /= Mc_Focus then
         Log ("mc found:" & Found'Image & " focus:" & Focused'Image);
         Mc_Found := Found;
         Mc_Focus := Focused;
      end if;
      State.Set_Mc (Mc_Found, Mc_Focus);
   end Mc_Refresh;

   procedure Rnd32 (V : out Unsigned_32) is
      X : Unsigned_64 := Seed;
   begin
      X := X xor Shift_Left (X, 13);
      X := X xor Shift_Right (X, 7);
      X := X xor Shift_Left (X, 17);
      Seed := X;
      V := Unsigned_32 (X mod 16#FFFF_FFFF#);
   end Rnd32;

   procedure Send_Click (Down : Boolean; Right : Boolean) is
      Flag : DWORD;
      Inp  : aliased INPUT;
      R    : DWORD;
   begin
      if Down then
         if Right then
            Flag := MOUSEEVENTF_RIGHTDOWN;
         else
            Flag := MOUSEEVENTF_LEFTDOWN;
         end if;
      else
         if Right then
            Flag := MOUSEEVENTF_RIGHTUP;
         else
            Flag := MOUSEEVENTF_LEFTUP;
         end if;
      end if;
      Inp :=
        (Kind => INPUT_MOUSE, Pad => 0, Dx => 0, Dy => 0, Data => 0,
         Flags => Flag, Time => 0, Extra => Tag_Addr);
      R := Send_Input (1, Inp'Address, Integer_32 (INPUT'Object_Size / 8));
      if R /= 1 then
         State.Note_Failed;
         Log ("send fail err" & Integer'Image (Integer (Get_Last_Error)));
      else
         State.Note_Sent;
      end if;
   end Send_Click;

   procedure Tick (S : out Snapshot) is
      Now    : constant Time := Clock;
      Ps     : Phys_Snap;
      Armed  : Boolean;
      Lh     : Boolean;
      Rh     : Boolean;
      Bd     : Boolean;
      Rgate  : Boolean;
      J1     : Float;
      J2     : Float;
      R1     : Unsigned_32;
      R2     : Unsigned_32;
      R3     : Unsigned_32;
      Cps    : Clicker_Core.Cps_Value;
      Ms     : Integer;
      Lg     : Boolean;
      Rg     : Boolean;
   begin
      S := State.Get;
      Mc_Refresh (Now);
      Ps := Phys.Get;
      if not Ms_Set then
         Ms_Base := Now;
         Ms_Set := True;
      end if;
      Ms := Integer (To_Duration (Now - Ms_Base) * 1000.0);
      if Ms > 2_000_000_000 then
         --  24 day overflow guard, release first so the
         --  game never keeps a stuck button
         if L_St.Down then
            Send_Click (False, False);
         end if;
         if R_St.Down then
            Send_Click (False, True);
         end if;
         Ms_Base := Now;
         Ms := 0;
         L_St := (Down => False, Next_Fire => 0, Up_At => 0);
         R_St := (Down => False, Next_Fire => 0, Up_At => 0);
      end if;

      Lh := Ps.L;
      Rh := Ps.R;

      if S.Bind /= 0 then
         Bd := Key_Down (Integer_32 (S.Bind));
         if Bd and not Prev_B then
            State.Toggle_Armed;
            S.Armed := not S.Armed;
         end if;
         Prev_B := Bd;
      end if;
      Armed := S.Bind = 0 or S.Armed;

      if S.Priming and Rh and Ps.Presses /= Handled then
         Latch := True;
      end if;
      if not Rh then
         Latch := False;
      end if;
      Handled := Ps.Presses;

      Lg := S.Left.Enabled and Armed and Mc_Found and Mc_Focus and Lh;
      if not L_St.Down and Lg and Ms >= L_St.Next_Fire then
         Rnd32 (R1);
         Rnd32 (R2);
         Rnd32 (R3);
         J1 := Float (R1 mod 1_000_000) / 1_000_000.0;
         J2 := Float (R2 mod 1_000_000) / 1_000_000.0;
         Cps := Clicker_Core.Pick_Cps (S.Left, R3);
         L_Delay := Clicker_Core.Next_Delay (S.Left, Cps, J1, J2);
      end if;
      declare
         Res : constant Clicker_Core.Step_Out :=
           Clicker_Core.Step (Lg, Ms, L_St, L_Delay);
      begin
         if Res.Act = Clicker_Core.Press then
            Send_Click (True, False);
         end if;
         if Res.Act = Clicker_Core.Release then
            Send_Click (False, False);
         end if;
         L_St := Res.Next;
      end;

      if S.Priming then
         Rgate := Latch;
      else
         Rgate := Rh;
      end if;
      Rg := S.Right.Enabled and Armed and Mc_Found and Mc_Focus and Rgate;
      if not R_St.Down and Rg and Ms >= R_St.Next_Fire then
         Rnd32 (R1);
         Rnd32 (R2);
         Rnd32 (R3);
         J1 := Float (R1 mod 1_000_000) / 1_000_000.0;
         J2 := Float (R2 mod 1_000_000) / 1_000_000.0;
         Cps := Clicker_Core.Pick_Cps (S.Right, R3);
         R_Delay := Clicker_Core.Next_Delay (S.Right, Cps, J1, J2);
      end if;
      declare
         Res : constant Clicker_Core.Step_Out :=
           Clicker_Core.Step (Rg, Ms, R_St, R_Delay);
      begin
         if Res.Act = Clicker_Core.Press then
            Send_Click (True, True);
         end if;
         if Res.Act = Clicker_Core.Release then
            Send_Click (False, True);
         end if;
         R_St := Res.Next;
      end;
   end Tick;

end Click_Engine;
