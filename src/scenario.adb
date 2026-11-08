with Ada.Command_Line;
with Ada.Text_IO;
with Colony;

procedure Scenario is
   Status : Integer;
begin
   Status := Colony.Run_Watch_Check;
   Ada.Text_IO.Put_Line (Colony.Report);
   if Status /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Status := Colony.Run_Manual_Check;
   Ada.Text_IO.Put_Line (Colony.Report);
   if Status /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Status := Colony.Run_Mechanics_Check;
   Ada.Text_IO.Put_Line (Colony.Report);
   if Status /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Scenario;
