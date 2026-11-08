package Colony_Names is
   function Faction_Name (Key : Natural) return String;
   function Leader (Key : Natural) return String;
   function Land_Name (Key, Index : Natural) return String;
   function Sea_Name (Key, Index : Natural) return String;
   function Land_Count (Key : Natural) return Natural;
   function Sea_Count (Key : Natural) return Natural;
   function Fallback_Count return Natural;
   function Fallback (Index : Natural) return String;
end Colony_Names;
