/****** Object:  View [dbo].[V_Candidate_Seq_Processing_Event_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Candidate_Seq_Processing_Event_History]
AS
SELECT TOP (100) PERCENT EventOrderQ.Event_Time, 
    EventOrderQ.Entry_ID, EventOrderQ.Event_Message, 
    StatsQ.Source_Database, StatsQ.Source_Job, 
    StatsQ.Queue_Wait_time_Minutes, 
    StatsQ.Processing_Time_Minutes, StatsQ.Sequence_Count, 
    StatsQ.Sequence_Count_New
FROM (SELECT Entered_Queue AS Event_Time, Entry_ID, 
          'Entered Queue' AS Event_Message
      FROM dbo.T_Candidate_Seq_Processing_History
      UNION
      SELECT Processing_Start AS Event_Time, Entry_ID, 
          'Started Processing' AS Event_Message
      FROM dbo.T_Candidate_Seq_Processing_History
      WHERE (NOT (Processing_Start IS NULL))
      UNION
      SELECT Processing_Complete AS Event_Time, Entry_ID, 
          'Processing Complete' AS Event_Message
      FROM dbo.T_Candidate_Seq_Processing_History
      WHERE (NOT (Processing_Complete IS NULL))) 
    AS EventOrderQ INNER JOIN
        (SELECT Entry_ID, Source_Database, Source_Job, 
           Queue_State, DATEDIFF(second, Entered_Queue, 
           Processing_Start) 
           / 60.0 AS Queue_Wait_time_Minutes, 
           DATEDIFF(second, Processing_Start, 
           Processing_Complete) 
           / 60.0 AS Processing_Time_Minutes, 
           Sequence_Count, Sequence_Count_New
      FROM dbo.T_Candidate_Seq_Processing_History)
     AS StatsQ ON 
    EventOrderQ.Entry_ID = StatsQ.Entry_ID
ORDER BY EventOrderQ.Event_Time, EventOrderQ.Entry_ID

GO
