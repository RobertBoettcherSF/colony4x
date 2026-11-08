--  Colony4X rules. The browser and the native scenario both call this
--  package. JavaScript only draws the integers the engine returns.
--
--  Not in this build (rejected in text, never simulated in JS):
--  warren supply sieges, tunnel flood/collapse, naval bombardment,
--  and the diplomacy bargain/trade AI. Factions start at war, which is
--  the Colony4X opening state, and stay there. Surface colonisation,
--  economy, research, fog, morale, policies, combat and the land AI are
--  the engine.
package Colony is

   function Run_Watch_Check return Integer
     with Export, Convention => C, External_Name => "c4x_check_watch";
   function Run_Manual_Check return Integer
     with Export, Convention => C, External_Name => "c4x_check_manual";
   function Report return String;

   function C_Ready return Integer
     with Export, Convention => C, External_Name => "c4x_ready";
   function C_New
     (Seed, Width, Height, Player, Num_AI, All_AI, Difficulty, Rules : Integer)
     return Integer
     with Export, Convention => C, External_Name => "c4x_new";
   function C_Act (Code, A, B, C : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_act";
   function C_Frame return Integer
     with Export, Convention => C, External_Name => "c4x_frame";
   function C_Frame_Ptr return Integer
     with Export, Convention => C, External_Name => "c4x_frame_ptr";
   function C_Text (Kind, A, B : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_text";
   function C_Text_Ptr return Integer
     with Export, Convention => C, External_Name => "c4x_text_ptr";
   function C_Option_Count (Kind, Owner : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_option_count";
   function C_Option (Kind, Owner, Index : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_option";
   function C_Tech_State (Fac, Tech : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_tech_state";
   function C_Stat (Kind, Field : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_stat";
   function C_Set_Viewer (Who : Integer) return Integer
     with Export, Convention => C, External_Name => "c4x_set_viewer";

   --  Action codes (C_Act).
   Act_End      : constant Integer := 1;
   Act_Move     : constant Integer := 2;
   Act_Goto     : constant Integer := 3;
   Act_Found    : constant Integer := 4;
   Act_Skip     : constant Integer := 5;
   Act_Fort     : constant Integer := 6;
   Act_Disband  : constant Integer := 7;
   Act_Research : constant Integer := 8;
   Act_Labs     : constant Integer := 9;
   Act_Queue    : constant Integer := 10;
   Act_Unqueue  : constant Integer := 11;
   Act_Buy      : constant Integer := 12;
   Act_Terra    : constant Integer := 13;
   Act_Control  : constant Integer := 14;
   Act_Handback : constant Integer := 15;
   Act_Policy   : constant Integer := 16;

   --  Default rule bits: conquest, ascension, economic, dominion, events.
   Default_Rules : constant Integer := 143;

end Colony;
