/****** Object:  View [dbo].[V_Candidate_Seq_Processing_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Candidate_Seq_Processing_History]
AS
SELECT Entry_ID,
       Source_Database,
       Source_Job,
       Candidate_Seqs_Table_Name,
       Queue_State,
       Entered_Queue,
       DATEDIFF(second, Entered_Queue, Processing_Start) AS Queue_Wait_Time_Seconds,
       DATEDIFF(second, Processing_Start, Processing_Complete)  AS Processing_Time_Seconds,
       Sequence_Count,
       Sequence_Count_New,
       CONVERT(decimal(9,2), Sequence_Count / (DATEDIFF(millisecond, Processing_Start, Processing_Complete) / 1000.0 )) AS Processing_Rate_SeqsPerSecond,
       Status_Message
FROM T_Candidate_Seq_Processing_History



GO
