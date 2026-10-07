with System; use type System.Address;
with System.Storage_Elements;
with Interfaces; use Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Text_IO;
with Click_Engine;
pragma Elaborate_All (Click_Engine);
with Win32; use Win32;
with Win32.User32; use Win32.User32;
with Win32.Gdi32; use Win32.Gdi32;

package body App with SPARK_Mode => Off is

   G : Settings;

   Cls_Name  : aliased char_array := To_C ("AdaClicker");
   Win_Title : aliased char_array := To_C ("placebo");
   Face_Name : aliased char_array := To_C ("Segoe UI");
   Solo_Name : aliased char_array := To_C ("AdaClickerSolo");

   T_App : aliased char_array := To_C ("placebo");

   Main_W    : HWND := System.Null_Address;
   Dark_Bg   : HBRUSH := System.Null_Address;
   Pink_Br   : HBRUSH := System.Null_Address;
   Card_Br   : HBRUSH := System.Null_Address;
   Card_Hov  : HBRUSH := System.Null_Address;
   Track_Br  : HBRUSH := System.Null_Address;
   White_Br  : HBRUSH := System.Null_Address;
   Green_Br  : HBRUSH := System.Null_Address;
   Dim_Br    : HBRUSH := System.Null_Address;
   Null_Pen  : HPEN := System.Null_Address;
   Arrow_Cur : HCURSOR := System.Null_Address;

   Title_F : HFONT := System.Null_Address;
   Ui_F    : HFONT := System.Null_Address;
   Small_F : HFONT := System.Null_Address;

   Hover     : Integer := -1;
   Dragging  : Integer := -1;
   Cap_Prev  : HWND := System.Null_Address;
   Anim_L    : Float := 0.0;
   Anim_R    : Float := 0.0;
   Anim_P    : Float := 0.0;
   Tick      : Natural := 0;
   Capturing : Boolean := False;
   Cfg_Dirty : Boolean := False;
   Save_At   : Natural := 0;

   function Bind_Str return String;
   function Config_Path return String;
   function Hit_Test (X : Integer_32; Y : Integer_32) return Integer;
   function Img (V : Integer) return String;
   function Key_Name (V : Natural) return String;
   procedure Load_Cfg;
   procedure Log (Msg : String);
   procedure Mark_Dirty;
   procedure Paint (W : HWND);
   procedure Poll_Bind;
   procedure Save_Cfg;
   function Status_Str return String;
   function Slider_Hit
     (Top : Integer_32; X : Integer_32; Y : Integer_32; Base : Integer)
      return Integer;
   procedure Slider_Set (Code : Integer; X : Integer_32);
   function Wnd_Proc
     (W : HWND; M : UINT; Wp : WPARAM; Lp : LPARAM)
      return LRESULT;
   pragma Convention (Stdcall, Wnd_Proc);

   function Bind_Str return String is
   begin
      if Capturing then
         return "bind: press a key (esc cancels)";
      elsif G.Bind = 0 then
         return "bind: none";
      elsif G.Armed then
         return "bind: " & Key_Name (G.Bind) & " [ON]";
      else
         return "bind: " & Key_Name (G.Bind) & " [OFF]";
      end if;
   end Bind_Str;

   function Current return Settings is (G);

   function Config_Path return String is
      Buf : aliased char_array (0 .. 259) := [others => nul];
      N : Integer_32;
   begin
      N := Get_Module_File_Name
        (System.Null_Address, Buf'Address, 260);
      if N <= 0 then
         return "placebo.ini";
      end if;
      declare
         Full : constant String := To_Ada (Buf);
         Last : Natural := Full'Last;
      begin
         while Last > Full'First and then Full (Last) /= '\' loop
            Last := Last - 1;
         end loop;
         return Full (Full'First .. Last) & "placebo.ini";
      end;
   end Config_Path;

   function Hit_Test (X : Integer_32; Y : Integer_32) return Integer is
   begin
      if X >= 16 and X <= 404 then
         if Y >= 40 and Y <= 136 then
            return 0;
         elsif Y >= 144 and Y <= 240 then
            return 1;
         elsif Y >= 248 and Y <= 304 then
            return 2;
         elsif Y >= 312 and Y <= 356 then
            return 3;
         end if;
      end if;
      return -1;
   end Hit_Test;

   function Img (V : Integer) return String is
      S : constant String := Integer'Image (V);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   function Key_Name (V : Natural) return String is
   begin
      case V is
         when 8 => return "backspace";
         when 9 => return "tab";
         when 13 => return "enter";
         when 16 => return "shift";
         when 17 => return "ctrl";
         when 18 => return "alt";
         when 19 => return "pause";
         when 20 => return "caps lock";
         when 27 => return "esc";
         when 32 => return "space";
         when 33 => return "page up";
         when 34 => return "page down";
         when 35 => return "end";
         when 36 => return "home";
         when 37 => return "left arrow";
         when 38 => return "up arrow";
         when 39 => return "right arrow";
         when 40 => return "down arrow";
         when 45 => return "insert";
         when 46 => return "delete";
         when 48 .. 57 | 65 .. 90 =>
            return [Character'Val (V)];
         when 96 .. 105 =>
            return "num" & [Character'Val (V - 48)];
         when 112 .. 123 =>
            return "F" & Img (V - 111);
         when 144 => return "num lock";
         when 160 | 161 => return "shift";
         when 162 | 163 => return "ctrl";
         when 164 | 165 => return "alt";
         when others => return "vk" & Img (V);
      end case;
   end Key_Name;

   procedure Load_Cfg is
      F : Ada.Text_IO.File_Type;

      procedure Apply (Line : String);

      procedure Apply (Line : String) is
         Eq : Natural := 0;
      begin
         for I in Line'Range loop
            if Line (I) = '=' then
               Eq := I;
               exit;
            end if;
         end loop;
         if Eq = 0 or Eq = Line'Last then
            return;
         end if;
         declare
            V : constant Integer := Integer'Value (Line (Eq + 1 .. Line'Last));
         begin
            if Line'Length >= Eq and then
              Line (Line'First .. Eq - 1) = "left_min"
            then
               if V >= 1 and V <= 60 then
                  G.Left.Min_Cps := V;
               end if;
            elsif Line (Line'First .. Eq - 1) = "left_max" then
               if V >= 1 and V <= 60 then
                  G.Left.Max_Cps := V;
               end if;
            elsif Line (Line'First .. Eq - 1) = "left_on" then
               G.Left.Enabled := V /= 0;
            elsif Line (Line'First .. Eq - 1) = "right_min" then
               if V >= 1 and V <= 60 then
                  G.Right.Min_Cps := V;
               end if;
            elsif Line (Line'First .. Eq - 1) = "right_max" then
               if V >= 1 and V <= 60 then
                  G.Right.Max_Cps := V;
               end if;
            elsif Line (Line'First .. Eq - 1) = "right_on" then
               G.Right.Enabled := V /= 0;
            elsif Line (Line'First .. Eq - 1) = "priming" then
               G.Priming := V /= 0;
            elsif Line (Line'First .. Eq - 1) = "bind" then
               if V >= 0 and V <= 254 then
                  G.Bind := V;
               end if;
            end if;
         exception
            when others =>
               null;
         end;
      end Apply;

   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Config_Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Ln : String (1 .. 128);
            Ll : Natural;
         begin
            Ada.Text_IO.Get_Line (F, Ln, Ll);
            Apply (Ln (1 .. Ll));
         end;
      end loop;
      Ada.Text_IO.Close (F);
      Click_Engine.State.Set_Cps
        (True, G.Left.Min_Cps, G.Left.Max_Cps);
      Click_Engine.State.Set_Cps
        (False, G.Right.Min_Cps, G.Right.Max_Cps);
      Click_Engine.State.Set_Left (G.Left.Enabled);
      Click_Engine.State.Set_Right (G.Right.Enabled);
      Click_Engine.State.Set_Priming (G.Priming);
      Click_Engine.State.Set_Bind (G.Bind);
      declare
         S : constant Click_Engine.Snapshot := Click_Engine.State.Get;
      begin
         G.Left := S.Left;
         G.Right := S.Right;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end Load_Cfg;

   procedure Log (Msg : String) is
      pragma Unreferenced (Msg);
   begin
      null;
   end Log;

   procedure Mark_Dirty is
   begin
      Cfg_Dirty := True;
      Save_At := Tick + 30;
   end Mark_Dirty;

   procedure Paint (W : HWND) is
      Ps    : aliased PAINTSTRUCT;
      Dc    : HWND;
      Mem   : HDC;
      Bmp   : HGDIOBJ;
      Old   : HGDIOBJ;
      Rc    : aliased RECT;
      Rr    : Integer_32;
      Dummy : Integer_32;
      Wd    : Integer_32 := 440;
      Ht    : Integer_32 := 360;

      procedure Card
        (Top : Integer_32; H : Integer_32; Txt : System.Address;
         Row : Integer);
      procedure Sel (B : HGDIOBJ);
      procedure Slider
        (Y : Integer_32; Lab : System.Address; Val : Integer; Code : Integer);

      procedure Sub_Line (Top : Integer_32; Txt : System.Address);
      procedure Toggle (Top : Integer_32; H : Integer_32; On : Float);

      procedure Card
        (Top : Integer_32; H : Integer_32; Txt : System.Address;
         Row : Integer)
      is
         Cr : aliased RECT;
      begin
         Sel (HGDIOBJ (Null_Pen));
         if Row = Hover then
            Sel (HGDIOBJ (Card_Hov));
         else
            Sel (HGDIOBJ (Card_Br));
         end if;
         Dummy := Round_Rect (Mem, 16, Top, 404, Top + H, 12, 12);
         Sel (HGDIOBJ (Ui_F));
         Dummy := Set_Bk_Mode (Mem, Transparent);
         Dummy := Integer_32 (Set_Text_Color (Mem, RGB (235, 235, 240)));
         Cr := (34, Top + 8, 300, Top + 32);
         Dummy := Draw_Text
           (Mem, Txt, -1, Cr'Address,
            DT_LEFT or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);
      end Card;

      procedure Sel (B : HGDIOBJ) is
         Prev : HGDIOBJ;
      begin
         Prev := Select_Object (Mem, B);
         if Prev = System.Null_Address then
            Log ("select failed");
         end if;
      end Sel;

      procedure Slider
        (Y : Integer_32; Lab : System.Address; Val : Integer; Code : Integer)
      is
         Kx : constant Integer_32 := 76 + (Integer_32 (Val - 1) * 190) / 59;
         Lr : aliased RECT := (34, Y, 72, Y + 24);
         Vr : aliased RECT := (274, Y, 326, Y + 24);
         Vl : aliased char_array := To_C (Img (Val));
      begin
         Sel (HGDIOBJ (Small_F));
         Dummy := Integer_32 (Set_Text_Color (Mem, RGB (140, 140, 150)));
         Dummy := Draw_Text
           (Mem, Lab, -1, Lr'Address,
            DT_LEFT or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);
         Sel (HGDIOBJ (Null_Pen));
         Sel (HGDIOBJ (Track_Br));
         Dummy := Round_Rect (Mem, 76, Y + 9, 266, Y + 15, 6, 6);
         if Kx > 80 then
            Sel (HGDIOBJ (Pink_Br));
            Dummy := Round_Rect (Mem, 76, Y + 9, Kx, Y + 15, 6, 6);
         end if;
         if Hover = Code or Dragging = Code then
            Sel (HGDIOBJ (Pink_Br));
         else
            Sel (HGDIOBJ (White_Br));
         end if;
         Dummy := Ellipse (Mem, Kx - 9, Y + 3, Kx + 9, Y + 21);
         Sel (HGDIOBJ (Ui_F));
         Dummy := Integer_32 (Set_Text_Color (Mem, RGB (235, 235, 240)));
         Dummy := Draw_Text
           (Mem, Vl'Address, -1, Vr'Address,
            DT_LEFT or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);
      end Slider;

      procedure Sub_Line (Top : Integer_32; Txt : System.Address) is
         Cr : aliased RECT;
      begin
         Sel (HGDIOBJ (Small_F));
         Dummy := Integer_32 (Set_Text_Color (Mem, RGB (140, 140, 150)));
         Cr := (34, Top + 30, 300, Top + 52);
         Dummy := Draw_Text
           (Mem, Txt, -1, Cr'Address,
            DT_LEFT or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);
      end Sub_Line;

      procedure Toggle (Top : Integer_32; H : Integer_32; On : Float) is
         Tx : constant Integer_32 := 336;
         Ty : constant Integer_32 := Top + (H - 24) / 2;
         Kx : constant Integer_32 := Lerp (Tx + 3, Tx + 25, On);
      begin
         Sel (HGDIOBJ (Null_Pen));
         if On > 0.5 then
            Sel (HGDIOBJ (Pink_Br));
         else
            Sel (HGDIOBJ (Track_Br));
         end if;
         Dummy := Round_Rect (Mem, Tx, Ty, Tx + 48, Ty + 24, 24, 24);
         Sel (HGDIOBJ (White_Br));
         Dummy := Ellipse (Mem, Kx, Ty + 3, Kx + 20, Ty + 23);
      end Toggle;

   begin
      Dc := Begin_Paint (W, Ps'Access);
      Rr := Get_Client_Rect (W, Rc'Access);
      if Rr = 0 then
         Log ("client failed");
         Rr := End_Paint (W, Ps'Access);
         return;
      end if;
      Wd := Rc.Right - Rc.Left;
      Ht := Rc.Bottom - Rc.Top;

      Mem := Create_Compatible_DC (HDC (Dc));
      Bmp := Create_Compatible_Bitmap (HDC (Dc), Wd, Ht);
      Old := Select_Object (Mem, Bmp);

      Rc := (0, 0, Wd, Ht);
      Dummy := Fill_Rect (Mem, Rc'Address, Dark_Bg);
      Dummy := Set_Bk_Mode (Mem, Transparent);

      Sel (HGDIOBJ (Small_F));
      Dummy := Integer_32 (Set_Text_Color (Mem, RGB (235, 235, 240)));
      Rc := (14, 0, 180, 32);
      Dummy := Draw_Text
        (Mem, T_App'Address, -1, Rc'Address,
         DT_LEFT or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);

      Sel (HGDIOBJ (Small_F));
      Dummy := Integer_32 (Set_Text_Color (Mem, RGB (140, 140, 150)));
      declare
         St : aliased char_array := To_C (Status_Str);
         Sr : aliased RECT := (118, 0, 344, 32);
      begin
         Dummy := Draw_Text
           (Mem, St'Address, -1, Sr'Address,
            DT_LEFT or DT_SINGLELINE or DT_VCENTER);
      end;

      declare
         Live : constant Boolean :=
           (G.Left.Enabled or G.Right.Enabled) and G.Mc_Focus;
         Glow : constant Boolean := (Tick / 30) mod 2 = 0;
      begin
         Sel (HGDIOBJ (Null_Pen));
         if Live and Glow then
            Sel (HGDIOBJ (Green_Br));
         elsif Live then
            Sel (HGDIOBJ (Dim_Br));
         else
            Sel (HGDIOBJ (Track_Br));
         end if;
         Dummy := Ellipse (Mem, 96, 9, 110, 23);
      end;

      declare
         Mn : aliased char_array := To_C ("-");
         Cl : aliased char_array := To_C ("x");
      begin
         if Hover = 20 then
            Rc := (376, 0, 408, 32);
            Dummy := Fill_Rect (Mem, Rc'Address, Card_Hov);
         end if;
         if Hover = 21 then
            Rc := (408, 0, 440, 32);
            Dummy := Fill_Rect (Mem, Rc'Address, Pink_Br);
         end if;
         Sel (HGDIOBJ (Ui_F));
         Dummy :=
           Integer_32 (Set_Text_Color (Mem, RGB (200, 200, 210)));
         Rc := (376, 0, 408, 32);
         Dummy := Draw_Text
           (Mem, Mn'Address, -1, Rc'Address,
            DT_CENTER or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);
         Rc := (408, 0, 440, 32);
         Dummy := Draw_Text
           (Mem, Cl'Address, -1, Rc'Address,
            DT_CENTER or DT_SINGLELINE or DT_VCENTER or DT_NOCLIP);
      end;

      declare
         Lt : aliased char_array :=
           To_C ("left clicker");
         Rt : aliased char_array :=
           To_C ("right clicker");
         Pt : aliased char_array :=
           To_C ("right priming");
         Ps_T : aliased char_array :=
           To_C ("hold rmb, tap lmb to burst");
         Bt : aliased char_array := To_C (Bind_Str);
         Bt_Cap : aliased char_array :=
           To_C ("bind: press a key...");
         Mn_L : aliased char_array := To_C ("min");
         Mx_L : aliased char_array := To_C ("max");
      begin
         Card (40, 96, Lt'Address, 0);
         Slider (40 + 32, Mn_L'Address, G.Left.Min_Cps, 4);
         Slider (40 + 60, Mx_L'Address, G.Left.Max_Cps, 5);
         Toggle (40, 96, Anim_L);
         Card (144, 96, Rt'Address, 1);
         Slider (144 + 32, Mn_L'Address, G.Right.Min_Cps, 6);
         Slider (144 + 60, Mx_L'Address, G.Right.Max_Cps, 7);
         Toggle (144, 96, Anim_R);
         Card (248, 56, Pt'Address, 2);
         Sub_Line (248, Ps_T'Address);
         Toggle (248, 56, Anim_P);
         if Capturing and (Tick mod 20) < 10 then
            Card (312, 44, Bt_Cap'Address, 3);
         else
            Card (312, 44, Bt'Address, 3);
         end if;
      end;

      Rr := Bit_Blt
        (HDC (Dc), 0, 0, Wd, Ht, Mem, 0, 0, SRCCOPY);
      if Rr = 0 then
         Log ("blit failed");
      end if;
      Old := Select_Object (Mem, Bmp);
      if Old = System.Null_Address then
         Log ("restore failed");
      end if;
      Dummy := Delete_Object (Bmp);
      Dummy := Delete_DC (Mem);
      Rr := End_Paint (W, Ps'Access);
      if Rr = 0 then
         Log ("paint failed");
      end if;
   end Paint;

   procedure Poll_Bind is
      R : Integer_32;
   begin
      for Vk in 8 .. 254 loop
         if Get_Async_Key_State (Integer_32 (Vk)) < 0 then
            if Vk = 27 then
               G.Bind := 0;
            else
               G.Bind := Vk;
            end if;
            Click_Engine.State.Set_Bind (G.Bind);
            Capturing := False;
            Mark_Dirty;
            R := Invalidate_Rect (Main_W, System.Null_Address, 0);
            if R = 0 then
               Log ("bind paint failed");
            end if;
            exit;
         end if;
      end loop;
   end Poll_Bind;

   procedure Run (H : Integer := 0) is
      pragma Unreferenced (H);
      Cls : aliased WNDCLASSEXA;
      W   : HWND;
      M   : aliased MSG;
      R   : Integer_32;
      T   : Unsigned_64;
      Fr  : aliased RECT;
      App_Icon : HICON := System.Null_Address;
   begin
      Log ("run enter");
      declare
         Mx : constant HANDLE :=
           Create_Mutex
             (System.Null_Address, 0, Solo_Name'Address);
      begin
         if Mx = System.Null_Address then
            Log ("mutex failed");
            Exit_Process (1);
         end if;
         if Get_Last_Error = 183 then
            --  die for real, returning leaves the engine
            --  task keeping a windowless zombie alive
            Log ("already running");
            Exit_Process (0);
         end if;
      end;
      Dark_Bg := Create_Brush (RGB (8, 8, 10));
      Card_Br := Create_Brush (RGB (17, 17, 20));
      Card_Hov := Create_Brush (RGB (26, 26, 32));
      Track_Br := Create_Brush (RGB (60, 60, 66));
      Pink_Br := Create_Brush (RGB (230, 57, 70));
      White_Br := Create_Brush (RGB (245, 245, 250));
      Green_Br := Create_Brush (RGB (55, 200, 110));
      Dim_Br := Create_Brush (RGB (30, 120, 70));
      Null_Pen := Create_Pen (PS_SOLID, 1, RGB (8, 8, 10));
      Arrow_Cur := Load_Cursor
        (System.Null_Address,
         System.Storage_Elements.To_Address
           (System.Storage_Elements.Integer_Address (IDC_ARROW)));
      App_Icon := Load_Icon
        (Get_Module_Handle (System.Null_Address),
         System.Storage_Elements.To_Address (1));
      if App_Icon = System.Null_Address then
         Log ("icon load failed");
      end if;
      Title_F := Create_Font
        (-22, 0, 0, 0, FW_BOLD, 0, 0, 0, 1, 0, 0, 0, 0,
         Face_Name'Address);
      Ui_F := Create_Font
        (-17, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0,
         Face_Name'Address);
      Small_F := Create_Font
        (-15, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0,
         Face_Name'Address);
      if Dark_Bg = System.Null_Address then
         Log ("brush failed");
      end if;
      if Title_F = System.Null_Address then
         Log ("font failed");
      end if;

      Cls :=
        (Cb_Size    => WNDCLASSEXA'Size / 8,
         Style      => 0,
         Wnd_Proc   => Wnd_Proc'Address,
         Cls_Extra  => 0,
         Wnd_Extra  => 0,
         Instance   => System.Null_Address,
         Icon       => App_Icon,
         Cursor     => System.Null_Address,
         Background => Dark_Bg,
         Menu_Name  => System.Null_Address,
         Class_Name => Cls_Name'Address,
         Icon_Sm    => App_Icon);

      if Register_Class (Cls'Access) = 0 then
         if Get_Last_Error /= 1410 then
            Log ("register failed");
            return;
         end if;
      end if;

      Fr := (0, 0, 440, 368);
      R := Adjust_Window_Rect
        (Fr'Access, WS_POPUP or WS_VISIBLE, 0);
      if R = 0 then
         Log ("adjust failed");
         return;
      end if;

      W := Create_Window
        (0, Cls_Name'Address, Win_Title'Address,
         WS_POPUP or WS_VISIBLE,
         100, 100, Fr.Right - Fr.Left, Fr.Bottom - Fr.Top,
         System.Null_Address,
         System.Null_Address, System.Null_Address,
         System.Null_Address);
      if W = System.Null_Address then
         Log ("create failed");
         return;
      end if;
      Main_W := W;

      T := Set_Timer (W, 1, 16, System.Null_Address);

      R := Show_Window (W, SW_SHOWDEFAULT);
      if R < 0 then
         return;
      end if;
      R := Update_Window (W);
      if R < 0 then
         return;
      end if;

      G.Left := Clicker_Core.Clamp_Cps (12, 14);
      G.Left.Enabled := False;
      G.Left.Randomize := False;
      G.Right := Clicker_Core.Clamp_Cps (15, 17);
      G.Right.Enabled := False;
      G.Right.Randomize := False;
      Load_Cfg;

      if T = 0 then
         Log ("timer failed");
      end if;

      Log ("loop enter");

      loop
         exit when Get_Message
           (M'Access, System.Null_Address, 0, 0) <= 0;
         R := Translate_Message (M'Access);
         if R < 0 then
            return;
         end if;
         declare
            D : constant LRESULT := Dispatch_Message (M'Access);
         begin
            if D = LRESULT'Last then
               Log ("dispatch odd");
            end if;
         end;
      end loop;
      Log ("loop exit");
      Exit_Process (0);
   end Run;

   procedure Save_Cfg is
      F : Ada.Text_IO.File_Type;

      function On (B : Boolean) return String;

      function On (B : Boolean) return String is
      begin
         if B then
            return "1";
         end if;
         return "0";
      end On;

   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Config_Path);
      Ada.Text_IO.Put_Line (F, "left_on=" & On (G.Left.Enabled));
      Ada.Text_IO.Put_Line (F, "left_min=" & Img (G.Left.Min_Cps));
      Ada.Text_IO.Put_Line (F, "left_max=" & Img (G.Left.Max_Cps));
      Ada.Text_IO.Put_Line (F, "right_on=" & On (G.Right.Enabled));
      Ada.Text_IO.Put_Line (F, "right_min=" & Img (G.Right.Min_Cps));
      Ada.Text_IO.Put_Line (F, "right_max=" & Img (G.Right.Max_Cps));
      Ada.Text_IO.Put_Line (F, "priming=" & On (G.Priming));
      Ada.Text_IO.Put_Line (F, "bind=" & Img (G.Bind));
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end Save_Cfg;

   function Slider_Hit
     (Top : Integer_32; X : Integer_32; Y : Integer_32; Base : Integer)
      return Integer
   is
   begin
      if Y >= Top + 32 and Y <= Top + 56 then
         if X >= 34 and X <= 330 then
            return Base;
         end if;
      elsif Y >= Top + 60 and Y <= Top + 84 then
         if X >= 34 and X <= 330 then
            return Base + 1;
         end if;
      end if;
      return -1;
   end Slider_Hit;

   procedure Slider_Set (Code : Integer; X : Integer_32) is
      V : Integer := 1 + Integer (((X - 76) * 59) / 190);
      S : Click_Engine.Snapshot;
   begin
      if V < 1 then
         V := 1;
      elsif V > 60 then
         V := 60;
      end if;
      S := Click_Engine.State.Get;
      if Code = 4 then
         Click_Engine.State.Set_Cps (True, V, S.Left.Max_Cps);
         S := Click_Engine.State.Get;
         G.Left := S.Left;
      elsif Code = 5 then
         Click_Engine.State.Set_Cps (True, S.Left.Min_Cps, V);
         S := Click_Engine.State.Get;
         G.Left := S.Left;
      elsif Code = 6 then
         Click_Engine.State.Set_Cps (False, V, S.Right.Max_Cps);
         S := Click_Engine.State.Get;
         G.Right := S.Right;
      else
         Click_Engine.State.Set_Cps (False, S.Right.Min_Cps, V);
         S := Click_Engine.State.Get;
         G.Right := S.Right;
      end if;
      Mark_Dirty;
   end Slider_Set;

   function Status_Str return String is
   begin
      if G.Dead then
         return "engine dead";
      elsif G.Bind /= 0 and not G.Armed then
         return "off";
      elsif not G.Mc_Found then
         return "mc not found";
      elsif (G.Left.Enabled or G.Right.Enabled) and not G.Mc_Focus then
         return "click inside minecraft";
      elsif G.Left.Enabled and G.Right.Enabled then
         return "clicking both" &
           (if G.Priming then " - priming" else "");
      elsif G.Left.Enabled then
         return "clicking left" &
           (if G.Priming then " - priming" else "");
      elsif G.Right.Enabled then
         return "clicking right";
      else
         return "idle";
      end if;
   end Status_Str;

   function Wnd_Proc
     (W : HWND; M : UINT; Wp : WPARAM; Lp : LPARAM)
      return LRESULT
   is
      Id : Integer;
      R  : Integer_32;

      function Mouse_X return Integer_32;
      function Mouse_Y return Integer_32;

      function Mouse_X return Integer_32 is
         Raw : constant Unsigned_64 :=
           Interfaces."and"
             (Interfaces.Unsigned_64 (Integer_64 (Lp)), 16#FFFF#);
      begin
         --  sign extend: 2nd monitor lives in negatives
         if Raw > 32_767 then
            return Integer_32 (Raw) - 65_536;
         end if;
         return Integer_32 (Raw);
      end Mouse_X;

      function Mouse_Y return Integer_32 is
         Raw : constant Unsigned_64 :=
           Interfaces."and"
             (Interfaces.Shift_Right
                (Interfaces.Unsigned_64 (Integer_64 (Lp)), 16),
              16#FFFF#);
      begin
         if Raw > 32_767 then
            return Integer_32 (Raw) - 65_536;
         end if;
         return Integer_32 (Raw);
      end Mouse_Y;
   begin
      if M = WM_DESTROY then
         Post_Quit (0);
         return 0;
      elsif M = WM_ERASEBKGND then
         return 1;
      elsif M = WM_PAINT then
         Paint (W);
         return 0;
      elsif M = WM_TIMER then
         Tick := Tick + 1;
         if Cfg_Dirty and then Tick >= Save_At then
            Cfg_Dirty := False;
            Save_Cfg;
         end if;
         declare
            NS : constant Click_Engine.Snapshot := Click_Engine.State.Get;
         begin
            if NS.Mc_Found /= G.Mc_Found or
              NS.Mc_Focused /= G.Mc_Focus or NS.Armed /= G.Armed or
              NS.Dead /= G.Dead
            then
               G.Mc_Found := NS.Mc_Found;
               G.Mc_Focus := NS.Mc_Focused;
               G.Armed := NS.Armed;
               G.Dead := NS.Dead;
               R := Invalidate_Rect (W, System.Null_Address, 0);
               if R = 0 then
                  Log ("invalidate failed");
               end if;
            end if;
         end;
         if Capturing then
            Poll_Bind;
         end if;
         declare
            Tl : constant Float := (if G.Left.Enabled then 1.0 else 0.0);
            Tr : constant Float := (if G.Right.Enabled then 1.0 else 0.0);
            Tp : constant Float := (if G.Priming then 1.0 else 0.0);
            Moved : Boolean := False;
         begin
            if Anim_L < Tl then
               Anim_L := Float'Min (Anim_L + 0.2, 1.0);
               Moved := True;
            elsif Anim_L > Tl then
               Anim_L := Float'Max (Anim_L - 0.2, 0.0);
               Moved := True;
            end if;
            if Anim_R < Tr then
               Anim_R := Float'Min (Anim_R + 0.2, 1.0);
               Moved := True;
            elsif Anim_R > Tr then
               Anim_R := Float'Max (Anim_R - 0.2, 0.0);
               Moved := True;
            end if;
            if Anim_P < Tp then
               Anim_P := Float'Min (Anim_P + 0.2, 1.0);
               Moved := True;
            elsif Anim_P > Tp then
               Anim_P := Float'Max (Anim_P - 0.2, 0.0);
               Moved := True;
            end if;
            if Moved or (Tick mod 30) = 0 or Capturing then
               R := Invalidate_Rect (W, System.Null_Address, 0);
               if R = 0 then
                  Log ("invalidate failed");
               end if;
            end if;
         end;
         return 0;
      elsif M = WM_NCHITTEST then
         --  nchittest arrives in SCREEN coords, convert first
         --  (comparing screen y against 32 was why the
         --  buttons looked alive but never clicked, oops)
         declare
            Pt : aliased POINT := (X => Mouse_X, Y => Mouse_Y);
         begin
            R := Screen_To_Client (W, Pt'Access);
            if R = 0 then
               return HTCLIENT;
            end if;
            if Pt.Y < 32 then
               if (Pt.X >= 376 and Pt.X <= 408) or
                 (Pt.X >= 408 and Pt.X <= 440)
               then
                  return HTCLIENT;
               end if;
               return HTCAPTION;
            end if;
            if Hit_Test (Pt.X, Pt.Y) = -1 then
               return HTCAPTION;
            end if;
            return HTCLIENT;
         end;
      elsif M = WM_SETCURSOR then
         declare
            Prev : constant HCURSOR := Set_Cursor (Arrow_Cur);
         begin
            if Prev = System.Null_Address and Arrow_Cur = Prev then
               Log ("cursor odd");
            end if;
         end;
         return 1;
      elsif M = WM_MOUSEMOVE then
         if Dragging /= -1 then
            Slider_Set (Dragging, Mouse_X);
            R := Invalidate_Rect (W, System.Null_Address, 0);
            if R = 0 then
               Log ("invalidate failed");
            end if;
            return 0;
         end if;
         if Mouse_Y < 32 then
            if Mouse_X >= 376 and Mouse_X <= 408 then
               Id := 20;
            elsif Mouse_X >= 408 and Mouse_X <= 440 then
               Id := 21;
            else
               Id := -1;
            end if;
         else
            Id := Slider_Hit (40, Mouse_X, Mouse_Y, 4);
            if Id = -1 then
               Id := Slider_Hit (144, Mouse_X, Mouse_Y, 6);
            end if;
            if Id = -1 then
               Id := Hit_Test (Mouse_X, Mouse_Y);
            end if;
         end if;
         if Id /= Hover then
            Hover := Id;
            R := Invalidate_Rect (W, System.Null_Address, 0);
            if R = 0 then
               Log ("invalidate failed");
            end if;
         end if;
         return 0;
      elsif M = WM_NCLBUTTONDBLCLK then
         return 0;
      elsif M = WM_LBUTTONDOWN then
         --  our own synthetic downs carry the tag, never
         --  let the engine click its own ui in a loop
         if Get_Message_Extra_Info = LPARAM (Injected_Tag) then
            return 0;
         end if;
         if Mouse_Y < 32 then
            if Mouse_X >= 376 and Mouse_X <= 408 then
               R := Show_Window (W, SW_MINIMIZE);
               if R = Integer_32'Last then
                  Log ("min odd");
               end if;
            elsif Mouse_X >= 408 and Mouse_X <= 440 then
               R := Destroy_Window (W);
               if R = 0 then
                  Log ("close failed");
               end if;
            end if;
            return 0;
         end if;
         Id := Slider_Hit (40, Mouse_X, Mouse_Y, 4);
         if Id = -1 then
            Id := Slider_Hit (144, Mouse_X, Mouse_Y, 6);
         end if;
         if Id = -1 then
            Id := Hit_Test (Mouse_X, Mouse_Y);
         end if;
         if Id = 0 then
            G.Left.Enabled := not G.Left.Enabled;
            Click_Engine.State.Set_Left (G.Left.Enabled);
            Mark_Dirty;
         elsif Id = 1 then
            G.Right.Enabled := not G.Right.Enabled;
            Click_Engine.State.Set_Right (G.Right.Enabled);
            Mark_Dirty;
         elsif Id = 2 then
            G.Priming := not G.Priming;
            Click_Engine.State.Set_Priming (G.Priming);
            Mark_Dirty;
         elsif Id = 3 then
            Capturing := not Capturing;
            R := Invalidate_Rect (W, System.Null_Address, 0);
            if R = 0 then
               Log ("invalidate failed");
            end if;
         elsif Id >= 4 and Id <= 7 then
            Dragging := Id;
            Cap_Prev := Set_Capture (W);
            if Cap_Prev = Main_W then
               Log ("self capture");
            end if;
            Slider_Set (Id, Mouse_X);
            R := Invalidate_Rect (W, System.Null_Address, 0);
            if R = 0 then
               Log ("invalidate failed");
            end if;
         end if;
         return 0;
      elsif M = WM_LBUTTONUP then
         if Dragging /= -1 then
            Dragging := -1;
            R := Release_Capture;
            if R = 0 then
               Log ("release failed");
            end if;
         end if;
         return 0;
      end if;
      return Def_Window_Proc (W, M, Wp, Lp);
   exception
      when others =>
         return Def_Window_Proc (W, M, Wp, Lp);
   end Wnd_Proc;

end App;
