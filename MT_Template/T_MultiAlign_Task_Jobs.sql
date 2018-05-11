/****** Object:  Table [dbo].[T_MultiAlign_Task_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MultiAlign_Task_Jobs](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Task_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
 CONSTRAINT [PK_T_MultiAlign_Task_Jobs_Entry_ID] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_MultiAlign_Task_Jobs_Task_ID_Job] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MultiAlign_Task_Jobs_Task_ID_Job] ON [dbo].[T_MultiAlign_Task_Jobs]
(
	[Task_ID] ASC,
	[Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs]  WITH CHECK ADD  CONSTRAINT [FK_T_MultiAlign_Task_Jobs_T_FTICR_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_FTICR_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs] CHECK CONSTRAINT [FK_T_MultiAlign_Task_Jobs_T_FTICR_Analysis_Description]
GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs]  WITH CHECK ADD  CONSTRAINT [FK_T_MultiAlign_Task_Jobs_T_MultiAlign_Task] FOREIGN KEY([Task_ID])
REFERENCES [dbo].[T_MultiAlign_Task] ([Task_ID])
GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs] CHECK CONSTRAINT [FK_T_MultiAlign_Task_Jobs_T_MultiAlign_Task]
GO
/****** Object:  Trigger [dbo].[trig_d_T_MultiAlign_Task_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Trigger [dbo].[trig_d_T_MultiAlign_Task_Jobs] on [dbo].[T_MultiAlign_Task_Jobs]
For Delete
/****************************************************
**
**	Desc:	Updates the Job_Count field in T_MultiAlign_Task for the updated
**			tasks in T_MultiAlign_Task_Jobs
**
**	Auth:	mem
**	Date:	12/17/2007
**			01/15/2008 mem - Fixed counting bug that appeared if deleted contained more than 2 rows  
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	UPDATE T_MultiAlign_Task
	SET Job_Count = IsNull(JobQ.JobCount, 0)
	FROM T_MultiAlign_Task MaT INNER JOIN 
		 deleted ON MaT.Task_ID = deleted.Task_ID LEFT OUTER JOIN
		 (	SELECT MTJ.Task_ID, COUNT(*) AS JobCount
			FROM T_MultiAlign_Task_Jobs MTJ
            WHERE MTJ.Task_ID IN (SELECT DISTINCT Task_ID FROM deleted)
			GROUP BY MTJ.Task_ID
		 ) JobQ ON MaT.Task_ID = JobQ.Task_ID


GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs] ENABLE TRIGGER [trig_d_T_MultiAlign_Task_Jobs]
GO
/****** Object:  Trigger [dbo].[trig_i_T_MultiAlign_Task_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Trigger [dbo].[trig_i_T_MultiAlign_Task_Jobs] on [dbo].[T_MultiAlign_Task_Jobs]
For Insert
/****************************************************
**
**	Desc:	Updates the Job_Count field in T_MultiAlign_Task for the updated
**			tasks in T_MultiAlign_Task_Jobs
**
**	Auth:	mem
**	Date:	12/17/2007
**			01/15/2008 mem - Fixed counting bug that appeared if inserted contained more than 2 rows  
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	UPDATE T_MultiAlign_Task
	SET Job_Count = IsNull(JobQ.JobCount, 0)
	FROM T_MultiAlign_Task MaT INNER JOIN 
		 (	SELECT MTJ.Task_ID, COUNT(*) AS JobCount
			FROM T_MultiAlign_Task_Jobs MTJ
            WHERE MTJ.Task_ID IN (SELECT DISTINCT Task_ID FROM inserted)
			GROUP BY MTJ.Task_ID
		 ) JobQ ON MaT.Task_ID = JobQ.Task_ID



GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs] ENABLE TRIGGER [trig_i_T_MultiAlign_Task_Jobs]
GO
/****** Object:  Trigger [dbo].[trig_u_T_MultiAlign_Task_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Trigger [dbo].[trig_u_T_MultiAlign_Task_Jobs] on [dbo].[T_MultiAlign_Task_Jobs]
For Update
/****************************************************
**
**	Desc:	Updates the Job_Count field in T_MultiAlign_Task for the updated
**			tasks in T_MultiAlign_Task_Jobs
**
**	Auth:	mem
**	Date:	12/17/2007
**			01/15/2008 mem - Fixed counting bug that appeared if inserted or deleted contained more than 2 rows  
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	UPDATE T_MultiAlign_Task
	SET Job_Count = IsNull(JobQ.JobCount, 0)
	FROM T_MultiAlign_Task MaT INNER JOIN 
		 (	SELECT MTJ.Task_ID, COUNT(*) AS JobCount
			FROM T_MultiAlign_Task_Jobs MTJ
            WHERE MTJ.Task_ID IN (SELECT DISTINCT Task_ID FROM inserted)
			GROUP BY MTJ.Task_ID
		 ) JobQ ON MaT.Task_ID = JobQ.Task_ID

	UPDATE T_MultiAlign_Task
	SET Job_Count = IsNull(JobQ.JobCount, 0)
	FROM T_MultiAlign_Task MaT INNER JOIN 
		 deleted ON MaT.Task_ID = deleted.Task_ID LEFT OUTER JOIN
		 (	SELECT MTJ.Task_ID, COUNT(*) AS JobCount
			FROM T_MultiAlign_Task_Jobs MTJ
            WHERE MTJ.Task_ID IN (SELECT DISTINCT Task_ID FROM deleted)
			GROUP BY MTJ.Task_ID
		 ) JobQ ON MaT.Task_ID = JobQ.Task_ID


GO
ALTER TABLE [dbo].[T_MultiAlign_Task_Jobs] ENABLE TRIGGER [trig_u_T_MultiAlign_Task_Jobs]
GO
