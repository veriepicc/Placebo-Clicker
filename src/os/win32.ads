with Interfaces; use Interfaces;
with System;

package Win32 with SPARK_Mode => Off is

   subtype DWORD is Unsigned_32;
   subtype BOOL is Integer_32;
   subtype HANDLE is System.Address;
   subtype LPVOID is System.Address;
   subtype LPCVOID is System.Address;
   subtype LPCSTR is System.Address;
   subtype SIZE_T is Unsigned_64;

   Null_Handle : constant HANDLE := System.Null_Address;

   PROCESS_QUERY_INFORMATION : constant DWORD := 16#0400#;
   PROCESS_VM_READ           : constant DWORD := 16#0010#;
   PROCESS_VM_WRITE          : constant DWORD := 16#0020#;
   PROCESS_VM_OPERATION      : constant DWORD := 16#0008#;

   MEM_COMMIT  : constant DWORD := 16#1000#;
   MEM_PRIVATE : constant DWORD := 16#20000#;
   MEM_IMAGE   : constant DWORD := 16#1000000#;

   PAGE_READWRITE : constant DWORD := 16#04#;
   PAGE_GUARD     : constant DWORD := 16#100#;

   type MEMORY_BASIC_INFORMATION is record
      Base_Address       : LPVOID;
      Allocation_Base    : LPVOID;
      Allocation_Protect : DWORD;
      Region_Size        : Long_Long_Integer;
      State              : DWORD;
      Protect            : DWORD;
      Kind               : DWORD;
   end record with Convention => C;

   function OpenProcess
     (Desired : DWORD;
      Inherit : BOOL;
      Pid     : DWORD) return HANDLE with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "OpenProcess";

   function CloseHandle (H : HANDLE) return BOOL with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CloseHandle";

   function Virtual_Query_Ex
     (Proc   : HANDLE;
      Addr   : LPCVOID;
      Info   : access MEMORY_BASIC_INFORMATION;
      Length : Long_Long_Integer) return Long_Long_Integer with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "VirtualQueryEx";

   function Read_Process_Memory
     (Proc     : HANDLE;
      Base     : LPCVOID;
      Buf      : LPVOID;
      Size     : Long_Long_Integer;
      Got      : access Long_Long_Integer) return BOOL with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "ReadProcessMemory";

   function Write_Process_Memory
     (Proc     : HANDLE;
      Base     : LPVOID;
      Buf      : LPCVOID;
      Size     : Long_Long_Integer;
      Wrote    : access Long_Long_Integer) return BOOL with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "WriteProcessMemory";

   function Get_Last_Error return DWORD with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "GetLastError";

   procedure Exit_Process (Code : DWORD) with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "ExitProcess";
   pragma No_Return (Exit_Process);

   function Create_Mutex
     (Attr : LPVOID; Own : BOOL; Name : LPVOID) return HANDLE with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "CreateMutexA";

   MOUSEEVENTF_LEFTDOWN   : constant DWORD := 16#0002#;
   MOUSEEVENTF_LEFTUP     : constant DWORD := 16#0004#;
   MOUSEEVENTF_RIGHTDOWN  : constant DWORD := 16#0008#;
   MOUSEEVENTF_RIGHTUP    : constant DWORD := 16#0010#;
   INPUT_MOUSE            : constant DWORD := 0;

   Injected_Tag : constant Unsigned_64 := 16#504C414345424F00#;

   type MSLLHOOKSTRUCT is record
      X     : Integer_32;
      Y     : Integer_32;
      Data  : DWORD;
      Flags : DWORD;
      Time  : DWORD;
      Extra : System.Address;
   end record with Convention => C;

   type INPUT is record
      Kind  : DWORD;
      Pad   : DWORD;
      Dx    : Integer_32;
      Dy    : Integer_32;
      Data  : DWORD;
      Flags : DWORD;
      Time  : DWORD;
      Extra : System.Address;
   end record with Convention => C;

   function Send_Input
     (N     : DWORD;
      Inp   : LPVOID;
      Size  : Integer_32) return DWORD with
     Import        => True,
     Convention    => Stdcall,
     External_Name => "SendInput";

   function Get_Async_Key_State (Vkey : Integer_32) return Integer_16 with
      Import        => True,
      Convention    => Stdcall,
      External_Name => "GetAsyncKeyState";

   function Get_Module_Handle (Name : System.Address) return HANDLE with
      Import        => True,
      Convention    => Stdcall,
      External_Name => "GetModuleHandleA";

end Win32;
