/****** Object:  View [dbo].[V_Candidate_Seq_Processing_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Candidate_Seq_Processing_History]
AS
SELECT TOP (100) PERCENT Entry_ID, Source_Database, Source_Job, 
    Candidate_Seqs_Table_Name, Queue_State, Entered_Queue, 
    DATEDIFF(second, Entered_Queue, Processing_Start) 
    / 60.0 AS Queue_Wait_time_Minutes, DATEDIFF(second, 
    Processing_Start, Processing_Complete) 
    / 60.0 AS Processing_Time_Minutes, Sequence_Count, 
    Sequence_Count_New, Status_Message
FROM T_Candidate_Seq_Processing_History
ORDER BY Entry_ID

GO
