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
	[Scan_Count] [int] NULL,
	[Created] [datetime] NOT NULL CONSTRAINT [DF_T_Datasets_Created]  DEFAULT (getdate()),
	[Dataset_Process_State] [int] NOT NULL CONSTRAINT [DF_T_Datasets_Dataset_Process_State]  DEFAULT (0),
	[SIC_Job] [int] NULL,
 CONSTRAINT [PK_T_Datasets] PRIMARY KEY CLUSTERED 
(
	[Dataset_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

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
ALTER TABLE [dbo].[T_Datasets]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Datasets_T_Analysis_Description] FOREIGN KEY([SIC_Job])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Datasets] CHECK CONSTRAINT [FK_T_Datasets_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Datasets]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Datasets_T_Dataset_Process_State] FOREIGN KEY([Dataset_Process_State])
REFERENCES [T_Dataset_Process_State] ([ID])
GO
ALTER TABLE [dbo].[T_Datasets] CHECK CONSTRAINT [FK_T_Datasets_T_Dataset_Process_State]
GO
