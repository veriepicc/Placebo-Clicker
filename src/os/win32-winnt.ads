with Interfaces;

package Win32.Winnt with SPARK_Mode => Off is

   subtype DWORD is Interfaces.Unsigned_32;

   type IMAGE_DOS_HEADER is record
      e_magic  : Interfaces.Unsigned_16;
      e_cblp   : Interfaces.Unsigned_16;
      e_cp     : Interfaces.Unsigned_16;
      e_crlc   : Interfaces.Unsigned_16;
      e_cparhdr : Interfaces.Unsigned_16;
      e_minalloc : Interfaces.Unsigned_16;
      e_maxalloc : Interfaces.Unsigned_16;
      e_ss     : Interfaces.Unsigned_16;
      e_sp     : Interfaces.Unsigned_16;
      e_csum   : Interfaces.Unsigned_16;
      e_ip     : Interfaces.Unsigned_16;
      e_cs     : Interfaces.Unsigned_16;
      e_lfarlc : Interfaces.Unsigned_16;
      e_ovno   : Interfaces.Unsigned_16;
      e_res1   : Interfaces.Unsigned_16;
      e_res2   : Interfaces.Unsigned_16;
      e_res3   : Interfaces.Unsigned_16;
      e_res4   : Interfaces.Unsigned_16;
      e_oemid  : Interfaces.Unsigned_16;
      e_oeminfo : Interfaces.Unsigned_16;
      e_res5   : Interfaces.Unsigned_16;
      e_res6   : Interfaces.Unsigned_16;
      e_res7   : Interfaces.Unsigned_16;
      e_res8   : Interfaces.Unsigned_16;
      e_res9   : Interfaces.Unsigned_16;
      e_res10  : Interfaces.Unsigned_16;
      e_lfanew : Integer_32;
   end record with Convention => C;
   type PIMAGE_DOS_HEADER is access all IMAGE_DOS_HEADER;

   type IMAGE_OPTIONAL_HEADER64 is record
      SizeOfImage : Interfaces.Unsigned_32;
   end record with Convention => C;

   type IMAGE_NT_HEADERS is record
      Signature      : Interfaces.Unsigned_32;
      OptionalHeader : IMAGE_OPTIONAL_HEADER64;
   end record with Convention => C;
   type PIMAGE_NT_HEADERS is access all IMAGE_NT_HEADERS;

end Win32.Winnt;
