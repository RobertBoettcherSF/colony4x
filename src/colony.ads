--  Colony4X rules. The browser and the native scenario both call this
--  package. JavaScript only draws the integers the engine returns.
--
--  Rules follow the JavaScript edition in game.js. status=pass in a
--  report means every expectation held. status=fail means a mismatch.
--  code=0 only together with status=pass. The process exit status is 0
--  only when every report line says status=pass.
package Colony is

   function Run_Watch_Check return Integer
     with Export, Convention => C, External_Name => "c4x_check_watch";
   function Run_Manual_Check return Integer
     with Export, Convention => C, External_Name => "c4x_check_manual";
   function Run_Mechanics_Check return Integer
     with Export, Convention => C, External_Name => "c4x_check_mechanics";
   procedure Run_Trace (Turns, All_AI : Integer);
   function Trace_Report return String;
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
   Act_Bombard  : constant Integer := 17;
   Act_Collapse : constant Integer := 18;
   Act_Flood    : constant Integer := 19;
   Act_Propose  : constant Integer := 20;
   Act_Answer   : constant Integer := 21;
   Act_War      : constant Integer := 22;

   --  Default rule bits. 911 is conquest, ascension, economic, dominion,
   --  events, diplomatic and cooperative, with aggressive off:
   --  0 conquest, 1 ascension, 2 economic, 3 dominion, 4 full map,
   --  5 accelerated, 6 slow research, 7 events, 8 diplomatic,
   --  9 cooperative, 10 aggressive rivals.
   Default_Rules : constant Integer := 911;

end Colony;
