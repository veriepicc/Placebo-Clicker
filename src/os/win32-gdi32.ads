with System;
with Win32.User32; use Win32.User32;

package Win32.Gdi32 with SPARK_Mode => Off is

   subtype HDC is System.Address;
   subtype HGDIOBJ is System.Address;
   subtype HPEN is System.Address;
   subtype HFONT is System.Address;
   subtype COLORREF is Unsigned_32;

   PS_SOLID : constant := 0;
   PS_NULL  : constant := 5;

   function Create_Brush
     (Color : COLORREF) return HBRUSH with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreateSolidBrush";

   function Create_Pen
     (Style : Integer_32; Width : Integer_32; Color : COLORREF)
      return HPEN with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreatePen";

   function Create_Compatible_DC (Dc : HDC) return HDC with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreateCompatibleDC";

   function Create_Compatible_Bitmap
     (Dc : HDC; W : Integer_32; H : Integer_32) return HGDIOBJ with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreateCompatibleBitmap";

   function Select_Object (Dc : HDC; Obj : HGDIOBJ) return HGDIOBJ with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SelectObject";

   function Delete_Object (Obj : HGDIOBJ) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "DeleteObject";

   function Delete_DC (Dc : HDC) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "DeleteDC";

   function Bit_Blt
     (Dst    : HDC;
      X      : Integer_32;
      Y      : Integer_32;
      W      : Integer_32;
      H      : Integer_32;
      Src    : HDC;
      Sx     : Integer_32;
      Sy     : Integer_32;
      Rop    : Unsigned_32) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "BitBlt";

   SRCCOPY : constant := 16#00CC0020#;

   function Round_Rect
     (Dc : HDC;
      L  : Integer_32;
      T  : Integer_32;
      R  : Integer_32;
      B  : Integer_32;
      W  : Integer_32;
      H  : Integer_32) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "RoundRect";

   function Ellipse
     (Dc : HDC;
      L  : Integer_32;
      T  : Integer_32;
      R  : Integer_32;
      B  : Integer_32) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "Ellipse";

   function Set_Bk_Color
     (Dc : HDC; Color : COLORREF) return COLORREF with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetBkColor";

   function Set_Text_Color
     (Dc : HDC; Color : COLORREF) return COLORREF with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetTextColor";

   function Set_Bk_Mode
     (Dc : HDC; Mode : Integer_32) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SetBkMode";

   Transparent : constant := 1;

   function Fill_Rect
     (Dc : HDC; Rc : System.Address; Br : HBRUSH)
      return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "FillRect";

   function Draw_Text
     (Dc : HDC;
      S  : System.Address;
      N  : Integer_32;
      Rc : System.Address;
      F  : Unsigned_32) return Integer_32 with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "DrawTextA";

   DT_LEFT        : constant := 16#00000000#;
   DT_CENTER      : constant := 16#00000001#;
   DT_SINGLELINE  : constant := 16#00000020#;
   DT_VCENTER     : constant := 16#00000004#;
   DT_NOCLIP      : constant := 16#00000100#;

   function RGB
     (R : Unsigned_8; G : Unsigned_8; B : Unsigned_8)
      return COLORREF is
     (COLORREF (R) or
      COLORREF (G) * 256 or
      COLORREF (B) * 65_536);

   FW_BOLD : constant := 700;

   function Create_Font
     (H      : Integer_32;
      W      : Integer_32;
      Esc    : Integer_32;
      Orient : Integer_32;
      Weight : Integer_32;
      Italic : Unsigned_32;
      Under  : Unsigned_32;
      Strike : Unsigned_32;
      Char   : Unsigned_32;
      Outp   : Unsigned_32;
      Clip   : Unsigned_32;
      Qual   : Unsigned_32;
      Pitch  : Unsigned_32;
      Face   : System.Address) return HFONT with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreateFontA";

   function Lerp (A : Integer_32; B : Integer_32; T : Float)
     return Integer_32 is
     (A + Integer_32 (Float (B - A) * T));

   function Lerp_C
     (A : Unsigned_8; B : Unsigned_8; T : Float) return Unsigned_8 is
     (Unsigned_8 (Integer_32 (A) +
       Integer_32 (Float (Integer_32 (B) - Integer_32 (A)) * T)));

end Win32.Gdi32;
