with System;

package Win32.Winbase with SPARK_Mode => Off is

   function GetModuleHandle (Name : System.Address) return System.Address with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetModuleHandleA";

end Win32.Winbase;
