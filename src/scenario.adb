with Ada.Command_Line;
with Ada.Text_IO;
with Colony;

procedure Scenario is
   Status : Integer;
begin
   if Ada.Command_Line.Argument_Count > 0
     and then Ada.Command_Line.Argument (1) = "trace"
   then
      Colony.Run_Trace (25, 0);
      declare
         R : constant String := Colony.Trace_Report;
      begin
         --  Closing standard output terminates the last line, so the
         --  report's final newline is left off here.
         if R'Length > 0 and then R (R'Last) = ASCII.LF then
            Ada.Text_IO.Put (R (R'First .. R'Last - 1));
         else
            Ada.Text_IO.Put (R);
         end if;
      end;
      return;
   end if;
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
