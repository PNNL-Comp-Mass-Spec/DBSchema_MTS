/****** Object:  Table [dbo].[T_Datasets] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Datasets](
	[Dataset_ID] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created_DMS] [datetime] NULL,
	[Acq_Time_Start] [datetime] NULL,
	[Acq_Time_End] [datetime] NULL,
	[Acq_Length] [decimal](9, 2) NULL,
	[Scan_Count] [int] NULL,
	[Created] [datetime] NOT NULL,
	[Dataset_Process_State] [int] NOT NULL,
	[SIC_Job] [int] NULL,
 CONSTRAINT [PK_T_Datasets] PRIMARY KEY CLUSTERED 
(
	[Dataset_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Trigger [dbo].[trig_d_Datasets] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_d_Datasets] on [dbo].[T_Datasets]
For Delete
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 2, deleted.Dataset_ID, 0, deleted.Dataset_Process_State, GetDate()
	FROM deleted
	order by deleted.Dataset_ID

GO
/****** Object:  Trigger [dbo].[trig_i_Datasets] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_i_Datasets] on [dbo].[T_Datasets]
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 2, inserted.Dataset_ID, inserted.Dataset_Process_State, 0, GetDate()
	FROM inserted
	ORDER BY inserted.Dataset_ID

GO
/****** Object:  Trigger [dbo].[trig_iu_T_Datasets] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [trig_iu_T_Datasets] ON dbo.T_Datasets 
FOR INSERT, UPDATE
AS
/****************************************************
**
**	Desc: 
**		Validates that the SIC_Job assigned to a given
**		Dataset_ID belongs to the same Dataset_ID
**
**		Auth: mem
**		Date: 01/23/2005
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	If Update(SIC_Job)
	Begin

		Declare @FirstInvalidDataset int

		Set @FirstInvalidDataset = Null

		SELECT Top 1 @FirstInvalidDataset = Dataset_ID
		FROM inserted
		WHERE (Dataset_ID NOT IN
			        	(SELECT inserted.Dataset_ID
				FROM inserted INNER JOIN
			           		T_Analysis_Description TAD ON 
			           		inserted.SIC_Job = TAD.Job AND 
			           		inserted.Dataset_ID = TAD.Dataset_ID)
				) AND 
			NOT (SIC_Job IS NULL)


		If Not (@FirstInvalidDataset Is NULL)
		Begin
			Declare @message varchar(128)
			Set @message = 'Error: Dataset_ID defined or updated with SIC_Job having a different Dataset_ID value; first invalid Dataset_ID is ' + convert(varchar(12), @FirstInvalidDataset)
			RAISERROR (@message, 16, 1)
			ROLLBACK TRANSACTION

		End
	End

GO
/****** Object:  Trigger [dbo].[trig_u_Datasets] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_u_Datasets] on [dbo].[T_Datasets]
For Update
AS
	If @@RowCount = 0
		Return

	if update(Dataset_Process_State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 2, inserted.Dataset_ID, inserted.Dataset_Process_State, deleted.Dataset_Process_State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.Dataset_ID = inserted.Dataset_ID
		ORDER BY inserted.Dataset_ID

GO
ALTER TABLE [dbo].[T_Datasets]  WITH CHECK ADD  CONSTRAINT [FK_T_Datasets_T_Analysis_Description] FOREIGN KEY([SIC_Job])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Datasets] CHECK CONSTRAINT [FK_T_Datasets_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Datasets]  WITH CHECK ADD  CONSTRAINT [FK_T_Datasets_T_Dataset_Process_State] FOREIGN KEY([Dataset_Process_State])
REFERENCES [T_Dataset_Process_State] ([ID])
GO
ALTER TABLE [dbo].[T_Datasets] CHECK CONSTRAINT [FK_T_Datasets_T_Dataset_Process_State]
GO
ALTER TABLE [dbo].[T_Datasets] ADD  CONSTRAINT [DF_T_Datasets_Created]  DEFAULT (getdate()) FOR [Created]
GO
ALTER TABLE [dbo].[T_Datasets] ADD  CONSTRAINT [DF_T_Datasets_Dataset_Process_State]  DEFAULT ((0)) FOR [Dataset_Process_State]
GO
