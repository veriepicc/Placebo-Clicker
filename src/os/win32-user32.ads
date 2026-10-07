with System;
with Interfaces;

package Win32.User32 with SPARK_Mode => Off is

   subtype HWND is System.Address;
   subtype HINSTANCE is System.Address;
   subtype HMENU is System.Address;
   subtype HICON is System.Address;
   subtype HCURSOR is System.Address;
   subtype HBRUSH is System.Address;
   subtype WPARAM is Interfaces.Unsigned_64;
   subtype LPARAM is Interfaces.Integer_64;
   subtype LRESULT is Interfaces.Integer_64;
   subtype UINT is Interfaces.Unsigned_32;
   subtype ATOM is Interfaces.Unsigned_16;

   WS_OVERLAPPEDWINDOW : constant := 16#00CF0000#;
   WS_POPUP            : constant := 16#80000000#;
   WS_VISIBLE          : constant := 16#10000000#;
   WS_CHILD            : constant := 16#40000000#;
   WS_BORDER           : constant := 16#00800000#;
   BS_AUTOCHECKBOX     : constant := 16#00000003#;
   SS_LEFT             : constant := 16#00000000#;

   WM_CREATE  : constant := 16#0001#;
   WM_DESTROY : constant := 16#0002#;
   WM_COMMAND : constant := 16#0111#;
   WM_CLOSE   : constant := 16#0010#;

   WM_CTLCOLORSTATIC : constant := 16#0138#;
   WM_CTLCOLORBTN    : constant := 16#0135#;
   WM_PAINT          : constant := 16#000F#;
   WM_ERASEBKGND     : constant := 16#0014#;
   WM_TIMER          : constant := 16#0113#;
   WM_MOUSEMOVE      : constant := 16#0200#;
   WM_LBUTTONDOWN    : constant := 16#0201#;
   WM_LBUTTONUP      : constant := 16#0202#;
   WM_RBUTTONDOWN    : constant := 16#0204#;
   WM_RBUTTONUP      : constant := 16#0205#;
   WM_MOUSELEAVE     : constant := 16#02A3#;
   WM_NCHITTEST      : constant := 16#0084#;
   WM_SETCURSOR      : constant := 16#0020#;
   WM_NCLBUTTONDBLCLK : constant := 16#00A3#;

   HTCLIENT  : constant := 1;
   HTCAPTION : constant := 2;

   IDC_ARROW : constant := 32512;

   BN_CLICKED : constant := 0;

   SW_SHOWDEFAULT : constant := 10;
   SW_MINIMIZE    : constant := 6;

   type WNDCLASSEXA is record
      Cb_Size    : Interfaces.Unsigned_32;
      Style      : Interfaces.Unsigned_32;
      Wnd_Proc   : System.Address;
      Cls_Extra  : Interfaces.Integer_32;
      Wnd_Extra  : Interfaces.Integer_32;
      Instance   : HINSTANCE;
      Icon       : HICON;
      Cursor     : HCURSOR;
      Background : HBRUSH;
      Menu_Name  : System.Address;
      Class_Name : System.Address;
      Icon_Sm    : HICON;
   end record with Convention => C;

   type MSG is record
      H_Wnd   : HWND;
      Msg_Id  : UINT;
      W_Param : WPARAM;
      L_Param : LPARAM;
      Time    : Interfaces.Unsigned_32;
      X       : Interfaces.Integer_32;
      Y       : Interfaces.Integer_32;
   end record with Convention => C;

   function Register_Class
     (Cls : access WNDCLASSEXA) return ATOM with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "RegisterClassExA";

   function Create_Window
     (Ex_Style : Interfaces.Unsigned_32;
      Class    : System.Address;
      Title    : System.Address;
      Style    : Interfaces.Unsigned_32;
      X        : Interfaces.Integer_32;
      Y        : Interfaces.Integer_32;
      W        : Interfaces.Integer_32;
      H        : Interfaces.Integer_32;
      Parent   : HWND;
      Menu     : HMENU;
      Inst     : HINSTANCE;
      Param    : System.Address) return HWND with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreateWindowExA";

   function Def_Window_Proc
     (W : HWND; M : UINT; Wp : WPARAM; Lp : LPARAM)
      return LRESULT with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "DefWindowProcA";

   function Show_Window
     (W : HWND; Cmd : Interfaces.Integer_32)
      return Interfaces.Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "ShowWindow";

   function Update_Window
     (W : HWND) return Interfaces.Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "UpdateWindow";

   function Get_Message
     (M : access MSG; W : HWND; Min : UINT; Max : UINT)
      return Interfaces.Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetMessageA";

   function Translate_Message
     (M : access MSG) return Interfaces.Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "TranslateMessage";

   function Dispatch_Message
     (M : access MSG) return LRESULT with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "DispatchMessageA";

   procedure Post_Quit (Code : Interfaces.Integer_32) with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "PostQuitMessage";

   type RECT is record
      Left   : Interfaces.Integer_32;
      Top    : Interfaces.Integer_32;
      Right  : Interfaces.Integer_32;
      Bottom : Interfaces.Integer_32;
   end record with Convention => C;

   type POINT is record
      X : Interfaces.Integer_32;
      Y : Interfaces.Integer_32;
   end record with Convention => C;

   function Screen_To_Client
     (W : HWND; P : access POINT) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "ScreenToClient";

   function Load_Cursor
     (I : HINSTANCE; Id : System.Address) return HCURSOR with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "LoadCursorA";

   function Get_Module_File_Name
     (I : HINSTANCE; Buf : System.Address; Max : Integer_32)
      return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetModuleFileNameA";

   function Load_Icon
     (I : HINSTANCE; Id : System.Address) return HICON with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "LoadIconA";

   WM_SETICON : constant := 16#0080#;
   ICON_SMALL : constant := 0;
   ICON_BIG   : constant := 1;

   function Send_Message
     (W : HWND; M : UINT; Wp : WPARAM; Lp : LPARAM)
      return LRESULT with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SendMessageA";

   function Set_Cursor (C : HCURSOR) return HCURSOR with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetCursor";

   type PAINTSTRUCT is record
      Dc         : HWND;
      Erase      : Interfaces.Integer_32;
      Paint_Rect : RECT;
      Restore    : Interfaces.Integer_32;
      Inc_Update : Interfaces.Integer_32;
      Reserved   : Interfaces.Integer_32;
      Reserved2  : Interfaces.Integer_32;
      Reserved3  : Interfaces.Integer_32;
      Reserved4  : Interfaces.Integer_32;
      Reserved5  : Interfaces.Integer_32;
      Reserved6  : Interfaces.Integer_32;
      Reserved7  : Interfaces.Integer_32;
      Reserved8  : Interfaces.Integer_32;
      Reserved9  : Interfaces.Integer_32;
      Reserved10 : Interfaces.Integer_32;
      Reserved11 : Interfaces.Integer_32;
   end record with Convention => C;

   function Begin_Paint
     (W : HWND; P : access PAINTSTRUCT) return HWND with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "BeginPaint";

   function End_Paint
     (W : HWND; P : access PAINTSTRUCT) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "EndPaint";

   function Invalidate_Rect
     (W : HWND; R : System.Address; Erase : Integer_32)
      return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "InvalidateRect";

   function Set_Timer
     (W : HWND;
      Id : Interfaces.Unsigned_64;
      Ms : Interfaces.Unsigned_32;
      Cb : System.Address) return Interfaces.Unsigned_64 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetTimer";

   function Get_Client_Rect
     (W : HWND; R : access RECT) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetClientRect";

   function Destroy_Window (W : HWND) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "DestroyWindow";

   function Enum_Windows
     (Cb : System.Address; Lp : LPARAM) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "EnumWindows";

   function Get_Foreground return HWND with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetForegroundWindow";

   function Get_Window_Text
     (W : HWND; Buf : System.Address; Max : Integer_32)
      return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetWindowTextA";

   function Get_Window_Thread
     (W : HWND; Pid : access DWORD) return DWORD with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetWindowThreadProcessId";

   function Is_Visible (W : HWND) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "IsWindowVisible";

   function Set_Capture (W : HWND) return HWND with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetCapture";

   function Release_Capture return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "ReleaseCapture";

   WH_MOUSE_LL    : constant := 14;
   HC_ACTION      : constant := 0;
   LLMHF_INJECTED : constant := 1;

   function Set_Hook
     (Id : Integer_32; Cb : System.Address; Md : HANDLE;
      Thread : DWORD) return HANDLE with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetWindowsHookExW";

   function Call_Next
     (H : HANDLE; Code : Integer_32; Msg : WPARAM; Param : LPARAM)
      return LRESULT with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CallNextHookEx";

   function Get_Message_Extra_Info return LPARAM with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetMessageExtraInfo";

   function Adjust_Window_Rect
     (R : access RECT; Style : Interfaces.Unsigned_32; Menu : Integer_32)
      return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "AdjustWindowRect";

end Win32.User32;
