with Ada.Unchecked_Conversion;
with Colony_Names;
with Interfaces;
with System;
with System.Storage_Elements;

package body Colony is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   subtype U32 is Interfaces.Unsigned_32;
   subtype U8 is Interfaces.Unsigned_8;

   function To_U32 is new Ada.Unchecked_Conversion (Integer, U32);
   function To_Int is new Ada.Unchecked_Conversion (U32, Integer);

   Max_W      : constant := 48;
   Max_H      : constant := 32;
   Max_Tiles  : constant := Max_W * Max_H;
   Max_Units  : constant := 280;
   Max_Cities : constant := 80;
   Max_Ev     : constant := 36;
   Name_Max   : constant := 24;

   type Tech_Kind is
     (Soil, Deep, Photon, Kinetic, Sensors, Signal, Lattice, Field, Neural,
      Tidal, Myco, Habitat, Plasma, Gravitic, Quantum, Synth, Sapper, Boring,
      Naval, Ordnance, Dread, Ascend);
   type Unit_Kind is
     (Colonist, Sea_Colonist, Terraformer, Scout, Trooper, Warden, Lancer,
      Striker, Skimmer, Skiff, Transport, Frigate, Cruiser, Beast, Rebel);

   type Fac_Kind is
     (Hydro, Fab, Spire, Shield, Dome, Docks, Fishery, Tidal_C, Rec, Theatre,
      Beacon, Asc_Array);

   type Imp_Kind is (None, Farm, Mine, Solar);
   type Work_Kind is (W_None, W_Clear, W_Road, W_Farm, W_Mine, W_Solar);
   type Nbr_Arr is array (0 .. 200) of Integer;
   type Queue_Arr is array (0 .. 5) of Integer;
   type Facs_Arr is array (0 .. 7) of Integer;
   type Worked_Arr is array (0 .. 20) of Integer;
   type Tech_Set is array (Tech_Kind) of Boolean;
   type Pol_Arr is array (0 .. 3) of Integer;
   type Tile_Bools is array (0 .. Max_Tiles - 1) of Boolean;
   type Tile_Bytes is array (0 .. Max_Tiles - 1) of U8;

   type Tile is record
      Land, Fungus, Road : Boolean := False;
      Moist, Rock        : Natural := 0;
      Elev               : Natural := 0;
      Imp                : Imp_Kind := None;
      Sea_Dist           : Natural := 99;
   end record;

   type Unit_Rec is record
      Id, Fac, Loc, HP, MP, Home, Goto_At, Target, Work_Left, On_Ship : Integer := -1;
      Kind  : Unit_Kind := Trooper;
      Fort, Skip : Boolean := False;
      Work  : Work_Kind := W_None;
   end record;

   type City_Rec is record
      Id, Fac, Loc, Pop, Food, Prod, Founded : Integer := 0;
      Name_Len : Natural := 0;
      Name     : String (1 .. Name_Max) := (others => ' ');
      Q_Len, Fac_N, Work_N : Natural := 0;
      Queue    : Queue_Arr := (others => -1);
      Facs     : Facs_Arr := (others => -1);
      Worked   : Worked_Arr := (others => -1);
      Sea, Capital : Boolean := False;
      Mood     : Natural := 0;
      Mor10    : Integer := 30;
      Mood_Add : Integer := 0;
      Mood_Until : Integer := 0;
   end record;

   type Faction_Rec is record
      Used, Alive, AI, Policy_Set : Boolean := False;
      Keyi, Credits, RP, Research, Tech_N, Plan, Unrest, Start : Integer := 0;
      Labs : Long_Float := 0.5;
      WW   : Long_Float := 0.0;
      Techs : Tech_Set := (others => False);
      Pol   : Pol_Arr := (others => 0);
      Seen, Vis : Tile_Bools := (others => False);
      Mem : Tile_Bytes := (others => 0);
      Built, Lost, Kills, Founded, Combats : Natural := 0;
   end record;

   W, H, NTiles, Unit_N, City_N, Fac_N : Integer := 0;
   Next_Id, Turn_N, Human, Viewer, Winner, Win_Type : Integer := 0;
   Dom_Turns : array (0 .. 3) of Integer := (others => 0);
   Asc_On : Boolean := False;
   Asc_Fac, Asc_City, Asc_Left : Integer := 0;
   Difficulty, Max_Turns, Last_Status : Integer := 0;
   Rules : U32 := 0;
   Seed, RS : U32 := 1;
   Tiles : array (0 .. Max_Tiles - 1) of Tile;
   Units : array (0 .. Max_Units - 1) of Unit_Rec;
   Cities : array (0 .. Max_Cities - 1) of City_Rec;
   Factions : array (0 .. 3) of Faction_Rec;
   Work_A, Work_B, Work_E : array (0 .. Max_Tiles - 1) of Long_Float;
   Dist_A, Prev_A : array (0 .. Max_Tiles - 1) of Integer;
   Occ_A : array (0 .. Max_Tiles - 1) of U8;
   Terr : array (0 .. Max_Tiles - 1) of Integer;

   RBuf : String (1 .. 2400);
   RLen : Natural := 0;
   EBuf : String (1 .. 180);
   ELen : Natural := 0;
   TBuf : String (1 .. 512);
   TLen : Natural := 0;
   Frame : array (0 .. 262143) of U8;
   Frame_Len : Natural := 0;
   Ev_Buf : array (0 .. Max_Ev - 1) of String (1 .. 110);
   Ev_Len : array (0 .. Max_Ev - 1) of Natural := (others => 0);
   Ev_Head, Ev_Count : Natural := 0;

   procedure Update_Seen (Fid : Integer);

   function Rule (Bit : Natural) return Boolean is
     ((Rules and Interfaces.Shift_Left (U32'(1), Bit)) /= 0);

   function Img (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Img;

   function Hex8 (V : U32) return String is
      Hex : constant String := "0123456789abcdef";
      R   : String (1 .. 8);
      X   : U32 := V;
   begin
      for I in reverse 1 .. 8 loop
         R (I) := Hex (Natural (X and 15) + 1);
         X := Interfaces.Shift_Right (X, 4);
      end loop;
      return R;
   end Hex8;

   function JS_Round (X : Long_Float) return Integer is
     (Integer (Long_Float'Floor (X + 0.5)));

   procedure Add_R (S : String) is
   begin
      if RLen + S'Length <= RBuf'Last then
         RBuf (RLen + 1 .. RLen + S'Length) := S;
         RLen := RLen + S'Length;
      end if;
   end Add_R;

   procedure Set_Error (S : String) is
      N : constant Natural := Integer'Min (S'Length, EBuf'Last);
   begin
      ELen := N;
      if N > 0 then
         EBuf (1 .. N) := S (S'First .. S'First + N - 1);
      end if;
      Last_Status := 1;
   end Set_Error;

   procedure Log (S : String) is
      N : constant Natural := Integer'Min (S'Length, 110);
      Line : String (1 .. 110) := (others => ' ');
   begin
      if N > 0 then
         Line (1 .. N) := S (S'First .. S'First + N - 1);
      end if;
      Ev_Buf (Ev_Head) := Line;
      Ev_Len (Ev_Head) := N;
      Ev_Head := (Ev_Head + 1) mod Max_Ev;
      if Ev_Count < Max_Ev then
         Ev_Count := Ev_Count + 1;
      end if;
   end Log;

   function Rand_U return U32 is
      T : U32;
   begin
      RS := RS + 16#6D2B79F5#;
      T := RS;
      T := (T xor Interfaces.Shift_Right (T, 15)) * (1 or T);
      T := (T + ((T xor Interfaces.Shift_Right (T, 7)) * (61 or T))) xor T;
      return T xor Interfaces.Shift_Right (T, 14);
   end Rand_U;

   function Rand return Long_Float is
     (Long_Float (Rand_U) / 4294967296.0);

   function RI (N : Natural) return Natural is
      R : Natural;
   begin
      if N <= 1 then
         return 0;
      end if;
      R := Natural (Long_Float'Floor (Rand * Long_Float (N)));
      if R >= N then
         return N - 1;
      end if;
      return R;
   end RI;

   function X_Of (I : Integer) return Integer is (I mod W);
   function Y_Of (I : Integer) return Integer is (I / W);

   function In_Map (X, Y : Integer) return Boolean is
     (X >= 0 and then Y >= 0 and then X < W and then Y < H);

   function Dist (A, B : Integer) return Integer is
      DX : constant Integer := abs (X_Of (A) - X_Of (B));
      DY : constant Integer := abs (Y_Of (A) - Y_Of (B));
   begin
      return Integer'Max (DX, DY);
   end Dist;

   procedure Nbrs (I : Integer; Radius : Integer; Out_N : out Natural;
                   Out_A : out Nbr_Arr) is
      X0 : constant Integer := X_Of (I);
      Y0 : constant Integer := Y_Of (I);
   begin
      Out_A := (others => -1);
      Out_N := 0;
      for DY in -Radius .. Radius loop
         for DX in -Radius .. Radius loop
            if (DX /= 0 or else DY /= 0) and then In_Map (X0 + DX, Y0 + DY) then
               if Out_N < Out_A'Length then
                  Out_A (Out_N) := (Y0 + DY) * W + (X0 + DX);
                  Out_N := Out_N + 1;
               end if;
            end if;
         end loop;
      end loop;
   end Nbrs;

   function Slot_Key (S : Integer) return Integer is
     (if S in 0 .. Fac_N - 1 then Factions (S).Keyi else 0);

   function Has_Tech (Fid, Tech : Integer) return Boolean is
   begin
      if Fid < 0 or else Fid >= Fac_N or else Tech < 0 or else Tech > 21 then
         return False;
      end if;
      return Factions (Fid).Techs (Tech_Kind'Val (Tech));
   end Has_Tech;

   function U_Cost (K : Unit_Kind) return Integer is
   begin
      case K is
         when Colonist => return 30;
         when Sea_Colonist => return 40;
         when Terraformer => return 20;
         when Scout => return 15;
         when Trooper => return 25;
         when Warden => return 30;
         when Lancer => return 35;
         when Striker => return 50;
         when Skimmer => return 55;
         when Skiff => return 20;
         when Transport => return 35;
         when Frigate => return 45;
         when Cruiser => return 75;
         when Beast | Rebel => return 0;
      end case;
   end U_Cost;

   function U_Atk (K : Unit_Kind) return Integer is
   begin
      case K is
         when Colonist | Sea_Colonist | Terraformer | Transport => return 0;
         when Scout | Warden | Skiff => return 1;
         when Trooper | Beast | Rebel => return 2;
         when Frigate => return 3;
         when Lancer => return 4;
         when Skimmer => return 5;
         when Striker | Cruiser => return 6;
      end case;
   end U_Atk;

   function U_Def (K : Unit_Kind) return Integer is
   begin
      case K is
         when Colonist | Sea_Colonist | Terraformer | Scout | Transport | Rebel | Skiff => return 1;
         when Trooper | Lancer | Beast => return 2;
         when Warden | Striker | Skimmer | Frigate => return 3;
         when Cruiser => return 5;
      end case;
   end U_Def;

   function U_Mv (K : Unit_Kind) return Integer is
   begin
      case K is
         when Scout => return 2;
         when Skimmer | Skiff | Transport | Frigate => return 3;
         when Cruiser => return 4;
         when others => return 1;
      end case;
   end U_Mv;

   function U_Civ (K : Unit_Kind) return Boolean is
     (K in Colonist | Sea_Colonist | Terraformer | Transport);

   function U_Ship (K : Unit_Kind) return Boolean is
     (K in Skiff | Transport | Frigate | Cruiser);

   function U_Native (K : Unit_Kind) return Boolean is
     (K in Beast | Rebel);

   function U_Found (K : Unit_Kind) return Boolean is
     (K in Colonist | Sea_Colonist);

   function U_Tech (K : Unit_Kind) return Integer is
   begin
      case K is
         when Sea_Colonist => return Tech_Kind'Pos (Tidal);
         when Warden => return Tech_Kind'Pos (Lattice);
         when Lancer => return Tech_Kind'Pos (Kinetic);
         when Striker => return Tech_Kind'Pos (Plasma);
         when Skimmer => return Tech_Kind'Pos (Gravitic);
         when Skiff | Transport => return Tech_Kind'Pos (Naval);
         when Frigate => return Tech_Kind'Pos (Ordnance);
         when Cruiser => return Tech_Kind'Pos (Dread);
         when others => return -1;
      end case;
   end U_Tech;

   function U_Name (K : Unit_Kind) return String is
   begin
      case K is
         when Colonist => return "Colonist";
         when Sea_Colonist => return "Sea Colonist";
         when Terraformer => return "Terraformer";
         when Scout => return "Scout";
         when Trooper => return "Trooper";
         when Warden => return "Warden";
         when Lancer => return "Lancer";
         when Striker => return "Striker";
         when Skimmer => return "Skimmer";
         when Skiff => return "Scout Skiff";
         when Transport => return "Troop Transport";
         when Frigate => return "Frigate";
         when Cruiser => return "Assault Cruiser";
         when Beast => return "Spore Beast";
         when Rebel => return "Insurgents";
      end case;
   end U_Name;

   function U_Glyph (K : Unit_Kind) return String is
   begin
      case K is
         when Colonist => return "C";
         when Sea_Colonist => return "~";
         when Terraformer => return "T";
         when Scout => return "S";
         when Trooper => return "I";
         when Warden => return "W";
         when Lancer => return "L";
         when Striker => return "X";
         when Skimmer => return "K";
         when Skiff => return "s";
         when Transport => return "t";
         when Frigate => return "f";
         when Cruiser => return "A";
         when Beast => return "B";
         when Rebel => return "!";
      end case;
   end U_Glyph;

   function F_Name (K : Fac_Kind) return String is
   begin
      case K is
         when Hydro => return "Hydroponic Vats";
         when Fab => return "Fabricator";
         when Spire => return "Data Spire";
         when Shield => return "Perimeter Shield";
         when Dome => return "Habitat Dome";
         when Docks => return "Coastal Docks";
         when Fishery => return "Fisheries";
         when Tidal_C => return "Tidal Collectors";
         when Rec => return "Recreation Commons";
         when Theatre => return "Dreamweave Theatre";
         when Beacon => return "Resonance Beacon";
         when Asc_Array => return "Ascension Array";
      end case;
   end F_Name;

   function F_Cost (K : Fac_Kind) return Integer is
   begin
      case K is
         when Hydro | Spire => return 50;
         when Fab => return 50;
         when Shield => return 45;
         when Dome | Theatre => return 60;
         when Docks | Fishery | Rec => return 35;
         when Tidal_C => return 40;
         when Beacon => return 300;
         when Asc_Array => return 900;
      end case;
   end F_Cost;

   function F_Maint (K : Fac_Kind) return Integer is
   begin
      case K is
         when Dome | Theatre | Beacon => return 2;
         when Asc_Array => return 0;
         when others => return 1;
      end case;
   end F_Maint;

   function F_Tech (K : Fac_Kind) return Integer is
   begin
      case K is
         when Hydro => return Tech_Kind'Pos (Soil);
         when Fab => return Tech_Kind'Pos (Deep);
         when Spire => return Tech_Kind'Pos (Neural);
         when Shield => return Tech_Kind'Pos (Field);
         when Dome => return Tech_Kind'Pos (Habitat);
         when Docks | Fishery | Tidal_C => return Tech_Kind'Pos (Naval);
         when Theatre => return Tech_Kind'Pos (Signal);
         when Beacon | Asc_Array => return Tech_Kind'Pos (Ascend);
         when Rec => return -1;
      end case;
   end F_Tech;

   function F_Coast (K : Fac_Kind) return Boolean is
     (K in Docks | Fishery | Tidal_C);

   function F_Project (K : Fac_Kind) return Boolean is
     (K in Beacon | Asc_Array);

   function F_Ent (K : Fac_Kind) return Integer is
     (if K = Rec then 2 elsif K = Theatre then 3 else 0);

   function Tech_Name (T : Integer) return String is
   begin
      if T < 0 or else T > 21 then
         return "?";
      end if;
      case Tech_Kind'Val (T) is
         when Soil => return "Soil Lattice Genetics";
         when Deep => return "Deep Core Sampling";
         when Photon => return "Photonic Weave";
         when Kinetic => return "Kinetic Arms";
         when Sensors => return "Sensor Lattice";
         when Signal => return "Signal Theory";
         when Lattice => return "Lattice Armor";
         when Field => return "Field Projection";
         when Neural => return "Neural Archive";
         when Tidal => return "Tidal Harvest";
         when Myco => return "Mycelial Accord";
         when Habitat => return "Habitat Engineering";
         when Plasma => return "Plasma Lance";
         when Gravitic => return "Gravitic Drives";
         when Quantum => return "Quantum Cognition";
         when Synth => return "Synthetic Sentience";
         when Sapper => return "Seismic Sapping";
         when Boring => return "Lithic Boring";
         when Naval => return "Hydrodynamic Hulls";
         when Ordnance => return "Naval Ordnance";
         when Dread => return "Armoured Hulls";
         when Ascend => return "Ascendant Convergence";
      end case;
   end Tech_Name;

   function Tech_Blurb (T : Integer) return String is
   begin
      if T < 0 or else T > 21 then
         return "";
      end if;
      case Tech_Kind'Val (T) is
         when Soil => return "Unlocks Hydroponic Vats.";
         when Deep => return "Unlocks the Fabricator.";
         when Photon => return "Terraformers can build Solar Collectors.";
         when Kinetic => return "Unlocks the Lancer.";
         when Sensors => return "+1 vision for units and cities.";
         when Signal => return "+10% research. Unlocks the Dreamweave Theatre.";
         when Lattice => return "Unlocks the Warden.";
         when Field => return "Unlocks the Perimeter Shield.";
         when Neural => return "Unlocks the Data Spire.";
         when Tidal => return "Sea tiles +1 nutrient. Unlocks the Sea Colonist.";
         when Myco => return "Fungus yields food, minerals and energy and is easier to cross.";
         when Habitat => return "Unlocks the Habitat Dome (higher population cap).";
         when Plasma => return "Unlocks the Striker.";
         when Gravitic => return "Unlocks the Skimmer.";
         when Quantum => return "+25% research.";
         when Synth => return "+2 minerals in every city.";
         when Sapper => return "On the tree. Warren assaults are not in this build.";
         when Boring => return "On the tree. Warren construction is not in this build.";
         when Naval => return "Unlocks docks, fisheries, tidal collectors and ships.";
         when Ordnance => return "Unlocks the Frigate. Bombardment orders are not in this build.";
         when Dread => return "Unlocks the Assault Cruiser.";
         when Ascend => return "Unlocks the Resonance Beacon and the Ascension Asc_Array.";
      end case;
   end Tech_Blurb;

   function Pre (T : Tech_Kind; Slot : Positive) return Integer is
   begin
      case T is
         when Sensors => return (if Slot = 1 then Tech_Kind'Pos (Signal) else -1);
         when Lattice => return (if Slot = 1 then Tech_Kind'Pos (Deep) else -1);
         when Field =>
            return (if Slot = 1 then Tech_Kind'Pos (Lattice) else Tech_Kind'Pos (Photon));
         when Neural => return (if Slot = 1 then Tech_Kind'Pos (Signal) else -1);
         when Tidal => return (if Slot = 1 then Tech_Kind'Pos (Soil) else -1);
         when Myco =>
            return (if Slot = 1 then Tech_Kind'Pos (Soil) else Tech_Kind'Pos (Signal));
         when Habitat =>
            return (if Slot = 1 then Tech_Kind'Pos (Soil) else Tech_Kind'Pos (Deep));
         when Plasma =>
            return (if Slot = 1 then Tech_Kind'Pos (Kinetic) else Tech_Kind'Pos (Photon));
         when Gravitic =>
            return (if Slot = 1 then Tech_Kind'Pos (Plasma) else Tech_Kind'Pos (Field));
         when Quantum =>
            return (if Slot = 1 then Tech_Kind'Pos (Neural) else Tech_Kind'Pos (Photon));
         when Synth =>
            return (if Slot = 1 then Tech_Kind'Pos (Quantum) else Tech_Kind'Pos (Habitat));
         when Sapper =>
            return (if Slot = 1 then Tech_Kind'Pos (Boring) else Tech_Kind'Pos (Plasma));
         when Boring => return (if Slot = 1 then Tech_Kind'Pos (Deep) else -1);
         when Naval => return (if Slot = 1 then Tech_Kind'Pos (Tidal) else -1);
         when Ordnance =>
            return (if Slot = 1 then Tech_Kind'Pos (Naval) else Tech_Kind'Pos (Kinetic));
         when Dread =>
            return (if Slot = 1 then Tech_Kind'Pos (Ordnance) else Tech_Kind'Pos (Plasma));
         when Ascend =>
            return (if Slot = 1 then Tech_Kind'Pos (Synth) else Tech_Kind'Pos (Myco));
         when others => return -1;
      end case;
   end Pre;

   --  Personality research order, tech positions. 22 entries each.
   Prio : constant array (0 .. 3, 0 .. 21) of Integer :=
     (0 => (3, 1, 6, 17, 4, 2, 12, 0, 9, 18, 19, 16, 7, 13, 20, 5, 11, 8, 14, 10, 15, 21),
      1 => (5, 8, 4, 0, 2, 14, 1, 11, 17, 9, 18, 10, 15, 21, 6, 7, 3, 19, 12, 16, 13, 20),
      2 => (0, 5, 10, 2, 4, 9, 18, 1, 11, 3, 19, 17, 8, 14, 15, 21, 6, 7, 12, 16, 13, 20),
      3 => (0, 1, 2, 9, 18, 11, 17, 5, 4, 8, 3, 19, 6, 10, 14, 15, 21, 7, 12, 16, 13, 20));

   --  Initial policies: econ, focus, society, env. Defaults are 0,0,0,0.
   AI_Pol : constant array (0 .. 3, 0 .. 3) of Integer :=
     (0 => (2, 2, 3, 0),
      1 => (1, 1, 1, 0),
      2 => (3, 3, 2, 2),
      3 => (1, 3, 2, 3));

   function Pol_Name (Axis, Value : Integer) return String is
   begin
      case Axis is
         when 0 =>
            case Value is
               when 0 => return "Balanced Ledger";
               when 1 => return "Open Exchange";
               when 2 => return "Directed Output";
               when 3 => return "Symbiotic Charter";
               when others => return "?";
            end case;
         when 1 =>
            case Value is
               when 0 => return "Civic Balance";
               when 1 => return "Inquiry Mandate";
               when 2 => return "Vigilance Doctrine";
               when 3 => return "Prosperity Pact";
               when others => return "?";
            end case;
         when 2 =>
            case Value is
               when 0 => return "Civic Assembly";
               when 1 => return "Merit Councils";
               when 2 => return "Frontier Charter";
               when 3 => return "Martial Levy";
               when others => return "?";
            end case;
         when others =>
            case Value is
               when 0 => return "Managed Land";
               when 1 => return "Extractive Drive";
               when 2 => return "Fungal Harmony";
               when 3 => return "Reclamation Corps";
               when others => return "?";
            end case;
      end case;
   end Pol_Name;

   type Mods is record
      En, Min, Labs, Att, Tech, Growth, Col, Unit, Rep, Beast, Terra, Ww : Long_Float := 1.0;
      Food, Upkeep, Fung_Rel, F_Move, Calm, En_City, Mor, Law, Fsoothe : Long_Float := 0.0;
   end record;

   function Policy (Fid : Integer) return Mods is
      M : Mods;
      P : Integer;
   begin
      if Fid < 0 or else Fid >= Fac_N then
         return M;
      end if;
      for Axis in 0 .. 3 loop
         P := Factions (Fid).Pol (Axis);
         if Axis = 0 and then P = 1 then
            M.En := M.En * 1.2; M.Min := M.Min * 0.9; M.Rep := M.Rep * 1.25;
         elsif Axis = 0 and then P = 2 then
            M.Min := M.Min * 1.15; M.En := M.En * 0.85;
         elsif Axis = 0 and then P = 3 then
            M.Food := M.Food + 1.0; M.Min := M.Min * 0.9; M.Fung_Rel := M.Fung_Rel + 5.0;
         elsif Axis = 1 and then P = 1 then
            M.Labs := M.Labs * 1.2; M.Min := M.Min * 0.9;
         elsif Axis = 1 and then P = 2 then
            M.Ww := M.Ww * 0.75; M.Att := M.Att * 1.2; M.Labs := M.Labs * 0.85;
         elsif Axis = 1 and then P = 3 then
            M.Food := M.Food + 1.0; M.Labs := M.Labs * 0.9; M.Mor := M.Mor + 1.0;
         elsif Axis = 2 and then P = 0 then
            M.Mor := M.Mor + 1.0;
         elsif Axis = 2 and then P = 1 then
            M.Tech := M.Tech * 0.88; M.Growth := M.Growth * 1.1;
         elsif Axis = 2 and then P = 2 then
            M.Mor := M.Mor - 1.0; M.Col := M.Col * 0.7; M.Growth := M.Growth * 0.9;
            M.Upkeep := M.Upkeep + 0.25; M.Labs := M.Labs * 0.95;
         elsif Axis = 2 and then P = 3 then
            M.Law := M.Law + 1.0; M.Ww := M.Ww * 0.5; M.Unit := M.Unit * 0.9;
            M.Rep := M.Rep * 0.75;
         elsif Axis = 3 and then P = 1 then
            M.Mor := M.Mor - 1.0; M.Min := M.Min * 1.12; M.Beast := M.Beast * 1.5;
            M.Fung_Rel := M.Fung_Rel - 12.0;
         elsif Axis = 3 and then P = 2 then
            M.Fsoothe := M.Fsoothe + 1.0; M.F_Move := M.F_Move + 1.0;
            M.Calm := M.Calm + 1.0; M.Fung_Rel := M.Fung_Rel + 10.0; M.Min := M.Min * 0.9;
         elsif Axis = 3 and then P = 3 then
            M.Terra := M.Terra * 0.65; M.En_City := M.En_City + (1.0 / 3.0);
            M.En := M.En * 0.95; M.Fung_Rel := M.Fung_Rel - 5.0;
         end if;
      end loop;
      if Factions (Fid).Unrest > 0 then
         M.Min := M.Min * 0.85;
         M.Labs := M.Labs * 0.85;
      end if;
      return M;
   end Policy;

   function City_At (I : Integer) return Integer is
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Loc = I then
            return C;
         end if;
      end loop;
      return -1;
   end City_At;

   function Find_Unit (Id : Integer) return Integer is
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Id = Id then
            return U;
         end if;
      end loop;
      return -1;
   end Find_Unit;

   function Find_City (Id : Integer) return Integer is
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Id = Id then
            return C;
         end if;
      end loop;
      return -1;
   end Find_City;

   procedure Remove_Unit (Idx : Integer) is
   begin
      if Idx < 0 or else Idx >= Unit_N then
         return;
      end if;
      for J in Idx .. Unit_N - 2 loop
         Units (J) := Units (J + 1);
      end loop;
      Unit_N := Unit_N - 1;
   end Remove_Unit;

   procedure Remove_City (Idx : Integer) is
   begin
      if Idx < 0 or else Idx >= City_N then
         return;
      end if;
      for J in Idx .. City_N - 2 loop
         Cities (J) := Cities (J + 1);
      end loop;
      City_N := City_N - 1;
   end Remove_City;

   function Make_Unit (Fid : Integer; K : Unit_Kind; Loc : Integer) return Integer is
      U : Unit_Rec;
   begin
      if Unit_N >= Max_Units or else Loc < 0 or else Loc >= NTiles then
         return -1;
      end if;
      U.Id := Next_Id;
      Next_Id := Next_Id + 1;
      U.Fac := Fid;
      U.Kind := K;
      U.Loc := Loc;
      U.HP := 10;
      U.MP := U_Mv (K) * 3;
      U.Goto_At := -1;
      U.Target := -1;
      U.Home := -1;
      U.On_Ship := -1;
      Units (Unit_N) := U;
      Unit_N := Unit_N + 1;
      return Unit_N - 1;
   end Make_Unit;

   function City_Has (C : Integer; F : Fac_Kind) return Boolean is
   begin
      if C < 0 or else C >= City_N then
         return False;
      end if;
      for I in 0 .. Cities (C).Fac_N - 1 loop
         if Cities (C).Facs (I) = Fac_Kind'Pos (F) then
            return True;
         end if;
      end loop;
      return False;
   end City_Has;

   function Has_Docks (Fid : Integer) return Boolean is
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid and then City_Has (C, Docks) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Docks;

   procedure Yield3 (I, Fid : Integer; N, Mi, En : out Integer) is
      T : Tile;
   begin
      N := 0; Mi := 0; En := 0;
      if I < 0 or else I >= NTiles then
         return;
      end if;
      T := Tiles (I);
      if not T.Land then
         N := 1;
         if Has_Tech (Fid, Tech_Kind'Pos (Tidal)) then
            N := N + 1;
         end if;
         En := 1;
         return;
      end if;
      if T.Fungus then
         if Has_Tech (Fid, Tech_Kind'Pos (Myco)) then
            N := 1; Mi := 1; En := 2;
         elsif Fid >= 0 and then Slot_Key (Fid) = 2 then
            N := 1; Mi := 1; En := 1;
         end if;
         return;
      end if;
      N := T.Moist;
      if T.Rock = 2 and then N > 0 then
         N := N - 1;
      end if;
      if T.Rock >= 1 then
         Mi := 1;
      end if;
      if T.Elev > 60 then
         En := 1;
      end if;
      case T.Imp is
         when Farm => N := N + 1;
         when Mine =>
            if T.Rock >= 1 then
               Mi := Mi + 2;
            else
               Mi := Mi + 1;
            end if;
         when Solar => En := En + 2;
         when None => null;
      end case;
      if N < 0 then
         N := 0;
      end if;
   end Yield3;

   procedure Territory is
      D : Integer;
      R : Integer;
      DBest : array (0 .. Max_Tiles - 1) of Integer := (others => 99);
      IdBest : array (0 .. Max_Tiles - 1) of Integer := (others => Integer'Last);
   begin
      for I in 0 .. NTiles - 1 loop
         Terr (I) := -1;
      end loop;
         for C in 0 .. City_N - 1 loop
            R := (if Cities (C).Pop >= 5 then 4 else 3);
            for I in 0 .. NTiles - 1 loop
               D := Dist (I, Cities (C).Loc);
               if D <= R and then (D < DBest (I) or else (D = DBest (I) and then Cities (C).Id < IdBest (I))) then
                  DBest (I) := D;
                  IdBest (I) := Cities (C).Id;
                  Terr (I) := Cities (C).Fac;
               end if;
            end loop;
         end loop;
   end Territory;

   function Site_Score (I, Fid : Integer; Sea : Boolean) return Long_Float is
      Nb : Nbr_Arr;
      NN : Natural;
      N, Mi, En : Integer;
      S : Long_Float := 0.0;
      Reach : Integer;
   begin
      if I < 0 or else I >= NTiles then
         return -1.0;
      end if;
      if Sea then
         Reach := (if Has_Docks (Fid) then 3 else 1);
         if Tiles (I).Land or else Tiles (I).Sea_Dist > Reach then
            return -1.0;
         end if;
      else
         if not Tiles (I).Land or else Tiles (I).Fungus then
            return -1.0;
         end if;
      end if;
      for C in 0 .. City_N - 1 loop
         if Dist (Cities (C).Loc, I) < 3 then
            return -1.0;
         end if;
      end loop;
      Territory;
      if Terr (I) >= 0 and then Terr (I) /= Fid then
         return -1.0;
      end if;
      Nbrs (I, 2, NN, Nb);
      for K in 0 .. NN - 1 loop
         Yield3 (Nb (K), Fid, N, Mi, En);
         S := S + Long_Float (N) * 1.5 + Long_Float (Mi) + Long_Float (En);
      end loop;
      if Tiles (I).Rock = 2 then
         S := S - 2.0;
      end if;
      Nbrs (I, 1, NN, Nb);
      for K in 0 .. NN - 1 loop
         if not Tiles (Nb (K)).Land then
            S := S + 2.0;
            exit;
         end if;
      end loop;
      return S;
   end Site_Score;

   function Count_Cities (Fid : Integer) return Integer is
      N : Integer := 0;
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Cities;

   function Count_Units (Fid : Integer; K : Unit_Kind) return Integer is
      N : Integer := 0;
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac = Fid and then Units (U).Kind = K then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Units;

   procedure Assign_Work (C : Integer) is
      Taken : array (0 .. Max_Tiles - 1) of Boolean := (others => False);
      Cand : array (0 .. 48) of Integer;
      CN, NN : Natural;
      Nb : Nbr_Arr;
      N, Mi, En, Food, Pick, Best : Integer;
      Need : Boolean;
      BV, V : Long_Float;
   begin
      for O in 0 .. City_N - 1 loop
         if O /= C then
            for Wk in 0 .. Cities (O).Work_N - 1 loop
               if Cities (O).Worked (Wk) in 0 .. NTiles - 1 then
                  Taken (Cities (O).Worked (Wk)) := True;
               end if;
            end loop;
         end if;
      end loop;
      Nbrs (Cities (C).Loc, 2, NN, Nb);
      CN := 0;
      for K in 0 .. NN - 1 loop
         if not Taken (Nb (K)) and then City_At (Nb (K)) < 0 then
            Cand (CN) := Nb (K);
            CN := CN + 1;
         end if;
      end loop;
      Cities (C).Work_N := 0;
      Yield3 (Cities (C).Loc, Cities (C).Fac, N, Mi, En);
      Food := N + 1;
      for P in 1 .. Cities (C).Pop loop
         exit when CN = 0;
         Need := Food - 2 * Cities (C).Pop < 2;
         Best := 0;
         BV := -1.0e9;
         for K in 0 .. CN - 1 loop
            Yield3 (Cand (K), Cities (C).Fac, N, Mi, En);
            V := Long_Float (N) * (if Need then 3.0 else 1.6)
              + Long_Float (Mi) * 2.0 + Long_Float (En) * 1.4;
            if V > BV or else (V = BV and then Cand (K) < Cand (Best)) then
               BV := V;
               Best := K;
            end if;
         end loop;
         Pick := Cand (Best);
         Cities (C).Worked (Cities (C).Work_N) := Pick;
         Cities (C).Work_N := Cities (C).Work_N + 1;
         Yield3 (Pick, Cities (C).Fac, N, Mi, En);
         Food := Food + N;
         Cand (Best) := Cand (CN - 1);
         CN := CN - 1;
      end loop;
   end Assign_Work;

   procedure City_Base (C : Integer; N, Mi, En : out Integer) is
      A, B, D : Integer;
   begin
      Yield3 (Cities (C).Loc, Cities (C).Fac, A, B, D);
      N := Integer'Max (2, A) + 1;
      Mi := Integer'Max (1, B);
      En := Integer'Max (1, D) + 2;
      for Wk in 0 .. Cities (C).Work_N - 1 loop
         Yield3 (Cities (C).Worked (Wk), Cities (C).Fac, A, B, D);
         N := N + A;
         Mi := Mi + B;
         En := En + D;
         if not Tiles (Cities (C).Worked (Wk)).Land then
            if City_Has (C, Fishery) then
               N := N + 1;
            end if;
            if City_Has (C, Tidal_C) then
               En := En + 1;
            end if;
         end if;
      end loop;
      if City_Has (C, Hydro) then
         N := N + 3;
      end if;
      if Has_Tech (Cities (C).Fac, Tech_Kind'Pos (Synth)) then
         Mi := Mi + 2;
      end if;
      if City_Has (C, Fab) then
         Mi := (Mi * 5) / 4;
      end if;
   end City_Base;

   function Food_Box (C : Integer) return Integer is
      M : constant Mods := Policy (Cities (C).Fac);
      G : Long_Float := 1.0;
   begin
      if Slot_Key (Cities (C).Fac) = 3 then
         G := 0.85;
      end if;
      return JS_Round (Long_Float (Cities (C).Pop + 1) * 7.0 * G * M.Growth);
   end Food_Box;

   function Pop_Cap (C : Integer) return Integer is
     (if City_Has (C, Dome) then 14 else 8);

   function Tech_Cost (Fid : Integer) return Integer is
      NC : constant Integer := Count_Cities (Fid);
      M : constant Mods := Policy (Fid);
      Base : Long_Float;
   begin
      Base := Long_Float (20 + Factions (Fid).Tech_N * 17)
        * (1.0 + 0.04 * Long_Float (Integer'Max (0, NC - 4)));
      if Rule (6) then
         Base := Base * 1.5;
      end if;
      Base := Base * M.Tech;
      return Integer'Max (1, JS_Round (Base));
   end Tech_Cost;

   function Tech_OK (Fid, Tech : Integer) return Boolean is
   begin
      if Has_Tech (Fid, Tech) or else Tech not in 0 .. 21 then
         return False;
      end if;
      for Slot in 1 .. 2 loop
         declare
            P : constant Integer := Pre (Tech_Kind'Val (Tech), Slot);
         begin
            if P >= 0 and then not Has_Tech (Fid, P) then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Tech_OK;

   procedure Pick_Research (Fid : Integer) is
      F : Faction_Rec renames Factions (Fid);
   begin
      if F.Research >= 0 then
         return;
      end if;
      for I in 0 .. 21 loop
         if Tech_OK (Fid, Prio (Slot_Key (Fid), I)) then
            F.Research := Prio (Slot_Key (Fid), I);
            return;
         end if;
      end loop;
      for T in 0 .. 21 loop
         if Tech_OK (Fid, T) then
            F.Research := T;
            return;
         end if;
      end loop;
   end Pick_Research;

   function Item_Is_Unit (Code : Integer) return Boolean is
     (Code in 0 .. Unit_Kind'Pos (Unit_Kind'Last));

   function Item_Cost (Code, Fid : Integer) return Integer is
      M : Mods;
      V : Integer;
   begin
      if Item_Is_Unit (Code) then
         V := U_Cost (Unit_Kind'Val (Code));
         if Fid in 0 .. Fac_N - 1 then
            M := Policy (Fid);
            if U_Found (Unit_Kind'Val (Code)) then
               V := JS_Round (Long_Float (V) * M.Col);
            elsif not U_Civ (Unit_Kind'Val (Code)) then
               V := JS_Round (Long_Float (V) * M.Unit);
            end if;
         end if;
         return Integer'Max (1, V);
      elsif Code in 100 .. 100 + Fac_Kind'Pos (Fac_Kind'Last) then
         return F_Cost (Fac_Kind'Val (Code - 100));
      end if;
      return 1;
   end Item_Cost;

   function Coastal (C : Integer) return Boolean is
      Nb : Nbr_Arr;
      NN : Natural;
   begin
      if C < 0 then
         return False;
      end if;
      if Cities (C).Sea then
         return True;
      end if;
      Nbrs (Cities (C).Loc, 1, NN, Nb);
      for K in 0 .. NN - 1 loop
         if not Tiles (Nb (K)).Land then
            return True;
         end if;
      end loop;
      return False;
   end Coastal;

   function Can_Build (Fid, Code : Integer) return Boolean is
      K : Unit_Kind;
      Fk : Fac_Kind;
      Pop, Nc : Integer;
   begin
      if Fid < 0 or else not Factions (Fid).Alive then
         return False;
      end if;
      if Item_Is_Unit (Code) then
         K := Unit_Kind'Val (Code);
         if U_Native (K) then
            return False;
         end if;
         if U_Tech (K) >= 0 and then not Has_Tech (Fid, U_Tech (K)) then
            return False;
         end if;
         return True;
      end if;
      if Code < 100 or else Code > 100 + Fac_Kind'Pos (Fac_Kind'Last) then
         return False;
      end if;
      Fk := Fac_Kind'Val (Code - 100);
      if F_Tech (Fk) >= 0 and then not Has_Tech (Fid, F_Tech (Fk)) then
         return False;
      end if;
      if F_Project (Fk) and then not Rule (1) then
         return False;
      end if;
      if F_Project (Fk) then
         for C in 0 .. City_N - 1 loop
            if Cities (C).Fac = Fid and then City_Has (C, Fk) then
               return False;
            end if;
         end loop;
         if Fk = Asc_Array then
            Nc := 0;
            Pop := 0;
            for C in 0 .. City_N - 1 loop
               if Cities (C).Fac = Fid then
                  if not City_Has (C, Beacon) then
                     null;
                  end if;
                  Nc := Nc + 1;
                  Pop := Pop + Cities (C).Pop;
               end if;
            end loop;
            if not (for some C in 0 .. City_N - 1 =>
                      Cities (C).Fac = Fid and then City_Has (C, Beacon))
            then
               return False;
            end if;
            if Nc < 5 or else Pop < 35 then
               return False;
            end if;
         end if;
      end if;
      return True;
   end Can_Build;

   function Queue_Has (C, Code : Integer) return Boolean is
   begin
      for I in 0 .. Cities (C).Q_Len - 1 loop
         if Cities (C).Queue (I) = Code then
            return True;
         end if;
      end loop;
      return False;
   end Queue_Has;

   function Build_Count (C : Integer) return Integer is
      N : Integer := 0;
      Code : Integer;
   begin
      if C < 0 or else C >= City_N then
         return 0;
      end if;
      for K in Unit_Kind loop
         Code := Unit_Kind'Pos (K);
         if Can_Build (Cities (C).Fac, Code) then
            if U_Ship (K) and then not City_Has (C, Docks) then
               null;
            else
               N := N + 1;
            end if;
         end if;
      end loop;
      for K in Fac_Kind loop
         Code := 100 + Fac_Kind'Pos (K);
         if Can_Build (Cities (C).Fac, Code)
           and then not City_Has (C, K)
           and then not Queue_Has (C, Code)
           and then not (F_Coast (K) and then not Coastal (C))
           and then not (F_Project (K) and then
             (for some O in 0 .. City_N - 1 =>
                Cities (O).Fac = Cities (C).Fac and then Queue_Has (O, Code)))
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Build_Count;

   function Build_At (C, Index : Integer) return Integer is
      N : Integer := 0;
      Code : Integer;
   begin
      if C < 0 or else C >= City_N or else Index < 0 then
         return -1;
      end if;
      for K in Unit_Kind loop
         Code := Unit_Kind'Pos (K);
         if Can_Build (Cities (C).Fac, Code) then
            if not (U_Ship (K) and then not City_Has (C, Docks)) then
               if N = Index then
                  return Code;
               end if;
               N := N + 1;
            end if;
         end if;
      end loop;
      for K in Fac_Kind loop
         Code := 100 + Fac_Kind'Pos (K);
         if Can_Build (Cities (C).Fac, Code)
           and then not City_Has (C, K)
           and then not Queue_Has (C, Code)
           and then not (F_Coast (K) and then not Coastal (C))
           and then not (F_Project (K) and then
             (for some O in 0 .. City_N - 1 =>
                Cities (O).Fac = Cities (C).Fac and then Queue_Has (O, Code)))
         then
            if N = Index then
               return Code;
            end if;
            N := N + 1;
         end if;
      end loop;
      return -1;
   end Build_At;

   function Buy_Cost (C : Integer) return Integer is
      Left : Integer;
   begin
      if C < 0 or else Cities (C).Q_Len = 0 then
         return 0;
      end if;
      Left := Item_Cost (Cities (C).Queue (0), Cities (C).Fac) - Cities (C).Prod;
      if Left < 0 then
         Left := 0;
      end if;
      if Cities (C).Prod = 0 then
         return Left * 2 + Left;
      end if;
      return Left * 2;
   end Buy_Cost;

   procedure Set_Name (C : in out City_Rec; S : String) is
      N : constant Natural := Integer'Min (S'Length, Name_Max);
   begin
      C.Name := (others => ' ');
      C.Name_Len := N;
      if N > 0 then
         C.Name (1 .. N) := S (S'First .. S'First + N - 1);
      end if;
   end Set_Name;

   function Name_Of (C : City_Rec) return String is
     (C.Name (1 .. C.Name_Len));

   function Name_Taken (S : String) return Boolean is
   begin
      for C in 0 .. City_N - 1 loop
         if Name_Of (Cities (C)) = S then
            return True;
         end if;
      end loop;
      return False;
   end Name_Taken;

   function Suggest (Fid : Integer; Sea : Boolean) return String is
      Key : constant Integer := Slot_Key (Fid);
      N : Natural;
   begin
      N := (if Sea then Colony_Names.Sea_Count (Key) else Colony_Names.Land_Count (Key));
      for I in 0 .. N - 1 loop
         declare
            S : constant String :=
              (if Sea then Colony_Names.Sea_Name (Key, I) else Colony_Names.Land_Name (Key, I));
         begin
            if S'Length > 0 and then not Name_Taken (S) then
               return S;
            end if;
         end;
      end loop;
      for I in 0 .. Colony_Names.Fallback_Count - 1 loop
         declare
            S : constant String := Colony_Names.Fallback (I);
         begin
            if not Name_Taken (S) then
               return S;
            end if;
         end;
      end loop;
      return "Colony " & Img (City_N + 1);
   end Suggest;

   function Can_Found (Uidx : Integer; Loc : Integer) return String is
      U : Unit_Rec;
      Reach : Integer;
   begin
      if Uidx < 0 or else Uidx >= Unit_N then
         return "No such unit";
      end if;
      U := Units (Uidx);
      if not U_Found (U.Kind) then
         return "Only colonists can found cities";
      end if;
      if Loc < 0 or else Loc >= NTiles then
         return "No site here";
      end if;
      if U.Kind = Sea_Colonist then
         if Tiles (Loc).Land then
            return "Sea colonists found on ocean tiles";
         end if;
         if Loc /= U.Loc and then Dist (Loc, U.Loc) /= 1 then
            return "Must be adjacent";
         end if;
         Reach := (if Has_Docks (U.Fac) then 3 else 1);
         if Tiles (Loc).Sea_Dist > Reach then
            return "Too far from land";
         end if;
      else
         if not Tiles (Loc).Land then
            return "Must be on land";
         end if;
         if Loc /= U.Loc then
            return "Found on the colonist's own tile";
         end if;
      end if;
      for C in 0 .. City_N - 1 loop
         if Dist (Cities (C).Loc, Loc) < 3 then
            return "Too close to another city (min distance 3)";
         end if;
      end loop;
      Territory;
      if Terr (Loc) >= 0 and then Terr (Loc) /= U.Fac then
         return "Inside rival territory";
      end if;
      return "";
   end Can_Found;

   function Found_At (Uidx, Loc : Integer) return Boolean is
      Why : constant String := Can_Found (Uidx, Loc);
      C : City_Rec;
      Nm : String (1 .. Name_Max) := (others => ' ');
      NL : Natural := 0;
   begin
      if Why'Length > 0 then
         Set_Error (Why);
         return False;
      end if;
      declare
         S : constant String := Suggest (Units (Uidx).Fac, not Tiles (Loc).Land);
      begin
         NL := Integer'Min (S'Length, Name_Max);
         if NL > 0 then
            Nm (1 .. NL) := S (S'First .. S'First + NL - 1);
         end if;
      end;
      C.Id := Next_Id;
      Next_Id := Next_Id + 1;
      C.Fac := Units (Uidx).Fac;
      C.Loc := Loc;
      C.Pop := 1;
      C.Food := 0;
      C.Prod := 0;
      C.Founded := Turn_N;
      C.Sea := not Tiles (Loc).Land;
      C.Capital := Count_Cities (C.Fac) = 0;
      if NL = 0 then
         Set_Name (C, "Colony");
      else
         Set_Name (C, Nm (1 .. NL));
      end if;
      if City_N >= Max_Cities then
         Set_Error ("Too many cities");
         return False;
      end if;
      Cities (City_N) := C;
      City_N := City_N + 1;
      Tiles (Loc).Fungus := False;
      Tiles (Loc).Road := True;
      Factions (C.Fac).Founded := Factions (C.Fac).Founded + 1;
      Remove_Unit (Uidx);
      Assign_Work (City_N - 1);
      Update_Seen (C.Fac);
      Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (C.Fac))
           & " founds " & Name_Of (Cities (City_N - 1)));
      return True;
   end Found_At;

   function Found_City (Uidx : Integer) return Boolean is
      Loc : Integer := Units (Uidx).Loc;
      Nb : Nbr_Arr;
      NN : Natural;
      Best : Integer := -1;
      BS, S : Long_Float;
   begin
      if Units (Uidx).Kind = Sea_Colonist and then Tiles (Loc).Land then
         Nbrs (Loc, 1, NN, Nb);
         BS := -1.0e9;
         for K in 0 .. NN - 1 loop
            S := Site_Score (Nb (K), Units (Uidx).Fac, True);
            if S > BS then
               BS := S;
               Best := Nb (K);
            end if;
         end loop;
         Loc := Best;
      end if;
      if Loc < 0 then
         Set_Error ("No coastal ocean tile next to this unit");
         return False;
      end if;
      return Found_At (Uidx, Loc);
   end Found_City;

   function Vis_R (U : Unit_Rec) return Integer is
      R : Integer := (if U_Mv (U.Kind) > 1 then 3 else 2);
   begin
      if Tiles (U.Loc).Land and then not U_Ship (U.Kind)
        and then (Tiles (U.Loc).Rock = 2 or else Tiles (U.Loc).Elev >= 70)
      then
         R := R + 1;
      end if;
      if U.Fac >= 0 and then Has_Tech (U.Fac, Tech_Kind'Pos (Sensors)) then
         R := R + 1;
      end if;
      return R;
   end Vis_R;

   procedure Mark (Fid, Loc, Radius : Integer) is
      Nb : Nbr_Arr;
      NN : Natural;
      M : U8;
   begin
      if Fid < 0 or else Loc < 0 or else Loc >= NTiles then
         return;
      end if;
      Factions (Fid).Vis (Loc) := True;
      Factions (Fid).Seen (Loc) := True;
      M := 0;
      if Tiles (Loc).Fungus then
         M := M or 1;
      end if;
      if Tiles (Loc).Road then
         M := M or 2;
      end if;
      M := M or Interfaces.Shift_Left (U8 (Imp_Kind'Pos (Tiles (Loc).Imp)), 2);
      Factions (Fid).Mem (Loc) := M;
      Nbrs (Loc, Radius, NN, Nb);
      for K in 0 .. NN - 1 loop
         Factions (Fid).Vis (Nb (K)) := True;
         Factions (Fid).Seen (Nb (K)) := True;
         M := 0;
         if Tiles (Nb (K)).Fungus then
            M := M or 1;
         end if;
         if Tiles (Nb (K)).Road then
            M := M or 2;
         end if;
         M := M or Interfaces.Shift_Left (U8 (Imp_Kind'Pos (Tiles (Nb (K)).Imp)), 2);
         Factions (Fid).Mem (Nb (K)) := M;
      end loop;
   end Mark;

   procedure Update_Seen (Fid : Integer) is
   begin
      if Fid < 0 or else Fid >= Fac_N then
         return;
      end if;
      for I in 0 .. NTiles - 1 loop
         Factions (Fid).Vis (I) := False;
      end loop;
      if Rule (4) then
         for I in 0 .. NTiles - 1 loop
            Factions (Fid).Seen (I) := True;
         end loop;
      end if;
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac = Fid and then Units (U).On_Ship < 0 then
            Mark (Fid, Units (U).Loc, Vis_R (Units (U)));
         end if;
      end loop;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid then
            Mark (Fid, Cities (C).Loc, (if Has_Tech (Fid, Tech_Kind'Pos (Sensors)) then 4 else 3));
         end if;
      end loop;
   end Update_Seen;

   function Mul_For (Fid : Integer) return Long_Float is
      type Row is record
         Mor, AI, Hu, Nat : Long_Float;
      end record;
      D : constant array (0 .. 5) of Row :=
        ((0.6, 0.7, 1.15, 0.6),
         (0.8, 0.85, 1.05, 0.8),
         (1.0, 1.0, 1.0, 1.0),
         (1.2, 1.15, 1.0, 1.1),
         (1.4, 1.3, 0.95, 1.25),
         (1.6, 1.5, 0.9, 1.5));
      Ix : Integer := Difficulty;
   begin
      if Ix < 0 then
         Ix := 0;
      elsif Ix > 5 then
         Ix := 5;
      end if;
      if Fid in 0 .. Fac_N - 1 and then not Factions (Fid).AI then
         return D (Ix).Hu;
      end if;
      return D (Ix).AI;
   end Mul_For;

   function Nat_Press return Long_Float is
      D : constant array (0 .. 5) of Long_Float := (0.6, 0.8, 1.0, 1.1, 1.25, 1.5);
      Ix : Integer := Difficulty;
   begin
      if Ix < 0 then
         Ix := 0;
      elsif Ix > 5 then
         Ix := 5;
      end if;
      return D (Ix);
   end Nat_Press;

   function Mor_Press (Fid : Integer) return Long_Float is
      D : constant array (0 .. 5) of Long_Float := (0.6, 0.8, 1.0, 1.2, 1.4, 1.6);
      Ix : Integer := Difficulty;
   begin
      if Fid not in 0 .. Fac_N - 1 or else Factions (Fid).AI then
         return 1.0;
      end if;
      if Ix < 0 then
         Ix := 0;
      elsif Ix > 5 then
         Ix := 5;
      end if;
      return D (Ix);
   end Mor_Press;

   procedure Morale (C : Integer) is
      M : constant Mods := Policy (Cities (C).Fac);
      Pos, Neg, V : Long_Float := 0.0;
      NF : Integer := 0;
      Nb : Nbr_Arr;
      NN : Natural;
      G : Integer := 0;
      procedure Add (X : Long_Float) is
      begin
         if X > 0.0 then
            Pos := Pos + X;
         elsif X < 0.0 then
            Neg := Neg - X;
         end if;
      end Add;
   begin
      Add (3.0);
      Add (M.Mor);
      for I in 0 .. Cities (C).Fac_N - 1 loop
         if Cities (C).Facs (I) in 0 .. Fac_Kind'Pos (Fac_Kind'Last) then
            Add (Long_Float (F_Ent (Fac_Kind'Val (Cities (C).Facs (I)))));
         end if;
      end loop;
      if City_Has (C, Dome) then
         Add (1.0);
      end if;
      Add (-Long_Float (Integer'Max (0, Cities (C).Pop - 5)) * 0.4);
      Add (-Long_Float (Integer'Max (0, Count_Cities (Cities (C).Fac) - 6)) * 0.25);
      Nbrs (Cities (C).Loc, 2, NN, Nb);
      for K in 0 .. NN - 1 loop
         if Tiles (Nb (K)).Fungus then
            NF := NF + 1;
         end if;
      end loop;
      if M.Fsoothe > 0.0 or else Slot_Key (Cities (C).Fac) = 2 then
         Add (Long_Float'Min (1.0, Long_Float (NF) / 8.0));
      else
         Add (-Long_Float'Min (2.0, Long_Float (NF) / 5.0));
      end if;
      Add (-Long_Float'Min (3.0, (Factions (Cities (C).Fac).WW / 3.0) * M.Ww));
      if M.Law > 0.0 then
         for U in 0 .. Unit_N - 1 loop
            if Units (U).Loc = Cities (C).Loc and then Units (U).Fac = Cities (C).Fac
              and then not U_Civ (Units (U).Kind) and then not U_Ship (Units (U).Kind)
            then
               G := G + 1;
            end if;
         end loop;
         Add (Long_Float (Integer'Min (2, G)));
      end if;
      if Factions (Cities (C).Fac).Unrest > 0 then
         Add (-2.0);
      end if;
      if Cities (C).Mood_Until >= Turn_N then
         Add (Long_Float (Cities (C).Mood_Add));
      end if;
      V := Pos - Neg * Mor_Press (Cities (C).Fac);
      Cities (C).Mor10 := JS_Round (V * 10.0);
      if Cities (C).Mor10 >= 0 then
         Cities (C).Mood := 0;
      elsif Cities (C).Mor10 > -30 then
         Cities (C).Mood := 1;
      else
         Cities (C).Mood := 2;
      end if;
   end Morale;

   function Att_Str (U : Integer) return Long_Float is
      A : Long_Float := Long_Float (U_Atk (Units (U).Kind));
   begin
      if Units (U).On_Ship >= 0 then
         A := A * 0.7;
      end if;
      if Units (U).Fac >= 0 then
         A := A * Policy (Units (U).Fac).Att;
         if Slot_Key (Units (U).Fac) = 0 then
            A := A * (if Turn_N >= 100 then 1.25 else 1.12);
         end if;
      end if;
      return A * (0.5 + Long_Float (Units (U).HP) / 20.0);
   end Att_Str;

   function Def_Str (U, Att : Integer) return Long_Float is
      D : Long_Float := Long_Float (U_Def (Units (U).Kind));
      C : constant Integer := City_At (Units (U).Loc);
      Nb : Nbr_Arr;
      NN : Natural;
      Coast : Boolean := False;
   begin
      if U_Ship (Units (U).Kind) then
         if C >= 0 then
            D := D * 0.6;
         else
            Nbrs (Units (U).Loc, 1, NN, Nb);
            for K in 0 .. NN - 1 loop
               if Tiles (Nb (K)).Land then
                  Coast := True;
               end if;
            end loop;
            D := D * (if Coast then 1.25 else 0.9);
         end if;
      end if;
      if C >= 0 then
         D := D * 1.25;
         if Turn_N - Cities (C).Founded < 15 then
            D := D * 1.5;
         end if;
         if Turn_N < 100 and then Count_Cities (Units (U).Fac) = 1 then
            D := D * 1.75;
         end if;
         if Cities (C).Capital and then Cities (C).Fac = Units (U).Fac then
            D := D * (if Slot_Key (Units (U).Fac) = 1 then 1.8 else 1.5);
         end if;
         if City_Has (C, Shield) and then Att >= 0 and then Units (Att).Fac >= 0 then
            D := D * 2.0;
         end if;
      end if;
      if Tiles (Units (U).Loc).Rock = 2 then
         D := D * 1.25;
      end if;
      if Units (U).Fort then
         D := D * 1.25;
      end if;
      if Tiles (Units (U).Loc).Fungus and then Units (U).Fac < 0 then
         D := D * 1.25;
      end if;
      return D * (0.5 + Long_Float (Units (U).HP) / 20.0);
   end Def_Str;

   function Best_Def (Loc, Att : Integer) return Integer is
      Best : Integer := -1;
      BV, V : Long_Float := -1.0;
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Loc = Loc and then Units (U).Fac /= Units (Att).Fac
           and then Units (U).On_Ship < 0
         then
            V := Def_Str (U, Att);
            if V > BV then
               BV := V;
               Best := U;
            end if;
         end if;
      end loop;
      return Best;
   end Best_Def;

   procedure Fix_Capital (Fid : Integer) is
      Best, BP, Bid : Integer;
   begin
      if Fid < 0 then
         return;
      end if;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid and then Cities (C).Capital then
            return;
         end if;
      end loop;
      Best := -1;
      BP := -1;
      Bid := Integer'Last;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid
           and then (Cities (C).Pop > BP or else (Cities (C).Pop = BP and then Cities (C).Id < Bid))
         then
            BP := Cities (C).Pop;
            Bid := Cities (C).Id;
            Best := C;
         end if;
      end loop;
      if Best >= 0 then
         Cities (Best).Capital := True;
         Log ("T" & Img (Turn_N) & " capital moves to " & Name_Of (Cities (Best)));
      end if;
   end Fix_Capital;

   procedure Combat (Att, Def : Integer) is
      A : constant Long_Float := Att_Str (Att);
      D : constant Long_Float := Def_Str (Def, Att);
      P : constant Long_Float := A / Long_Float'Max (0.001, A + D);
      Win : Boolean;
      Loser, Wn : Integer;
   begin
      while Units (Att).HP > 0 and then Units (Def).HP > 0 loop
         if Rand < P then
            Units (Def).HP := Units (Def).HP - (1 + RI (3));
         else
            Units (Att).HP := Units (Att).HP - (1 + RI (3));
         end if;
      end loop;
      Win := Units (Att).HP > 0;
      if Win then
         Loser := Def;
         Wn := Att;
         if Units (Att).HP < 1 then
            Units (Att).HP := 1;
         end if;
      else
         Loser := Att;
         Wn := Def;
         if Units (Def).HP < 1 then
            Units (Def).HP := 1;
         end if;
      end if;
      if Units (Loser).Fac >= 0 then
         Factions (Units (Loser).Fac).Lost := Factions (Units (Loser).Fac).Lost + 1;
      end if;
      if Units (Wn).Fac >= 0 then
         Factions (Units (Wn).Fac).Kills := Factions (Units (Wn).Fac).Kills + 1;
         Factions (Units (Wn).Fac).Combats := Factions (Units (Wn).Fac).Combats + 1;
      end if;
      Log ("T" & Img (Turn_N) & " " & U_Name (Units (Att).Kind) & " fights "
           & U_Name (Units (Def).Kind) & " (" & (if Win then "attacker" else "defender") & ")");
      --  Remove the higher index first so the other index stays valid.
      if Loser > Wn then
         Remove_Unit (Loser);
      else
         Remove_Unit (Loser);
      end if;
   end Combat;

   function Enemy_At (I, Fid : Integer) return Boolean is
      C : Integer;
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Loc = I and then Units (U).Fac /= Fid and then Units (U).On_Ship < 0 then
            return True;
         end if;
      end loop;
      C := City_At (I);
      return C >= 0 and then Cities (C).Fac /= Fid;
   end Enemy_At;

   function Step (Uidx, To : Integer) return Boolean is
      U : Integer := Uidx;
      Cost : Integer;
      C, D : Integer;
      From : Integer;
   begin
      if U < 0 or else U >= Unit_N then
         Set_Error ("No such unit");
         return False;
      end if;
      if Units (U).MP <= 0 then
         Set_Error ("No moves left");
         return False;
      end if;
      if To < 0 or else To >= NTiles or else Dist (Units (U).Loc, To) /= 1 then
         Set_Error ("Not adjacent");
         return False;
      end if;
      if Units (U).On_Ship >= 0 then
         if not Tiles (To).Land and then City_At (To) < 0 then
            Set_Error ("Aboard a transport. Move onto a shore tile to land");
            return False;
         end if;
         Units (U).On_Ship := -1;
      end if;
      if U_Ship (Units (U).Kind) then
         C := City_At (To);
         if Tiles (To).Land and then C < 0 then
            Set_Error ("Ships cannot go ashore");
            return False;
         end if;
         if C >= 0 and then Cities (C).Fac /= Units (U).Fac then
            Set_Error ("Ships cannot storm a city");
            return False;
         end if;
         if C >= 0 and then not Coastal (C) then
            Set_Error ("Not a port");
            return False;
         end if;
      elsif not Tiles (To).Land and then City_At (To) < 0 then
         --  Board a friendly transport with room, or a docked sea colonist sails.
         declare
            Tr : Integer := -1;
            Cargo : Integer := 0;
         begin
            for O in 0 .. Unit_N - 1 loop
               if Units (O).Loc = To and then Units (O).Fac = Units (U).Fac
                 and then Units (O).Kind = Transport
               then
                  Tr := O;
               end if;
               if Tr >= 0 and then Units (O).On_Ship = Units (Tr).Id then
                  Cargo := Cargo + 1;
               end if;
            end loop;
            if Tr >= 0 and then Cargo < 3 then
               Units (U).On_Ship := Units (Tr).Id;
               Units (U).Loc := To;
               Units (U).MP := 0;
               Units (U).Fort := False;
               Units (U).Work := W_None;
               Log ("T" & Img (Turn_N) & " " & U_Name (Units (U).Kind) & " boards a transport");
               return True;
            end if;
         end;
         if not (Units (U).Kind = Sea_Colonist and then Has_Docks (Units (U).Fac)) then
            Set_Error ("Cannot enter sea");
            return False;
         end if;
      end if;
      From := Units (U).Loc;
      Units (U).Fort := False;
      Units (U).Work := W_None;
      if Enemy_At (To, Units (U).Fac) then
         if U_Atk (Units (U).Kind) <= 0 then
            Set_Error ("Non-combat unit cannot attack");
            return False;
         end if;
         D := Best_Def (To, U);
         if D >= 0 then
            declare
               Aid : constant Integer := Units (U).Id;
            begin
               Combat (U, D);
               U := Find_Unit (Aid);
               if U < 0 then
                  return True;
               end if;
               Units (U).MP := 0;
               if Best_Def (To, U) >= 0 then
                  return True;
               end if;
            end;
         end if;
         C := City_At (To);
         if C >= 0 and then Cities (C).Fac /= Units (U).Fac then
            if Units (U).Fac < 0 then
               if Cities (C).Pop > 1 then
                  Cities (C).Pop := Cities (C).Pop - 1;
               end if;
               Cities (C).Food := 0;
               Cities (C).Prod := Cities (C).Prod / 2;
               Units (U).MP := 0;
               Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " is ravaged");
               return True;
            end if;
            Cities (C).Pop := Cities (C).Pop - 1;
            if Cities (C).Pop < 1 then
               Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " is razed");
               declare
                  Old : constant Integer := Cities (C).Fac;
               begin
                  Remove_City (C);
                  Fix_Capital (Old);
               end;
            else
               declare
                  Old : constant Integer := Cities (C).Fac;
               begin
                  if Slot_Key (Units (U).Fac) = 0 then
                     Factions (Units (U).Fac).Credits :=
                       Factions (Units (U).Fac).Credits + 10 * (Cities (C).Pop + 1);
                  end if;
                  Cities (C).Fac := Units (U).Fac;
                  Cities (C).Q_Len := 0;
                  Cities (C).Prod := 0;
                  Cities (C).Capital := False;
                  Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " is captured");
                  Fix_Capital (Old);
               end;
            end if;
         end if;
         if Best_Def (To, U) < 0 then
            Units (U).Loc := To;
         end if;
         Units (U).MP := 0;
         if Units (U).Fac >= 0 then
            Mark (Units (U).Fac, Units (U).Loc, Vis_R (Units (U)));
         end if;
         return True;
      end if;
      Cost := 3;
      if Tiles (To).Road and then Tiles (From).Road then
         Cost := 1;
      elsif Tiles (To).Fungus and then not
        (Units (U).Fac < 0 or else Has_Tech (Units (U).Fac, Tech_Kind'Pos (Myco))
         or else (Units (U).Fac >= 0 and then Slot_Key (Units (U).Fac) = 2)
         or else (Units (U).Fac >= 0 and then Policy (Units (U).Fac).F_Move > 0.0))
      then
         Cost := 6;
      end if;
      if U_Ship (Units (U).Kind) then
         Cost := 1;
      end if;
      Units (U).MP := Integer'Max (0, Units (U).MP - Cost);
      Units (U).Loc := To;
      if U_Ship (Units (U).Kind) then
         for O in 0 .. Unit_N - 1 loop
            if Units (O).On_Ship = Units (U).Id then
               Units (O).Loc := To;
            end if;
         end loop;
      end if;
      if Units (U).Fac >= 0 then
         Mark (Units (U).Fac, To, Vis_R (Units (U)));
      end if;
      return True;
   end Step;

   procedure BFS (Start, Fid, Max_D : Integer) is
      Q : array (0 .. Max_Tiles - 1) of Integer;
      Qh, Qt : Integer := 0;
      C, Nx, Ny, N : Integer;
   begin
      for I in 0 .. NTiles - 1 loop
         Dist_A (I) := -1;
         Prev_A (I) := -1;
         Occ_A (I) := 0;
      end loop;
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac /= Fid and then Units (U).On_Ship < 0 then
            Occ_A (Units (U).Loc) := Occ_A (Units (U).Loc) or 1;
         end if;
      end loop;
      for CI in 0 .. City_N - 1 loop
         Occ_A (Cities (CI).Loc) := Occ_A (Cities (CI).Loc) or 2;
         if Cities (CI).Fac /= Fid then
            Occ_A (Cities (CI).Loc) := Occ_A (Cities (CI).Loc) or 1;
         end if;
      end loop;
      if Start < 0 or else Start >= NTiles then
         return;
      end if;
      Dist_A (Start) := 0;
      Q (0) := Start;
      Qt := 1;
      while Qh < Qt loop
         C := Q (Qh);
         Qh := Qh + 1;
         if Dist_A (C) < Max_D and then (C = Start or else (Occ_A (C) and 1) = 0) then
            for DY in -1 .. 1 loop
               for DX in -1 .. 1 loop
                  if DX /= 0 or else DY /= 0 then
                     Nx := X_Of (C) + DX;
                     Ny := Y_Of (C) + DY;
                     if In_Map (Nx, Ny) then
                        N := Ny * W + Nx;
                        if Dist_A (N) < 0
                          and then (Tiles (N).Land or else (Occ_A (N) and 2) /= 0)
                        then
                           Dist_A (N) := Dist_A (C) + 1;
                           Prev_A (N) := C;
                           Q (Qt) := N;
                           Qt := Qt + 1;
                        end if;
                     end if;
                  end if;
               end loop;
            end loop;
         end if;
      end loop;
   end BFS;

   procedure Move_Toward (Uidx, To, Max_D : Integer) is
      Path : Nbr_Arr := (others => -1);
      PN : Natural := 0;
      C : Integer;
      Id : Integer;
      U : Integer;
   begin
      if Uidx < 0 or else Uidx >= Unit_N or else To < 0 or else To >= NTiles then
         return;
      end if;
      if Units (Uidx).MP <= 0 or else Units (Uidx).Loc = To then
         return;
      end if;
      if U_Ship (Units (Uidx).Kind) then
         return;
      end if;
      BFS (Units (Uidx).Loc, Units (Uidx).Fac, Max_D);
      if Dist_A (To) < 0 then
         return;
      end if;
      C := To;
      while C /= Units (Uidx).Loc and then C >= 0 and then PN < Path'Length loop
         Path (PN) := C;
         PN := PN + 1;
         C := Prev_A (C);
      end loop;
      Id := Units (Uidx).Id;
      for K in reverse 0 .. PN - 1 loop
         U := Find_Unit (Id);
         exit when U < 0 or else Units (U).MP <= 0;
         exit when Enemy_At (Path (K), Units (U).Fac) and then Path (K) /= To;
         exit when not Step (U, Path (K));
      end loop;
   end Move_Toward;

   function Grace return Integer is
      Area : constant Integer := 48 * 32 - W * H;
      Small : Integer := 0;
   begin
      if Area > 0 then
         Small := JS_Round (Long_Float (Area) / 60.0);
      end if;
      return 50 - Difficulty * 3 + Small;
   end Grace;

   function Econ_Target return Integer is
      Scale : constant Long_Float :=
        1.0 + (Long_Float'Max (1.0, Long_Float (W * H) / 1536.0) - 1.0) * 0.25;
   begin
      return (JS_Round (3000.0 * Scale / 100.0)) * 100;
   end Econ_Target;

   function Score_Of (Fid : Integer) return Integer is
      S : Integer := Factions (Fid).Tech_N * 2;
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid then
            S := S + Cities (C).Pop + 3 + Cities (C).Fac_N;
         end if;
      end loop;
      return S;
   end Score_Of;

   procedure Start_Work (U : Integer; K : Work_Kind) is
      Turns : Integer;
      M : constant Mods := Policy (Units (U).Fac);
   begin
      case K is
         when W_Clear => Turns := 3;
         when W_Road => Turns := 2;
         when W_Farm => Turns := 3;
         when W_Mine => Turns := 5;
         when W_Solar => Turns := 4;
         when W_None => return;
      end case;
      Turns := Integer'Max (1, JS_Round (Long_Float (Turns) * M.Terra));
      Units (U).Work := K;
      Units (U).Work_Left := Turns;
      Units (U).MP := 0;
      Units (U).Fort := False;
   end Start_Work;

   function Job_Of (Fid, I : Integer) return Work_Kind is
      T : Tile;
   begin
      if I < 0 or else I >= NTiles or else not Tiles (I).Land or else City_At (I) >= 0 then
         return W_None;
      end if;
      T := Tiles (I);
      if T.Fungus then
         return W_Clear;
      end if;
      if T.Imp = None then
         if T.Rock >= 1 and then T.Moist = 0 then
            return W_Mine;
         elsif T.Moist >= 1 and then T.Rock < 2 then
            return W_Farm;
         elsif Has_Tech (Fid, Tech_Kind'Pos (Photon)) then
            return W_Solar;
         elsif T.Rock >= 1 then
            return W_Mine;
         end if;
      elsif not T.Road then
         for C in 0 .. City_N - 1 loop
            if Cities (C).Fac = Fid and then Dist (Cities (C).Loc, I) <= 1 then
               return W_Road;
            end if;
         end loop;
      end if;
      return W_None;
   end Job_Of;

   function Best_Mil (Fid : Integer; Defense : Boolean) return Integer is
      Best : Integer := Unit_Kind'Pos (Trooper);
      BV, V : Integer := -1;
   begin
      for K in Unit_Kind loop
         if Can_Build (Fid, Unit_Kind'Pos (K)) and then not U_Civ (K)
           and then not U_Ship (K) and then K /= Scout
         then
            if Defense then
               V := U_Def (K) * 100 - U_Cost (K);
            else
               V := U_Atk (K) * 100 + U_Mv (K);
            end if;
            if V > BV then
               BV := V;
               Best := Unit_Kind'Pos (K);
            end if;
         end if;
      end loop;
      return Best;
   end Best_Mil;

   procedure AI_City (C : Integer) is
      Fid : constant Integer := Cities (C).Fac;
      Key : constant Integer := Slot_Key (Fid);
      Gar, Cols, Mil, Terr_N : Integer := 0;
      Target : Integer := 6;
      Plan : constant Integer := Factions (Fid).Plan;
   begin
      if Cities (C).Q_Len > 0 then
         return;
      end if;
      if Key = 3 then
         Target := 8;
      end if;
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac = Fid then
            if Units (U).Kind = Colonist then
               Cols := Cols + 1;
            end if;
            if Units (U).Kind = Terraformer then
               Terr_N := Terr_N + 1;
            end if;
            if not U_Civ (Units (U).Kind) and then not U_Ship (Units (U).Kind) then
               Mil := Mil + 1;
               if Units (U).Loc = Cities (C).Loc then
                  Gar := Gar + 1;
               end if;
            end if;
         end if;
      end loop;
      if Plan = 0 and then Cities (C).Pop >= 2
        and then Count_Cities (Fid) < Target + 3
        and then Cols < Integer'Max (1, (Count_Cities (Fid) + 1) / 2)
      then
         Cities (C).Queue (0) := Unit_Kind'Pos (Colonist);
         Cities (C).Q_Len := 1;
         return;
      end if;
      if Gar < 1 then
         Cities (C).Queue (0) := Best_Mil (Fid, True);
         Cities (C).Q_Len := 1;
         return;
      end if;
      if Count_Cities (Fid) < Target and then Cities (C).Pop >= 2
        and then Cols < (Count_Cities (Fid) + 1) / 2
      then
         Cities (C).Queue (0) := Unit_Kind'Pos (Colonist);
         Cities (C).Q_Len := 1;
         return;
      end if;
      if Terr_N < Count_Cities (Fid) then
         Cities (C).Queue (0) := Unit_Kind'Pos (Terraformer);
         Cities (C).Q_Len := 1;
         return;
      end if;
      if Turn_N >= 10 and then Cities (C).Mor10 < 0 then
         if Can_Build (Fid, 100 + Fac_Kind'Pos (Rec)) and then not City_Has (C, Rec) then
            Cities (C).Queue (0) := 100 + Fac_Kind'Pos (Rec);
            Cities (C).Q_Len := 1;
            return;
         elsif Can_Build (Fid, 100 + Fac_Kind'Pos (Theatre)) and then not City_Has (C, Theatre) then
            Cities (C).Queue (0) := 100 + Fac_Kind'Pos (Theatre);
            Cities (C).Q_Len := 1;
            return;
         end if;
      end if;
      if Mil < Count_Cities (Fid) * 2 then
         Cities (C).Queue (0) := Best_Mil (Fid, Plan = 2);
         Cities (C).Q_Len := 1;
         return;
      end if;
      for K in Fac_Kind loop
         if not F_Project (K) and then not F_Coast (K)
           and then Can_Build (Fid, 100 + Fac_Kind'Pos (K))
           and then not City_Has (C, K)
           and then (K /= Dome or else Cities (C).Pop >= 6)
           and then (K /= Hydro or else Cities (C).Pop >= 3)
         then
            Cities (C).Queue (0) := 100 + Fac_Kind'Pos (K);
            Cities (C).Q_Len := 1;
            return;
         end if;
      end loop;
      Cities (C).Queue (0) := Best_Mil (Fid, False);
      Cities (C).Q_Len := 1;
   end AI_City;

   procedure AI_Unit (U : Integer) is
      Fid : constant Integer := Units (U).Fac;
      Best, BD : Integer;
      BS : Long_Float;
      S : Long_Float;
      J : Work_Kind;
   begin
      if U < 0 or else Units (U).MP <= 0 or else Units (U).Work /= W_None then
         return;
      end if;
      if Units (U).Fac < 0 or else U_Ship (Units (U).Kind) or else Units (U).On_Ship >= 0 then
         return;
      end if;
      if Units (U).Kind = Colonist then
         BFS (Units (U).Loc, Fid, 10);
         if Units (U).Target < 0 or else Site_Score (Units (U).Target, Fid, False) <= 0.0
           or else Dist_A (Units (U).Target) < 0
         then
            Best := -1;
            BS := 0.0;
            for I in 0 .. NTiles - 1 loop
               if Dist_A (I) >= 0 then
                  S := Site_Score (I, Fid, False) - Long_Float (Dist_A (I)) * 1.2;
                  if S > BS then
                     BS := S;
                     Best := I;
                  end if;
               end if;
            end loop;
            Units (U).Target := Best;
         end if;
         if Units (U).Target < 0 then
            if Site_Score (Units (U).Loc, Fid, False) > 0.0 then
               if Found_City (U) then
                  return;
               end if;
            end if;
            return;
         end if;
         if Units (U).Loc = Units (U).Target then
            if Found_City (U) then
               return;
            end if;
            Units (U).Target := -1;
            return;
         end if;
         Move_Toward (U, Units (U).Target, 12);
         declare
            Id : constant Integer := Units (U).Id;
            V : constant Integer := Find_Unit (Id);
         begin
            if V >= 0 and then Units (V).Loc = Units (V).Target and then Units (V).MP > 0 then
               if not Found_City (V) then
                  Units (V).Target := -1;
               end if;
            end if;
         end;
         return;
      end if;
      if Units (U).Kind = Terraformer then
         Best := -1;
         BD := 999;
         for C in 0 .. City_N - 1 loop
            if Cities (C).Fac = Fid then
               for I in 0 .. NTiles - 1 loop
                  if Dist (Cities (C).Loc, I) <= 2 then
                     J := Job_Of (Fid, I);
                     if J /= W_None and then Dist (Units (U).Loc, I) < BD then
                        BD := Dist (Units (U).Loc, I);
                        Best := I;
                     end if;
                  end if;
               end loop;
            end if;
         end loop;
         if Best < 0 then
            return;
         end if;
         if Units (U).Loc /= Best then
            Move_Toward (U, Best, 14);
         end if;
         declare
            Id : constant Integer := Units (U).Id;
            V : constant Integer := Find_Unit (Id);
         begin
            if V >= 0 and then Units (V).Loc = Best and then Units (V).MP > 0 then
               J := Job_Of (Fid, Best);
               if J /= W_None then
                  Start_Work (V, J);
               end if;
            end if;
         end;
         return;
      end if;
      --  Garrison the unit with the highest defence already standing in an own city.
      declare
         Home : constant Integer := City_At (Units (U).Loc);
         Top : Integer := U;
      begin
         if Home >= 0 and then Cities (Home).Fac = Fid and then not U_Civ (Units (U).Kind) then
            for O in 0 .. Unit_N - 1 loop
               if Units (O).Loc = Units (U).Loc and then Units (O).Fac = Fid
                 and then not U_Civ (Units (O).Kind)
                 and then U_Def (Units (O).Kind) > U_Def (Units (Top).Kind)
               then
                  Top := O;
               end if;
            end loop;
            if Top = U then
               Units (U).Fort := True;
               return;
            end if;
         end if;
      end;
      Best := -1;
      BD := 999;
      for O in 0 .. Unit_N - 1 loop
         if Units (O).Fac /= Fid and then Units (O).On_Ship < 0
           and then Dist (Units (O).Loc, Units (U).Loc) < BD
           and then Dist (Units (O).Loc, Units (U).Loc) <= 8
         then
            BD := Dist (Units (O).Loc, Units (U).Loc);
            Best := Units (O).Loc;
         end if;
      end loop;
      if Best < 0 and then (Turn_N >= Grace or else Factions (Fid).Plan = 2) then
         for C in 0 .. City_N - 1 loop
            if Cities (C).Fac /= Fid and then Dist (Cities (C).Loc, Units (U).Loc) < BD then
               BD := Dist (Cities (C).Loc, Units (U).Loc);
               Best := Cities (C).Loc;
            end if;
         end loop;
         if BD > 16 then
            Best := -1;
         end if;
      end if;
      if Best >= 0 and then U_Atk (Units (U).Kind) > 0 then
         Move_Toward (U, Best, 16);
         return;
      end if;
      if Units (U).Kind = Scout or else RI (4) = 0 then
         if Units (U).Target < 0 or else Units (U).Loc = Units (U).Target
           or else Factions (Fid).Seen (Units (U).Target)
         then
            Units (U).Target := -1;
            for K in 1 .. 30 loop
               declare
                  I : constant Integer := RI (NTiles);
               begin
                  if Tiles (I).Land and then not Factions (Fid).Seen (I) then
                     Units (U).Target := I;
                     exit;
                  end if;
               end;
            end loop;
         end if;
         if Units (U).Target >= 0 then
            Move_Toward (U, Units (U).Target, 40);
         end if;
         return;
      end if;
      Best := -1;
      BD := Integer'Last;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid and then Dist (Cities (C).Loc, Units (U).Loc) < BD then
            BD := Dist (Cities (C).Loc, Units (U).Loc);
            Best := Cities (C).Loc;
         end if;
      end loop;
      if Best >= 0 and then Best /= Units (U).Loc then
         Move_Toward (U, Best, 30);
      else
         Units (U).Fort := True;
      end if;
   end AI_Unit;

   procedure Run_AI (Fid : Integer) is
      Ids : array (0 .. Max_Units - 1) of Integer;
      N : Integer;
      U : Integer;
   begin
      if Fid < 0 or else not Factions (Fid).Alive or else not Factions (Fid).AI then
         return;
      end if;
      Update_Seen (Fid);
      if Turn_N >= 15 and then not Factions (Fid).Policy_Set then
         for Axis in 0 .. 3 loop
            Factions (Fid).Pol (Axis) := AI_Pol (Slot_Key (Fid), Axis);
         end loop;
         Factions (Fid).Policy_Set := True;
         Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (Fid))
              & " sets its policies");
      end if;
      if Turn_N < 25 and then Count_Cities (Fid) < 4 then
         Factions (Fid).Plan := 0;
      elsif Count_Units (Fid, Trooper) + Count_Units (Fid, Lancer) < Count_Cities (Fid) then
         Factions (Fid).Plan := 2;
      else
         Factions (Fid).Plan := 1;
      end if;
      if Slot_Key (Fid) = 1 then
         Factions (Fid).Labs := 0.7;
      elsif Slot_Key (Fid) = 0 then
         Factions (Fid).Labs := 0.4;
      else
         Factions (Fid).Labs := 0.5;
      end if;
      Pick_Research (Fid);
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid then
            AI_City (C);
            if Cities (C).Q_Len > 0 and then Item_Is_Unit (Cities (C).Queue (0))
              and then Buy_Cost (C) > 0
              and then Factions (Fid).Credits > Buy_Cost (C) + 40
            then
               declare
                  Gar : Boolean := False;
               begin
                  for V in 0 .. Unit_N - 1 loop
                     if Units (V).Loc = Cities (C).Loc and then Units (V).Fac = Fid
                       and then not U_Civ (Units (V).Kind)
                     then
                        Gar := True;
                     end if;
                  end loop;
                  if not Gar then
                     Factions (Fid).Credits := Factions (Fid).Credits - Buy_Cost (C);
                     Cities (C).Prod := Item_Cost (Cities (C).Queue (0), Fid);
                  end if;
               end;
            end if;
         end if;
      end loop;
      N := Unit_N;
      for I in 0 .. N - 1 loop
         Ids (I) := Units (I).Id;
      end loop;
      for I in 0 .. N - 1 loop
         U := Find_Unit (Ids (I));
         if U >= 0 and then Units (U).Fac = Fid then
            AI_Unit (U);
         end if;
      end loop;
      Update_Seen (Fid);
   end Run_AI;

   procedure Run_Natives is
      Cap : Integer;
      Nb : Nbr_Arr;
      NN : Natural;
      Best, BD : Integer;
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac < 0 and then Units (U).MP > 0 then
            Best := -1;
            BD := 99;
            for O in 0 .. Unit_N - 1 loop
               if Units (O).Fac >= 0 and then Dist (Units (O).Loc, Units (U).Loc) in 1 .. 6
                 and then Dist (Units (O).Loc, Units (U).Loc) < BD
               then
                  if not (Slot_Key (Units (O).Fac) = 2 and then (Units (O).Loc + Turn_N) mod 4 = 0) then
                     BD := Dist (Units (O).Loc, Units (U).Loc);
                     Best := Units (O).Loc;
                  end if;
               end if;
            end loop;
            if Best < 0 then
               for C in 0 .. City_N - 1 loop
                  if Dist (Cities (C).Loc, Units (U).Loc) in 1 .. 6
                    and then Dist (Cities (C).Loc, Units (U).Loc) < BD
                  then
                     BD := Dist (Cities (C).Loc, Units (U).Loc);
                     Best := Cities (C).Loc;
                  end if;
               end loop;
            end if;
            if Best >= 0 then
               Move_Toward (U, Best, 6);
            else
               Nbrs (Units (U).Loc, 1, NN, Nb);
               declare
                  Choices : Nbr_Arr := (others => -1);
                  CN : Natural := 0;
               begin
                  for K in 0 .. NN - 1 loop
                     if Tiles (Nb (K)).Land and then not Enemy_At (Nb (K), -1) then
                        Choices (CN) := Nb (K);
                        CN := CN + 1;
                     end if;
                  end loop;
                  if CN > 0 then
                     declare
                        Id : constant Integer := Units (U).Id;
                        V : Integer;
                     begin
                        V := Find_Unit (Id);
                        if V >= 0 then
                           if not Step (V, Choices (RI (CN))) then
                              ELen := 0;
                              Last_Status := 0;
                           end if;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end if;
      end loop;
      for K in 1 .. 3 loop
         if Rand < 0.45 then
            declare
               Fung : array (0 .. Max_Tiles - 1) of Integer;
               FN : Natural := 0;
               S : Integer;
            begin
               for I in 0 .. NTiles - 1 loop
                  if Tiles (I).Fungus then
                     Fung (FN) := I;
                     FN := FN + 1;
                  end if;
               end loop;
               if FN > 0 then
                  S := Fung (RI (FN));
                  Nbrs (S, 1, NN, Nb);
                  declare
                     Choices : Nbr_Arr := (others => -1);
                     CN : Natural := 0;
                  begin
                     for J in 0 .. NN - 1 loop
                        if Tiles (Nb (J)).Land and then not Tiles (Nb (J)).Fungus
                          and then Tiles (Nb (J)).Imp = None and then City_At (Nb (J)) < 0
                        then
                           Choices (CN) := Nb (J);
                           CN := CN + 1;
                        end if;
                     end loop;
                     if CN > 0 then
                        Tiles (Choices (RI (CN))).Fungus := True;
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;
      Cap := 1 + Integer (Long_Float'Floor (Long_Float (Turn_N) / 14.0 * Nat_Press));
      declare
         Beasts : Integer := 0;
         FN : Natural := 0;
      begin
         for U in 0 .. Unit_N - 1 loop
            if Units (U).Fac < 0 then
               Beasts := Beasts + 1;
            end if;
         end loop;
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Fungus then
               FN := FN + 1;
            end if;
         end loop;
         if FN > 0 and then Beasts < Cap and then Rand < Long_Float'Min (0.6, Long_Float (FN) / 120.0 * Nat_Press) then
            for Tries in 1 .. 8 loop
               declare
                  I : constant Integer := RI (NTiles);
                  Near : Boolean := False;
               begin
                  if Tiles (I).Fungus and then City_At (I) < 0 then
                     for C in 0 .. City_N - 1 loop
                        if Dist (Cities (C).Loc, I) <= 3 then
                           Near := True;
                        end if;
                     end loop;
                     for U in 0 .. Unit_N - 1 loop
                        if Units (U).Loc = I then
                           Near := True;
                        end if;
                     end loop;
                     if not Near then
                        if Make_Unit (-1, Beast, I) >= 0 then
                           Log ("T" & Img (Turn_N) & " a Spore Beast emerges");
                        end if;
                        exit;
                     end if;
                  end if;
               end;
            end loop;
         end if;
      end;
   end Run_Natives;

   procedure Random_Events is
   begin
      if not Rule (7) or else Turn_N < Grace then
         return;
      end if;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive and then Rand < 0.035 then
            declare
               List : array (0 .. Max_Cities - 1) of Integer;
               N : Natural := 0;
               C, Kind : Integer;
            begin
               for I in 0 .. City_N - 1 loop
                  if Cities (I).Fac = F then
                     List (N) := I;
                     N := N + 1;
                  end if;
               end loop;
               if N > 0 then
                  C := List (RI (N));
                  Kind := RI (6);
                  case Kind is
                     when 0 =>
                        Cities (C).Prod := Cities (C).Prod + 25;
                        Log ("T" & Img (Turn_N) & " mineral windfall at " & Name_Of (Cities (C)));
                     when 1 =>
                        Factions (F).Credits := Factions (F).Credits + 40;
                        Cities (C).Mood_Add := 1;
                        Cities (C).Mood_Until := Turn_N + 6;
                        Log ("T" & Img (Turn_N) & " supply pod at " & Name_Of (Cities (C)));
                     when 2 =>
                        declare
                           L : constant Integer := Integer'Min (Factions (F).Credits, 25);
                        begin
                           Factions (F).Credits := Factions (F).Credits - L;
                           Log ("T" & Img (Turn_N) & " solar flare");
                        end;
                     when 3 =>
                        Cities (C).Food := Food_Box (C) - 1;
                        Cities (C).Mood_Add := 1;
                        Cities (C).Mood_Until := Turn_N + 8;
                        Log ("T" & Img (Turn_N) & " bumper harvest at " & Name_Of (Cities (C)));
                     when 4 =>
                        Cities (C).Mood_Add := (if Slot_Key (F) = 2 then 1 else -1);
                        Cities (C).Mood_Until := Turn_N + 8;
                        Log ("T" & Img (Turn_N) & " fungal bloom near " & Name_Of (Cities (C)));
                     when others =>
                        declare
                           Nb : Nbr_Arr;
                           NN : Natural;
                           Spot : Integer := -1;
                        begin
                           Nbrs (Cities (C).Loc, 4, NN, Nb);
                           for K in 0 .. NN - 1 loop
                              if Tiles (Nb (K)).Land and then Dist (Nb (K), Cities (C).Loc) >= 3
                                and then City_At (Nb (K)) < 0
                              then
                                 Spot := Nb (K);
                              end if;
                           end loop;
                           if Spot >= 0 and then Make_Unit (-1, Beast, Spot) >= 0 then
                              Log ("T" & Img (Turn_N) & " spore surge near " & Name_Of (Cities (C)));
                           end if;
                        end;
                  end case;
               end if;
            end;
         end if;
      end loop;
   end Random_Events;

   procedure Finish_Item (C : Integer) is
      Code : constant Integer := Cities (C).Queue (0);
      Cost : constant Integer := Item_Cost (Code, Cities (C).Fac);
      Idx : Integer;
   begin
      if Item_Is_Unit (Code) and then U_Found (Unit_Kind'Val (Code)) and then Cities (C).Pop < 2 then
         return;
      end if;
      for I in 0 .. Cities (C).Q_Len - 2 loop
         Cities (C).Queue (I) := Cities (C).Queue (I + 1);
      end loop;
      Cities (C).Q_Len := Cities (C).Q_Len - 1;
      Cities (C).Prod := Cities (C).Prod - Cost;
      if Item_Is_Unit (Code) then
         Idx := Make_Unit (Cities (C).Fac, Unit_Kind'Val (Code), Cities (C).Loc);
         if Idx >= 0 then
            Units (Idx).Home := Cities (C).Id;
            Factions (Cities (C).Fac).Built := Factions (Cities (C).Fac).Built + 1;
            if U_Found (Unit_Kind'Val (Code)) and then Cities (C).Pop > 1 then
               Cities (C).Pop := Cities (C).Pop - 1;
            end if;
            Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " builds " & U_Name (Unit_Kind'Val (Code)));
         end if;
      else
         if Cities (C).Fac_N < Cities (C).Facs'Length then
            Cities (C).Facs (Cities (C).Fac_N) := Code - 100;
            Cities (C).Fac_N := Cities (C).Fac_N + 1;
         end if;
         if Code = 100 + Fac_Kind'Pos (Asc_Array) then
            Asc_On := True;
            Asc_Fac := Cities (C).Fac;
            Asc_City := Cities (C).Id;
            Asc_Left := 12;
            Log ("T" & Img (Turn_N) & " ascension begins in " & Name_Of (Cities (C)));
         else
            Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " builds "
                 & F_Name (Fac_Kind'Val (Code - 100)));
         end if;
      end if;
   end Finish_Item;

   procedure Process_Faction (Fid : Integer) is
      N, Mi, En, Sur, Mood, NC : Integer;
      Energy, Maint, Labs, Econ : Integer := 0;
      M : Mods;
      Spires : Integer := 0;
      Mul, Labs_Mul : Long_Float;
   begin
      M := Policy (Fid);
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid then
            Assign_Work (C);
            Morale (C);
            Mood := (if Turn_N >= 10 then Cities (C).Mood else 0);
            City_Base (C, N, Mi, En);
            N := N + Integer (Long_Float'Floor (M.Food));
            Mi := JS_Round (Long_Float (Mi) * M.Min);
            En := JS_Round (Long_Float (En) * M.En);
            if Mood = 1 then
               Mi := JS_Round (Long_Float (Mi) * 0.9);
            elsif Mood = 2 then
               Mi := JS_Round (Long_Float (Mi) * 0.6);
            end if;
            Sur := N - 2 * Cities (C).Pop;
            if Sur > 0 and then Mood = 2 then
               Sur := 0;
            elsif Sur > 0 and then Mood = 1 then
               Sur := (Sur * 3) / 4;
            end if;
            Cities (C).Food := Cities (C).Food + Sur;
            if Cities (C).Food >= Food_Box (C) then
               if Cities (C).Pop < Pop_Cap (C) then
                  Cities (C).Pop := Cities (C).Pop + 1;
                  Cities (C).Food := 0;
                  Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " grows to " & Img (Cities (C).Pop));
               else
                  Cities (C).Food := Food_Box (C);
               end if;
            elsif Cities (C).Food < 0 then
               if Cities (C).Pop > 1 then
                  Cities (C).Pop := Cities (C).Pop - 1;
                  Log ("T" & Img (Turn_N) & " " & Name_Of (Cities (C)) & " starves");
               end if;
               Cities (C).Food := 0;
            end if;
            if not Factions (Fid).AI and then Cities (C).Q_Len = 0 then
               if Cities (C).Pop >= 2 and then Count_Units (Fid, Colonist) = 0 then
                  Cities (C).Queue (0) := Unit_Kind'Pos (Colonist);
               else
                  Cities (C).Queue (0) := Unit_Kind'Pos (Trooper);
               end if;
               Cities (C).Q_Len := 1;
            end if;
            Mul := Mul_For (Fid);
            if Slot_Key (Fid) = 1 and then Cities (C).Q_Len > 0
              and then not Item_Is_Unit (Cities (C).Queue (0))
              and then F_Project (Fac_Kind'Val (Cities (C).Queue (0) - 100))
            then
               Mul := Mul * 1.35;
            end if;
            Cities (C).Prod := Cities (C).Prod + Integer'Max (0, JS_Round (Long_Float (Mi) * Mul));
            Energy := Energy + En;
            for I in 0 .. Cities (C).Fac_N - 1 loop
               if Cities (C).Facs (I) in 0 .. Fac_Kind'Pos (Fac_Kind'Last) then
                  Maint := Maint + F_Maint (Fac_Kind'Val (Cities (C).Facs (I)));
                  if Fac_Kind'Val (Cities (C).Facs (I)) = Spire then
                     Spires := Spires + 1;
                  end if;
               end if;
            end loop;
            if Cities (C).Q_Len > 0 and then Cities (C).Prod >= Item_Cost (Cities (C).Queue (0), Fid) then
               Finish_Item (C);
            end if;
         end if;
      end loop;
      NC := Count_Cities (Fid);
      Energy := Energy + Integer (Long_Float'Floor (Long_Float (NC) * M.En_City));
      Maint := Maint + Integer (Long_Float'Floor (Long_Float (NC) * M.Upkeep));
      if Factions (Fid).Unrest > 0 then
         Factions (Fid).Unrest := Factions (Fid).Unrest - 1;
      end if;
      declare
         Ineff : constant Long_Float :=
           Long_Float'Min (0.5, Long_Float (Integer'Max (0, NC - 5)) * 0.05);
      begin
         Energy := JS_Round (Long_Float (Energy) * (1.0 - Ineff));
      end;
      Maint := Maint + Integer'Max (0, NC - 8);
      Labs_Mul := 1.0;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid and then City_Has (C, Beacon) then
            Labs_Mul := 1.25;
         end if;
      end loop;
      if Slot_Key (Fid) = 1 then
         Labs_Mul := Labs_Mul * 1.45;
      end if;
      if Has_Tech (Fid, Tech_Kind'Pos (Signal)) then
         Labs_Mul := Labs_Mul * 1.1;
      end if;
      if Has_Tech (Fid, Tech_Kind'Pos (Quantum)) then
         Labs_Mul := Labs_Mul * 1.25;
      end if;
      Labs := JS_Round (Long_Float (Energy) * Factions (Fid).Labs);
      Econ := Energy - Labs;
      if NC < 1 then
         NC := 1;
      end if;
      Labs := JS_Round (Long_Float (Labs) * Labs_Mul * (1.0 + 0.5 * Long_Float (Spires) / Long_Float (NC))
                        * Mul_For (Fid) * M.Labs);
      Factions (Fid).Credits := Factions (Fid).Credits + Econ - Maint;
      if Factions (Fid).Credits < 0 then
         Factions (Fid).Credits := 0;
      end if;
      Pick_Research (Fid);
      if Factions (Fid).Research >= 0 then
         Factions (Fid).RP := Factions (Fid).RP + Labs;
         if Factions (Fid).RP >= Tech_Cost (Fid) then
            Factions (Fid).RP := Factions (Fid).RP - Tech_Cost (Fid);
            Factions (Fid).Techs (Tech_Kind'Val (Factions (Fid).Research)) := True;
            Factions (Fid).Tech_N := Factions (Fid).Tech_N + 1;
            Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (Fid))
                 & " discovers " & Tech_Name (Factions (Fid).Research));
            Factions (Fid).Research := -1;
         end if;
      end if;
   end Process_Faction;

   procedure Check_Victory is
      Alive_N : Integer := 0;
      Alive_I : Integer := -1;
      Land_N, Owned : Integer;
      Share : Long_Float;
      Best, BI : Integer;
   begin
      if Winner /= -2 then
         return;
      end if;
      if Asc_On then
         declare
            C : constant Integer := Find_City (Asc_City);
         begin
            if C < 0 or else Cities (C).Fac /= Asc_Fac then
               Asc_On := False;
               Log ("T" & Img (Turn_N) & " the ascension fails");
            else
               Asc_Left := Asc_Left - 1;
               if Asc_Left <= 0 then
                  Winner := Asc_Fac;
                  Win_Type := 2;
                  Log ("T" & Img (Turn_N) & " ascension victory");
                  return;
               end if;
            end if;
         end;
      end if;
      if Rule (2) then
         for F in 0 .. Fac_N - 1 loop
            if Factions (F).Alive and then Factions (F).Credits >= Econ_Target then
               Winner := F;
               Win_Type := 3;
               Log ("T" & Img (Turn_N) & " economic victory");
               return;
            end if;
         end loop;
      end if;
      if Rule (3) then
         Land_N := 0;
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land then
               Land_N := Land_N + 1;
            end if;
         end loop;
         Territory;
         for F in 0 .. Fac_N - 1 loop
            Owned := 0;
            for I in 0 .. NTiles - 1 loop
               if Tiles (I).Land and then Terr (I) = F then
                  Owned := Owned + 1;
               end if;
            end loop;
            Share := Long_Float (Owned) / Long_Float (Integer'Max (1, Land_N));
            if Share >= 0.5 then
               Dom_Turns (F) := Dom_Turns (F) + 1;
            else
               Dom_Turns (F) := 0;
            end if;
            if Dom_Turns (F) >= 10 then
               Winner := F;
               Win_Type := 4;
               Log ("T" & Img (Turn_N) & " dominion victory");
               return;
            end if;
         end loop;
      end if;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive then
            if Count_Cities (F) = 0 and then Count_Units (F, Colonist) = 0
              and then Count_Units (F, Sea_Colonist) = 0
            then
               Factions (F).Alive := False;
               declare
                  U : Integer := 0;
               begin
                  while U < Unit_N loop
                     if Units (U).Fac = F then
                        Remove_Unit (U);
                     else
                        U := U + 1;
                     end if;
                  end loop;
               end;
               Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (F)) & " is eliminated");
            end if;
         end if;
      end loop;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive then
            Alive_N := Alive_N + 1;
            Alive_I := F;
         end if;
      end loop;
      if Rule (0) and then Alive_N = 1 then
         Winner := Alive_I;
         Win_Type := 1;
         Log ("T" & Img (Turn_N) & " conquest victory");
         return;
      elsif Alive_N = 0 then
         Winner := -1;
         Win_Type := 6;
         Log ("T" & Img (Turn_N) & " extinction");
         return;
      end if;
      if Turn_N >= Max_Turns then
         Best := -1;
         BI := 0;
         for F in 0 .. Fac_N - 1 loop
            if Score_Of (F) > Best then
               Best := Score_Of (F);
               BI := F;
            end if;
         end loop;
         Winner := BI;
         Win_Type := 5;
         Log ("T" & Img (Turn_N) & " score victory");
      end if;
   end Check_Victory;

   procedure End_Turn is
      Id : Integer;
      U : Integer;
   begin
      if NTiles = 0 or else Winner /= -2 then
         return;
      end if;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive and then Factions (F).AI then
            Run_AI (F);
         end if;
      end loop;
      Run_Natives;
      Random_Events;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive then
            Process_Faction (F);
         end if;
      end loop;
      for Ix in 0 .. Unit_N - 1 loop
         if Units (Ix).Work /= W_None then
            Units (Ix).Work_Left := Units (Ix).Work_Left - 1;
            if Units (Ix).Work_Left <= 0 then
               case Units (Ix).Work is
                  when W_Clear => Tiles (Units (Ix).Loc).Fungus := False;
                  when W_Road => Tiles (Units (Ix).Loc).Road := True;
                  when W_Farm =>
                     if not Tiles (Units (Ix).Loc).Fungus then
                        Tiles (Units (Ix).Loc).Imp := Farm;
                     end if;
                  when W_Mine =>
                     if not Tiles (Units (Ix).Loc).Fungus then
                        Tiles (Units (Ix).Loc).Imp := Mine;
                     end if;
                  when W_Solar =>
                     if not Tiles (Units (Ix).Loc).Fungus then
                        Tiles (Units (Ix).Loc).Imp := Solar;
                     end if;
                  when W_None => null;
               end case;
               Log ("T" & Img (Turn_N) & " terraforming finishes");
               Units (Ix).Work := W_None;
            end if;
         end if;
         declare
            C : constant Integer := City_At (Units (Ix).Loc);
            Heal : Integer := 1;
         begin
            if C >= 0 and then Cities (C).Fac = Units (Ix).Fac then
               Heal := 3;
            end if;
            if Units (Ix).HP < 10 and then Units (Ix).MP = U_Mv (Units (Ix).Kind) * 3 then
               Units (Ix).HP := Integer'Min (10, Units (Ix).HP + Heal);
            end if;
         end;
         Units (Ix).MP := U_Mv (Units (Ix).Kind) * 3;
         Units (Ix).Skip := Units (Ix).Fort;
      end loop;
      Check_Victory;
      Turn_N := Turn_N + 1;
      for I in 0 .. Unit_N - 1 loop
         if Units (I).Goto_At >= 0 and then Units (I).Fac >= 0 and then not Factions (Units (I).Fac).AI then
            Id := Units (I).Id;
            Move_Toward (I, Units (I).Goto_At, 40);
            U := Find_Unit (Id);
            if U >= 0 and then Units (U).Loc = Units (U).Goto_At then
               Units (U).Goto_At := -1;
            end if;
         end if;
      end loop;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive then
            Update_Seen (F);
         end if;
      end loop;
   end End_Turn;

   function Act (Code, A, B : Integer) return Integer is
      U, C : Integer;
      procedure Ok is
      begin
         Last_Status := 0;
         ELen := 0;
      end Ok;
   begin
      if NTiles = 0 then
         Set_Error ("No game");
         return 1;
      end if;
      Ok;
      case Code is
         when Act_End =>
            End_Turn;
            return 0;
         when Act_Move =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            if not Step (U, B) then
               return 1;
            end if;
            return 0;
         when Act_Goto =>
            U := Find_Unit (A);
            if U < 0 or else B < 0 or else B >= NTiles then
               Set_Error ("Cannot go there");
               return 1;
            end if;
            if not Tiles (B).Land and then City_At (B) < 0 and then not U_Ship (Units (U).Kind) then
               Set_Error ("Cannot go to sea");
               return 1;
            end if;
            Units (U).Goto_At := B;
            Units (U).Work := W_None;
            Units (U).Fort := False;
            Move_Toward (U, B, 40);
            U := Find_Unit (A);
            if U >= 0 and then Units (U).Loc = B then
               Units (U).Goto_At := -1;
            end if;
            return 0;
         when Act_Found =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            if Found_City (U) then
               return 0;
            end if;
            return 1;
         when Act_Skip =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            Units (U).Skip := True;
            return 0;
         when Act_Fort =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            Units (U).Fort := True;
            Units (U).Skip := True;
            Units (U).Goto_At := -1;
            return 0;
         when Act_Disband =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            Remove_Unit (U);
            return 0;
         when Act_Research =>
            if Human < 0 or else not Tech_OK (Human, A) then
               Set_Error ("That research is not available");
               return 1;
            end if;
            Factions (Human).Research := A;
            Log ("T" & Img (Turn_N) & " research set to " & Tech_Name (A));
            return 0;
         when Act_Labs =>
            if Human < 0 then
               Set_Error ("No faction to tune");
               return 1;
            end if;
            declare
               V : Integer := A;
            begin
               if V < 0 then
                  V := 0;
               elsif V > 100 then
                  V := 100;
               end if;
               Factions (Human).Labs := Long_Float (V) / 100.0;
            end;
            return 0;
         when Act_Queue =>
            C := Find_City (A);
            if C < 0 then
               Set_Error ("No such city");
               return 1;
            end if;
            if Cities (C).Q_Len >= 6 then
               Set_Error ("Queue full");
               return 1;
            end if;
            if Build_At (C, 0) < 0 then
               null;
            end if;
            declare
               Found_Code : Boolean := False;
            begin
               for I in 0 .. Build_Count (C) - 1 loop
                  if Build_At (C, I) = B then
                     Found_Code := True;
                  end if;
               end loop;
               if not Found_Code then
                  Set_Error ("Cannot build that");
                  return 1;
               end if;
            end;
            Cities (C).Queue (Cities (C).Q_Len) := B;
            Cities (C).Q_Len := Cities (C).Q_Len + 1;
            return 0;
         when Act_Unqueue =>
            C := Find_City (A);
            if C < 0 or else B < 0 or else B >= Cities (C).Q_Len then
               Set_Error ("Bad queue index");
               return 1;
            end if;
            if B = 0 then
               Cities (C).Prod := Cities (C).Prod / 2;
            end if;
            for I in B .. Cities (C).Q_Len - 2 loop
               Cities (C).Queue (I) := Cities (C).Queue (I + 1);
            end loop;
            Cities (C).Q_Len := Cities (C).Q_Len - 1;
            return 0;
         when Act_Buy =>
            C := Find_City (A);
            if C < 0 or else Cities (C).Q_Len = 0 then
               Set_Error ("Nothing queued");
               return 1;
            end if;
            if Factions (Cities (C).Fac).Credits < Buy_Cost (C) then
               Set_Error ("Need " & Img (Buy_Cost (C)) & " credits");
               return 1;
            end if;
            Factions (Cities (C).Fac).Credits :=
              Factions (Cities (C).Fac).Credits - Buy_Cost (C);
            Cities (C).Prod := Item_Cost (Cities (C).Queue (0), Cities (C).Fac);
            return 0;
         when Act_Terra =>
            U := Find_Unit (A);
            if U < 0 or else Units (U).Kind /= Terraformer then
               Set_Error ("Only terraformers");
               return 1;
            end if;
            case B is
               when 1 => Start_Work (U, W_Farm);
               when 2 => Start_Work (U, W_Mine);
               when 3 =>
                  if not Has_Tech (Units (U).Fac, Tech_Kind'Pos (Photon)) then
                     Set_Error ("Requires Photonic Weave");
                     return 1;
                  end if;
                  Start_Work (U, W_Solar);
               when 4 => Start_Work (U, W_Road);
               when 5 =>
                  if not Tiles (Units (U).Loc).Fungus then
                     Set_Error ("No fungus here");
                     return 1;
                  end if;
                  Start_Work (U, W_Clear);
               when others =>
                  Set_Error ("Unknown improvement");
                  return 1;
            end case;
            return 0;
         when Act_Control =>
            if A < 0 or else A >= Fac_N or else not Factions (A).Alive then
               Set_Error ("No such faction");
               return 1;
            end if;
            for F in 0 .. Fac_N - 1 loop
               Factions (F).AI := F /= A;
            end loop;
            Human := A;
            Viewer := A;
            Log ("T" & Img (Turn_N) & " you take control of "
                 & Colony_Names.Faction_Name (Slot_Key (A)));
            return 0;
         when Act_Handback =>
            for F in 0 .. Fac_N - 1 loop
               Factions (F).AI := True;
            end loop;
            Human := -1;
            Viewer := -1;
            Log ("T" & Img (Turn_N) & " all factions are AI-controlled");
            return 0;
         when Act_Policy =>
            if Human < 0 then
               Set_Error ("Take control of a faction first");
               return 1;
            end if;
            declare
               Old : Integer;
               Cost, Turns : Integer;
            begin
               if A not in 0 .. 3 or else B not in 0 .. 3 then
                  Set_Error ("Unknown policy");
                  return 1;
               end if;
               if Factions (Human).Pol (A) = B then
                  Set_Error ("Already in force");
                  return 1;
               end if;
               Cost := (if Turn_N < 20 then 0 else 20 + 3 * Count_Cities (Human));
               if Factions (Human).Credits < Cost then
                  Set_Error ("Changing policy costs " & Img (Cost) & " credits");
                  return 1;
               end if;
               Old := Factions (Human).Pol (A);
               Turns := 3;
               if Turn_N >= 20 and then A = 2 and then (Old = 3 or else B = 3) then
                  Turns := 6;
               end if;
               Factions (Human).Credits := Factions (Human).Credits - Cost;
               Factions (Human).Pol (A) := B;
               Factions (Human).Policy_Set := True;
               if Turn_N >= 20 then
                  if Factions (Human).Unrest < Turns then
                     Factions (Human).Unrest := Turns;
                  end if;
               end if;
               Log ("T" & Img (Turn_N) & " policy: " & Pol_Name (A, B));
            end;
            return 0;
         when others =>
            Set_Error ("Unknown action");
            return 1;
      end case;
   end Act;

   procedure Smooth (Passes : Natural) is
      X0, Y0 : Integer;
      S : Long_Float;
      Cnt : Natural;
   begin
      for K in 1 .. Passes loop
         for I in 0 .. NTiles - 1 loop
            S := Work_A (I);
            Cnt := 1;
            X0 := I mod W;
            Y0 := I / W;
            for DY in -1 .. 1 loop
               for DX in -1 .. 1 loop
                  if (DX /= 0 or else DY /= 0) and then In_Map (X0 + DX, Y0 + DY) then
                     S := S + Work_A ((Y0 + DY) * W + (X0 + DX));
                     Cnt := Cnt + 1;
                  end if;
               end loop;
            end loop;
            Work_B (I) := S / Long_Float (Cnt);
         end loop;
         for I in 0 .. NTiles - 1 loop
            Work_A (I) := Work_B (I);
         end loop;
      end loop;
   end Smooth;

   procedure Field (Passes : Natural) is
      Mn, Mx : Long_Float;
   begin
      for I in 0 .. NTiles - 1 loop
         Work_A (I) := Rand;
      end loop;
      Smooth (Passes);
      Mn := Work_A (0);
      Mx := Work_A (0);
      for I in 0 .. NTiles - 1 loop
         if Work_A (I) < Mn then
            Mn := Work_A (I);
         end if;
         if Work_A (I) > Mx then
            Mx := Work_A (I);
         end if;
      end loop;
      if Mx <= Mn then
         Mx := Mn + 1.0;
      end if;
      for I in 0 .. NTiles - 1 loop
         Work_A (I) := (Work_A (I) - Mn) / (Mx - Mn);
      end loop;
   end Field;

   procedure Gen_Map is
      Sorted : array (0 .. Max_Tiles - 1) of Long_Float;
      Thr, Top, Edge, Drop, Rel : Long_Float;
      X0, Y0, Hnd, Seeds, C, Land_N : Integer;
      DX, DY : Long_Float;
      Land_List : array (0 .. Max_Tiles - 1) of Integer;
      Nb : Nbr_Arr;
      NN : Natural;
      Q : array (0 .. Max_Tiles - 1) of Integer;
      Qh, Qt : Integer;
   begin
      Field (4);
      for I in 0 .. NTiles - 1 loop
         X0 := I mod W;
         Y0 := I / W;
         DX := Long_Float (Integer'Min (X0, W - 1 - X0)) / (Long_Float (W) / 2.0);
         DY := Long_Float (Integer'Min (Y0, H - 1 - Y0)) / (Long_Float (H) / 2.0);
         Edge := Long_Float'Min (DX, DY);
         if Edge < 0.25 then
            Drop := (0.25 - Edge) * 2.0;
         else
            Drop := 0.0;
         end if;
         Work_E (I) := Work_A (I) - Drop;
         Sorted (I) := Work_E (I);
      end loop;
      for I in 1 .. NTiles - 1 loop
         declare
            V : constant Long_Float := Sorted (I);
            J : Integer := I;
         begin
            while J > 0 and then Sorted (J - 1) > V loop
               Sorted (J) := Sorted (J - 1);
               J := J - 1;
            end loop;
            Sorted (J) := V;
         end;
      end loop;
      Thr := Sorted (NTiles / 2);
      Top := Sorted (NTiles - 1);
      Field (3);
      for I in 0 .. NTiles - 1 loop
         if Work_A (I) < 0.35 then
            Tiles (I).Moist := 0;
         elsif Work_A (I) < 0.68 then
            Tiles (I).Moist := 1;
         else
            Tiles (I).Moist := 2;
         end if;
      end loop;
      Field (2);
      Land_N := 0;
      for I in 0 .. NTiles - 1 loop
         Tiles (I).Land := False;
         Tiles (I).Fungus := False;
         Tiles (I).Road := False;
         Tiles (I).Elev := 0;
         Tiles (I).Imp := None;
         Tiles (I).Sea_Dist := 99;
         Tiles (I).Land := Work_E (I) > Thr;
         if Tiles (I).Land then
            Rel := (Work_E (I) - Thr) / (if Top = Thr then 1.0 else Top - Thr);
            Hnd := JS_Round (Rel * 100.0);
            if Hnd < 0 then
               Hnd := 0;
            elsif Hnd > 100 then
               Hnd := 100;
            end if;
            Tiles (I).Elev := Hnd;
            Land_List (Land_N) := I;
            Land_N := Land_N + 1;
         end if;
         if Work_A (I) < 0.4 then
            Tiles (I).Rock := 0;
         elsif Work_A (I) < 0.75 then
            Tiles (I).Rock := 1;
         else
            Tiles (I).Rock := 2;
         end if;
      end loop;
      if Land_N > 0 then
         Seeds := Integer'Max (3, Land_N / 55);
         for S in 1 .. Seeds loop
            C := Land_List (RI (Land_N));
            for K in 1 .. 10 loop
               Tiles (C).Fungus := True;
               Nbrs (C, 1, NN, Nb);
               declare
                  Choices : Nbr_Arr := (others => -1);
                  CN : Natural := 0;
               begin
                  for J in 0 .. NN - 1 loop
                     if Tiles (Nb (J)).Land then
                        Choices (CN) := Nb (J);
                        CN := CN + 1;
                     end if;
                  end loop;
                  exit when CN = 0;
                  C := Choices (RI (CN));
               end;
            end loop;
         end loop;
      end if;
      Qt := 0;
      for I in 0 .. NTiles - 1 loop
         if Tiles (I).Land then
            Tiles (I).Sea_Dist := 0;
            Q (Qt) := I;
            Qt := Qt + 1;
         else
            Tiles (I).Sea_Dist := 99;
         end if;
      end loop;
      Qh := 0;
      while Qh < Qt loop
         C := Q (Qh);
         Qh := Qh + 1;
         if Tiles (C).Sea_Dist < 9 then
            Nbrs (C, 1, NN, Nb);
            for J in 0 .. NN - 1 loop
               if Tiles (Nb (J)).Sea_Dist > Tiles (C).Sea_Dist + 1 then
                  Tiles (Nb (J)).Sea_Dist := Tiles (C).Sea_Dist + 1;
                  Q (Qt) := Nb (J);
                  Qt := Qt + 1;
               end if;
            end loop;
         end if;
      end loop;
   end Gen_Map;

   function Land_Neighbors (I : Integer) return Integer is
      Nb : Nbr_Arr;
      NN : Natural;
      N : Integer := 0;
   begin
      Nbrs (I, 1, NN, Nb);
      for K in 0 .. NN - 1 loop
         if Tiles (Nb (K)).Land then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Land_Neighbors;

   procedure Place_Starts is
      Cand : array (0 .. Max_Tiles - 1) of Integer;
      CN : Natural := 0;
      Chosen : array (0 .. 3) of Integer := (others => -1);
      Best, BS, SC, MD, C : Integer;
      Order : array (0 .. 5) of Unit_Kind;
      OC : Natural;
   begin
      for I in 0 .. NTiles - 1 loop
         if Tiles (I).Land and then not Tiles (I).Fungus
           and then X_Of (I) > 1 and then Y_Of (I) > 1
           and then X_Of (I) < W - 2 and then Y_Of (I) < H - 2
           and then Land_Neighbors (I) >= 6
         then
            Cand (CN) := I;
            CN := CN + 1;
         end if;
      end loop;
      if CN = 0 then
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land then
               Cand (CN) := I;
               CN := CN + 1;
            end if;
         end loop;
      end if;
      for F in 0 .. Fac_N - 1 loop
         Best := Cand (0);
         BS := -1;
         for K in 1 .. 300 loop
            C := Cand (RI (CN));
            MD := 99;
            for P in 0 .. F - 1 loop
               MD := Integer'Min (MD, Dist (Chosen (P), C));
            end loop;
            SC := Integer'Min (MD, 20) * 10;
            declare
               Nb : Nbr_Arr;
               NN : Natural;
               LN : Integer := 0;
            begin
               Nbrs (C, 2, NN, Nb);
               for J in 0 .. NN - 1 loop
                  if Tiles (Nb (J)).Land then
                     LN := LN + 1;
                  end if;
               end loop;
               SC := SC + LN;
            end;
            if SC > BS then
               BS := SC;
               Best := C;
            end if;
         end loop;
         Chosen (F) := Best;
         Factions (F).Start := Best;
         OC := 0;
         Order (OC) := Colonist; OC := OC + 1;
         Order (OC) := Colonist; OC := OC + 1;
         Order (OC) := Terraformer; OC := OC + 1;
         Order (OC) := Scout; OC := OC + 1;
         Order (OC) := Trooper; OC := OC + 1;
         if Slot_Key (F) = 1 then
            Order (OC) := Trooper;
            OC := OC + 1;
         end if;
         for I in 0 .. OC - 1 loop
            if Make_Unit (F, Order (I), Best) < 0 then
               exit;
            end if;
         end loop;
      end loop;
   end Place_Starts;

   function New_Game
     (Seed_I, Width_I, Height_I, Player_I, Num_AI_I, All_AI_I, Diff_I, Rules_I : Integer)
     return Integer
   is
      Keys : array (0 .. 3) of Integer;
      KN : Natural := 0;
      AI_N : Integer := Num_AI_I;
   begin
      if Width_I < 16 or else Height_I < 12 or else Width_I > Max_W or else Height_I > Max_H then
         Set_Error ("Map size must be between 16x12 and 48x32");
         return 1;
      end if;
      if Player_I not in 0 .. 3 then
         Set_Error ("Unknown faction");
         return 1;
      end if;
      if AI_N < 1 then
         AI_N := 1;
      elsif AI_N > 3 then
         AI_N := 3;
      end if;
      W := Width_I;
      H := Height_I;
      NTiles := W * H;
      Unit_N := 0;
      City_N := 0;
      Next_Id := 1;
      Turn_N := 1;
      Winner := -2;
      Win_Type := 0;
      Difficulty := Diff_I;
      if Difficulty < 0 then
         Difficulty := 0;
      elsif Difficulty > 5 then
         Difficulty := 5;
      end if;
      Rules := To_U32 (Rules_I);
      Seed := To_U32 (Seed_I);
      RS := Seed;
      Ev_Head := 0;
      Ev_Count := 0;
      ELen := 0;
      Last_Status := 0;
      Asc_On := False;
      Asc_Fac := -1;
      Asc_City := -1;
      Asc_Left := 0;
      Dom_Turns := (others => 0);
      for F in 0 .. 3 loop
         Factions (F) := (Used => False, Alive => False, AI => True, Policy_Set => False,
                          Keyi => 0, Credits => 10, RP => 0, Research => -1, Tech_N => 0,
                          Plan => 0, Unrest => 0, Start => 0, Labs => 0.5, WW => 0.0,
                          Techs => (others => False), Pol => (others => 0),
                          Seen => (others => False), Vis => (others => False),
                          Mem => (others => 0), Built => 0, Lost => 0, Kills => 0,
                          Founded => 0, Combats => 0);
      end loop;
      Keys (0) := Player_I;
      KN := 1;
      for K in 0 .. 3 loop
         if K /= Player_I and then KN < 1 + AI_N then
            Keys (KN) := K;
            KN := KN + 1;
         end if;
      end loop;
      Fac_N := Integer (KN);
      for F in 0 .. Fac_N - 1 loop
         Factions (F).Used := True;
         Factions (F).Alive := True;
         Factions (F).Keyi := Keys (F);
         Factions (F).AI := All_AI_I /= 0 or else F > 0;
         if Keys (F) = 3 then
            Factions (F).Credits := 30;
         end if;
      end loop;
      if All_AI_I /= 0 then
         Human := -1;
         Viewer := -1;
      else
         Human := 0;
         Viewer := 0;
      end if;
      Max_Turns := 300;
      Gen_Map;
      Place_Starts;
      if Rule (5) then
         for F in 0 .. Fac_N - 1 loop
            if Make_Unit (F, Colonist, Factions (F).Start) >= 0
              and then Make_Unit (F, Terraformer, Factions (F).Start) >= 0
            then
               if Make_Unit (F, Trooper, Factions (F).Start) < 0 then
                  null;
               end if;
            end if;
            Factions (F).Credits := Factions (F).Credits + 60;
            for K in 1 .. 2 loop
               Pick_Research (F);
               if Factions (F).Research >= 0 then
                  Factions (F).Techs (Tech_Kind'Val (Factions (F).Research)) := True;
                  Factions (F).Tech_N := Factions (F).Tech_N + 1;
                  Factions (F).Research := -1;
               end if;
            end loop;
         end loop;
      end if;
      for F in 0 .. Fac_N - 1 loop
         Update_Seen (F);
      end loop;
      Log ("T1 game start, seed " & Img (Integer (Seed)) & ". Factions begin at war.");
      return 0;
   end New_Game;

   function Land_Mask return U32 is
      Hsh : U32 := 2166136261;
      B : U32;
   begin
      for I in 0 .. NTiles - 1 loop
         B := 0;
         if Tiles (I).Land then
            B := B or 1;
         end if;
         if Tiles (I).Fungus then
            B := B or 2;
         end if;
         B := B or Interfaces.Shift_Left (U32 (Tiles (I).Moist), 2);
         B := B or Interfaces.Shift_Left (U32 (Tiles (I).Rock), 4);
         Hsh := (Hsh xor B) * 16777619;
      end loop;
      return Hsh;
   end Land_Mask;

   function Fingerprint return U32 is
      Hsh : U32 := 2166136261;
      procedure Mix (V : U32) is
      begin
         Hsh := (Hsh xor V) * 16777619;
      end Mix;
   begin
      Mix (U32 (Turn_N));
      Mix (RS);
      Mix (U32 (City_N));
      Mix (U32 (Unit_N));
      for C in 0 .. City_N - 1 loop
         Mix (U32 (Cities (C).Id));
         Mix (U32 (Cities (C).Fac + 3));
         Mix (U32 (Cities (C).Loc));
         Mix (U32 (Cities (C).Pop));
         Mix (To_U32 (Cities (C).Food));
         Mix (To_U32 (Cities (C).Prod));
      end loop;
      for U in 0 .. Unit_N - 1 loop
         Mix (U32 (Units (U).Id));
         Mix (To_U32 (Units (U).Fac + 3));
         Mix (U32 (Unit_Kind'Pos (Units (U).Kind)));
         Mix (U32 (Units (U).Loc));
         Mix (To_U32 (Units (U).HP));
         Mix (To_U32 (Units (U).MP));
      end loop;
      for F in 0 .. Fac_N - 1 loop
         Mix (To_U32 (Factions (F).Credits));
         Mix (To_U32 (Factions (F).RP));
         Mix (U32 (Factions (F).Tech_N));
      end loop;
      return Hsh;
   end Fingerprint;

   function Count_Land return Integer is
      N : Integer := 0;
   begin
      for I in 0 .. NTiles - 1 loop
         if Tiles (I).Land then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Land;

   function Count_Fung return Integer is
      N : Integer := 0;
   begin
      for I in 0 .. NTiles - 1 loop
         if Tiles (I).Fungus then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Fung;

   function Pop_Total return Integer is
      N : Integer := 0;
   begin
      for C in 0 .. City_N - 1 loop
         N := N + Cities (C).Pop;
      end loop;
      return N;
   end Pop_Total;

   procedure Fill_Report (Tag : String; Code : Integer) is
   begin
      RLen := 0;
      Add_R (Tag);
      Add_R (" ok=");
      Add_R (Img (Code));
      Add_R (" turn=");
      Add_R (Img (Turn_N));
      Add_R (" seed=");
      Add_R (Img (To_Int (Seed)));
      Add_R (" land=");
      Add_R (Img (Count_Land));
      Add_R (" fung=");
      Add_R (Img (Count_Fung));
      Add_R (" mask=");
      Add_R (Hex8 (Land_Mask));
      Add_R (" rs=");
      Add_R (Img (To_Int (RS)));
      Add_R (" cities=");
      Add_R (Img (City_N));
      Add_R (" pop=");
      Add_R (Img (Pop_Total));
      Add_R (" units=");
      Add_R (Img (Unit_N));
      Add_R (" fp=");
      Add_R (Hex8 (Fingerprint));
      Add_R (" credits=");
      for F in 0 .. Fac_N - 1 loop
         if F > 0 then
            Add_R (",");
         end if;
         Add_R (Img (Factions (F).Credits));
      end loop;
      Add_R (" techs=");
      for F in 0 .. Fac_N - 1 loop
         if F > 0 then
            Add_R (",");
         end if;
         Add_R (Img (Factions (F).Tech_N));
      end loop;
      if ELen > 0 then
         Add_R (" err=");
         for I in 1 .. ELen loop
            if EBuf (I) = ' ' then
               Add_R ("_");
            else
               Add_R (EBuf (I .. I));
            end if;
         end loop;
      end if;
   end Fill_Report;

   procedure Put_I32 (Word : Integer; V : Integer) is
      Off : constant Integer := Word * 4;
      U : constant U32 := To_U32 (V);
   begin
      Frame (Off) := U8 (U and 16#FF#);
      Frame (Off + 1) := U8 (Interfaces.Shift_Right (U, 8) and 16#FF#);
      Frame (Off + 2) := U8 (Interfaces.Shift_Right (U, 16) and 16#FF#);
      Frame (Off + 3) := U8 (Interfaces.Shift_Right (U, 24) and 16#FF#);
   end Put_I32;

   procedure Build_Frame is
      Off : Integer := 128;
      Ready : Integer := 0;
      N, Mi, En : Integer;
      Flags : Integer;
      Mask : U32;
      procedure Put (V : Integer) is
      begin
         Put_I32 (Off / 4, V);
         Off := Off + 4;
      end Put;
   begin
      if Human in 0 .. Fac_N - 1 then
         for U in 0 .. Unit_N - 1 loop
            if Units (U).Fac = Human and then Units (U).MP > 0 and then not Units (U).Skip
              and then Units (U).Work = W_None and then Units (U).On_Ship < 0
            then
               Ready := Ready + 1;
            end if;
         end loop;
      end if;
      for I in 0 .. 31 loop
         Put_I32 (I, 0);
      end loop;
      Put_I32 (0, To_Int (16#58344C43#));
      Put_I32 (1, 1);
      Put_I32 (2, Turn_N);
      Put_I32 (3, W);
      Put_I32 (4, H);
      Put_I32 (5, Fac_N);
      Put_I32 (6, City_N);
      Put_I32 (7, Unit_N);
      Put_I32 (8, Human);
      Put_I32 (9, Winner);
      Put_I32 (10, Win_Type);
      Put_I32 (11, To_Int (Seed));
      Put_I32 (12, To_Int (Fingerprint));
      Put_I32 (13, Viewer);
      Put_I32 (14, To_Int (Rules));
      Put_I32 (15, Difficulty);
      Put_I32 (16, Last_Status);
      Put_I32 (17, Integer (Ev_Count));
      Put_I32 (18, To_Int (RS));
      Put_I32 (19, Count_Land);
      Put_I32 (20, Count_Fung);
      Put_I32 (21, Max_Turns);
      Put_I32 (22, Ready);
      Put_I32 (24, 16);
      Put_I32 (25, 24);
      Put_I32 (26, 8);
      Put_I32 (27, 32);
      Put_I32 (28, 128);
      Off := 128;
      for F in 0 .. Fac_N - 1 loop
         Mask := 0;
         for T in Tech_Kind loop
            if Factions (F).Techs (T) then
               Mask := Mask or Interfaces.Shift_Left (U32'(1), Tech_Kind'Pos (T));
            end if;
         end loop;
         Put (Factions (F).Keyi);
         Put (if Factions (F).Alive then 1 else 0);
         Put (if Factions (F).AI then 1 else 0);
         Put (Factions (F).Credits);
         Put (Factions (F).RP);
         Put (Factions (F).Research);
         Put (To_Int (Mask));
         Put (JS_Round (Factions (F).Labs * 100.0));
         Put (Count_Cities (F));
         declare
            P : Integer := 0;
            Uc : Integer := 0;
         begin
            for C in 0 .. City_N - 1 loop
               if Cities (C).Fac = F then
                  P := P + Cities (C).Pop;
               end if;
            end loop;
            for U in 0 .. Unit_N - 1 loop
               if Units (U).Fac = F then
                  Uc := Uc + 1;
               end if;
            end loop;
            Put (P);
            Put (Uc);
         end;
         Put (Score_Of (F));
         Put (Factions (F).Plan);
         Put (Factions (F).Unrest);
         Put (Factions (F).Pol (0) + Factions (F).Pol (1) * 256
              + Factions (F).Pol (2) * 65536 + Factions (F).Pol (3) * 16777216);
         declare
            Col : U32;
         begin
            case Factions (F).Keyi is
               when 0 => Col := 16#E0553A#;
               when 1 => Col := 16#4AA3FF#;
               when 2 => Col := 16#5FD35F#;
               when 3 => Col := 16#E6C34A#;
               when others => Col := 16#888888#;
            end case;
            Put (To_Int (Col));
         end;
      end loop;
      Territory;
      for C in 0 .. City_N - 1 loop
         City_Base (C, N, Mi, En);
         Flags := Cities (C).Mood * 256;
         if Cities (C).Capital then
            Flags := Flags + 1;
         end if;
         if Cities (C).Sea then
            Flags := Flags + 2;
         end if;
         Put (Cities (C).Id);
         Put (Cities (C).Fac);
         Put (Cities (C).Loc);
         Put (Cities (C).Pop);
         Put (Pop_Cap (C));
         Put (Cities (C).Food);
         Put (Food_Box (C));
         Put (Cities (C).Prod);
         Put (if Cities (C).Q_Len > 0 then Item_Cost (Cities (C).Queue (0), Cities (C).Fac) else 0);
         Put (N);
         Put (Mi);
         Put (En);
         Put (Flags);
         Put (Cities (C).Mor10);
         Put (Cities (C).Q_Len);
         for Q in 0 .. 5 loop
            Put (if Q < Cities (C).Q_Len then Cities (C).Queue (Q) else -1);
         end loop;
         Put (Cities (C).Work_N);
         Put (0);
         Put (0);
      end loop;
      for U in 0 .. Unit_N - 1 loop
         Flags := Work_Kind'Pos (Units (U).Work) * 256;
         if Units (U).Fort then
            Flags := Flags + 1;
         end if;
         if Units (U).Skip then
            Flags := Flags + 2;
         end if;
         Put (Units (U).Id);
         Put (Units (U).Fac);
         Put (Unit_Kind'Pos (Units (U).Kind));
         Put (Units (U).Loc);
         Put (Units (U).HP);
         Put (Units (U).MP);
         Put (Flags);
         Put (Units (U).Work_Left);
      end loop;
      Put_I32 (29, Off);
      for I in 0 .. NTiles - 1 loop
         declare
            Wrd : U32 := 0;
         begin
            if Tiles (I).Land then
               Wrd := Wrd or 1;
            end if;
            Wrd := Wrd or Interfaces.Shift_Left (U32 (Tiles (I).Moist), 1);
            Wrd := Wrd or Interfaces.Shift_Left (U32 (Tiles (I).Rock), 3);
            if Tiles (I).Fungus then
               Wrd := Wrd or 32;
            end if;
            if Tiles (I).Road then
               Wrd := Wrd or 64;
            end if;
            Wrd := Wrd or Interfaces.Shift_Left (U32 (Imp_Kind'Pos (Tiles (I).Imp)), 7);
            Wrd := Wrd or Interfaces.Shift_Left (U32 (Tiles (I).Elev), 9);
            if Terr (I) >= 0 then
               Wrd := Wrd or Interfaces.Shift_Left (U32 (Terr (I) + 1), 16);
            end if;
            Put (To_Int (Wrd));
         end;
      end loop;
      while Off mod 4 /= 0 loop
         Frame (Off) := 0;
         Off := Off + 1;
      end loop;
      Put_I32 (30, Off);
      for I in 0 .. NTiles - 1 loop
         if Viewer < 0 then
            Frame (Off) := 3;
         elsif Viewer < Fac_N then
            declare
               B : U8 := 0;
            begin
               if Factions (Viewer).Seen (I) then
                  B := B or 1;
               end if;
               if Factions (Viewer).Vis (I) then
                  B := B or 2;
               end if;
               Frame (Off) := B;
            end;
         else
            Frame (Off) := 0;
         end if;
         Off := Off + 1;
      end loop;
      while Off mod 4 /= 0 loop
         Frame (Off) := 0;
         Off := Off + 1;
      end loop;
      Put_I32 (31, Off);
      for I in 0 .. NTiles - 1 loop
         if Viewer in 0 .. Fac_N - 1 then
            Frame (Off) := Factions (Viewer).Mem (I);
         else
            Frame (Off) := 0;
         end if;
         Off := Off + 1;
      end loop;
      Frame_Len := Off;
      Put_I32 (23, Frame_Len);
   end Build_Frame;

   procedure Copy_Text (S : String) is
      N : constant Natural := Integer'Min (S'Length, TBuf'Last);
   begin
      TLen := N;
      if N > 0 then
         TBuf (1 .. N) := S (S'First .. S'First + N - 1);
      end if;
   end Copy_Text;

   function Addr32 (A : System.Address) return Integer is
      U : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64 (System.Storage_Elements.To_Integer (A));
   begin
      return To_Int (U32 (U and 16#FFFF_FFFF#));
   end Addr32;

   function Report return String is
   begin
      if RLen = 0 then
         return "";
      end if;
      return RBuf (1 .. RLen);
   end Report;

   function Run_Watch_Check return Integer is
      Code : Integer := 0;
      Moved : Boolean := False;
      Starts : array (0 .. Max_Units - 1) of Integer;
      Ids : array (0 .. Max_Units - 1) of Integer;
      N0 : Integer;
   begin
      if New_Game (7919, 36, 24, 0, 3, 1, 2, Default_Rules) /= 0 then
         Fill_Report ("WATCH", 1);
         return 1;
      end if;
      if Count_Land /= 431 or else Count_Fung /= 55
        or else Land_Mask /= 16#2788E95A#
        or else RS /= 3927067312
        or else Unit_N /= 21
        or else Factions (0).Start /= 451
        or else Factions (1).Start /= 365
        or else Factions (2).Start /= 356
        or else Factions (3).Start /= 713
        or else Factions (0).Credits /= 10
        or else Factions (3).Credits /= 30
      then
         Code := 2;
      end if;
      if Code = 0 and then (not Tiles (451).Land or else Tiles (451).Moist /= 1
                            or else Tiles (451).Rock /= 1 or else Tiles (451).Elev /= 56)
      then
         Code := 3;
      end if;
      N0 := Unit_N;
      for I in 0 .. N0 - 1 loop
         Starts (I) := Units (I).Loc;
         Ids (I) := Units (I).Id;
      end loop;
      if Code = 0 then
         for T in 1 .. 20 loop
            End_Turn;
         end loop;
         if City_N < 2 or else Turn_N /= 21 then
            Code := 4;
         end if;
         for I in 0 .. N0 - 1 loop
            declare
               U : constant Integer := Find_Unit (Ids (I));
            begin
               if U >= 0 and then Units (U).Loc /= Starts (I) then
                  Moved := True;
               end if;
            end;
         end loop;
         if Code = 0 and then not Moved then
            Code := 5;
         end if;
      end if;
      Build_Frame;
      if Code = 0 and then (Frame_Len < 128 or else Frame (0) /= 16#43#
                            or else Frame (1) /= 16#4C# or else Frame (2) /= 16#34#
                            or else Frame (3) /= 16#58#)
      then
         Code := 6;
      end if;
      Fill_Report ("WATCH", Code);
      declare
         HL, HM, HR, HF : U32 := 2166136261;
      begin
         for I in 0 .. NTiles - 1 loop
            HL := (HL xor (if Tiles (I).Land then 1 else 0)) * 16777619;
            HM := (HM xor U32 (Tiles (I).Moist)) * 16777619;
            HR := (HR xor U32 (Tiles (I).Rock)) * 16777619;
            HF := (HF xor (if Tiles (I).Fungus then 1 else 0)) * 16777619;
         end loop;
         Add_R (" hL="); Add_R (Hex8 (HL));
         Add_R (" hM="); Add_R (Hex8 (HM));
         Add_R (" hR="); Add_R (Hex8 (HR));
         Add_R (" hF="); Add_R (Hex8 (HF));
         Add_R (" st=");
         for F in 0 .. Fac_N - 1 loop
            if F > 0 then
               Add_R (",");
            end if;
            Add_R (Img (Factions (F).Start));
         end loop;
      end;
      if Tiles (451).Land then
         Add_R (" e451=");
         Add_R (Img (Tiles (451).Elev));
      end if;
      return Code;
   end Run_Watch_Check;

   function Run_Manual_Check return Integer is
      Code : Integer := 0;
      U, Id : Integer;
      St : Integer;
   begin
      if New_Game (42, 24, 16, 0, 1, 0, 2, Default_Rules) /= 0 then
         Fill_Report ("MANUAL", 1);
         return 1;
      end if;
      U := -1;
      for I in 0 .. Unit_N - 1 loop
         if Units (I).Fac = 0 and then Units (I).Kind = Colonist then
            U := I;
            exit;
         end if;
      end loop;
      if U < 0 or else not Found_City (U) or else City_N /= 1
        or else Name_Of (Cities (0)) /= "Anvil Ridge"
      then
         Code := 2;
      end if;
      if Code = 0 then
         U := -1;
         for I in 0 .. Unit_N - 1 loop
            if Units (I).Fac = 0 and then Units (I).Kind = Terraformer then
               U := I;
               exit;
            end if;
         end loop;
         if U < 0 then
            Code := 3;
         else
            Id := Units (U).Id;
            St := Act (Act_Move, Id, 0);
            if St = 0 or else ELen = 0 then
               Code := 4;
            else
               End_Turn;
               if Turn_N /= 2 then
                  Code := 5;
               else
                  U := Find_Unit (Id);
                  if U < 0 then
                     Code := 6;
                  else
                     declare
                        Nb : Nbr_Arr;
                        NN : Natural;
                        Dest : Integer := -1;
                     begin
                        Nbrs (Units (U).Loc, 1, NN, Nb);
                        for K in 0 .. NN - 1 loop
                           if Tiles (Nb (K)).Land and then City_At (Nb (K)) < 0 then
                              Dest := Nb (K);
                              exit;
                           end if;
                        end loop;
                        if Dest < 0 or else Act (Act_Move, Id, Dest) /= 0 then
                           Code := 7;
                        end if;
                     end;
                  end if;
               end if;
            end if;
         end if;
      end if;
      Build_Frame;
      Fill_Report ("MANUAL", Code);
      return Code;
   end Run_Manual_Check;

   function C_Ready return Integer is (1);

   function C_New
     (Seed, Width, Height, Player, Num_AI, All_AI, Difficulty, Rules : Integer)
     return Integer
   is
      Code : Integer;
   begin
      Code := New_Game (Seed, Width, Height, Player, Num_AI, All_AI, Difficulty, Rules);
      Build_Frame;
      return Code;
   end C_New;

   function C_Act (Code, A, B, C : Integer) return Integer is
      R : Integer;
      pragma Unreferenced (C);
   begin
      R := Act (Code, A, B);
      Build_Frame;
      return R;
   end C_Act;

   function C_Frame return Integer is
   begin
      Build_Frame;
      return Frame_Len;
   end C_Frame;

   function C_Frame_Ptr return Integer is (Addr32 (Frame'Address));

   function C_Text (Kind, A, B : Integer) return Integer is
   begin
      case Kind is
         when 0 => Copy_Text ("ada-wasm");
         when 1 => Copy_Text (Colony_Names.Faction_Name (A));
         when 2 => Copy_Text (Colony_Names.Leader (A));
         when 3 =>
            if A in 0 .. City_N - 1 then
               Copy_Text (Name_Of (Cities (A)));
            else
               Copy_Text ("");
            end if;
         when 4 =>
            if A in 0 .. Unit_Kind'Pos (Unit_Kind'Last) then
               Copy_Text (U_Name (Unit_Kind'Val (A)));
            else
               Copy_Text ("");
            end if;
         when 5 => Copy_Text (Tech_Name (A));
         when 6 =>
            if A in 0 .. Fac_Kind'Pos (Fac_Kind'Last) then
               Copy_Text (F_Name (Fac_Kind'Val (A)));
            else
               Copy_Text ("");
            end if;
         when 7 =>
            if A in 0 .. Integer (Ev_Count) - 1 then
               declare
                  Ix : constant Natural := (Ev_Head + Max_Ev - 1 - Natural (A)) mod Max_Ev;
               begin
                  Copy_Text (Ev_Buf (Ix) (1 .. Ev_Len (Ix)));
               end;
            else
               Copy_Text ("");
            end if;
         when 8 =>
            if ELen = 0 then
               Copy_Text ("");
            else
               Copy_Text (EBuf (1 .. ELen));
            end if;
         when 9 =>
            case A is
               when 0 => Copy_Text ("militant");
               when 1 => Copy_Text ("scholarly");
               when 2 => Copy_Text ("eco");
               when 3 => Copy_Text ("expansionist");
               when others => Copy_Text ("");
            end case;
         when 10 => Copy_Text (Pol_Name (A, B));
         when 11 =>
            if A in 0 .. Unit_Kind'Pos (Unit_Kind'Last) then
               Copy_Text (U_Glyph (Unit_Kind'Val (A)));
            else
               Copy_Text ("?");
            end if;
         when 12 =>
            case A is
               when 1 => Copy_Text ("conquest");
               when 2 => Copy_Text ("ascension");
               when 3 => Copy_Text ("economic");
               when 4 => Copy_Text ("dominion");
               when 5 => Copy_Text ("score");
               when 6 => Copy_Text ("extinction");
               when others => Copy_Text ("");
            end case;
         when 13 => Copy_Text (Tech_Blurb (A));
         when 18 =>
            case Difficulty is
               when 0 => Copy_Text ("Cadet");
               when 1 => Copy_Text ("Homesteader");
               when 2 => Copy_Text ("Steward");
               when 3 => Copy_Text ("Commander");
               when 4 => Copy_Text ("Archon");
               when 5 => Copy_Text ("Paragon");
               when others => Copy_Text ("Steward");
            end case;
         when 20 => Copy_Text (Report);
         when others => Copy_Text ("");
      end case;
      return TLen;
   end C_Text;

   function C_Text_Ptr return Integer is (Addr32 (TBuf'Address));

   function C_Option_Count (Kind, Owner : Integer) return Integer is
      N : Integer := 0;
   begin
      if Kind = 1 then
         return Build_Count (Owner);
      elsif Kind = 2 and then Owner in 0 .. Fac_N - 1 then
         for T in 0 .. 21 loop
            if Tech_OK (Owner, T) then
               N := N + 1;
            end if;
         end loop;
         return N;
      end if;
      return 0;
   end C_Option_Count;

   function C_Option (Kind, Owner, Index : Integer) return Integer is
      N : Integer := 0;
   begin
      if Kind = 1 then
         return Build_At (Owner, Index);
      elsif Kind = 2 and then Owner in 0 .. Fac_N - 1 and then Index >= 0 then
         for T in 0 .. 21 loop
            if Tech_OK (Owner, T) then
               if N = Index then
                  return T;
               end if;
               N := N + 1;
            end if;
         end loop;
      end if;
      return -1;
   end C_Option;

   function C_Tech_State (Fac, Tech : Integer) return Integer is
   begin
      if Fac not in 0 .. Fac_N - 1 or else Tech not in 0 .. 21 then
         return 0;
      end if;
      if Factions (Fac).Research = Tech then
         return 3;
      elsif Has_Tech (Fac, Tech) then
         return 2;
      elsif Tech_OK (Fac, Tech) then
         return 1;
      end if;
      return 0;
   end C_Tech_State;

   function C_Stat (Kind, Field : Integer) return Integer is
   begin
      if Kind not in 0 .. Unit_Kind'Pos (Unit_Kind'Last) then
         return 0;
      end if;
      case Field is
         when 1 => return U_Cost (Unit_Kind'Val (Kind));
         when 2 => return U_Atk (Unit_Kind'Val (Kind));
         when 3 => return U_Def (Unit_Kind'Val (Kind));
         when 4 => return U_Mv (Unit_Kind'Val (Kind));
         when others => return 0;
      end case;
   end C_Stat;

   function C_Set_Viewer (Who : Integer) return Integer is
   begin
      if Who < -1 or else Who >= Fac_N then
         Set_Error ("No such viewer");
         return 1;
      end if;
      Viewer := Who;
      Build_Frame;
      return 0;
   end C_Set_Viewer;

end Colony;
