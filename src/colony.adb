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
     (Colonist, Sea_Colonist, Burrower, Terraformer, Scout, Trooper, Warden, Lancer,
      Striker, Skimmer, Skiff, Transport, Frigate, Cruiser, Beast, Rebel);

   type Fac_Kind is
     (Hydro, Fab, Spire, Shield, Dome, Docks, Fishery, Tidal_C, Rec, Theatre,
      Beacon, Asc_Array, Scrub);

   type Imp_Kind is (None, Farm, Mine, Solar);
   type Work_Kind is (W_None, W_Clear, W_Road, W_Farm, W_Mine, W_Solar, W_Tunnel);
   type Rel_Kind is (Rel_War, Rel_Cease, Rel_Peace, Rel_Ally);
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
      Tun                : Integer := -1;
      Flooded, Collapsed : Boolean := False;
   end record;

   type Unit_Rec is record
      Id, Fac, Loc, HP, MP, Home, Goto_At, Target, Work_Left, On_Ship, Tn,
      Wait_T, Dest, Dest_T, Lt, Orig : Integer := -1;
      Kind  : Unit_Kind := Trooper;
      Fort, Skip, No_Heal, Want_Ship, Rush : Boolean := False;
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
      Sea, Capital, UG, Res_Set : Boolean := False;
      Air, Food_R, Pow, Cut, Low, Air_Out : Integer := 0;
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
   type Rel_Mat is array (0 .. 3, 0 .. 3) of Rel_Kind;
   type Int_Mat is array (0 .. 3, 0 .. 3) of Integer;
   type Bool_Mat is array (0 .. 3, 0 .. 3) of Boolean;
   Rel : Rel_Mat := (others => (others => Rel_War));
   Since : Int_Mat := (others => (others => 0));
   Open_B, Contact : Bool_Mat := (others => (others => False));
   Rep_V : array (0 .. 3) of Integer := (others => 50);
   Lock_Until : array (0 .. 3) of Integer := (others => 0);
   Fung_Cut : array (0 .. 3) of Integer := (others => 0);
   War_Target : array (0 .. 3) of Integer := (others => -1);
   War_City : array (0 .. 3) of Integer := (others => -1);
   Land_Share : array (0 .. 3) of Long_Float := (others => 0.0);
   Dip_Turns : array (0 .. 3) of Integer := (others => 0);
   Coop_Turns : Integer := 0;
   Coop_Key : Integer := 0;
   type Ghost_Rec is record
      Live : Boolean := False;
      Id, Loc, Fac, Kind, Seen : Integer := -1;
   end record;
   Ghosts : array (0 .. 3, 0 .. 63) of Ghost_Rec := (others => (others => <>));
   type CMem_Rec is record
      Live : Boolean := False;
      Id, Loc, Fac : Integer := -1;
   end record;
   CMem : array (0 .. 3, 0 .. 31) of CMem_Rec := (others => (others => <>));
   type Contract_Rec is record
      Live, Energy : Boolean := False;
      Seller, Buyer, Amt, Left, Price : Integer := 0;
   end record;
   Contracts : array (0 .. 15) of Contract_Rec;
   type Offer_Rec is record
      Live, Buy, Energy : Boolean := False;
      Id, From, To, Kind, Amt, Price, Turn : Integer := 0;
   end record;
   Pending : array (0 .. 7) of Offer_Rec;
   Next_Offer : Integer := 1;
   Last_Hits : Integer := 0;
   Ask : array (0 .. 3, 0 .. 3, 0 .. 4) of Integer :=
     (others => (others => (others => -100)));
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
   procedure Supply_Turn;
   procedure Diplo_Turn;
   procedure AI_Diplomacy (Fid : Integer);
   procedure AI_Collapse (Fid : Integer);
   function Collapse_Tunnel (Fid, Tile : Integer) return String;
   function U_Bomb (K : Unit_Kind) return Boolean;
   function Bombard (Uidx, Tile : Integer) return Boolean;
   function Known_Owner (Fid, Cidx : Integer) return Integer;
   function Mil_Power (Fid : Integer) return Long_Float;
   function Strength_Of (A, B : Integer) return Long_Float;
   procedure Plan_Faction (Fid : Integer);
   procedure Score_Diplomacy;
   function At_War (A, B : Integer) return Boolean;
   function Pass_OK (Fid, Owner : Integer) return Boolean;

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
         when Burrower => return 35;
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
         when Colonist | Sea_Colonist | Burrower | Terraformer | Transport => return 0;
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
         when Colonist | Sea_Colonist | Burrower | Terraformer | Scout | Transport | Rebel | Skiff => return 1;
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
     (K in Colonist | Sea_Colonist | Burrower | Terraformer | Transport);

   function U_Ship (K : Unit_Kind) return Boolean is
     (K in Skiff | Transport | Frigate | Cruiser);

   function U_Native (K : Unit_Kind) return Boolean is
     (K in Beast | Rebel);

   function U_Found (K : Unit_Kind) return Boolean is
     (K in Colonist | Sea_Colonist | Burrower);

   function U_Tech (K : Unit_Kind) return Integer is
   begin
      case K is
         when Sea_Colonist => return Tech_Kind'Pos (Tidal);
         when Burrower => return Tech_Kind'Pos (Boring);
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
         when Burrower => return "Burrower";
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
         when Burrower => return "U";
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
         when Scrub => return "CO2 Scrubbers";
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
         when Tidal_C | Scrub => return 40;
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
         when Scrub => return Tech_Kind'Pos (Boring);
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
         when Sapper => return "Assault warrens from the surface and flood any tunnel.";
         when Boring => return "Unlocks the Burrower: warrens and tunnels.";
         when Naval => return "Unlocks docks, fisheries, tidal collectors and ships.";
         when Ordnance => return "Unlocks the Frigate, which can bombard a coastal city.";
         when Dread => return "Unlocks the Assault Cruiser.";
         when Ascend => return "Unlocks the Resonance Beacon and the Ascension Array.";
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
      U.Tn := 0;
      U.No_Heal := False;
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

   procedure Yield3 (I, Fid : Integer; N, Mi, En : out Integer; UG : Boolean := False) is
      T : Tile;
   begin
      N := 0; Mi := 0; En := 0;
      if I < 0 or else I >= NTiles then
         return;
      end if;
      T := Tiles (I);
      if UG then
         if T.Land then
            Mi := 1 + T.Rock + (if T.Rock = 2 then 1 else 0);
            if T.Tun >= 0 then
               En := 1;
            end if;
         end if;
         return;
      end if;
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
         if O /= C and then Cities (O).UG = Cities (C).UG then
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
         Yield3 (Cities (C).Worked (Wk), Cities (C).Fac, A, B, D, Cities (C).UG);
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
     (if Cities (C).UG then (if City_Has (C, Dome) then 10 else 6)
      else (if City_Has (C, Dome) then 14 else 8));

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
           and then not (K = Scrub and then not Cities (C).UG)
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
           and then not (K = Scrub and then not Cities (C).UG)
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
      if U.Kind = Burrower then
         if not Tiles (Loc).Land then
            return "Must be on land";
         end if;
         if Loc /= U.Loc then
            return "Found on the colonist's own tile";
         end if;
         if not (Tiles (Loc).Rock = 2 or else Tiles (Loc).Elev > 60) then
            return "Underground bases need rocky or high ground";
         end if;
      elsif U.Kind = Sea_Colonist then
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
      C.Sea := not Tiles (Loc).Land and then Units (Uidx).Kind /= Burrower;
      C.UG := Units (Uidx).Kind = Burrower;
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
      if Cities (City_N - 1).UG then
         Tiles (Loc).Tun := Cities (City_N - 1).Fac;
      else
         Tiles (Loc).Fungus := False;
         Tiles (Loc).Road := True;
      end if;
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
            Mark (Fid, Cities (C).Loc,
                  (if Cities (C).UG then 2 else 3)
                  + (if Has_Tech (Fid, Tech_Kind'Pos (Sensors)) then 1 else 0));
         end if;
      end loop;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac /= Fid and then Factions (Fid).Vis (Cities (C).Loc) then
            declare
               Slot : Integer := -1;
            begin
               for I in CMem'Range (2) loop
                  if CMem (Fid, I).Live and then CMem (Fid, I).Id = Cities (C).Id then
                     Slot := I;
                     exit;
                  elsif not CMem (Fid, I).Live and then Slot < 0 then
                     Slot := I;
                  end if;
               end loop;
               if Slot >= 0 then
                  CMem (Fid, Slot) := (Live => True, Id => Cities (C).Id,
                                       Loc => Cities (C).Loc, Fac => Cities (C).Fac);
               end if;
            end;
         end if;
      end loop;
      for I in CMem'Range (2) loop
         if CMem (Fid, I).Live and then Factions (Fid).Vis (CMem (Fid, I).Loc) then
            declare
               Still : Boolean := False;
            begin
               for C in 0 .. City_N - 1 loop
                  if Cities (C).Id = CMem (Fid, I).Id then
                     Still := True;
                  end if;
               end loop;
               if not Still then
                  CMem (Fid, I).Live := False;
               end if;
            end;
         end if;
      end loop;
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac /= Fid and then Factions (Fid).Vis (Units (U).Loc) then
            declare
               Slot : Integer := -1;
            begin
               for I in Ghosts'Range (2) loop
                  if Ghosts (Fid, I).Live and then Ghosts (Fid, I).Id = Units (U).Id then
                     Slot := I;
                     exit;
                  elsif not Ghosts (Fid, I).Live and then Slot < 0 then
                     Slot := I;
                  end if;
               end loop;
               if Slot >= 0 then
                  Ghosts (Fid, Slot) := (Live => True, Id => Units (U).Id, Loc => Units (U).Loc,
                                         Fac => Units (U).Fac, Kind => Unit_Kind'Pos (Units (U).Kind),
                                         Seen => Turn_N);
               end if;
            end;
         end if;
      end loop;
      for I in Ghosts'Range (2) loop
         if Ghosts (Fid, I).Live then
            declare
               G : Ghost_Rec renames Ghosts (Fid, I);
               U : Integer := -1;
            begin
               for V in 0 .. Unit_N - 1 loop
                  if Units (V).Id = G.Id then
                     U := V;
                  end if;
               end loop;
               if G.Seen = Turn_N and then U >= 0 and then Factions (Fid).Vis (Units (U).Loc) then
                  null;
               elsif Factions (Fid).Vis (G.Loc) or else Turn_N - G.Seen > 50 then
                  G.Live := False;
               end if;
            end;
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
         if Cities (C).UG and then not (Att >= 0 and then Has_Tech (Units (Att).Fac, Tech_Kind'Pos (Sapper))) then
            D := D * 1.5;
         end if;
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
      Was_Aboard, From_Sea : Boolean := False;
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
      Was_Aboard := Units (U).On_Ship >= 0;
      From_Sea := not Tiles (Units (U).Loc).Land and then City_At (Units (U).Loc) < 0;
      if Was_Aboard and then not Tiles (To).Land and then City_At (To) < 0 then
         Set_Error ("Aboard a transport. Move onto a shore tile to land");
         return False;
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
      declare
         Block : Integer := -1;
         Ow : Integer;
      begin
         for O in 0 .. Unit_N - 1 loop
            if Units (O).Loc = To and then Units (O).Fac /= Units (U).Fac
              and then Units (O).On_Ship < 0 and then not At_War (Units (U).Fac, Units (O).Fac)
            then
               Block := Units (O).Fac;
            end if;
         end loop;
         declare
            CC : constant Integer := City_At (To);
         begin
            if CC >= 0 and then not At_War (Units (U).Fac, Cities (CC).Fac) then
               Block := Cities (CC).Fac;
            end if;
         end;
         if Block >= 0 then
            Set_Error ("Declare war first");
            return False;
         end if;
         if Units (U).Fac >= 0 and then (Tiles (To).Land or else City_At (To) >= 0) then
            Territory;
            Ow := Terr (To);
            if Ow >= 0 and then not Pass_OK (Units (U).Fac, Ow) and then Terr (From) /= Ow then
               Set_Error ("Closed borders");
               return False;
            end if;
         end if;
      end;
      Units (U).Fort := False;
      Units (U).Work := W_None;
      if Enemy_At (To, Units (U).Fac) then
         declare
            WC : constant Integer := City_At (To);
         begin
            if WC >= 0 and then Cities (WC).UG and then Cities (WC).Fac /= Units (U).Fac
              and then Tiles (Units (U).Loc).Tun < 0
              and then U_Atk (Units (U).Kind) < 4
              and then not Has_Tech (Units (U).Fac, Tech_Kind'Pos (Sapper))
            then
               Set_Error ("Underground base: attack from a tunnel tile or with an attack-4+ unit");
               return False;
            end if;
         end;
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
         if Was_Aboard then
            Units (U).On_Ship := -1;
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
      if Units (U).Fac >= 0 and then Tiles (From).Tun = Units (U).Fac
        and then Tiles (To).Tun = Units (U).Fac
        and then not Tiles (From).Flooded and then not Tiles (To).Flooded
        and then Units (U).Tn < 8
      then
         Cost := 0;
         Units (U).Tn := Units (U).Tn + 1;
      end if;
      Units (U).MP := Integer'Max (0, Units (U).MP - Cost);
      Units (U).Loc := To;
      if Was_Aboard then
         Units (U).On_Ship := -1;
         if From_Sea then
            Units (U).MP := 0;
         end if;
      end if;
      if Units (U).Fac >= 0 and then Tiles (To).Tun >= 0 and then Tiles (To).Tun /= Units (U).Fac
        and then At_War (Units (U).Fac, Tiles (To).Tun) and then City_At (To) < 0
      then
         Tiles (To).Tun := Units (U).Fac;
         Log ("T" & Img (Turn_N) & " tunnel breached");
      end if;
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

   procedure BFS (Start, Fid, Max_D : Integer; Ignore_Enemy : Boolean := False; Mode : Integer := 0) is
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
         if Fid >= 0 and then Coastal (CI)
           and then (Cities (CI).Fac = Fid
                     or else (Cities (CI).Fac >= 0 and then Rel (Fid, Cities (CI).Fac) = Rel_Ally))
         then
            Occ_A (Cities (CI).Loc) := Occ_A (Cities (CI).Loc) or 8;
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
         if Dist_A (C) < Max_D
           and then (C = Start or else Ignore_Enemy or else (Occ_A (C) and 1) = 0)
         then
            for DY in -1 .. 1 loop
               for DX in -1 .. 1 loop
                  if DX /= 0 or else DY /= 0 then
                     Nx := X_Of (C) + DX;
                     Ny := Y_Of (C) + DY;
                     if In_Map (Nx, Ny) then
                        N := Ny * W + Nx;
                        if Dist_A (N) < 0
                          and then (if Mode = 1
                                    then (not Tiles (N).Land and then (Occ_A (N) and 2) = 0)
                                      or else (Occ_A (N) and 8) /= 0
                                    else Tiles (N).Land or else (Occ_A (N) and 2) /= 0)
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
         BFS (Units (Uidx).Loc, Units (Uidx).Fac, Max_D, False, 1);
      else
         BFS (Units (Uidx).Loc, Units (Uidx).Fac, Max_D);
      end if;
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
         when W_Tunnel => Turns := 2;
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
      if not Cities (C).UG and then Can_Build (Fid, Unit_Kind'Pos (Burrower)) then
         declare
            Wars, Burs, Tuns : Integer := 0;
         begin
            for O in 0 .. City_N - 1 loop
               if Cities (O).Fac = Fid and then Cities (O).UG then
                  Wars := Wars + 1;
               end if;
            end loop;
            for V in 0 .. Unit_N - 1 loop
               if Units (V).Fac = Fid and then Units (V).Kind = Burrower then
                  Burs := Burs + 1;
               end if;
            end loop;
            for I in 0 .. NTiles - 1 loop
               if Tiles (I).Tun = Fid then
                  Tuns := Tuns + 1;
               end if;
            end loop;
            if Count_Cities (Fid) <= 2 and then Wars = 0 and then Burs = 0
              and then Cities (C).Pop >= 2 and then Turn_N > 60 and then Rand < 0.6
            then
               Cities (C).Queue (0) := Unit_Kind'Pos (Burrower);
               Cities (C).Q_Len := 1;
               return;
            end if;
            if Cities (C).Pop >= 3 and then Burs < 1 and then Count_Cities (Fid) >= 2
              and then (Wars < 2 or else (Wars < 3 and then Key = 0)) and then Rand < 0.45
            then
               Cities (C).Queue (0) := Unit_Kind'Pos (Burrower);
               Cities (C).Q_Len := 1;
               return;
            end if;
            if Wars >= 1 and then Burs < 1 and then Tuns < Wars * 6
              and then Cities (C).Pop >= 3 and then Rand < 0.35
            then
               Cities (C).Queue (0) := Unit_Kind'Pos (Burrower);
               Cities (C).Q_Len := 1;
               return;
            end if;
            if Key = 0 and then (Plan = 4 or else Plan = 2) and then War_Target (Fid) >= 0
              and then Burs < 2 and then Cities (C).Pop >= 3 and then Rand < 0.4
            then
               Cities (C).Queue (0) := Unit_Kind'Pos (Burrower);
               Cities (C).Q_Len := 1;
               return;
            end if;
         end;
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
         if not F_Project (K) and then not F_Coast (K) and then K /= Scrub
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

   function AI_Rush (U : Integer) return Boolean is
      Fid : constant Integer := Units (U).Fac;
      E, ED, T, TD, Job : Integer;
      C : Integer;
      Path : array (0 .. 48) of Integer;
      PN : Natural;
   begin
      E := -1;
      ED := 99;
      if War_City (Fid) >= 0 then
         for I in 0 .. City_N - 1 loop
            if Cities (I).Loc = War_City (Fid) and then Known_Owner (Fid, I) = War_Target (Fid) then
               E := I;
               ED := Dist (Cities (I).Loc, Units (U).Loc);
            end if;
         end loop;
      end if;
      if E < 0 then
      for I in 0 .. City_N - 1 loop
         if Cities (I).Fac /= Fid and then Known_Owner (Fid, I) = War_Target (Fid) then
            if Dist (Cities (I).Loc, Units (U).Loc) < ED then
               ED := Dist (Cities (I).Loc, Units (U).Loc);
               E := I;
            end if;
         end if;
      end loop;
      end if;
      if E < 0 or else ED > 16 then
         return False;
      end if;
      T := -1;
      TD := 99;
      for I in 0 .. NTiles - 1 loop
         if Tiles (I).Tun /= Fid then
            null;
         else
            declare
               Own_City : Boolean := False;
            begin
               for K in 0 .. City_N - 1 loop
                  if Cities (K).Loc = I and then Cities (K).Fac = Fid then
                     Own_City := True;
                  end if;
               end loop;
               if not Own_City and then Dist (I, Cities (E).Loc) < TD then
                  TD := Dist (I, Cities (E).Loc);
                  T := I;
               end if;
            end;
         end if;
      end loop;
      if T < 0 or else TD <= 1 or else TD > 14 then
         return False;
      end if;
      BFS (T, Fid, 16, True);
      if Dist_A (Cities (E).Loc) < 0 then
         return False;
      end if;
      PN := 0;
      C := Prev_A (Cities (E).Loc);
      while C >= 0 and then C /= T and then PN < Path'Length loop
         Path (PN) := C;
         PN := PN + 1;
         C := Prev_A (C);
      end loop;
      Job := -1;
      for K in reverse 0 .. PN - 1 loop
         if Tiles (Path (K)).Tun /= Fid and then Tiles (Path (K)).Land
           and then City_At (Path (K)) < 0 and then (Occ_A (Path (K)) and 1) = 0
         then
            Job := Path (K);
            exit;
         end if;
      end loop;
      if Job < 0 then
         return False;
      end if;
      Units (U).Target := Job;
      if Units (U).Loc /= Job then
         Move_Toward (U, Job, 20);
      end if;
      declare
         Id : constant Integer := Units (U).Id;
         V : constant Integer := Find_Unit (Id);
      begin
         if V >= 0 and then Units (V).Loc = Job and then Units (V).MP > 0
           and then Tiles (Job).Tun /= Fid
         then
            Units (V).Work := W_Tunnel;
            Units (V).Work_Left := (if Tiles (Job).Rock = 2 then 3 else 2);
            Units (V).Rush := True;
            Units (V).MP := 0;
         end if;
      end;
      return True;
   end AI_Rush;

   procedure Load_Waiters (U : Integer);
   procedure Sail_Cargo (U : Integer) is
      Fid : Integer;
      Cargo : Integer := 0;
      Lm : array (0 .. Max_Tiles - 1) of Integer := (others => -1);
      Next_Lm : Integer := 0;
      Dest, Spot, Best, BV : Integer;
      Nb : Nbr_Arr;
      NN : Natural;
   begin
      Load_Waiters (U);
      if U < 0 then
         return;
      end if;
      Fid := Units (U).Fac;
      for O in 0 .. Unit_N - 1 loop
         if Units (O).On_Ship = Units (U).Id then
            Cargo := Cargo + 1;
         end if;
      end loop;
      if Cargo = 0 then
         return;
      end if;
      for I in 0 .. NTiles - 1 loop
         if Tiles (I).Land and then Lm (I) < 0 then
            declare
               Q : array (0 .. Max_Tiles - 1) of Integer;
               Qh, Qt : Integer;
            begin
               Q (0) := I;
               Qt := 1;
               Qh := 0;
               Lm (I) := Next_Lm;
               while Qh < Qt loop
                  Nbrs (Q (Qh), 1, NN, Nb);
                  Qh := Qh + 1;
                  for K in 0 .. NN - 1 loop
                     if Tiles (Nb (K)).Land and then Lm (Nb (K)) < 0 then
                        Lm (Nb (K)) := Next_Lm;
                        Q (Qt) := Nb (K);
                        Qt := Qt + 1;
                     end if;
                  end loop;
               end loop;
               Next_Lm := Next_Lm + 1;
            end;
         end if;
      end loop;
      Dest := -1;
      BV := -100000;
      declare
         Home_Lm : Integer := -2;
      begin
      if Units (U).Orig in 0 .. NTiles - 1 then
         Home_Lm := Lm (Units (U).Orig);
      end if;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac /= Fid and then At_War (Fid, Cities (C).Fac)
           and then Known_Owner (Fid, C) = Cities (C).Fac
           and then Lm (Cities (C).Loc) /= Home_Lm
         then
            declare
               Score : Integer := -Dist (Cities (C).Loc, Units (U).Loc) - Cities (C).Pop;
            begin
               if Cities (C).Fac = War_Target (Fid) then
                  Score := Score + 12;
               end if;
               if Score > BV then
                  BV := Score;
                  Dest := Cities (C).Loc;
               end if;
            end;
         end if;
      end loop;
      end;
      if Dest < 0 then
         return;
      end if;
      BFS (Units (U).Loc, Fid, 40, False, 1);
      Spot := -1;
      Best := 100000;
      for I in 0 .. NTiles - 1 loop
         if Dist_A (I) >= 0 and then not Tiles (I).Land and then City_At (I) < 0
           and then Dist (I, Dest) <= 6
         then
            Nbrs (I, 1, NN, Nb);
            for K in 0 .. NN - 1 loop
               if Tiles (Nb (K)).Land and then Lm (Nb (K)) = Lm (Dest) and then City_At (Nb (K)) < 0 then
                  if Dist_A (I) + Dist (Nb (K), Dest) * 2 < Best then
                     Best := Dist_A (I) + Dist (Nb (K), Dest) * 2;
                     Spot := I;
                  end if;
               end if;
            end loop;
         end if;
      end loop;
      if Spot >= 0 and then Spot /= Units (U).Loc then
         Move_Toward (U, Spot, 40);
      end if;
      declare
         Id : constant Integer := Units (U).Id;
         V : Integer := Find_Unit (Id);
         Shore : Integer;
      begin
         if V < 0 or else Tiles (Units (V).Loc).Land then
            return;
         end if;
         Nbrs (Units (V).Loc, 1, NN, Nb);
         Shore := -1;
         for K in 0 .. NN - 1 loop
            if Tiles (Nb (K)).Land and then Lm (Nb (K)) = Lm (Dest)
              and then Dist (Nb (K), Dest) <= 6 and then City_At (Nb (K)) < 0
            then
               Shore := Nb (K);
               exit;
            end if;
         end loop;
         if Shore < 0 then
            return;
         end if;
         for O in 0 .. Unit_N - 1 loop
            if Units (O).On_Ship = Id then
               Units (O).MP := U_Mv (Units (O).Kind) * 3;
               if not Step (O, Shore) then
                  null;
               end if;
               V := Find_Unit (Id);
               exit when V < 0;
            end if;
         end loop;
      end;
   end Sail_Cargo;

   procedure Load_Waiters (U : Integer) is
      Room : Integer := 3;
   begin
      if U < 0 or else Units (U).Kind /= Transport then
         return;
      end if;
      for O in 0 .. Unit_N - 1 loop
         if Units (O).On_Ship = Units (U).Id then
            Room := Room - 1;
         end if;
      end loop;
      for O in 0 .. Unit_N - 1 loop
         exit when Room <= 0;
         if O /= U and then Units (O).Fac = Units (U).Fac and then Units (O).Loc = Units (U).Loc
           and then Units (O).Want_Ship and then Units (O).On_Ship < 0 and then not U_Ship (Units (O).Kind)
         then
            Units (O).On_Ship := Units (U).Id;
            Units (O).MP := 0;
            Units (O).Want_Ship := False;
            Units (O).Skip := False;
            Units (U).Orig := Units (U).Loc;
            Room := Room - 1;
            Log ("T" & Img (Turn_N) & " " & U_Name (Units (O).Kind) & " boards a transport");
         end if;
      end loop;
   end Load_Waiters;

   procedure AI_Burrower (U : Integer) is
      Fid : constant Integer := Units (U).Fac;
      Wars : Integer := 0;
      Best : Integer := -1;
      BS, Sc : Long_Float;
      Nb : Nbr_Arr;
      NN : Natural;
      Job, Near_C, ND : Integer;
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid and then Cities (C).UG then
            Wars := Wars + 1;
         end if;
      end loop;
      if Slot_Key (Fid) = 0 and then (Factions (Fid).Plan = 4 or else Factions (Fid).Plan = 2)
        and then War_Target (Fid) >= 0 and then Wars >= 1 and then AI_Rush (U)
      then
         return;
      end if;
      if Wars < 2 then
         BFS (Units (U).Loc, Fid, 10);
         BS := -1.0e9;
         for I in 0 .. NTiles - 1 loop
            if Dist_A (I) >= 0 and then Tiles (I).Land
              and then (Tiles (I).Rock = 2 or else Tiles (I).Elev > 60)
              and then Can_Found (U, I) = ""
            then
               declare
                  Taken : Boolean := False;
               begin
                  for O in 0 .. Unit_N - 1 loop
                     if O /= U and then Units (O).Fac = Fid and then Units (O).Kind = Burrower
                       and then Units (O).Target = I
                     then
                        Taken := True;
                     end if;
                  end loop;
                  if not Taken then
                     Sc := 0.0;
                     Nbrs (I, 2, NN, Nb);
                     for K in 0 .. NN - 1 loop
                        if Tiles (Nb (K)).Land then
                           Sc := Sc + 1.0 + Long_Float (Tiles (Nb (K)).Rock);
                        end if;
                     end loop;
                     Sc := Sc - Long_Float (Dist_A (I)) * 1.5;
                     if Sc > BS then
                        BS := Sc;
                        Best := I;
                     end if;
                  end if;
               end;
            end if;
         end loop;
         if Best >= 0 then
            Units (U).Target := Best;
            if Units (U).Loc /= Best then
               Move_Toward (U, Best, 12);
            end if;
            declare
               Id : constant Integer := Units (U).Id;
               V : constant Integer := Find_Unit (Id);
            begin
               if V >= 0 and then Units (V).Loc = Best and then Units (V).MP > 0 then
                  if not Found_City (V) then
                     null;
                  end if;
               end if;
            end;
            return;
         end if;
      end if;
      if Wars = 0 then
         return;
      end if;
      Job := -1;
      for W in 0 .. City_N - 1 loop
         exit when Job >= 0;
         if Cities (W).Fac = Fid and then Cities (W).UG then
            Near_C := -1;
            ND := 99;
            for C in 0 .. City_N - 1 loop
               if Cities (C).Fac = Fid and then not Cities (C).UG
                 and then Dist (Cities (C).Loc, Cities (W).Loc) < ND
               then
                  ND := Dist (Cities (C).Loc, Cities (W).Loc);
                  Near_C := Cities (C).Loc;
               end if;
            end loop;
            if Near_C >= 0 and then ND <= 14 then
               BFS (Cities (W).Loc, Fid, 16, True);
               if Dist_A (Near_C) >= 0 then
                  declare
                     Path : array (0 .. 40) of Integer;
                     PN : Natural := 0;
                     C : Integer := Near_C;
                  begin
                     while C >= 0 and then C /= Cities (W).Loc and then PN < Path'Length loop
                        Path (PN) := C;
                        PN := PN + 1;
                        C := Prev_A (C);
                     end loop;
                     for K in reverse 0 .. PN - 1 loop
                        if Tiles (Path (K)).Tun /= Fid and then Tiles (Path (K)).Land then
                           declare
                              Taken : Boolean := False;
                           begin
                              for O in 0 .. Unit_N - 1 loop
                                 if O /= U and then Units (O).Fac = Fid and then Units (O).Kind = Burrower
                                   and then Units (O).Target = Path (K)
                                 then
                                    Taken := True;
                                 end if;
                              end loop;
                              if not Taken then
                                 Job := Path (K);
                                 exit;
                              end if;
                           end;
                        end if;
                     end loop;
                  end;
               end if;
            end if;
         end if;
      end loop;
      if Job < 0 then
         Units (U).Fort := True;
         return;
      end if;
      Units (U).Target := Job;
      if Units (U).Loc /= Job then
         Move_Toward (U, Job, 20);
      end if;
      declare
         Id : constant Integer := Units (U).Id;
         V : constant Integer := Find_Unit (Id);
      begin
         if V >= 0 and then Units (V).Loc = Job and then Tiles (Job).Tun /= Fid then
            Units (V).Work := W_Tunnel;
            Units (V).Work_Left := (if Tiles (Job).Rock = 2 then 3 else 2);
            Units (V).MP := 0;
         end if;
      end;
   end AI_Burrower;

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
      if Units (U).Fac < 0 then
         return;
      end if;
      if Units (U).Kind = Transport then
         Sail_Cargo (U);
         return;
      end if;
      if U_Bomb (Units (U).Kind) and then Units (U).HP >= 5
        and then not Tiles (Units (U).Loc).Land and then City_At (Units (U).Loc) < 0
      then
         declare
            Nb : Nbr_Arr;
            NN : Natural;
            CC : Integer;
         begin
            Nbrs (Units (U).Loc, 1, NN, Nb);
            for K in 0 .. NN - 1 loop
               CC := City_At (Nb (K));
               if CC >= 0 and then Cities (CC).Fac /= Fid
                 and then (Cities (CC).Fac < 0 or else At_War (Fid, Cities (CC).Fac))
               then
                  if Bombard (U, Nb (K)) then
                     return;
                  end if;
               end if;
            end loop;
         end;
      end if;
      if U_Ship (Units (U).Kind) or else Units (U).On_Ship >= 0 then
         return;
      end if;
      if Units (U).Kind = Burrower then
         AI_Burrower (U);
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
      AI_Diplomacy (Fid);
      if Turn_N >= 15 and then not Factions (Fid).Policy_Set then
         for Axis in 0 .. 3 loop
            Factions (Fid).Pol (Axis) := AI_Pol (Slot_Key (Fid), Axis);
         end loop;
         Factions (Fid).Policy_Set := True;
         Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (Fid))
              & " sets its policies");
      end if;
      Plan_Faction (Fid);
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
      AI_Collapse (Fid);
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
            if F in 0 .. 3 then
               Land_Share (F) := Share;
            end if;
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
      Score_Diplomacy;
      if Winner /= -2 then
         return;
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

   function At_War (A, B : Integer) return Boolean is
   begin
      if A = B then
         return False;
      end if;
      if A < 0 or else B < 0 then
         return True;
      end if;
      if A >= Fac_N or else B >= Fac_N then
         return True;
      end if;
      return Rel (A, B) = Rel_War;
   end At_War;

   function Pass_OK (Fid, Owner : Integer) return Boolean is
   begin
      if Owner < 0 or else Fid < 0 or else Owner = Fid then
         return True;
      end if;
      if Owner >= Fac_N or else Fid >= Fac_N then
         return True;
      end if;
      return Rel (Fid, Owner) = Rel_War or else Rel (Fid, Owner) = Rel_Ally
        or else Open_B (Fid, Owner);
   end Pass_OK;

   function Rel_Code (A, B : Integer) return Integer is
   begin
      case Rel (A, B) is
         when Rel_War => return 0;
         when Rel_Cease => return 1;
         when Rel_Peace => return 2;
         when Rel_Ally => return 3;
      end case;
   end Rel_Code;

   procedure Set_Rel (A, B : Integer; R : Rel_Kind) is
   begin
      Rel (A, B) := R;
      Rel (B, A) := R;
      Since (A, B) := Turn_N;
      Since (B, A) := Turn_N;
      if R = Rel_War or else R = Rel_Cease then
         Open_B (A, B) := False;
         Open_B (B, A) := False;
      end if;
      if R = Rel_War then
         for I in Contracts'Range loop
            if Contracts (I).Live
              and then ((Contracts (I).Seller = A and then Contracts (I).Buyer = B)
                        or else (Contracts (I).Seller = B and then Contracts (I).Buyer = A))
            then
               Contracts (I).Live := False;
            end if;
         end loop;
      end if;
   end Set_Rel;

   function Declare_War (A, B : Integer) return String is
      Prev : Rel_Kind;
      Pen : Integer;
   begin
      if A = B or else B not in 0 .. Fac_N - 1 or else not Factions (B).Alive then
         return "No such faction";
      end if;
      Prev := Rel (A, B);
      if Prev = Rel_War then
         return "Already at war";
      end if;
      Pen := (case Prev is
                 when Rel_Cease => 15, when Rel_Peace => 25, when Rel_Ally => 35, when Rel_War => 0);
      if Pen > 0 then
         Rep_V (A) := Integer'Max (0, Rep_V (A) - Pen);
         Lock_Until (A) := Turn_N + 30;
         Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (A)) & " breaks a treaty");
      end if;
      Set_Rel (A, B, Rel_War);
      Log ("T" & Img (Turn_N) & " war declared");
      return "";
   end Declare_War;

   function Victory_Progress (Fid : Integer) return Long_Float is
      P : Long_Float := Long_Float (Factions (Fid).Tech_N) / 22.0 * 0.35;
      Cred : Long_Float;
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid and then City_Has (C, Beacon) then
            P := P + 0.15;
         end if;
      end loop;
      if Asc_On and then Asc_Fac = Fid and then Asc_Left > 0 then
         P := 0.8 + 0.2 * (1.0 - Long_Float (Asc_Left) / 12.0);
      end if;
      if Rule (2) then
         Cred := Long_Float (Factions (Fid).Credits) / Long_Float (Integer'Max (1, Econ_Target)) * 0.95;
         if Cred > P then
            P := Cred;
         end if;
      end if;
      if Fid in 0 .. 3 then
         P := Long_Float'Max (P, Long_Float (Dip_Turns (Fid)) / 15.0 * 0.6);
         P := Long_Float'Max (P, Long_Float (Dom_Turns (Fid)) / 10.0 * 0.9);
         P := Long_Float'Max (P, Land_Share (Fid) / 0.5 * 0.5);
      end if;
      P := Long_Float'Max (P, Long_Float (Coop_Turns) / 15.0 * 0.6);
      if P > 1.0 then
         P := 1.0;
      end if;
      return P;
   end Victory_Progress;

   function Pact_Count (Fid : Integer) return Integer is
      N : Integer := 0;
   begin
      for O in 0 .. Fac_N - 1 loop
         if O /= Fid and then Factions (O).Alive
           and then (Rel (Fid, O) = Rel_Peace or else Rel (Fid, O) = Rel_Ally)
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Pact_Count;

   function Top_Score (Fid : Integer) return Boolean is
   begin
      for O in 0 .. Fac_N - 1 loop
         if O /= Fid and then Factions (O).Alive and then Score_Of (O) >= Score_Of (Fid) then
            return False;
         end if;
      end loop;
      return True;
   end Top_Score;

   procedure Score_Diplomacy is
      Alive_N : Integer := 0;
      Need, Best, Best_S, Key, Lead, Lead_S : Integer;
      Ok : Boolean;
      Group : array (0 .. 3) of Boolean := (others => False);
      Any : Boolean;
   begin
      if Winner /= -2 then
         return;
      end if;
      for F in 0 .. Fac_N - 1 loop
         if Factions (F).Alive then
            Alive_N := Alive_N + 1;
         end if;
      end loop;
      if Rule (8) then
         Need := Integer'Max (2, Alive_N / 2);
         Best := -1;
         Best_S := -1;
         for F in 0 .. Fac_N - 1 loop
            if Factions (F).Alive then
               Ok := Top_Score (F) and then Alive_N >= 3 and then Turn_N >= 120
                 and then Pact_Count (F) >= Need and then Rep_V (F) >= 60;
               if Ok then
                  Dip_Turns (F) := Dip_Turns (F) + 1;
               else
                  Dip_Turns (F) := 0;
               end if;
               if Dip_Turns (F) >= 15 and then Score_Of (F) > Best_S then
                  Best := F;
                  Best_S := Score_Of (F);
               end if;
            end if;
         end loop;
         if Best >= 0 then
            Winner := Best;
            Win_Type := 7;
            Log ("T" & Img (Turn_N) & " diplomatic victory");
            return;
         end if;
      end if;
      if Rule (9) and then Turn_N >= 120 and then Alive_N >= 2 then
         Any := True;
         for A in 0 .. Fac_N - 1 loop
            if Factions (A).Alive then
               for B in A + 1 .. Fac_N - 1 loop
                  if Factions (B).Alive and then Rel (A, B) /= Rel_Ally then
                     Any := False;
                  end if;
               end loop;
            end if;
         end loop;
         Key := 0;
         if Any then
            for F in 0 .. Fac_N - 1 loop
               if Factions (F).Alive then
                  Group (F) := True;
                  Key := Key + 2 ** F;
               end if;
            end loop;
            Key := Key + 32;
         else
            for A in 0 .. Fac_N - 1 loop
               if Factions (A).Alive then
                  for B in A + 1 .. Fac_N - 1 loop
                     if Factions (B).Alive and then Rel (A, B) = Rel_Ally
                       and then Turn_N - Since (A, B) >= 10
                       and then Land_Share (A) + Land_Share (B) >= 0.6
                     then
                        Group (A) := True;
                        Group (B) := True;
                        Key := 2 ** A + 2 ** B;
                     end if;
                  end loop;
               end if;
            end loop;
         end if;
         if Key /= 0 and then Key = Coop_Key then
            Coop_Turns := Coop_Turns + 1;
         else
            Coop_Turns := (if Key /= 0 then 1 else 0);
            Coop_Key := Key;
         end if;
         if Key /= 0 and then Coop_Turns >= 15 then
            Lead := -1;
            Lead_S := -1;
            for F in 0 .. 3 loop
               if Group (F) and then Score_Of (F) > Lead_S then
                  Lead := F;
                  Lead_S := Score_Of (F);
               end if;
            end loop;
            if Lead >= 0 then
               Winner := Lead;
               Win_Type := 8;
               Log ("T" & Img (Turn_N) & " cooperative victory");
            end if;
         end if;
      end if;
   end Score_Diplomacy;

   function Wants_Break (Fid, Opp : Integer) return Boolean is
      Pers : constant Integer := Slot_Key (Fid);
      Prox : constant Long_Float := Victory_Progress (Opp);
      SR : constant Long_Float := Strength_Of (Fid, Opp);
      Held : constant Integer := Turn_N - Since (Fid, Opp);
   begin
      if Rel (Fid, Opp) = Rel_War then
         return True;
      end if;
      if Rel (Fid, Opp) = Rel_Ally then
         return Prox > 0.9 and then Pers = 0;
      end if;
      if Prox > 0.65 then
         return True;
      end if;
      if Pers = 0 then
         return Held >= 10 and then SR > 1.4 and then Turn_N >= Grace;
      end if;
      return Pers = 3 and then Rel (Fid, Opp) = Rel_Cease and then SR > 2.0 and then Held >= 8;
   end Wants_Break;

   type Abs_Rec is record
      Cities, Pop, Prod, Labs, Mil, Tech, Prog, Cr : Long_Float := 0.0;
   end record;

   procedure Abs_Apply (S, O : in out Abs_Rec; Plan : Integer) is
      NT : constant Long_Float := 22.0;
      Eff : Long_Float;
      K : Long_Float;
   begin
      Eff := 1.0 / (1.0 + Long_Float'Max (0.0, S.Cities - 5.0) * 0.06);
      S.Tech := Long_Float'Min (NT, S.Tech + S.Labs * 10.0 * Eff / (20.0 + 17.0 * S.Tech));
      case Plan is
         when 0 =>
            S.Cities := S.Cities + (if S.Cities < 14.0 then 1.4 else 0.4);
            S.Pop := S.Pop + 3.0;
            S.Prod := S.Prod * 1.06;
         when 1 =>
            S.Prod := S.Prod * 1.12;
            S.Labs := S.Labs * 1.2;
            S.Pop := S.Pop + 2.0;
         when 2 =>
            S.Mil := S.Mil + S.Prod * 10.0 / 30.0 * 3.2;
         when 3 =>
            if S.Tech >= NT - 0.5 then
               S.Prog := Long_Float'Min (1.0, S.Prog
                 + (S.Prod * 10.0 + S.Cr * 0.5) / 1200.0 * 0.55
                 * (if S.Cities >= 5.0 then 1.0 else 0.3));
            else
               S.Tech := Long_Float'Min (NT, S.Tech + S.Labs * 4.0 / (20.0 + 17.0 * S.Tech));
            end if;
            S.Cr := S.Cr * 0.5;
         when others =>
            if S.Mil > O.Mil * 1.15 then
               K := Long_Float'Min (O.Cities, 1.0 + Long_Float'Floor (S.Mil / (O.Mil + 1.0) / 3.0));
               O.Cities := O.Cities - K;
               S.Cities := S.Cities + K * 0.6;
               O.Prog := O.Prog * 0.5;
               O.Prod := O.Prod * 0.8;
               S.Mil := S.Mil * 0.7;
               O.Mil := O.Mil * 0.55;
            else
               S.Mil := S.Mil * 0.6;
               O.Mil := O.Mil * 0.85;
            end if;
      end case;
      S.Prog := Long_Float'Max (S.Prog, Long_Float'Min (0.35, S.Tech / NT * 0.35));
   end Abs_Apply;

   function Abs_Eval (Me, Op : Abs_Rec) return Long_Float is
      V : Long_Float;
   begin
      V := Me.Prog * 120.0 + Me.Cities * 3.0 + Me.Tech * 2.0 + Me.Mil * 0.35 + Me.Pop * 0.3
        - (Op.Prog * 130.0 + Op.Cities * 2.5 + Op.Tech * 1.5 + Op.Mil * 0.3);
      if Op.Prog >= 0.8 and then Me.Prog < Op.Prog then
         V := V - 150.0;
      end if;
      if Me.Cities <= 0.0 then
         V := V - 500.0;
      end if;
      return V;
   end Abs_Eval;

   function Mini (Me, Op : Abs_Rec; Depth : Natural; Max_Turn : Boolean;
                  Alpha, Beta : Long_Float) return Long_Float;
   function Mini_Plan (Me, Op : Abs_Rec) return Integer;

   function Mini (Me, Op : Abs_Rec; Depth : Natural; Max_Turn : Boolean;
                  Alpha, Beta : Long_Float) return Long_Float
   is
      Best : Long_Float;
      A : Long_Float := Alpha;
      B : Long_Float := Beta;
      NM, NO : Abs_Rec;
      V : Long_Float;
   begin
      if Depth = 0 then
         return Abs_Eval (Me, Op);
      end if;
      Best := (if Max_Turn then -1.0e30 else 1.0e30);
      for P in 0 .. 4 loop
         NM := Me;
         NO := Op;
         if Max_Turn then
            Abs_Apply (NM, NO, P);
         else
            Abs_Apply (NO, NM, P);
         end if;
         V := Mini (NM, NO, Depth - 1, not Max_Turn, A, B);
         if Max_Turn then
            if V > Best then
               Best := V;
            end if;
            if V > A then
               A := V;
            end if;
         else
            if V < Best then
               Best := V;
            end if;
            if V < B then
               B := V;
            end if;
         end if;
         exit when B <= A;
      end loop;
      return Best;
   end Mini;

   function Mini_Plan (Me, Op : Abs_Rec) return Integer is
      Best_P : Integer := 0;
      Best_V : Long_Float := -1.0e30;
      A : Long_Float := -1.0e30;
      B : constant Long_Float := 1.0e30;
      NM, NO : Abs_Rec;
      V : Long_Float;
   begin
      for P in 0 .. 4 loop
         NM := Me;
         NO := Op;
         Abs_Apply (NM, NO, P);
         V := Mini (NM, NO, 2, False, A, B);
         if V > Best_V then
            Best_V := V;
            Best_P := P;
         end if;
         if V > A then
            A := V;
         end if;
         exit when B <= A;
      end loop;
      return Best_P;
   end Mini_Plan;

   function Abs_Of (Fid : Integer) return Abs_Rec is
      S : Abs_Rec;
      N, Mi, En : Integer;
   begin
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac = Fid then
            City_Base (C, N, Mi, En);
            S.Prod := S.Prod + Long_Float (Mi);
            S.Labs := S.Labs + Long_Float (En);
            S.Pop := S.Pop + Long_Float (Cities (C).Pop);
            S.Cities := S.Cities + 1.0;
         end if;
      end loop;
      S.Labs := S.Labs * Factions (Fid).Labs + 1.0;
      S.Mil := Mil_Power (Fid);
      S.Tech := Long_Float (Factions (Fid).Tech_N);
      S.Prog := Victory_Progress (Fid);
      S.Cr := Long_Float (Factions (Fid).Credits);
      return S;
   end Abs_Of;

   procedure Plan_Faction (Fid : Integer) is
      Opp, Plan, BI : Integer;
      BV, V : Long_Float;
      Me, Op : Abs_Rec;
   begin
      if Fid < 0 or else not Factions (Fid).Alive then
         return;
      end if;
      Opp := -1;
      BV := -1.0;
      for R in 0 .. Fac_N - 1 loop
         if R /= Fid and then Factions (R).Alive then
            V := Victory_Progress (R) * 100.0 + Long_Float (Score_Of (R)) * 0.2;
            if Opp < 0 or else V > BV then
               BV := V;
               Opp := R;
            end if;
         end if;
      end loop;
      if Opp < 0 then
         return;
      end if;
      Me := Abs_Of (Fid);
      Op := Abs_Of (Opp);
      Plan := Mini_Plan (Me, Op);
      if Turn_N < 25 and then Me.Cities < 4.0 and then Plan /= 4 then
         Plan := 0;
      end if;
      if Plan = 4 and then Turn_N < Grace and then not Asc_On then
         Plan := 2;
      end if;
      if Asc_On and then Asc_Fac /= Fid and then Me.Mil > 0.0 then
         Plan := 4;
      end if;
      if Plan = 4 and then not At_War (Fid, Opp) then
         if Wants_Break (Fid, Opp) then
            declare
               Why : constant String := Declare_War (Fid, Opp);
            begin
               if Why /= "" then
                  Log ("T" & Img (Turn_N) & " strike not opened");
               end if;
            end;
         else
            BI := -1;
            BV := -1.0;
            for R in 0 .. Fac_N - 1 loop
               if R /= Fid and then Factions (R).Alive and then At_War (Fid, R) then
                  V := Victory_Progress (R) * 100.0 + Long_Float (Score_Of (R)) * 0.2;
                  if BI < 0 or else V > BV then
                     BV := V;
                     BI := R;
                  end if;
               end if;
            end loop;
            if BI >= 0 then
               Opp := BI;
            else
               Plan := 2;
            end if;
         end if;
      end if;
      if Plan = 4 then
         War_Target (Fid) := Opp;
         War_City (Fid) := -1;
         if Asc_On and then Asc_Fac = Opp then
            War_City (Fid) := -1;
            for C in 0 .. City_N - 1 loop
               if Cities (C).Id = Asc_City then
                  War_City (Fid) := Cities (C).Loc;
               end if;
            end loop;
         end if;
      else
         War_Target (Fid) := -1;
         War_City (Fid) := -1;
      end if;
      Factions (Fid).Plan := Plan;
   end Plan_Faction;

   function Mil_Power (Fid : Integer) return Long_Float is
      M : Long_Float := 0.0;
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac = Fid and then not U_Civ (Units (U).Kind) then
            M := M + Long_Float (U_Atk (Units (U).Kind) + U_Def (Units (U).Kind))
              * Long_Float (Units (U).HP) / 10.0;
         end if;
      end loop;
      return M;
   end Mil_Power;

   function Known_Owner (Fid, Cidx : Integer) return Integer is
   begin
      if Cidx < 0 or else Cidx >= City_N then
         return -1;
      end if;
      if Cities (Cidx).Fac = Fid then
         return Fid;
      end if;
      if Fid < 0 or else (Fid < Fac_N and then Factions (Fid).Vis (Cities (Cidx).Loc)) then
         return Cities (Cidx).Fac;
      end if;
      if Fid in 0 .. 3 then
         for I in CMem'Range (2) loop
            if CMem (Fid, I).Live and then CMem (Fid, I).Id = Cities (Cidx).Id then
               return CMem (Fid, I).Fac;
            end if;
         end loop;
      end if;
      return -1;
   end Known_Owner;

   function Known_Mil (A, B : Integer) return Long_Float is
      M : Long_Float := 0.0;
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac = B and then not U_Civ (Units (U).Kind)
           and then (A < 0 or else (A < Fac_N and then Factions (A).Vis (Units (U).Loc)))
         then
            M := M + Long_Float (U_Atk (Units (U).Kind) + U_Def (Units (U).Kind))
              * Long_Float (Units (U).HP) / 10.0;
         end if;
      end loop;
      if A in 0 .. 3 then
         for I in Ghosts'Range (2) loop
            if Ghosts (A, I).Live and then Ghosts (A, I).Fac = B then
               declare
                  K : constant Unit_Kind := Unit_Kind'Val (Ghosts (A, I).Kind);
                  Fresh : Boolean := False;
               begin
                  if not U_Civ (K) then
                     for U in 0 .. Unit_N - 1 loop
                        if Units (U).Id = Ghosts (A, I).Id and then Units (U).Fac = B
                          and then not U_Civ (Units (U).Kind)
                          and then Factions (A).Vis (Units (U).Loc)
                        then
                           Fresh := True;
                        end if;
                     end loop;
                     if not Fresh then
                        M := M + Long_Float (U_Atk (K) + U_Def (K)) * 0.9;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end if;
      for C in 0 .. City_N - 1 loop
         if Cities (C).Fac /= A and then Known_Owner (A, C) = B then
            M := M + 3.0;
         end if;
      end loop;
      return M;
   end Known_Mil;

   function Strength_Of (A, B : Integer) return Long_Float is
     ((Mil_Power (A) + 5.0) / (Known_Mil (A, B) + 5.0));

   function Fungus_Friendly (Fid : Integer) return Long_Float is
      Base : Long_Float;
   begin
      if Fid in 0 .. 3 and then Slot_Key (Fid) = 2 then
         Base := 20.0;
      else
         Base := 10.0;
         if Fid in 0 .. 3 then
            Base := Long_Float (10 - Fung_Cut (Fid));
         end if;
         if Base < -10.0 then
            Base := -10.0;
         end if;
      end if;
      if Fid in 0 .. Fac_N - 1 then
         Base := Base + Policy (Fid).Fung_Rel;
      end if;
      return Base;
   end Fungus_Friendly;

   function Deal_OK (From, To, Kind : Integer; Buy, Energy : Boolean; Amt, Price : Integer) return String is
      R : Rel_Kind;
      Held : Integer;
      pragma Unreferenced (Energy);
   begin
      if From = To or else To not in 0 .. Fac_N - 1 or else From not in 0 .. Fac_N - 1
        or else not Factions (To).Alive or else not Factions (From).Alive
      then
         return "No such faction";
      end if;
      if not Contact (From, To) then
         return "No contact yet";
      end if;
      R := Rel (From, To);
      Held := Turn_N - Since (From, To);
      case Kind is
         when 0 =>
            if R /= Rel_War then
               return "Not at war";
            end if;
         when 1 =>
            if R /= Rel_Cease then
               return "Needs a ceasefire first";
            end if;
            if Held < 3 then
               return "Ceasefire must hold 3 turns first";
            end if;
         when 2 =>
            if R /= Rel_Peace then
               return "Needs a peace treaty first";
            end if;
            if Held < 8 then
               return "Peace must hold 8 turns first";
            end if;
         when 3 =>
            if R = Rel_Ally then
               return "Allies already share passage";
            end if;
            if R /= Rel_Peace then
               return "Needs a peace treaty first";
            end if;
            if Open_B (From, To) then
               return "Borders already open";
            end if;
         when 4 =>
            if R = Rel_War then
               return "Cannot trade while at war";
            end if;
            if Amt < 1 or else Amt > 6 or else Price < 0 or else Price > 500 then
               return "Bad trade terms";
            end if;
            for I in Contracts'Range loop
               if Contracts (I).Live
                 and then ((Contracts (I).Seller = From and then Contracts (I).Buyer = To)
                           or else (Contracts (I).Seller = To and then Contracts (I).Buyer = From))
               then
                  return "A trade contract is already running";
               end if;
            end loop;
            declare
               Buyer : constant Integer := (if Buy then From else To);
            begin
               if Factions (Buyer).Credits < Price then
                  return "Lacks credits";
               end if;
            end;
         when others =>
            return "Unknown deal";
      end case;
      return "";
   end Deal_OK;

   function Common_Enemy (Me, Other : Integer) return Boolean is
   begin
      for X in 0 .. Fac_N - 1 loop
         if X /= Me and then X /= Other and then Factions (X).Alive
           and then Rel (Me, X) = Rel_War and then Rel (Other, X) = Rel_War
         then
            return True;
         end if;
      end loop;
      return False;
   end Common_Enemy;

   function Has_Ally (Me : Integer) return Boolean is
   begin
      for X in 0 .. Fac_N - 1 loop
         if X /= Me and then Factions (X).Alive and then Rel (Me, X) = Rel_Ally then
            return True;
         end if;
      end loop;
      return False;
   end Has_Ally;

   function Consider (Me, Other, Kind : Integer; Buy, Energy : Boolean; Amt, Price : Integer) return Boolean is
      Pers : constant Integer := Slot_Key (Me);
      SR : constant Long_Float := Strength_Of (Me, Other);
      Prox : Long_Float := Victory_Progress (Other);
      Losing : constant Boolean := SR < 0.7;
      FF : Long_Float := 0.0;
      Rep : constant Integer := Rep_V (Other);
      Locked : constant Boolean := Lock_Until (Other) > Turn_N;
      Held : constant Integer := Turn_N - Since (Me, Other);
   begin
      if Rule (2)
        and then Long_Float (Factions (Other).Credits)
          >= Long_Float (Econ_Target) * (if Pers = 2 then 0.55 else 0.35)
      then
         if Prox < 0.65 then
            Prox := 0.65;
         end if;
      end if;
      if Pers = 2 then
         FF := Fungus_Friendly (Other);
      end if;
      case Kind is
         when 0 =>
            if Pers = 0 then
               return Losing;
            end if;
            if Prox > 0.6 and then not Losing then
               return False;
            end if;
            if Rep < 20 and then not Losing then
               return False;
            end if;
            if Pers = 1 and then SR > 1.8 and then Me in 0 .. 3 and then War_Target (Me) = Other then
               return False;
            end if;
            if Pers = 3 and then SR > 1.5 then
               return False;
            end if;
            return True;
         when 1 =>
            if Locked and then not Losing then
               return False;
            end if;
            if Prox > 0.6 then
               return False;
            end if;
            if Pers = 0 then
               return Losing and then Rep >= 30;
            end if;
            return Long_Float (Rep) + FF >= (if Pers = 2 then 35.0 else 40.0);
         when 2 =>
            if Locked or else Prox > 0.5 or else Has_Ally (Me) then
               return False;
            end if;
            if Pers = 0 then
               return Common_Enemy (Me, Other) and then Rep >= 65;
            end if;
            if Pers = 2 then
               return Long_Float (Rep) + FF >= 55.0
                 and then (Common_Enemy (Me, Other) or else Held >= 15);
            end if;
            return Common_Enemy (Me, Other) and then Rep >= 60;
         when 3 =>
            if Locked or else Pers = 0 then
               return False;
            end if;
            if Pers = 2 then
               return Long_Float (Rep) + FF >= 45.0;
            end if;
            if Pers = 1 then
               return Rep >= 55;
            end if;
            return Rep >= 60;
         when 4 =>
            declare
               Tot : constant Integer := Amt * 10;
               Buyer_Is_Me : constant Boolean := not Buy;
               Rich : constant Boolean :=
                 Factions (Other).Credits >= (Econ_Target * 2) / 5
                 or else Factions (Me).Credits >= (Econ_Target * 2) / 5;
            begin
               if Locked or else Rich then
                  return False;
               end if;
               if not Buyer_Is_Me then
                  declare
                     Want : Integer;
                  begin
                     if Prox > 0.6 then
                        return False;
                     end if;
                     declare
                        Mult : Long_Float := 1.0;
                     begin
                        if Pers = 3 then
                           Mult := 0.75;
                        elsif Pers = 0 then
                           Mult := 1.15;
                        elsif Pers = 2 then
                           Mult := 0.95;
                        elsif Energy then
                           Mult := 1.3;
                        end if;
                        Want := JS_Round (Long_Float (Tot) * 1.5 * Mult);
                     end;
                     return Price >= Want;
                  end;
               end if;
               if Rep < 40 or else Factions (Me).Credits < Price then
                  return False;
               end if;
               declare
                  Val : Long_Float := Long_Float (Tot);
               begin
                  if Energy then
                     Val := Val * (if Pers = 1 then 2.2 elsif Pers = 3 then 1.3 else 1.5);
                  else
                     Val := Val * (if Pers = 0 then 1.9 else 1.5);
                  end if;
                  return Long_Float (Price) <= Val;
               end;
            end;
         when others =>
            return False;
      end case;
   end Consider;

   procedure Apply_Deal (From, To, Kind : Integer; Buy, Energy : Boolean; Amt, Price : Integer) is
      Buyer, Seller : Integer;
   begin
      if Kind = 0 then
         Set_Rel (From, To, Rel_Cease);
      elsif Kind = 1 then
         if Rel (From, To) = Rel_Cease then
            Rep_V (From) := Integer'Min (100, Rep_V (From) + 2);
            Rep_V (To) := Integer'Min (100, Rep_V (To) + 2);
         end if;
         Set_Rel (From, To, Rel_Peace);
      elsif Kind = 2 then
         Set_Rel (From, To, Rel_Ally);
      elsif Kind = 3 then
         Open_B (From, To) := True;
         Open_B (To, From) := True;
      elsif Kind = 4 then
         Buyer := (if Buy then From else To);
         Seller := (if Buy then To else From);
         Factions (Buyer).Credits := Factions (Buyer).Credits - Price;
         Factions (Seller).Credits := Factions (Seller).Credits + Price;
         for I in Contracts'Range loop
            if not Contracts (I).Live then
               Contracts (I) := (Live => True, Energy => Energy, Seller => Seller, Buyer => Buyer,
                                 Amt => Amt, Left => 10, Price => Price);
               exit;
            end if;
         end loop;
      end if;
      Log ("T" & Img (Turn_N) & " deal " & Img (Kind) & " between " & Img (From) & " and " & Img (To));
   end Apply_Deal;

   function Propose (From, To, Packed : Integer) return Boolean is
      Kind : constant Integer := Packed mod 8;
      Amt : constant Integer := (Packed / 8) mod 16;
      Price : constant Integer := (Packed / 128) mod 4096;
      Buy : constant Boolean := (Packed / 524288) mod 2 = 1;
      Energy : constant Boolean := (Packed / 1048576) mod 2 = 1;
      Why : constant String := Deal_OK (From, To, Kind, Buy, Energy, Amt, Price);
   begin
      if Why /= "" then
         Set_Error (Why);
         return False;
      end if;
      if not Factions (To).AI then
         for I in Pending'Range loop
            if not Pending (I).Live then
               Pending (I) := (Live => True, Buy => Buy, Energy => Energy, Id => Next_Offer,
                               From => From, To => To, Kind => Kind, Amt => Amt, Price => Price,
                               Turn => Turn_N);
               Next_Offer := Next_Offer + 1;
               exit;
            end if;
         end loop;
         Log ("T" & Img (Turn_N) & " offer sent");
         return True;
      end if;
      if Consider (To, From, Kind, Buy, Energy, Amt, Price) then
         Apply_Deal (From, To, Kind, Buy, Energy, Amt, Price);
         Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (To)) & " accepts");
      else
         Log ("T" & Img (Turn_N) & " " & Colony_Names.Faction_Name (Slot_Key (To)) & " declines");
      end if;
      return True;
   end Propose;

   function Answer_Offer (Fid, Id : Integer; Take : Boolean) return Boolean is
   begin
      for I in Pending'Range loop
         if Pending (I).Live and then Pending (I).Id = Id and then Pending (I).To = Fid then
            if Take then
               declare
                  Why : constant String :=
                    Deal_OK (Pending (I).From, Pending (I).To, Pending (I).Kind,
                             Pending (I).Buy, Pending (I).Energy, Pending (I).Amt, Pending (I).Price);
               begin
                  if Why /= "" then
                     Set_Error (Why);
                     Pending (I).Live := False;
                     return False;
                  end if;
               end;
               Apply_Deal (Pending (I).From, Pending (I).To, Pending (I).Kind,
                           Pending (I).Buy, Pending (I).Energy, Pending (I).Amt, Pending (I).Price);
            end if;
            Pending (I).Live := False;
            return True;
         end if;
      end loop;
      Set_Error ("No such offer");
      return False;
   end Answer_Offer;

   function Offer_Waiting (From, To : Integer) return Boolean is
   begin
      for I in Pending'Range loop
         if Pending (I).Live and then Pending (I).From = From and then Pending (I).To = To then
            return True;
         end if;
      end loop;
      return False;
   end Offer_Waiting;

   procedure AI_Diplomacy (Fid : Integer) is
      Pers : constant Integer := Slot_Key (Fid);
      Deal, Sent : Integer;
      function Kind_Of (Packed : Integer) return Integer is (Packed mod 8);
   begin
      if (Turn_N + Fid) mod 2 /= 0 then
         return;
      end if;
      Sent := 0;
      for J in 0 .. Fac_N - 1 loop
         exit when Sent >= 2;
         if J /= Fid and then Factions (J).Alive and then Contact (Fid, J)
           and then not Offer_Waiting (Fid, J)
         then
            Deal := -1;
            if Rel (Fid, J) = Rel_War and then Turn_N >= 8 and then Turn_N - Since (Fid, J) >= 3
              and then Victory_Progress (J) <= 0.6
            then
               if Pers = 2
                 or else (Pers = 1 and then not (Strength_Of (Fid, J) > 1.8 and then War_Target (Fid) = J))
                 or else (Pers = 3 and then Strength_Of (Fid, J) < 1.3)
                 or else (Pers = 0 and then Strength_Of (Fid, J) < 0.7)
               then
                  if Pers = 0 or else Rep_V (J) >= 20 then
                     Deal := 0;
                  end if;
               end if;
            elsif Rel (Fid, J) = Rel_Cease and then Turn_N - Since (Fid, J) >= 4
              and then Rep_V (J) >= 40 and then Victory_Progress (J) < 0.6
              and then (Pers /= 0 or else Strength_Of (Fid, J) < 0.7)
            then
               Deal := 1;
            elsif Rel (Fid, J) = Rel_Peace and then Turn_N - Since (Fid, J) >= 8
              and then Lock_Until (J) <= Turn_N and then Victory_Progress (J) < 0.5
              and then not Has_Ally (Fid)
              and then ((Common_Enemy (Fid, J) and then Rep_V (J) >= 60
                         and then (Pers /= 0 or else Rep_V (J) >= 65))
                        or else (Pers = 2 and then Long_Float (Rep_V (J)) + Fungus_Friendly (J) >= 55.0
                                 and then Turn_N - Since (Fid, J) >= 15))
            then
               Deal := 2;
            elsif Rel (Fid, J) = Rel_Peace and then not Open_B (Fid, J)
              and then (Pers = 2 or else Pers = 1) and then Rep_V (J) >= 50
              and then Turn_N - Since (Fid, J) >= 2
            then
               Deal := 3;
            end if;
            if Deal < 0 and then Rel (Fid, J) /= Rel_War and then Lock_Until (J) <= Turn_N
              and then Rep_V (J) >= 40
              and then Factions (Fid).Credits < (Econ_Target * 2) / 5
              and then Factions (J).Credits < (Econ_Target * 2) / 5
              and then (Turn_N + J) mod 6 < 2
            then
               if Pers = 1 and then Factions (Fid).Credits >= 70 then
                  Deal := 4 + (3 * 8) + (48 * 128) + 524288 + 1048576;
               elsif Pers = 3 and then Factions (J).Credits >= 60 and then Victory_Progress (J) < 0.6 then
                  Deal := 4 + (2 * 8) + (23 * 128);
               elsif Pers = 0 and then Factions (Fid).Credits >= 80
                 and then Has_Tech (Fid, Tech_Kind'Pos (Kinetic))
               then
                  Deal := 4 + (3 * 8) + (45 * 128) + 524288;
               end if;
            end if;
            if Deal >= 0 and then Turn_N - Ask (Fid, J, Kind_Of (Deal)) >= 6
              and then Deal_OK (Fid, J, Kind_Of (Deal), (Deal / 524288) mod 2 = 1,
                                (Deal / 1048576) mod 2 = 1, (Deal / 8) mod 16,
                                (Deal / 128) mod 4096) = ""
            then
               Ask (Fid, J, Kind_Of (Deal)) := Turn_N;
               if Propose (Fid, J, Deal) then
                  Sent := Sent + 1;
               end if;
            end if;
         end if;
      end loop;
   end AI_Diplomacy;

   procedure Diplo_Turn is
   begin
      for A in 0 .. Fac_N - 1 loop
         if Factions (A).Alive then
            for B in A + 1 .. Fac_N - 1 loop
               if Factions (B).Alive and then not Contact (A, B) then
                  declare
                     Seen : Boolean := False;
                  begin
                     for C in 0 .. City_N - 1 loop
                        if (Cities (C).Fac = B and then Factions (A).Vis (Cities (C).Loc))
                          or else (Cities (C).Fac = A and then Factions (B).Vis (Cities (C).Loc))
                        then
                           Seen := True;
                        end if;
                     end loop;
                     for U in 0 .. Unit_N - 1 loop
                        if (Units (U).Fac = B and then Factions (A).Vis (Units (U).Loc))
                          or else (Units (U).Fac = A and then Factions (B).Vis (Units (U).Loc))
                        then
                           Seen := True;
                        end if;
                     end loop;
                     if Seen then
                        Contact (A, B) := True;
                        Contact (B, A) := True;
                        Log ("T" & Img (Turn_N) & " contact");
                     end if;
                  end;
               end if;
               if Rel (A, B) = Rel_Cease and then Turn_N - Since (A, B) >= 15 then
                  Set_Rel (A, B, Rel_War);
                  Log ("T" & Img (Turn_N) & " ceasefire expired");
               end if;
            end loop;
         end if;
      end loop;
      for I in Contracts'Range loop
         if Contracts (I).Live then
            if not Factions (Contracts (I).Seller).Alive or else not Factions (Contracts (I).Buyer).Alive then
               Contracts (I).Live := False;
            else
               if Contracts (I).Energy then
                  declare
                     G : constant Integer :=
                       Integer'Min (Contracts (I).Amt, Integer'Max (0, Factions (Contracts (I).Seller).RP));
                  begin
                     Factions (Contracts (I).Seller).RP := Factions (Contracts (I).Seller).RP - G;
                     Factions (Contracts (I).Buyer).RP := Factions (Contracts (I).Buyer).RP + Contracts (I).Amt;
                  end;
               else
                  for C in 0 .. City_N - 1 loop
                     if Cities (C).Fac = Contracts (I).Seller and then Cities (C).Capital then
                        Cities (C).Prod := Integer'Max (0, Cities (C).Prod - Contracts (I).Amt);
                     elsif Cities (C).Fac = Contracts (I).Buyer and then Cities (C).Capital then
                        Cities (C).Prod := Cities (C).Prod + Contracts (I).Amt;
                     end if;
                  end loop;
               end if;
               Contracts (I).Left := Contracts (I).Left - 1;
               if Contracts (I).Left <= 0 then
                  Rep_V (Contracts (I).Seller) := Integer'Min (100, Rep_V (Contracts (I).Seller) + 1);
                  Contracts (I).Live := False;
                  Log ("T" & Img (Turn_N) & " trade contract honoured");
               end if;
            end if;
         end if;
      end loop;
      for I in Pending'Range loop
         if Pending (I).Live and then Turn_N - Pending (I).Turn >= 1 then
            Pending (I).Live := False;
            Log ("T" & Img (Turn_N) & " offer expired");
         end if;
      end loop;
   end Diplo_Turn;

   function Hostile_Near (Tile, Fid : Integer) return Integer is
   begin
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac >= 0 and then Units (U).Fac /= Fid and then U_Atk (Units (U).Kind) > 0
           and then At_War (Fid, Units (U).Fac) and then Dist (Units (U).Loc, Tile) <= 1
           and then (Fid < 0 or else Factions (Fid).Vis (Units (U).Loc))
         then
            return U;
         end if;
      end loop;
      return -1;
   end Hostile_Near;

   procedure Supply_Turn is
      Sup : array (0 .. 3, 0 .. Max_Tiles - 1) of Boolean := (others => (others => False));
      Host : array (0 .. Max_Tiles - 1) of Boolean := (others => False);
      Nb : Nbr_Arr;
      NN : Natural;
      Q : array (0 .. Max_Tiles - 1) of Integer;
      Qh, Qt, Cap_A, Cap_F : Integer;
   begin
      for F in 0 .. Fac_N - 1 loop
         Host := (others => False);
         for U in 0 .. Unit_N - 1 loop
            if Units (U).Fac >= 0 and then Units (U).Fac /= F and then U_Atk (Units (U).Kind) > 0 then
               Host (Units (U).Loc) := True;
               Nbrs (Units (U).Loc, 1, NN, Nb);
               for K in 0 .. NN - 1 loop
                  Host (Nb (K)) := True;
               end loop;
            end if;
         end loop;
         Qt := 0;
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Tun = F and then not Tiles (I).Flooded then
               declare
                  C : constant Integer := City_At (I);
                  Ent : Boolean := C >= 0 and then Cities (C).Fac = F;
               begin
                  if not Ent then
                     for O in 0 .. City_N - 1 loop
                        if Cities (O).Fac = F and then not Cities (O).UG and then Dist (Cities (O).Loc, I) <= 1 then
                           Ent := True;
                        end if;
                     end loop;
                  end if;
                  if Ent and then not Host (I) then
                     Sup (F, I) := True;
                     Q (Qt) := I;
                     Qt := Qt + 1;
                  end if;
               end;
            end if;
         end loop;
         Qh := 0;
         while Qh < Qt loop
            Nbrs (Q (Qh), 1, NN, Nb);
            Qh := Qh + 1;
            for K in 0 .. NN - 1 loop
               if not Sup (F, Nb (K)) and then Tiles (Nb (K)).Tun = F and then not Tiles (Nb (K)).Flooded then
                  Sup (F, Nb (K)) := True;
                  Q (Qt) := Nb (K);
                  Qt := Qt + 1;
               end if;
            end loop;
         end loop;
      end loop;
      declare
         C : Integer := 0;
         Dropped : Boolean;
         procedure Clear_Holders (Loc, Fid : Integer) is
            U : Integer := 0;
         begin
            while U < Unit_N loop
               if Units (U).Loc = Loc and then Units (U).Fac = Fid then
                  Remove_Unit (U);
               else
                  U := U + 1;
               end if;
            end loop;
         end Clear_Holders;
      begin
      while C < City_N loop
         Dropped := False;
         if Cities (C).UG then
            Cap_A := 3 + (if City_Has (C, Scrub) then 2 else 0);
            Cap_F := (if City_Has (C, Hydro) then 16 else 8);
            if not Cities (C).Res_Set then
               Cities (C).Air := Cap_A;
               Cities (C).Food_R := Cap_F;
               Cities (C).Pow := 6;
               Cities (C).Res_Set := True;
            end if;
            if Sup (Cities (C).Fac, Cities (C).Loc) then
               Cities (C).Air := Integer'Min (Cap_A, Cities (C).Air + 2);
               Cities (C).Food_R := Integer'Min (Cap_F, Cities (C).Food_R + 2);
               Cities (C).Pow := Integer'Min (6, Cities (C).Pow + 2);
               Cities (C).Cut := 0;
               Cities (C).Air_Out := 0;
               if Cities (C).Air > 1 and then Cities (C).Food_R > 1 and then Cities (C).Pow > 1 then
                  Cities (C).Low := 0;
               end if;
            else
               if Cities (C).Cut = 0 then
                  Cities (C).Cut := 1;
                  Log ("T" & Img (Turn_N) & " supply cut at " & Name_Of (Cities (C)));
               end if;
               if City_Has (C, Scrub) then
                  if Turn_N mod 2 = 1 then
                     Cities (C).Air := Integer'Max (0, Cities (C).Air - 1);
                  end if;
               else
                  Cities (C).Air := Integer'Max (0, Cities (C).Air - 1);
               end if;
               if City_Has (C, Hydro) then
                  if Turn_N mod 2 = 1 then
                     Cities (C).Food_R := Integer'Max (0, Cities (C).Food_R - 1);
                  end if;
               else
                  Cities (C).Food_R := Integer'Max (0, Cities (C).Food_R - 1);
               end if;
               Cities (C).Pow := Integer'Max (0, Cities (C).Pow - 1);
               if Cities (C).Air <= 1 or else Cities (C).Food_R <= 1 or else Cities (C).Pow <= 1 then
                  Cities (C).Low := 1;
               end if;
               if Cities (C).Air = 0 then
                  Cities (C).Air_Out := Cities (C).Air_Out + 1;
                  if Cities (C).Pop > 1 and then Cities (C).Air_Out < 2 then
                     Cities (C).Pop := Cities (C).Pop - 1;
                  end if;
                  declare
                     U : Integer := 0;
                  begin
                     while U < Unit_N loop
                        if Units (U).Loc = Cities (C).Loc and then Units (U).Fac = Cities (C).Fac then
                           Units (U).HP := Units (U).HP - 2;
                           Units (U).No_Heal := True;
                           if Units (U).HP <= 0 then
                              Remove_Unit (U);
                           else
                              U := U + 1;
                           end if;
                        else
                           U := U + 1;
                        end if;
                     end loop;
                  end;
               elsif Cities (C).Food_R = 0 and then Turn_N mod 2 = 0 and then Cities (C).Pop > 1 then
                  Cities (C).Pop := Cities (C).Pop - 1;
               end if;
               if Cities (C).Pop < 1 or else Cities (C).Air_Out >= 2 then
                  declare
                     B : constant Integer := Hostile_Near (Cities (C).Loc, Cities (C).Fac);
                     Old : constant Integer := Cities (C).Fac;
                  begin
                     Clear_Holders (Cities (C).Loc, Old);
                     if B >= 0 and then Cities (C).Pop >= 1 then
                        Cities (C).Fac := Units (B).Fac;
                        Cities (C).Capital := False;
                        Cities (C).Q_Len := 0;
                        Cities (C).Prod := 0;
                        Cities (C).Cut := 0;
                        Cities (C).Low := 0;
                        Cities (C).Air_Out := 0;
                        Cities (C).Air := Cap_A;
                        Cities (C).Food_R := Cap_F;
                        Cities (C).Pow := 6;
                        Log ("T" & Img (Turn_N) & " warren surrendered");
                        Fix_Capital (Old);
                     else
                        Log ("T" & Img (Turn_N) & " warren abandoned");
                        Remove_City (C);
                        Dropped := True;
                     end if;
                  end;
               end if;
            end if;
         end if;
         if not Dropped then
            C := C + 1;
         end if;
      end loop;
      end;
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Fac >= 0 and then Tiles (Units (U).Loc).Tun = Units (U).Fac then
            declare
               C : constant Integer := City_At (Units (U).Loc);
            begin
               if not (C >= 0 and then not Cities (C).UG)
                 and then not Sup (Units (U).Fac, Units (U).Loc)
               then
                  Units (U).No_Heal := True;
                  if not (C >= 0 and then Cities (C).UG) then
                     Units (U).HP := Integer'Max (1, Units (U).HP - 1);
                  end if;
               end if;
            end;
         end if;
      end loop;
   end Supply_Turn;

   function Collapse_Tunnel (Fid, Tile : Integer) return String is
      Hit : Integer := 0;
   begin
      if Tile < 0 or else Tile >= NTiles or else Tiles (Tile).Tun /= Fid then
         Set_Error ("Not your tunnel");
         return "Not your tunnel";
      end if;
      if City_At (Tile) >= 0 then
         Set_Error ("Cannot collapse a base or city tile");
         return "Cannot collapse a base or city tile";
      end if;
      for U in 0 .. Unit_N - 1 loop
         if Units (U).Loc = Tile and then Units (U).Fac = Fid then
            Set_Error ("Your own units are in that tunnel");
            return "Your own units are in that tunnel";
         end if;
      end loop;
      declare
         Near : Boolean := False;
      begin
         for U in 0 .. Unit_N - 1 loop
            if Units (U).Fac = Fid and then Dist (Units (U).Loc, Tile) <= 2 then
               Near := True;
            end if;
         end loop;
         for C in 0 .. City_N - 1 loop
            if Cities (C).Fac = Fid and then Dist (Cities (C).Loc, Tile) <= 3 then
               Near := True;
            end if;
         end loop;
         if not Near then
            Set_Error ("No engineers nearby");
            return "No engineers nearby";
         end if;
      end;
      Tiles (Tile).Tun := -1;
      Tiles (Tile).Flooded := False;
      Tiles (Tile).Collapsed := True;
      declare
         U : Integer := 0;
      begin
         while U < Unit_N loop
            if Units (U).Loc = Tile then
               Units (U).HP := Units (U).HP - 5;
               Hit := Hit + 1;
               if Units (U).HP <= 0 then
                  Remove_Unit (U);
               else
                  U := U + 1;
               end if;
            else
               U := U + 1;
            end if;
         end loop;
      end;
      Log ("T" & Img (Turn_N) & " tunnel collapsed");
      return "";
   end Collapse_Tunnel;

   procedure AI_Collapse (Fid : Integer) is
      Nb, Near : Nbr_Arr;
      NN, KN : Natural;
      Own, Here, Breach : Boolean;
   begin
      for W in 0 .. City_N - 1 loop
         if Cities (W).Fac = Fid and then Cities (W).UG then
            Nbrs (Cities (W).Loc, 2, NN, Nb);
            for K in 0 .. NN - 1 loop
               if Tiles (Nb (K)).Tun = Fid and then City_At (Nb (K)) < 0 then
                  Own := False;
                  Here := False;
                  for U in 0 .. Unit_N - 1 loop
                     if Units (U).Loc = Nb (K) then
                        if Units (U).Fac = Fid then
                           Own := True;
                        elsif Units (U).Fac >= 0 then
                           Here := True;
                        end if;
                     end if;
                  end loop;
                  Breach := False;
                  if not Own then
                     Nbrs (Nb (K), 1, KN, Near);
                     for P in 0 .. KN - 1 loop
                        if Tiles (Near (P)).Tun >= 0 and then Tiles (Near (P)).Tun /= Fid then
                           for U in 0 .. Unit_N - 1 loop
                              if Units (U).Loc = Near (P) and then Units (U).Fac >= 0
                                and then Units (U).Fac /= Fid and then U_Atk (Units (U).Kind) > 0
                              then
                                 Breach := True;
                              end if;
                           end loop;
                        end if;
                     end loop;
                     if Here or else Breach then
                        if Collapse_Tunnel (Fid, Nb (K)) = "" then
                           return;
                        end if;
                     end if;
                  end if;
               end if;
            end loop;
         end if;
      end loop;
   end AI_Collapse;

   function Can_Flood (Fid, Tile : Integer) return Boolean is
      Nb : Nbr_Arr;
      NN : Natural;
      Water : Boolean := False;
   begin
      if Tile < 0 or else Tile >= NTiles or else Tiles (Tile).Tun < 0 or else Tiles (Tile).Flooded
        or else City_At (Tile) >= 0
      then
         return False;
      end if;
      Nbrs (Tile, 1, NN, Nb);
      for K in 0 .. NN - 1 loop
         if not Tiles (Nb (K)).Land then
            Water := True;
         end if;
      end loop;
      return Water or else Has_Tech (Fid, Tech_Kind'Pos (Sapper));
   end Can_Flood;

   function Flood_Tunnel (Uidx, Tile : Integer) return Boolean is
      Target : Integer := Tile;
      Nb : Nbr_Arr;
      NN : Natural;
   begin
      if Uidx < 0 then
         Set_Error ("No such unit");
         return False;
      end if;
      if Target < 0 then
         if Can_Flood (Units (Uidx).Fac, Units (Uidx).Loc) then
            Target := Units (Uidx).Loc;
         else
            Nbrs (Units (Uidx).Loc, 1, NN, Nb);
            for K in 0 .. NN - 1 loop
               if Can_Flood (Units (Uidx).Fac, Nb (K)) and then Tiles (Nb (K)).Tun /= Units (Uidx).Fac then
                  Target := Nb (K);
                  exit;
               end if;
            end loop;
            if Target < 0 then
               for K in 0 .. NN - 1 loop
                  if Can_Flood (Units (Uidx).Fac, Nb (K)) then
                     Target := Nb (K);
                     exit;
                  end if;
               end loop;
            end if;
         end if;
      end if;
      if Target < 0 then
         Set_Error ("No floodable tunnel here (needs water next to it or Seismic Sapping)");
         return False;
      end if;
      if Units (Uidx).MP <= 0 then
         Set_Error ("No moves left");
         return False;
      end if;
      if Dist (Units (Uidx).Loc, Target) > 1 then
         Set_Error ("Too far");
         return False;
      end if;
      if City_At (Target) >= 0 then
         Set_Error ("Cannot flood a base");
         return False;
      end if;
      if Tiles (Target).Tun < 0 then
         Set_Error ("No tunnel there");
         return False;
      end if;
      if Tiles (Target).Flooded then
         Set_Error ("Already flooded");
         return False;
      end if;
      if not Can_Flood (Units (Uidx).Fac, Target) then
         Set_Error ("Needs water next to the tunnel, or Seismic Sapping");
         return False;
      end if;
      Tiles (Target).Flooded := True;
      Units (Uidx).MP := 0;
      declare
         U : Integer := 0;
      begin
         while U < Unit_N loop
            if Units (U).Loc = Target and then U /= Uidx then
               Units (U).HP := Units (U).HP - 3;
               if Units (U).HP <= 0 then
                  Remove_Unit (U);
               else
                  U := U + 1;
               end if;
            else
               U := U + 1;
            end if;
         end loop;
      end;
      Log ("T" & Img (Turn_N) & " tunnel flooded");
      return True;
   end Flood_Tunnel;

   function U_Bomb (K : Unit_Kind) return Boolean is
     (K in Frigate | Cruiser);

   function Bombard (Uidx, Tile : Integer) return Boolean is
      C, Hits, Taken : Integer := 0;
      A, D : Long_Float;
      Had : Boolean;
   begin
      if Uidx < 0 or else not U_Bomb (Units (Uidx).Kind) then
         Set_Error ("Only Frigates and Assault Cruisers can bombard");
         return False;
      end if;
      if Units (Uidx).MP <= 0 then
         Set_Error ("No moves left");
         return False;
      end if;
      if Tiles (Units (Uidx).Loc).Land or else City_At (Units (Uidx).Loc) >= 0 then
         Set_Error ("Must be at sea to bombard");
         return False;
      end if;
      if Tile < 0 or else Dist (Units (Uidx).Loc, Tile) /= 1 then
         Set_Error ("Target must be next to the ship");
         return False;
      end if;
      C := City_At (Tile);
      if C < 0 or else Cities (C).Fac = Units (Uidx).Fac then
         Set_Error ("No enemy city or warren entrance next to the ship");
         return False;
      end if;
      if Cities (C).Fac >= 0 and then not At_War (Units (Uidx).Fac, Cities (C).Fac) then
         Set_Error ("Declare war first");
         return False;
      end if;
      A := Att_Str (Uidx);
      if Cities (C).UG and then not Has_Tech (Units (Uidx).Fac, Tech_Kind'Pos (Sapper)) then
         A := A * 0.6;
      end if;
      Had := Best_Def (Tile, Uidx) >= 0;
      Hits := 0;
      Taken := 0;
      for K in 1 .. 3 loop
         declare
            Tg : constant Integer := Best_Def (Tile, Uidx);
         begin
            if Tg >= 0 then
               D := Def_Str (Tg, Uidx) * 0.7;
            else
               D := 2.0;
            end if;
            if Rand < A / (A + D) then
               Hits := Hits + 1;
               if Tg >= 0 then
                  Units (Tg).HP := Integer'Max (1, Units (Tg).HP - (1 + RI (2)));
               end if;
            else
               Taken := Taken + 1;
               Units (Uidx).HP := Integer'Max (1, Units (Uidx).HP - 1);
            end if;
         end;
      end loop;
      if not Had and then Hits > 0 then
         if Cities (C).Pop > 2 then
            Cities (C).Pop := Cities (C).Pop - 1;
         end if;
         Cities (C).Prod := Cities (C).Prod / 2;
      elsif Hits >= 2 then
         Cities (C).Prod := Integer'Max (0, Cities (C).Prod - Hits * 3);
      end if;
      Units (Uidx).MP := 0;
      Units (Uidx).Fort := False;
      Last_Hits := Hits;
      Log ("T" & Img (Turn_N) & " bombardment hits " & Img (Hits));
      return True;
   end Bombard;

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
      Diplo_Turn;
      Supply_Turn;
      for Ix in 0 .. Unit_N - 1 loop
         if Units (Ix).Work /= W_None then
            Units (Ix).Work_Left := Units (Ix).Work_Left - 1;
            if Units (Ix).Work_Left <= 0 then
               case Units (Ix).Work is
                  when W_Clear =>
                     Tiles (Units (Ix).Loc).Fungus := False;
                     if Units (Ix).Fac in 0 .. 3 then
                        Fung_Cut (Units (Ix).Fac) := Fung_Cut (Units (Ix).Fac) + 1;
                     end if;
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
                  when W_Tunnel =>
                     Tiles (Units (Ix).Loc).Tun := Units (Ix).Fac;
                     Tiles (Units (Ix).Loc).Flooded := False;
                     Tiles (Units (Ix).Loc).Collapsed := False;
                     Log ("T" & Img (Turn_N) & " tunnel dug");
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
            if not Units (Ix).No_Heal and then Units (Ix).HP < 10
              and then Units (Ix).MP = U_Mv (Units (Ix).Kind) * 3
            then
               Units (Ix).HP := Integer'Min (10, Units (Ix).HP + Heal);
            end if;
         end;
         Units (Ix).No_Heal := False;
         Units (Ix).Tn := 0;
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

   function Act (Code, A, B : Integer; Extra : Integer := 0) return Integer is
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
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            if B = 6 then
               if Units (U).Kind /= Burrower then
                  Set_Error ("Only Burrowers dig tunnels");
                  return 1;
               end if;
               if not Has_Tech (Units (U).Fac, Tech_Kind'Pos (Boring)) then
                  Set_Error ("Requires Lithic Boring");
                  return 1;
               end if;
               if not Tiles (Units (U).Loc).Land then
                  Set_Error ("Cannot tunnel under the sea");
                  return 1;
               end if;
               if Tiles (Units (U).Loc).Tun = Units (U).Fac and then not Tiles (Units (U).Loc).Flooded then
                  Set_Error ("Tunnel already here");
                  return 1;
               end if;
               declare
                  CC : constant Integer := City_At (Units (U).Loc);
               begin
                  if CC >= 0 and then not Cities (CC).UG then
                     Set_Error ("Cannot tunnel under a surface city");
                     return 1;
                  end if;
               end;
               Units (U).Work := W_Tunnel;
               if Tiles (Units (U).Loc).Flooded then
                  Units (U).Work_Left := 2;
               elsif Tiles (Units (U).Loc).Rock = 2 or else Tiles (Units (U).Loc).Collapsed then
                  Units (U).Work_Left := 3;
               else
                  Units (U).Work_Left := 2;
               end if;
               Units (U).MP := 0;
               return 0;
            end if;
            if Units (U).Kind /= Terraformer then
               if Units (U).Kind = Burrower then
                  Set_Error ("Burrowers only dig tunnels and found warrens");
               else
                  Set_Error ("Only terraformers");
               end if;
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
         when Act_Bombard =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            if not Bombard (U, B) then
               return 1;
            end if;
            return 0;
         when Act_Collapse =>
            if Collapse_Tunnel (A, B) /= "" then
               return 1;
            end if;
            return 0;
         when Act_Flood =>
            U := Find_Unit (A);
            if U < 0 then
               Set_Error ("No such unit");
               return 1;
            end if;
            if not Flood_Tunnel (U, B) then
               return 1;
            end if;
            return 0;
         when Act_Propose =>
            if not Propose (A, B, Extra) then
               return 1;
            end if;
            return 0;
         when Act_Answer =>
            if not Answer_Offer (A, B, Extra /= 0) then
               return 1;
            end if;
            return 0;
         when Act_War =>
            declare
               Why : constant String := Declare_War (A, B);
            begin
               if Why /= "" then
                  Set_Error (Why);
                  return 1;
               end if;
            end;
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
         Tiles (I).Tun := -1;
         Tiles (I).Flooded := False;
         Tiles (I).Collapsed := False;
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
      Rel := (others => (others => Rel_War));
      Since := (others => (others => 0));
      Open_B := (others => (others => False));
      Contact := (others => (others => False));
      Rep_V := (others => 50);
      Lock_Until := (others => 0);
      Fung_Cut := (others => 0);
      War_Target := (others => -1);
      War_City := (others => -1);
      Land_Share := (others => 0.0);
      Dip_Turns := (others => 0);
      Coop_Turns := 0;
      Coop_Key := 0;
      Ghosts := (others => (others => <>));
      CMem := (others => (others => <>));
      Contracts := (others => <>);
      Pending := (others => <>);
      Next_Offer := 1;
      Ask := (others => (others => (others => -100)));
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
      Add_R (if Code = 0 then " status=pass" else " status=fail");
      Add_R (" code=");
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
      if Code /= 0 and then ELen > 0 then
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
            if Tiles (I).Tun >= 0 then
               Wrd := Wrd or Interfaces.Shift_Left (U32 (Tiles (I).Tun + 1), 20);
            end if;
            if Tiles (I).Flooded then
               Wrd := Wrd or Interfaces.Shift_Left (U32'(1), 23);
            end if;
            if Tiles (I).Collapsed then
               Wrd := Wrd or Interfaces.Shift_Left (U32'(1), 24);
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

   function UImg (V : U32) return String is
      Digs : String (1 .. 12);
      N : Natural := 0;
      X : U32 := V;
      R : String (1 .. 12);
   begin
      if X = 0 then
         return "0";
      end if;
      while X > 0 loop
         N := N + 1;
         Digs (N) := Character'Val (Character'Pos ('0') + Integer (X mod 10));
         X := X / 10;
      end loop;
      for I in 1 .. N loop
         R (I) := Digs (N - I + 1);
      end loop;
      return R (1 .. N);
   end UImg;

   function Run_Mechanics_Check return Integer is
      function Rocky return Integer is
      begin
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land and then X_Of (I) > 2 and then Y_Of (I) > 2
              and then (Tiles (I).Rock = 2 or else Tiles (I).Elev > 60)
            then
               return I;
            end if;
         end loop;
         return -1;
      end Rocky;

      function Coastal_Land return Integer is
         Nb : Nbr_Arr;
         NN : Natural;
      begin
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land then
               Nbrs (I, 1, NN, Nb);
               for K in 0 .. NN - 1 loop
                  if not Tiles (Nb (K)).Land then
                     return I;
                  end if;
               end loop;
            end if;
         end loop;
         return -1;
      end Coastal_Land;

      function First_Sea (Around : Integer) return Integer is
         Nb : Nbr_Arr;
         NN : Natural;
      begin
         Nbrs (Around, 1, NN, Nb);
         for K in 0 .. NN - 1 loop
            if not Tiles (Nb (K)).Land then
               return Nb (K);
            end if;
         end loop;
         return -1;
      end First_Sea;

      procedure Grant (Fid, Tech : Integer) is
      begin
         if not Has_Tech (Fid, Tech) then
            Factions (Fid).Techs (Tech_Kind'Val (Tech)) := True;
            Factions (Fid).Tech_N := Factions (Fid).Tech_N + 1;
         end if;
      end Grant;

      Site, U, C, Sea, Foe, Own, Ship, Id : Integer;
      Code : Integer := 0;
      Air, Food, Pow, Cut, Pop, Col_Hp, Flood_Hp : Integer := -1;
      Iron_Cease, Verdant_Cease, Peace_Rel, Trade_Ok : Integer := -1;
      Sell_Cr, Buy_Cr, B_Hits, B_Hp, B_Pop, B_Prod : Integer := -1;
      Rs_After : U32 := 0;
      Collapsed : Integer := 0;
      Flooded : Integer := 0;
      Dig, Far, Aflood, Ally, Ob, Tlo, Thi, Surr, Leftu : Integer := -1;
      Rest_Code, Ghost_C, Wt, Wt2, Rush_Ok, Rjob, Rleft : Integer := -1;
      Aboard, Carried, Landed, Loaded, Dwin, Dtype, Cwin, Ctype : Integer := -1;
      Plans : String (1 .. 7) := "0,0,0,0";
   begin
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15) /= 0 then
         Code := 1;
      else
         Site := Rocky;
         Grant (0, Tech_Kind'Pos (Boring));
         U := Make_Unit (0, Burrower, Site);
         if Site < 0 or else U < 0 or else not Found_City (U) then
            Code := 2;
         else
            C := City_N - 1;
            declare
               Nb : Nbr_Arr;
               NN : Natural;
            begin
               Nbrs (Cities (C).Loc, 1, NN, Nb);
               if NN = 0 or else Make_Unit (1, Lancer, Nb (0)) < 0 then
                  Code := 2;
               else
                  Update_Seen (0);
                  Supply_Turn;
                  Supply_Turn;
                  Supply_Turn;
                  Air := Cities (C).Air;
                  Food := Cities (C).Food_R;
                  Pow := Cities (C).Pow;
                  Cut := Cities (C).Cut;
                  Pop := Cities (C).Pop;
               end if;
            end;
         end if;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := -1;
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land and then X_Of (I) > 2 and then Y_Of (I) > 2 then
               Site := I;
               exit;
            end if;
         end loop;
         Tiles (Site).Tun := 0;
         Foe := Make_Unit (1, Trooper, Site);
         Id := Units (Foe).Id;
         Units (Foe).HP := 8;
         declare
            Nb : Nbr_Arr;
            NN : Natural;
            Stand : Integer := Site;
         begin
            Nbrs (Site, 1, NN, Nb);
            for K in 0 .. NN - 1 loop
               if Tiles (Nb (K)).Land and then Nb (K) /= Site then
                  Stand := Nb (K);
                  exit;
               end if;
            end loop;
            Own := Make_Unit (0, Scout, Stand);
            if Own < 0 or else Collapse_Tunnel (0, Site) /= "" then
               Code := 3;
            else
               Foe := Find_Unit (Id);
               Col_Hp := (if Foe < 0 then 0 else Units (Foe).HP);
               Collapsed := (if Tiles (Site).Collapsed then 1 else 0);
            end if;
         end;
      else
         Code := 3;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := Coastal_Land;
         if Site < 0 then
            Code := 4;
         else
            declare
               Nb : Nbr_Arr;
               NN : Natural;
               Stand : Integer := -1;
            begin
               Nbrs (Site, 1, NN, Nb);
               for K in 0 .. NN - 1 loop
                  if Tiles (Nb (K)).Land then
                     Stand := Nb (K);
                     exit;
                  end if;
               end loop;
               Tiles (Site).Tun := 1;
               Foe := Make_Unit (1, Trooper, Site);
               Id := Units (Foe).Id;
               Units (Foe).HP := 6;
               Own := Make_Unit (0, Scout, Stand);
               if Own < 0 or else not Flood_Tunnel (Own, Site) then
                  Code := 4;
               else
                  Foe := Find_Unit (Id);
                  Flood_Hp := (if Foe < 0 then 0 else Units (Foe).HP);
                  Flooded := (if Tiles (Site).Flooded then 1 else 0);
               end if;
            end;
         end if;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := Coastal_Land;
         U := Make_Unit (0, Colonist, Site);
         if U < 0 or else not Found_City (U) then
            Code := 5;
         else
            C := City_N - 1;
            Sea := First_Sea (Cities (C).Loc);
            Ship := Make_Unit (1, Frigate, Sea);
            if Sea < 0 or else Ship < 0 or else not Bombard (Ship, Cities (C).Loc) then
               Code := 5;
            else
               B_Hits := Last_Hits;
               B_Hp := Units (Ship).HP;
               B_Pop := Cities (C).Pop;
               B_Prod := Cities (C).Prod;
               Rs_After := RS;
            end if;
         end if;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Contact (0, 2) := True;
         Contact (2, 0) := True;
         Factions (0).AI := True;
         Factions (2).AI := True;
         if not Propose (2, 0, 0) then
            Code := 6;
         else
            Iron_Cease := (if Rel (2, 0) = Rel_War then 0 else 1);
         end if;
         if Code = 0 and then not Propose (0, 2, 0) then
            Code := 6;
         else
            Verdant_Cease := Rel_Code (0, 2);
         end if;
         if Code = 0 then
            Since (0, 2) := Turn_N - 3;
            Since (2, 0) := Turn_N - 3;
            if not Propose (0, 2, 1) then
               Code := 6;
            else
               Peace_Rel := Rel_Code (0, 2);
            end if;
         end if;
         if Code = 0 then
            Factions (2).Credits := 100;
            if not Propose (0, 2, 4 + 2 * 8 + 23 * 128) then
               Code := 6;
            else
               Trade_Ok := (if Rel (0, 2) = Rel_Peace then 1 else 0);
               Sell_Cr := Factions (0).Credits;
               Buy_Cr := Factions (2).Credits;
               for I in Contracts'Range loop
                  if Contracts (I).Live then
                     Trade_Ok := 2;
                  end if;
               end loop;
            end if;
         end if;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := -1;
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land and then X_Of (I) > 2 and then Y_Of (I) > 2 and then Tiles (I).Rock /= 2 then
               Site := I;
               exit;
            end if;
         end loop;
         Grant (0, Tech_Kind'Pos (Boring));
         U := Make_Unit (0, Burrower, Site);
         if Site < 0 or else U < 0 or else Act (Act_Terra, Units (U).Id, 6) /= 0 then
            Code := 7;
         else
            Dig := Units (U).Work_Left;
         end if;
         Far := 0;
         for I in 0 .. NTiles - 1 loop
            if Tiles (I).Land then
               declare
                  Clear : Boolean := True;
               begin
                  for V in 0 .. Unit_N - 1 loop
                     if Dist (Units (V).Loc, I) <= 2 then
                        Clear := False;
                     end if;
                  end loop;
                  if Clear then
                     Tiles (I).Tun := 0;
                     if Collapse_Tunnel (0, I) /= "" then
                        Far := 1;
                     end if;
                     exit;
                  end if;
               end;
            end if;
         end loop;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := Coastal_Land;
         if Site >= 0 then
            declare
               Nb : Nbr_Arr;
               NN : Natural;
               Stand : Integer := -1;
            begin
               Nbrs (Site, 1, NN, Nb);
               for K in 0 .. NN - 1 loop
                  if Tiles (Nb (K)).Land then
                     Stand := Nb (K);
                     exit;
                  end if;
               end loop;
               Tiles (Site).Tun := 1;
               Own := Make_Unit (0, Scout, Stand);
               if Own >= 0 and then Flood_Tunnel (Own, -1) and then Tiles (Site).Flooded then
                  Aflood := 1;
               else
                  Aflood := 0;
               end if;
            end;
         end if;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := Rocky;
         Grant (0, Tech_Kind'Pos (Boring));
         U := Make_Unit (0, Burrower, Site);
         if Site < 0 or else U < 0 or else not Found_City (U) then
            Code := 8;
         else
            C := City_N - 1;
            Cities (C).Res_Set := True;
            Cities (C).Air := 0;
            Cities (C).Food_R := 8;
            Cities (C).Pow := 6;
            Cities (C).Air_Out := 1;
            Cities (C).Pop := 1;
            if Make_Unit (0, Trooper, Cities (C).Loc) < 0 then
               Code := 8;
            else
               declare
                  Nb : Nbr_Arr;
                  NN : Natural;
               begin
                  Nbrs (Cities (C).Loc, 1, NN, Nb);
                  if NN = 0 or else Make_Unit (1, Lancer, Nb (0)) < 0 then
                     Code := 8;
                  else
                     Update_Seen (0);
                     Supply_Turn;
                     Surr := Cities (C).Fac;
                     Leftu := 0;
                     for V in 0 .. Unit_N - 1 loop
                        if Units (V).Loc = Cities (C).Loc and then Units (V).Fac = 0 then
                           Leftu := Leftu + 1;
                        end if;
                     end loop;
                  end if;
               end;
            end if;
         end if;
      end if;

      if Code = 0 and then New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Contact (0, 2) := True;
         Contact (2, 0) := True;
         Contact (0, 3) := True;
         Contact (3, 0) := True;
         Contact (2, 3) := True;
         Contact (3, 2) := True;
         for F in 0 .. 3 loop
            Factions (F).AI := True;
         end loop;
         Set_Rel (0, 2, Rel_Peace);
         Since (0, 2) := Turn_N - 8;
         Since (2, 0) := Turn_N - 8;
         Rep_V (0) := 70;
         if not Propose (0, 2, 2) then
            Code := 9;
         else
            Ally := Rel_Code (0, 2);
         end if;
         if Code = 0 then
            Set_Rel (3, 2, Rel_Peace);
            Rep_V (3) := 50;
            if not Propose (3, 2, 3) then
               Code := 9;
            else
               Ob := (if Open_B (3, 2) then 1 else 0);
            end if;
         end if;
         if Code = 0 then
            Set_Rel (0, 3, Rel_Peace);
            Factions (0).Credits := 100;
            Factions (3).Credits := 100;
            Rep_V (0) := 50;
            if not Propose (0, 3, 4 + 2 * 8 + 22 * 128 + 524288) then
               Code := 9;
            else
               Tlo := 0;
               for I in Contracts'Range loop
                  if Contracts (I).Live then
                     Tlo := 1;
                  end if;
               end loop;
            end if;
            if Code = 0 and then not Propose (0, 3, 4 + 2 * 8 + 23 * 128 + 524288) then
               Code := 9;
            else
               Thi := 0;
               for I in Contracts'Range loop
                  if Contracts (I).Live then
                     Thi := 1;
                  end if;
               end loop;
            end if;
         end if;
      end if;

      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Rest_Code := 0;
         for F in 0 .. Fac_N - 1 loop
            Plan_Faction (F);
            Plans (F * 2 + 1) := Character'Val (Character'Pos ('0') + Factions (F).Plan);
         end loop;
      end if;
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         declare
            A, B, Best, Foe, Spot : Integer;
         begin
            A := -1;
            B := -1;
            Best := 0;
            for I in 0 .. NTiles - 1 loop
               if Tiles (I).Land then
                  for J in 0 .. NTiles - 1 loop
                     if Tiles (J).Land and then Dist (I, J) > Best and then Dist (I, J) < 20 then
                        Best := Dist (I, J);
                        A := I;
                        B := J;
                     end if;
                  end loop;
               end if;
            end loop;
            for V in 0 .. Unit_N - 1 loop
               if Units (V).Fac = 0 then
                  Units (V).Loc := A;
               end if;
            end loop;
            declare
               Nb : Nbr_Arr;
               NN : Natural;
            begin
               Nbrs (A, 1, NN, Nb);
               Spot := Nb (0);
               for K in 0 .. NN - 1 loop
                  if Tiles (Nb (K)).Land then
                     Spot := Nb (K);
                     exit;
                  end if;
               end loop;
            end;
            Foe := Make_Unit (1, Trooper, Spot);
            Update_Seen (0);
            for V in 0 .. Unit_N - 1 loop
               if Units (V).Fac = 0 then
                  Units (V).Loc := B;
               end if;
            end loop;
            Units (Foe).Loc := A;
            Update_Seen (0);
            Ghost_C := JS_Round (Known_Mil (0, 1) * 100.0);
         end;
      end if;
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Contact (0, 1) := True;
         Contact (1, 0) := True;
         Factions (0).AI := True;
         Factions (1).AI := True;
         if Make_Unit (1, Striker, Factions (1).Start) >= 0 then
            War_Target (1) := 0;
            if Propose (0, 1, 0) then
               Wt := (if Rel (0, 1) = Rel_War then 0 else 1);
            end if;
            War_Target (1) := -1;
            if Propose (0, 1, 0) then
               Wt2 := Rel_Code (0, 1);
            end if;
         end if;
      end if;
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         declare
            Anchor, Mid, City_At_I, Bur, Founder : Integer;
            Found_It : Boolean := False;
            Nb, Nb2 : Nbr_Arr;
            NN, NN2 : Natural;
         begin
            Anchor := -1;
            Mid := -1;
            City_At_I := -1;
            Search :
            for I in 0 .. NTiles - 1 loop
               if Tiles (I).Land and then X_Of (I) >= 3 and then Y_Of (I) >= 3 then
                  Nbrs (I, 1, NN, Nb);
                  for K in 0 .. NN - 1 loop
                     if Tiles (Nb (K)).Land then
                        Nbrs (Nb (K), 1, NN2, Nb2);
                        for P in 0 .. NN2 - 1 loop
                           if Nb2 (P) /= I and then Tiles (Nb2 (P)).Land
                             and then Dist (I, Nb2 (P)) = 2 and then City_At (Nb2 (P)) < 0
                           then
                              Anchor := I;
                              Mid := Nb (K);
                              City_At_I := Nb2 (P);
                              Found_It := True;
                              exit Search;
                           end if;
                        end loop;
                     end if;
                  end loop;
               end if;
            end loop Search;
            if Found_It and then Mid >= 0 then
               Tiles (Anchor).Tun := 0;
               Bur := Make_Unit (0, Burrower, Anchor);
               Founder := Make_Unit (1, Colonist, City_At_I);
               if Bur >= 0 and then Founder >= 0 and then Found_City (Founder) then
                  Update_Seen (0);
                  War_Target (0) := 1;
                  if AI_Rush (Bur) then
                     Rush_Ok := 1;
                  else
                     Rush_Ok := 0;
                  end if;
                  Rjob := Units (Bur).Target;
                  Rleft := (if Units (Bur).Work = W_None then -1 else Units (Bur).Work_Left);
               else
                  Rest_Code := 3;
               end if;
            else
               Rest_Code := 3;
            end if;
         end;
      end if;
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15) = 0 then
         Site := Coastal_Land;
         Sea := First_Sea (Site);
         Ship := Make_Unit (0, Transport, Sea);
         U := Make_Unit (0, Colonist, Site);
         if Ship >= 0 and then U >= 0 and then Act (Act_Move, Units (U).Id, Sea) = 0
           and then Units (U).On_Ship = Units (Ship).Id
         then
            Aboard := 1;
            declare
               Nb : Nbr_Arr;
               NN : Natural;
               Next, Shore : Integer;
            begin
               Nbrs (Sea, 1, NN, Nb);
               Next := -1;
               for K in 0 .. NN - 1 loop
                  if not Tiles (Nb (K)).Land then
                     declare
                        Nb2 : Nbr_Arr;
                        NN2 : Natural;
                        Has_Land : Boolean := False;
                     begin
                        Nbrs (Nb (K), 1, NN2, Nb2);
                        for P in 0 .. NN2 - 1 loop
                           if Tiles (Nb2 (P)).Land then
                              Has_Land := True;
                           end if;
                        end loop;
                        if Has_Land and then Next < 0 then
                           Next := Nb (K);
                        end if;
                     end;
                  end if;
               end loop;
               if Next < 0 or else Act (Act_Move, Units (Ship).Id, Next) /= 0
                 or else Units (U).Loc /= Units (Ship).Loc
               then
                  Carried := 0;
               else
                  Carried := 1;
                  Nbrs (Units (Ship).Loc, 1, NN, Nb);
                  Shore := -1;
                  for K in 0 .. NN - 1 loop
                     if Tiles (Nb (K)).Land then
                        Shore := Nb (K);
                        exit;
                     end if;
                  end loop;
                  Units (U).MP := U_Mv (Colonist) * 3;
                  if Shore >= 0 and then Act (Act_Move, Units (U).Id, Shore) = 0
                    and then Units (U).On_Ship < 0 and then Units (U).MP = 0
                    and then Tiles (Units (U).Loc).Land
                  then
                     Landed := 1;
                  else
                     Landed := 0;
                  end if;
               end if;
            end;
         else
            Aboard := 0;
            Carried := 0;
            Landed := 0;
         end if;
         Site := Coastal_Land;
         Ship := Make_Unit (0, Transport, Site);
         U := Make_Unit (0, Colonist, Site);
         if Ship >= 0 and then U >= 0 then
            Units (U).Want_Ship := True;
            Load_Waiters (Ship);
            Loaded := (if Units (U).On_Ship = Units (Ship).Id then 1 else 0);
         end if;
      end if;
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15 + 256) = 0 then
         Turn_N := 120;
         U := -1;
         for V in 0 .. Unit_N - 1 loop
            if Units (V).Fac = 0 and then Units (V).Kind = Colonist then
               U := V;
               exit;
            end if;
         end loop;
         if U >= 0 and then Found_City (U) then
            Set_Rel (0, 1, Rel_Peace);
            Set_Rel (0, 2, Rel_Peace);
            Since (0, 1) := 100;
            Since (1, 0) := 100;
            Since (0, 2) := 100;
            Since (2, 0) := 100;
            Rep_V (0) := 60;
            for K in 1 .. 15 loop
               Score_Diplomacy;
            end loop;
            Dwin := Winner;
            Dtype := (if Win_Type = 7 then 7 else 0);
         else
            Rest_Code := 5;
         end if;
      end if;
      if New_Game (7919, 36, 24, 0, 3, 0, 2, 15 + 512) = 0 then
         Turn_N := 120;
         Factions (2).Alive := False;
         Factions (3).Alive := False;
         U := -1;
         for V in 0 .. Unit_N - 1 loop
            if Units (V).Fac = 0 and then Units (V).Kind = Colonist then
               U := V;
               exit;
            end if;
         end loop;
         if U >= 0 and then Found_City (U) then
            Set_Rel (0, 1, Rel_Ally);
            Since (0, 1) := Turn_N - 10;
            Since (1, 0) := Turn_N - 10;
            Land_Share (0) := 0.4;
            Land_Share (1) := 0.3;
            for K in 1 .. 15 loop
               Score_Diplomacy;
            end loop;
            Cwin := Winner;
            Ctype := (if Win_Type = 8 then 8 else 0);
         else
            Rest_Code := 6;
         end if;
      end if;

      RLen := 0;
      Add_R ("MECH ");
      Add_R (if Code = 0 then "status=pass" else "status=fail");
      Add_R (" code="); Add_R (Img (Code));
      Add_R (" air="); Add_R (Img (Air));
      Add_R (" food="); Add_R (Img (Food));
      Add_R (" pow="); Add_R (Img (Pow));
      Add_R (" cut="); Add_R (Img (Cut));
      Add_R (" wpop="); Add_R (Img (Pop));
      Add_R (" col_hp="); Add_R (Img (Col_Hp));
      Add_R (" collapsed="); Add_R (Img (Collapsed));
      Add_R (" flood_hp="); Add_R (Img (Flood_Hp));
      Add_R (" flooded="); Add_R (Img (Flooded));
      Add_R (" bomb_hits="); Add_R (Img (B_Hits));
      Add_R (" bomb_hp="); Add_R (Img (B_Hp));
      Add_R (" bomb_pop="); Add_R (Img (B_Pop));
      Add_R (" bomb_prod="); Add_R (Img (B_Prod));
      Add_R (" bomb_rs="); Add_R (UImg (Rs_After));
      Add_R (" iron_cease="); Add_R (Img (Iron_Cease));
      Add_R (" verdant_rel="); Add_R (Img (Verdant_Cease));
      Add_R (" peace_rel="); Add_R (Img (Peace_Rel));
      Add_R (" trade="); Add_R (Img (Trade_Ok));
      Add_R (" sell_cr="); Add_R (Img (Sell_Cr));
      Add_R (" buy_cr="); Add_R (Img (Buy_Cr));
      Add_R (" dig="); Add_R (Img (Dig));
      Add_R (" far="); Add_R (Img (Far));
      Add_R (" aflood="); Add_R (Img (Aflood));
      Add_R (" surr="); Add_R (Img (Surr));
      Add_R (" leftu="); Add_R (Img (Leftu));
      Add_R (" ally="); Add_R (Img (Ally));
      Add_R (" ob="); Add_R (Img (Ob));
      Add_R (" tlo="); Add_R (Img (Tlo));
      Add_R (" thi="); Add_R (Img (Thi));
      Add_R (String'(1 => ASCII.LF));
      Add_R ("REST ");
      Add_R (if Rest_Code = 0 then "status=pass" else "status=fail");
      Add_R (" code="); Add_R (Img (Rest_Code));
      Add_R (" plans="); Add_R (Plans);
      Add_R (" ghost="); Add_R (Img (Ghost_C));
      Add_R (" wt="); Add_R (Img (Wt));
      Add_R (" wt2="); Add_R (Img (Wt2));
      Add_R (" rush="); Add_R (Img (Rush_Ok));
      Add_R (" rjob="); Add_R (Img (Rjob));
      Add_R (" rleft="); Add_R (Img (Rleft));
      Add_R (" aboard="); Add_R (Img (Aboard));
      Add_R (" carried="); Add_R (Img (Carried));
      Add_R (" landed="); Add_R (Img (Landed));
      Add_R (" loaded="); Add_R (Img (Loaded));
      Add_R (" dwin="); Add_R (Img (Dwin));
      Add_R (" dtype="); Add_R (Img (Dtype));
      Add_R (" cwin="); Add_R (Img (Cwin));
      Add_R (" ctype="); Add_R (Img (Ctype));
      if Code = 0 then
         return Rest_Code;
      end if;
      return Code;
   end Run_Mechanics_Check;

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
   begin
      R := Act (Code, A, B, C);
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
               when 7 => Copy_Text ("diplomatic");
               when 8 => Copy_Text ("cooperative");
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
         when 21 =>
            if Human < 0 or else A not in 0 .. Fac_N - 1 or else A = Human then
               Copy_Text ("");
            else
               case Rel (Human, A) is
                  when Rel_War => Copy_Text ("War");
                  when Rel_Cease => Copy_Text ("Ceasefire");
                  when Rel_Peace => Copy_Text ("Peace");
                  when Rel_Ally => Copy_Text ("Alliance");
               end case;
            end if;
         when 22 =>
            declare
               Found : Boolean := False;
            begin
               for I in Pending'Range loop
                  if Pending (I).Live and then Pending (I).To = Human then
                     Copy_Text (Img (Pending (I).Id) & " " & Img (Pending (I).Kind) & " "
                                & Img (Pending (I).From) & " " & Img (Pending (I).Amt) & " "
                                & Img (Pending (I).Price) & " "
                                & (if Pending (I).Buy then "1" else "0") & " "
                                & (if Pending (I).Energy then "1" else "0"));
                     Found := True;
                     exit;
                  end if;
               end loop;
               if not Found then
                  Copy_Text ("");
               end if;
            end;
         when 23 =>
            if A in 0 .. Fac_N - 1 then
               Copy_Text (Img (Rep_V (A)) & " " & Img (Lock_Until (A)) & " "
                          & (if Human >= 0 and then A /= Human and then Open_B (Human, A) then "1" else "0"));
            else
               Copy_Text ("");
            end if;
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
